import express, { NextFunction, Request, Response } from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { Server } from 'socket.io';
import dotenv from 'dotenv';
import { Prisma, PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import jwt, { JwtPayload } from 'jsonwebtoken';
import crypto from 'crypto';
import nodemailer from 'nodemailer';
import { resolveEthiopiaLocation } from './ethiopiaLocations';

dotenv.config();

type AuthPayload = JwtPayload & {
  userId: string;
  email: string;
};

type AuthedRequest = Request & {
  auth?: AuthPayload;
};

const app = express();
// Vercel Functions can serve the Express app, but they cannot host a persistent Socket.IO server.
const isVercelRuntime = process.env.VERCEL === '1';
const httpServer = isVercelRuntime ? null : createServer(app);
const io = httpServer
  ? new Server(httpServer, {
      cors: {
        origin: '*',
        methods: ['GET', 'POST', 'PATCH', 'DELETE'],
      },
    })
  : null;

const prisma = new PrismaClient();
const driverLocationStore = new Map<
  string,
  {
    lat: number;
    lng: number;
    updatedAt: string;
    loadId?: string;
  }
>();
const port = Number(process.env.PORT || 3000);
const jwtSecret = process.env.JWT_SECRET || 'replace-this-jwt-secret';
const bootstrapSuperAdminEmail = process.env.SUPER_ADMIN_EMAIL?.toLowerCase();
const appBaseUrl = process.env.APP_BASE_URL || 'http://localhost:3000';
const appDeepLinkScheme = process.env.APP_DEEPLINK_SCHEME || 'kora';
const smtpHost = process.env.SMTP_HOST;
const smtpPort = Number(process.env.SMTP_PORT || 587);
const smtpUser = process.env.SMTP_USER;
const smtpPass = process.env.SMTP_PASS;
const smtpFrom = process.env.SMTP_FROM || 'no-reply@kora.app';
const corsOrigins = (process.env.CORS_ORIGINS || '*')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

const emitRealtime = (room: string, event: string, payload: unknown) => {
  io?.to(room).emit(event, payload);
};

const broadcastRealtime = (event: string, payload: unknown) => {
  io?.emit(event, payload);
};

app.use(
  cors({
    origin: corsOrigins.includes('*') ? true : corsOrigins,
  }),
);
app.use(express.json());

const getMailer = () => {
  if (!smtpHost || !smtpUser || !smtpPass) {
    return null;
  }
  return nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: smtpPort === 465,
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });
};

const sanitizeUser = (user: {
  id: string;
  email: string;
  name: string;
  username?: string | null;
  phoneNumber?: string | null;
  truckType?: string | null;
  verificationStatus?: string | null;
  userType: string;
  isAdmin: boolean;
  isSuperAdmin: boolean;
}) => ({
  id: user.id,
  email: user.email,
  name: user.name,
  username: user.username ?? null,
  phoneNumber: user.phoneNumber ?? null,
  truckType: user.truckType ?? null,
  verificationStatus: user.verificationStatus ?? 'pending',
  userType: user.userType,
  isAdmin: user.isAdmin,
  isSuperAdmin: user.isSuperAdmin,
});

const asSingleParam = (value: string | string[] | undefined): string =>
  Array.isArray(value) ? value[0] ?? '' : value ?? '';

const signUserToken = (payload: { userId: string; email: string }) =>
  jwt.sign(payload, jwtSecret, { expiresIn: '7d' });

const requireAuth = (req: AuthedRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ ok: false, error: 'Missing bearer token' });
    return;
  }

  const token = authHeader.slice('Bearer '.length).trim();
  try {
    const decoded = jwt.verify(token, jwtSecret) as AuthPayload;
    req.auth = decoded;
    next();
  } catch {
    res.status(401).json({ ok: false, error: 'Invalid or expired token' });
  }
};

const requireAdmin = async (req: AuthedRequest, res: Response, next: NextFunction) => {
  const userId = req.auth?.userId;
  if (!userId) {
    res.status(401).json({ ok: false, error: 'Unauthorized' });
    return;
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { isAdmin: true, isSuperAdmin: true },
  });

  if (!user || (!user.isAdmin && !user.isSuperAdmin)) {
    res.status(403).json({ ok: false, error: 'Admin access required' });
    return;
  }

  next();
};

const requireSuperAdmin = async (req: AuthedRequest, res: Response, next: NextFunction) => {
  const userId = req.auth?.userId;
  if (!userId) {
    res.status(401).json({ ok: false, error: 'Unauthorized' });
    return;
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { isSuperAdmin: true },
  });

  if (!user?.isSuperAdmin) {
    res.status(403).json({ ok: false, error: 'Super admin access required' });
    return;
  }

  next();
};

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'kora-backend', now: new Date().toISOString() });
});

app.post('/api/auth/register', async (req: Request, res: Response) => {
  try {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const password = String(req.body?.password || '');
    const name = String(req.body?.name || '').trim();
    const userType = String(req.body?.userType || 'Cargo').trim();
    const username = String(req.body?.username || '').trim();
    const phoneNumber = String(req.body?.phoneNumber || '').trim();
    const truckType = String(req.body?.truckType || '').trim();

    if (!email || !password || !name) {
      res.status(400).json({ ok: false, error: 'email, password, and name are required' });
      return;
    }

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      res.status(409).json({ ok: false, error: 'Email already exists' });
      return;
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        name,
        userType,
        username: username.length === 0 ? null : username,
        phoneNumber: phoneNumber.length === 0 ? null : phoneNumber,
        truckType: truckType.length === 0 ? null : truckType,
      },
      select: {
        id: true,
        email: true,
        name: true,
        username: true,
        phoneNumber: true,
        truckType: true,
        verificationStatus: true,
        userType: true,
        isAdmin: true,
        isSuperAdmin: true,
      },
    });

    const token = signUserToken({ userId: user.id, email: user.email });
    res.status(201).json({ ok: true, token, user: sanitizeUser(user) });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      const target = Array.isArray(error.meta?.target)
        ? error.meta?.target.join(', ')
        : String(error.meta?.target ?? 'field');
      res.status(409).json({ ok: false, error: `${target} already exists` });
      return;
    }
    const message = error instanceof Error ? error.message : 'Registration failed';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/auth/login', async (req: Request, res: Response) => {
  try {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const password = String(req.body?.password || '');

    const found = await prisma.user.findUnique({ where: { email } });
    if (!found) {
      res.status(401).json({ ok: false, error: 'Invalid credentials' });
      return;
    }

    const valid = await bcrypt.compare(password, found.passwordHash);
    if (!valid) {
      res.status(401).json({ ok: false, error: 'Invalid credentials' });
      return;
    }

    let user = found;

    if (bootstrapSuperAdminEmail && found.email.toLowerCase() === bootstrapSuperAdminEmail) {
      const hasSuperAdmin = await prisma.user.count({ where: { isSuperAdmin: true } });
      if (hasSuperAdmin === 0 || !found.isSuperAdmin) {
        user = await prisma.user.update({
          where: { id: found.id },
          data: { isAdmin: true, isSuperAdmin: true },
        });
      }
    }

    const token = signUserToken({ userId: user.id, email: user.email });
    res.json({
      ok: true,
      token,
      user: sanitizeUser(user),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Login failed';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/auth/forgot-password', async (req: Request, res: Response) => {
  try {
    const email = String(req.body?.email || '').trim().toLowerCase();
    if (!email) {
      res.status(400).json({ ok: false, error: 'email is required' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { email },
      select: { id: true, name: true, email: true },
    });

    // Intentionally return ok even if the email does not exist.
    if (!user) {
      res.json({ ok: true });
      return;
    }

    const mailer = getMailer();
    if (!mailer) {
      res.status(500).json({ ok: false, error: 'Email service not configured' });
      return;
    }

    const rawToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');
    const expiresAt = new Date(Date.now() + 1000 * 60 * 60);

    await prisma.passwordResetToken.create({
      data: {
        userId: user.id,
        tokenHash,
        expiresAt,
      },
    });

    const resetUrl = `${appBaseUrl}/reset-password?token=${rawToken}&email=${encodeURIComponent(
      user.email,
    )}`;
    const deepLinkUrl = `${appDeepLinkScheme}://reset-password?token=${rawToken}&email=${encodeURIComponent(
      user.email,
    )}`;

    await mailer.sendMail({
      to: user.email,
      from: smtpFrom,
      subject: 'Reset your Kora password',
      text:
        `Hi ${user.name},\n\nUse this link to reset your password:\n${resetUrl}\n\n` +
        `If you have the mobile app installed, you can also open:\n${deepLinkUrl}\n\n` +
        `This link expires in 1 hour.`,
    });

    res.json({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to start reset';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/auth/reset-password', async (req: Request, res: Response) => {
  try {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const token = String(req.body?.token || '').trim();
    const newPassword = String(req.body?.password || '');

    if (!email || !token || !newPassword) {
      res.status(400).json({ ok: false, error: 'email, token, and password are required' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { email },
      select: { id: true },
    });
    if (!user) {
      res.status(400).json({ ok: false, error: 'Invalid reset token' });
      return;
    }

    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
    const reset = await prisma.passwordResetToken.findFirst({
      where: {
        userId: user.id,
        tokenHash,
        usedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
      select: { id: true },
    });

    if (!reset) {
      res.status(400).json({ ok: false, error: 'Invalid or expired reset token' });
      return;
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);

    await prisma.$transaction([
      prisma.user.update({
        where: { id: user.id },
        data: { passwordHash },
      }),
      prisma.passwordResetToken.update({
        where: { id: reset.id },
        data: { usedAt: new Date() },
      }),
    ]);

    res.json({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to reset password';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/auth/me', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        name: true,
        username: true,
        phoneNumber: true,
        truckType: true,
        verificationStatus: true,
        userType: true,
        isAdmin: true,
        isSuperAdmin: true,
      },
    });

    if (!user) {
      res.status(404).json({ ok: false, error: 'User not found' });
      return;
    }

    res.json({ ok: true, user: sanitizeUser(user) });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to load user';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/users/:userId/contact', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = asSingleParam(req.params.userId);

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        phoneNumber: true,
      },
    });

    if (!user) {
      res.status(404).json({ ok: false, error: 'User not found' });
      return;
    }

    res.json({ ok: true, user });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to load contact';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/users', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userType = req.query.userType == null ? undefined : String(req.query.userType);
    const limitRaw = req.query.limit == null ? undefined : Number(req.query.limit);
    const limit = Number.isFinite(limitRaw) && (limitRaw as number) > 0
      ? Math.min(limitRaw as number, 100)
      : undefined;

    const users = await prisma.user.findMany({
      where: userType ? { userType } : undefined,
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: {
        id: true,
        name: true,
        email: true,
        username: true,
        userType: true,
        profileImageUrl: true,
        ratingAverage: true,
        ratingCount: true,
      },
    });

    res.json({ ok: true, users });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch users';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/users/:userId', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = asSingleParam(req.params.userId);

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        email: true,
        username: true,
        userType: true,
        profileImageUrl: true,
        bio: true,
        link: true,
        truckType: true,
        licensePlate: true,
        licenseNumber: true,
        tradeLicense: true,
        ratingAverage: true,
        ratingCount: true,
      },
    });

    if (!user) {
      res.status(404).json({ ok: false, error: 'User not found' });
      return;
    }

    res.json({ ok: true, user });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch user';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/users/:userId/threads', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = asSingleParam(req.params.userId);

    const threads = await prisma.thread.findMany({
      where: { ownerId: userId },
      orderBy: { createdAt: 'desc' },
      include: {
        bids: {
          select: {
            id: true,
            amount: true,
            status: true,
            createdAt: true,
          },
        },
      },
    });

    res.json({ ok: true, threads });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch user threads';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/bids/me', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    const bids = await prisma.bid.findMany({
      where: { driverId: userId },
      orderBy: { createdAt: 'desc' },
      include: {
        load: {
          select: {
            id: true,
            ownerId: true,
            message: true,
            start: true,
            end: true,
            weight: true,
            weightUnit: true,
            deliveryStatus: true,
            startLat: true,
            startLng: true,
            endLat: true,
            endLng: true,
            packaging: true,
            type: true,
            createdAt: true,
          },
        },
      },
    });

    res.json({ ok: true, bids });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch your bids';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/telemetry/client', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;
    const type = String(req.body?.type || 'event').trim();
    const feature = String(req.body?.feature || '').trim();
    const name = String(req.body?.name || '').trim();
    const operation = String(req.body?.operation || '').trim();
    const error = req.body?.error == null ? null : String(req.body.error);
    const metadata = req.body?.metadata ?? {};

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    console.log('[client-telemetry]', {
      userId,
      type,
      feature,
      name,
      operation,
      error,
      metadata,
      at: new Date().toISOString(),
    });

    res.status(202).json({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to ingest telemetry';
    res.status(500).json({ ok: false, error: message });
  }
});

app.put('/api/drivers/:driverId/location', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const driverId = asSingleParam(req.params.driverId);
    const userId = req.auth?.userId;
    const latitude = Number(req.body?.latitude);
    const longitude = Number(req.body?.longitude);

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    if (userId !== driverId) {
      const caller = await prisma.user.findUnique({
        where: { id: userId },
        select: { isAdmin: true, isSuperAdmin: true },
      });
      if (!caller || (!caller.isAdmin && !caller.isSuperAdmin)) {
        res.status(403).json({ ok: false, error: 'Forbidden' });
        return;
      }
    }

    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      res.status(400).json({ ok: false, error: 'latitude and longitude are required numbers' });
      return;
    }

    const location = await prisma.driverLocation.upsert({
      where: { driverId },
      update: {
        latitude,
        longitude,
      },
      create: {
        driverId,
        latitude,
        longitude,
      },
      select: {
        driverId: true,
        latitude: true,
        longitude: true,
        updatedAt: true,
      },
    });

    emitRealtime(`tracking_${driverId}`, 'driver_location_changed', {
      driverId,
      latitude: location.latitude,
      longitude: location.longitude,
      updatedAt: location.updatedAt.toISOString(),
    });

    res.json({ ok: true, location });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to update location';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/drivers/:driverId/location', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const driverId = asSingleParam(req.params.driverId);
    const location = await prisma.driverLocation.findUnique({
      where: { driverId },
      select: {
        driverId: true,
        latitude: true,
        longitude: true,
        updatedAt: true,
      },
    });

    res.json({ ok: true, location });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch location';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/threads', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    const startLocation = resolveEthiopiaLocation({
      city: req.body?.startCity ?? req.body?.start,
      zone: req.body?.startZone,
      region: req.body?.startRegion,
      fallback: req.body?.start,
    });
    const endLocation = resolveEthiopiaLocation({
      city: req.body?.endCity ?? req.body?.end,
      zone: req.body?.endZone,
      region: req.body?.endRegion,
      fallback: req.body?.end,
    });

    const thread = await prisma.thread.create({
      data: {
        ownerId: userId,
        message: String(req.body?.message || ''),
        weight: req.body?.weight == null ? null : Number(req.body.weight),
        type: req.body?.type ?? null,
        start: startLocation.city ?? req.body?.start ?? null,
        end: endLocation.city ?? req.body?.end ?? null,
        packaging: req.body?.packaging ?? null,
        weightUnit: req.body?.weightUnit ?? 'kg',
        startLat: req.body?.startLat == null ? null : Number(req.body.startLat),
        startLng: req.body?.startLng == null ? null : Number(req.body.startLng),
        endLat: req.body?.endLat == null ? null : Number(req.body.endLat),
        endLng: req.body?.endLng == null ? null : Number(req.body.endLng),
        deliveryStatus: req.body?.deliveryStatus ?? 'pending',
        startRegion: startLocation.region,
        startZone: startLocation.zone,
        startCity: startLocation.city,
        endRegion: endLocation.region,
        endZone: endLocation.zone,
        endCity: endLocation.city,
      },
    });

    broadcastRealtime('new_thread', thread);
    res.status(201).json({ ok: true, thread });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to create thread';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/threads', async (req: Request, res: Response) => {
  try {
    const limitRaw = req.query.limit == null ? 12 : Number(req.query.limit);
    const offsetRaw = req.query.offset == null ? 0 : Number(req.query.offset);
    const limit = Number.isFinite(limitRaw) && (limitRaw as number) > 0
      ? Math.min(limitRaw as number, 50)
      : 12;
    const offset = Number.isFinite(offsetRaw) && (offsetRaw as number) >= 0
      ? Math.floor(offsetRaw as number)
      : 0;

    const threads = await prisma.thread.findMany({
      include: {
        owner: {
          select: { id: true, name: true, profileImageUrl: true, userType: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      skip: offset,
      take: limit + 1,
    });

    const hasMore = threads.length > limit;
    const items = hasMore ? threads.slice(0, limit) : threads;
    res.json({
      ok: true,
      threads: items,
      pagination: {
        limit,
        offset,
        hasMore,
        nextOffset: hasMore ? offset + items.length : null,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch threads';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/threads/:threadId', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const threadId = asSingleParam(req.params.threadId);
    const thread = await prisma.thread.findUnique({
      where: { id: threadId },
      include: {
        owner: {
          select: { id: true, name: true, profileImageUrl: true, userType: true },
        },
      },
    });

    if (!thread) {
      res.status(404).json({ ok: false, error: 'Thread not found' });
      return;
    }

    res.json({ ok: true, thread });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch thread';
    res.status(500).json({ ok: false, error: message });
  }
});

app.delete('/api/threads/:threadId', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const threadId = asSingleParam(req.params.threadId);
    const userId = req.auth?.userId;

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    const thread = await prisma.thread.findUnique({
      where: { id: threadId },
      select: { id: true, ownerId: true, deliveryStatus: true },
    });

    if (!thread) {
      res.status(404).json({ ok: false, error: 'Thread not found' });
      return;
    }

    if (thread.ownerId !== userId) {
      res.status(403).json({ ok: false, error: 'Only load owner can delete this thread' });
      return;
    }

    const deliveryStatus = String(thread.deliveryStatus || 'pending_bids')
      .trim()
      .toLowerCase();
    if (deliveryStatus !== 'pending_bids') {
      res.status(409).json({
        ok: false,
        error: 'Only loads that are still open for bids can be deleted.',
      });
      return;
    }

    const bidRows = await prisma.bid.findMany({
      where: { loadId: threadId },
      select: { id: true },
    });
    const bidIds = bidRows.map((bid) => bid.id);

    await prisma.$transaction(async (tx) => {
      if (bidIds.length > 0) {
        await tx.driverRating.deleteMany({
          where: { bidId: { in: bidIds } },
        });
      }

      await tx.chatMessage.deleteMany({ where: { threadId } });
      await tx.dispute.deleteMany({ where: { threadId } });
      await tx.comment.deleteMany({ where: { threadId } });
      await tx.bid.deleteMany({ where: { loadId: threadId } });
      await tx.thread.delete({ where: { id: threadId } });
    });

    res.json({ ok: true, deleted: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to delete thread';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/threads/:threadId/bids', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const threadId = asSingleParam(req.params.threadId);

      const bids = await prisma.bid.findMany({
        where: { loadId: threadId },
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          loadId: true,
          driverId: true,
          amount: true,
          status: true,
          note: true,
          createdAt: true,
          updatedAt: true,
          driver: {
            select: {
              id: true,
              name: true,
              profileImageUrl: true,
              ratingAverage: true,
              ratingCount: true,
              phoneNumber: true,
            },
          },
        },
      });

    res.json({ ok: true, bids });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch bids';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/threads/:threadId/chat', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const threadId = asSingleParam(req.params.threadId);

    const messages = await prisma.chatMessage.findMany({
      where: { threadId },
      orderBy: { createdAt: 'desc' },
      take: 100,
      select: {
        id: true,
        threadId: true,
        senderId: true,
        receiverId: true,
        text: true,
        createdAt: true,
      },
    });

    res.json({ ok: true, messages });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch chat messages';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/threads/:threadId/my-bid', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const threadId = asSingleParam(req.params.threadId);
    const userId = req.auth?.userId;

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    const bid = await prisma.bid.findFirst({
      where: {
        loadId: threadId,
        driverId: userId,
      },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        amount: true,
        note: true,
        status: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    res.json({ ok: true, bid });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch your bid';
    res.status(500).json({ ok: false, error: message });
  }
});

app.put('/api/threads/:threadId/my-bid', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const threadId = asSingleParam(req.params.threadId);
    const userId = req.auth?.userId;
    const amount = Number(req.body?.amount);
    const currency = String(req.body?.currency || '').trim();
    const carrierNotes = String(req.body?.carrierNotes || '').trim();

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    if (!Number.isFinite(amount) || amount <= 0) {
      res.status(400).json({ ok: false, error: 'amount must be greater than 0' });
      return;
    }

    const thread = await prisma.thread.findUnique({
      where: { id: threadId },
      select: { id: true, deliveryStatus: true },
    });

    if (!thread) {
      res.status(404).json({ ok: false, error: 'Thread not found' });
      return;
    }

    if ((thread.deliveryStatus ?? 'pending_bids') != 'pending_bids') {
      res.status(409).json({ ok: false, error: 'Bidding is closed for this load.' });
      return;
    }

    const note = JSON.stringify({ currency, carrierNotes });
    const existing = await prisma.bid.findFirst({
      where: {
        loadId: threadId,
        driverId: userId,
      },
      orderBy: { createdAt: 'desc' },
      select: { id: true },
    });

    const bid = existing
      ? await prisma.bid.update({
          where: { id: existing.id },
          data: {
            amount,
            note,
            status: 'pending',
          },
          select: {
            id: true,
            loadId: true,
            driverId: true,
            amount: true,
            note: true,
            status: true,
            createdAt: true,
            updatedAt: true,
          },
        })
      : await prisma.bid.create({
          data: {
            loadId: threadId,
            driverId: userId,
            amount,
            note,
            status: 'pending',
          },
          select: {
            id: true,
            loadId: true,
            driverId: true,
            amount: true,
            note: true,
            status: true,
            createdAt: true,
            updatedAt: true,
          },
        });

    res.json({ ok: true, bid, created: !existing });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to upsert bid';
    res.status(500).json({ ok: false, error: message });
  }
});

app.delete('/api/threads/:threadId/bids/:bidId', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const threadId = asSingleParam(req.params.threadId);
    const bidId = asSingleParam(req.params.bidId);
    const userId = req.auth?.userId;

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    const bid = await prisma.bid.findUnique({
      where: { id: bidId },
      select: { id: true, loadId: true, driverId: true, status: true },
    });

    if (!bid || bid.loadId !== threadId) {
      res.status(404).json({ ok: false, error: 'Bid not found for this thread' });
      return;
    }

    if (bid.driverId !== userId) {
      res.status(403).json({ ok: false, error: 'Only bid owner can delete bid' });
      return;
    }

    if (bid.status.toLowerCase() === 'accepted' || bid.status.toLowerCase() === 'completed') {
      res.status(409).json({ ok: false, error: 'Accepted bids cannot be deleted.' });
      return;
    }

    await prisma.bid.delete({ where: { id: bidId } });
    res.json({ ok: true, deleted: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to delete bid';
    res.status(500).json({ ok: false, error: message });
  }
});

app.patch('/api/threads/:threadId/bids/:bidId/accept', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const threadId = asSingleParam(req.params.threadId);
    const bidId = asSingleParam(req.params.bidId);
    const userId = req.auth?.userId;
    const acceptedCarrierId = String(req.body?.acceptedCarrierId || '').trim();
    const finalPrice = Number(req.body?.finalPrice);
    const closeBidding = Boolean(req.body?.closeBidding);

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    if (!acceptedCarrierId) {
      res.status(400).json({ ok: false, error: 'acceptedCarrierId is required' });
      return;
    }

    if (!Number.isFinite(finalPrice) || finalPrice <= 0) {
      res.status(400).json({ ok: false, error: 'finalPrice must be greater than 0' });
      return;
    }

    const thread = await prisma.thread.findUnique({
      where: { id: threadId },
      select: { id: true, ownerId: true, deliveryStatus: true, message: true },
    });

    if (!thread) {
      res.status(404).json({ ok: false, error: 'Load not found.' });
      return;
    }

    if (thread.ownerId !== userId) {
      res.status(403).json({ ok: false, error: 'Only load owner can accept bids.' });
      return;
    }

    if ((thread.deliveryStatus ?? 'pending_bids') !== 'pending_bids' && closeBidding) {
      res.status(409).json({ ok: false, error: 'Bidding is already closed for this load.' });
      return;
    }

    const winningBid = await prisma.bid.findUnique({
      where: { id: bidId },
      select: { id: true, loadId: true, driverId: true, note: true },
    });

    if (!winningBid || winningBid.loadId !== threadId) {
      res.status(404).json({ ok: false, error: 'Bid no longer exists.' });
      return;
    }

    if (winningBid.driverId !== acceptedCarrierId) {
      res.status(409).json({ ok: false, error: 'acceptedCarrierId does not match winning bid' });
      return;
    }

    const parsedWinningNote = (() => {
      const raw = winningBid.note ? String(winningBid.note) : '';
      if (!raw) return {} as Record<string, unknown>;
      try {
        const candidate = JSON.parse(raw) as unknown;
        if (candidate && typeof candidate === 'object') return candidate as Record<string, unknown>;
        return {} as Record<string, unknown>;
      } catch {
        return { note: raw } as Record<string, unknown>;
      }
    })();

    await prisma.$transaction(async (tx) => {
      await tx.bid.update({
        where: { id: bidId },
        data: {
          status: 'accepted',
          acceptedAt: new Date(),
          note: JSON.stringify({
            ...parsedWinningNote,
            finalPrice,
            acceptedBy: userId,
            acceptedAt: new Date().toISOString(),
          }),
        },
      });

      if (closeBidding) {
        await tx.bid.updateMany({
          where: {
            loadId: threadId,
            id: { not: bidId },
            status: 'pending',
          },
          data: {
            status: 'rejected',
          },
        });

        await tx.thread.update({
          where: { id: threadId },
          data: {
            deliveryStatus: 'accepted',
          },
        });
      }
    });

    const acceptedBid = await prisma.bid.findUnique({
      where: { id: bidId },
      select: {
        id: true,
        loadId: true,
        driverId: true,
        amount: true,
        status: true,
        note: true,
        acceptedAt: true,
      },
    });

    emitRealtime(`tracking_${threadId}`, 'bid_accepted', {
      threadId,
      bidId,
      acceptedCarrierId,
      finalPrice,
      closeBidding,
      at: new Date().toISOString(),
    });

    res.json({ ok: true, bid: acceptedBid });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to accept bid';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/threads/:threadId/chat', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const threadId = asSingleParam(req.params.threadId);
    const senderId = req.auth?.userId;
    const receiverId = req.body?.receiverId == null ? null : String(req.body.receiverId);
    const text = String(req.body?.text || '').trim();

    if (!senderId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    if (!text) {
      res.status(400).json({ ok: false, error: 'text is required' });
      return;
    }

    const message = await prisma.chatMessage.create({
      data: {
        threadId,
        senderId,
        receiverId,
        text,
      },
      select: {
        id: true,
        threadId: true,
        senderId: true,
        receiverId: true,
        text: true,
        createdAt: true,
      },
    });

    emitRealtime(`chat_${threadId}`, 'chat_message_created', message);
    res.status(201).json({ ok: true, message });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to send chat message';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/threads/:threadId/disputes', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const threadId = asSingleParam(req.params.threadId);
    const reporterId = req.auth?.userId;
    const category = String(req.body?.category || '').trim();
    const details = String(req.body?.details || '').trim();

    if (!reporterId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    if (!category) {
      res.status(400).json({ ok: false, error: 'category is required' });
      return;
    }

    const thread = await prisma.thread.findUnique({ where: { id: threadId }, select: { id: true } });
    if (!thread) {
      res.status(404).json({ ok: false, error: 'Thread not found' });
      return;
    }

    const dispute = await prisma.dispute.create({
      data: {
        threadId,
        reporterId,
        category,
        details,
        status: 'open',
      },
      select: {
        id: true,
        threadId: true,
        reporterId: true,
        category: true,
        details: true,
        status: true,
        createdAt: true,
      },
    });

    res.status(201).json({ ok: true, dispute });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to report issue';
    res.status(500).json({ ok: false, error: message });
  }
});

app.patch('/api/threads/:threadId/delivery/status', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const threadId = asSingleParam(req.params.threadId);
    const userId = req.auth?.userId;
    const nextStatus = String(req.body?.nextStatus || '').trim();

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    const flow = ['accepted', 'driving_to_location', 'picked_up', 'on_the_road', 'delivered'];
    if (!flow.includes(nextStatus)) {
      res.status(400).json({ ok: false, error: `Unknown delivery status: ${nextStatus}` });
      return;
    }

    const thread = await prisma.thread.findUnique({
      where: { id: threadId },
      select: { id: true, deliveryStatus: true, ownerId: true },
    });

    if (!thread) {
      res.status(404).json({ ok: false, error: 'Load not found.' });
      return;
    }

    const acceptedBid = await prisma.bid.findFirst({
      where: {
        loadId: threadId,
        driverId: userId,
        status: { in: ['accepted', 'completed'] },
      },
      orderBy: { createdAt: 'desc' },
      select: { id: true },
    });

    if (!acceptedBid) {
      res.status(403).json({ ok: false, error: 'Only the accepted driver can update shipment status.' });
      return;
    }

    const currentStatus = (thread.deliveryStatus ?? 'accepted').toString();
    const currentIndex = flow.indexOf(currentStatus);
    const nextIndex = flow.indexOf(nextStatus);

    if (currentIndex < 0) {
      res.status(409).json({ ok: false, error: `Current status is invalid: ${currentStatus}` });
      return;
    }
    if (nextIndex <= currentIndex) {
      res.status(409).json({ ok: false, error: `Status must move forward. Current: ${currentStatus}` });
      return;
    }
    if (nextIndex != currentIndex + 1) {
      res.status(409).json({ ok: false, error: `Status cannot skip steps. Current: ${currentStatus}` });
      return;
    }

    const updatedThread = await prisma.thread.update({
      where: { id: threadId },
      data: {
        deliveryStatus: nextStatus,
      },
      select: {
        id: true,
        deliveryStatus: true,
      },
    });

    if (nextStatus == 'delivered') {
      await prisma.bid.update({
        where: { id: acceptedBid.id },
        data: {
          status: 'completed',
          completedAt: new Date(),
        },
      });
    }

    emitRealtime(`tracking_${threadId}`, 'delivery_status_changed', {
      threadId,
      from: currentStatus,
      to: nextStatus,
      by: userId,
      at: new Date().toISOString(),
    });

    res.json({ ok: true, thread: updatedThread });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to update delivery status';
    res.status(500).json({ ok: false, error: message });
  }
});

app.patch('/api/threads/:threadId/delivery/complete', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const threadId = asSingleParam(req.params.threadId);
    const userId = req.auth?.userId;
    const bidId = String(req.body?.bidId || '').trim();
    const receiverName = String(req.body?.receiverName || '').trim();
    const deliveryNotes = String(req.body?.deliveryNotes || '').trim();
    const photoUrl = req.body?.photoUrl == null ? null : String(req.body.photoUrl);

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    if (!bidId) {
      res.status(400).json({ ok: false, error: 'bidId is required' });
      return;
    }

    const thread = await prisma.thread.findUnique({
      where: { id: threadId },
      select: { id: true, ownerId: true, deliveryStatus: true },
    });

    if (!thread) {
      res.status(404).json({ ok: false, error: 'Thread not found' });
      return;
    }

    if (thread.ownerId !== userId) {
      res.status(403).json({ ok: false, error: 'Only the load owner can complete delivery' });
      return;
    }

    const bid = await prisma.bid.findUnique({
      where: { id: bidId },
      select: { id: true, loadId: true, driverId: true, note: true },
    });

    if (!bid || bid.loadId !== threadId) {
      res.status(404).json({ ok: false, error: 'Accepted bid not found for this thread' });
      return;
    }

    const allowed = new Set(['accepted', 'driving_to_location', 'picked_up', 'on_the_road']);
    if (!allowed.has((thread.deliveryStatus ?? '').toString())) {
      res.status(409).json({ ok: false, error: 'Delivery cannot be completed from current status' });
      return;
    }

    const proof = {
      receiverName,
      deliveryNotes,
      photoUrl,
      capturedAt: new Date().toISOString(),
      capturedBy: userId,
      bidId,
      driverId: bid.driverId,
    };

    const previousNote = bid.note ? String(bid.note) : '';
    let parsedNote: Record<string, unknown> = {};
    if (previousNote) {
      try {
        const candidate = JSON.parse(previousNote) as unknown;
        if (candidate && typeof candidate === 'object') {
          parsedNote = candidate as Record<string, unknown>;
        }
      } catch {
        parsedNote = { note: previousNote };
      }
    }

    const [updatedThread, updatedBid] = await prisma.$transaction([
      prisma.thread.update({
        where: { id: threadId },
        data: {
          deliveryStatus: 'delivered',
        },
      }),
      prisma.bid.update({
        where: { id: bidId },
        data: {
          status: 'completed',
          completedAt: new Date(),
          note: JSON.stringify({ ...parsedNote, proofOfDelivery: proof }),
        },
      }),
    ]);

    res.json({ ok: true, thread: updatedThread, bid: updatedBid });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to complete delivery';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/users/:driverId/ratings', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const driverId = asSingleParam(req.params.driverId);
    const ownerId = req.auth?.userId;
    const bidId = String(req.body?.bidId || '').trim();
    const rating = Number(req.body?.rating);
    const comment = req.body?.comment == null ? null : String(req.body.comment).trim();

    if (!ownerId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    if (!bidId) {
      res.status(400).json({ ok: false, error: 'bidId is required' });
      return;
    }

    if (!Number.isFinite(rating) || rating < 1 || rating > 5) {
      res.status(400).json({ ok: false, error: 'rating must be between 1 and 5' });
      return;
    }

    const bid = await prisma.bid.findUnique({
      where: { id: bidId },
      include: {
        load: {
          select: {
            ownerId: true,
          },
        },
      },
    });

    if (!bid || bid.driverId !== driverId) {
      res.status(404).json({ ok: false, error: 'Bid not found for driver' });
      return;
    }

    if (bid.load.ownerId !== ownerId) {
      res.status(403).json({ ok: false, error: 'Only the load owner can rate this driver' });
      return;
    }

    await prisma.driverRating.upsert({
      where: { bidId },
      update: {
        rating,
        comment,
      },
      create: {
        driverId,
        ownerId,
        bidId,
        rating,
        comment,
      },
    });

    const aggregate = await prisma.driverRating.aggregate({
      where: { driverId },
      _avg: { rating: true },
      _count: { rating: true },
      _sum: { rating: true },
    });

    const ratingTotal = aggregate._sum.rating ?? 0;
    const ratingCount = aggregate._count.rating;
    const ratingAverage = aggregate._avg.rating ?? 0;

    await prisma.user.update({
      where: { id: driverId },
      data: {
        ratingTotal,
        ratingCount,
        ratingAverage,
      },
    });

    res.status(201).json({
      ok: true,
      summary: {
        driverId,
        ratingTotal,
        ratingCount,
        ratingAverage,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to submit rating';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/telemetry/event', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;
    const feature = String(req.body?.feature || '').trim();
    const name = String(req.body?.name || '').trim();
    const metadata = req.body?.metadata ?? {};

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    console.log('[telemetry:event]', { userId, feature, name, metadata, at: new Date().toISOString() });
    res.status(201).json({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to submit telemetry event';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/telemetry/error', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;
    const feature = String(req.body?.feature || '').trim();
    const operation = String(req.body?.operation || '').trim();
    const errorValue = String(req.body?.error || '').trim();
    const stack = req.body?.stack ?? null;
    const metadata = req.body?.metadata ?? {};

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    console.error('[telemetry:error]', {
      userId,
      feature,
      operation,
      error: errorValue,
      stack,
      metadata,
      at: new Date().toISOString(),
    });

    res.status(201).json({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to submit telemetry error';
    res.status(500).json({ ok: false, error: message });
  }
});

app.put('/api/drivers/:driverId/location', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const driverId = asSingleParam(req.params.driverId);
    const userId = req.auth?.userId;
    const lat = Number(req.body?.latitude);
    const lng = Number(req.body?.longitude);
    const loadId = req.body?.loadId == null ? undefined : String(req.body.loadId);

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    if (userId !== driverId) {
      res.status(403).json({ ok: false, error: 'Only the same driver can update location' });
      return;
    }

    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      res.status(400).json({ ok: false, error: 'latitude and longitude are required numbers' });
      return;
    }

    const payload = {
      lat,
      lng,
      updatedAt: new Date().toISOString(),
      loadId,
    };

    driverLocationStore.set(driverId, payload);
    if (loadId) {
      emitRealtime(`tracking_${loadId}`, 'driver_location_changed', {
        driverId,
        lat,
        lng,
        loadId,
        updatedAt: payload.updatedAt,
      });
    }

    res.json({ ok: true, location: payload });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to update location';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/drivers/:driverId/location', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const driverId = asSingleParam(req.params.driverId);
    const location = driverLocationStore.get(driverId) ?? null;
    res.json({ ok: true, location });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch location';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/admin/dashboard', requireAuth, requireAdmin, async (_req, res) => {
  try {
    const now = new Date();
    const windowStart = new Date(now.getFullYear(), now.getMonth() - 5, 1);

    const [
      userCount,
      driverCount,
      cargoCount,
      adminCount,
      superAdminCount,
      threadCount,
      pendingLoads,
      activeLoads,
      deliveredLoads,
      cancelledLoads,
      bidCount,
      pendingBidCount,
      acceptedBidCount,
      completedBidCount,
      averageBidAmount,
      openDisputes,
      inReviewDisputes,
      resolvedDisputes,
      pendingVerification,
      approvedVerification,
      rejectedVerification,
      routeRows,
      trendRows,
      recentLoads,
    ] = await Promise.all([
      prisma.user.count(),
      prisma.user.count({ where: { userType: 'Driver' } }),
      prisma.user.count({ where: { userType: 'Cargo' } }),
      prisma.user.count({ where: { isAdmin: true } }),
      prisma.user.count({ where: { isSuperAdmin: true } }),
      prisma.thread.count(),
      prisma.thread.count({ where: { deliveryStatus: 'pending_bids' } }),
      prisma.thread.count({
        where: {
          deliveryStatus: {
            in: ['accepted', 'driving_to_location', 'picked_up', 'on_the_road'],
          },
        },
      }),
      prisma.thread.count({ where: { deliveryStatus: 'delivered' } }),
      prisma.thread.count({ where: { deliveryStatus: 'cancelled' } }),
      prisma.bid.count(),
      prisma.bid.count({ where: { status: 'pending' } }),
      prisma.bid.count({ where: { status: 'accepted' } }),
      prisma.bid.count({ where: { status: 'completed' } }),
      prisma.bid.aggregate({ _avg: { amount: true } }),
      prisma.dispute.count({ where: { status: 'open' } }),
      prisma.dispute.count({ where: { status: 'in_review' } }),
      prisma.dispute.count({ where: { status: 'resolved' } }),
      prisma.user.count({ where: { verificationStatus: 'pending' } }),
      prisma.user.count({ where: { verificationStatus: 'approved' } }),
      prisma.user.count({ where: { verificationStatus: 'rejected' } }),
      prisma.thread.findMany({
        select: {
          start: true,
          startCity: true,
          startZone: true,
          startRegion: true,
          end: true,
          endCity: true,
          endZone: true,
          endRegion: true,
          createdAt: true,
        },
      }),
      prisma.thread.findMany({
        where: { createdAt: { gte: windowStart } },
        select: { createdAt: true },
      }),
      prisma.thread.findMany({
        orderBy: { createdAt: 'desc' },
        take: 8,
        select: {
          id: true,
          message: true,
          start: true,
          startCity: true,
          startZone: true,
          startRegion: true,
          end: true,
          endCity: true,
          endZone: true,
          endRegion: true,
          weight: true,
          weightUnit: true,
          deliveryStatus: true,
          createdAt: true,
          owner: {
            select: { id: true, name: true, email: true },
          },
          _count: {
            select: {
              bids: true,
              disputes: true,
            },
          },
          bids: {
            orderBy: { amount: 'desc' },
            take: 1,
            select: {
              amount: true,
              status: true,
            },
          },
        },
      }),
    ]);

    const routeMap = new Map<string, { route: string; count: number }>();
    for (const row of routeRows) {
      const startLocation = resolveEthiopiaLocation({
        city: row.startCity ?? row.start,
        zone: row.startZone,
        region: row.startRegion,
        fallback: row.start,
      });
      const endLocation = resolveEthiopiaLocation({
        city: row.endCity ?? row.end,
        zone: row.endZone,
        region: row.endRegion,
        fallback: row.end,
      });
      const start = startLocation.city ?? 'Unknown origin';
      const end = endLocation.city ?? 'Unknown destination';
      const key = `${start}__${end}`;
      const route = `${start} -> ${end}`;
      const current = routeMap.get(key);
      routeMap.set(key, {
        route,
        count: (current?.count ?? 0) + 1,
      });
    }

    const topRoutes = [...routeMap.values()]
      .sort((a, b) => b.count - a.count)
      .slice(0, 6);

    const monthlyLoads = Array.from({ length: 6 }, (_, index) => {
      const date = new Date(now.getFullYear(), now.getMonth() - (5 - index), 1);
      const label = date.toLocaleString('en-US', {
        month: 'short',
        year: '2-digit',
      });
      return {
        key: `${date.getFullYear()}-${date.getMonth()}`,
        label,
        count: 0,
      };
    });

    const monthlyMap = new Map(monthlyLoads.map((entry) => [entry.key, entry]));
    for (const row of trendRows) {
      const createdAt = new Date(row.createdAt);
      const key = `${createdAt.getFullYear()}-${createdAt.getMonth()}`;
      const target = monthlyMap.get(key);
      if (target) {
        target.count += 1;
      }
    }

    const statusBreakdown = [
      { label: 'Open for bids', count: pendingLoads, tone: 'warning' },
      { label: 'Active delivery', count: activeLoads, tone: 'info' },
      { label: 'Delivered', count: deliveredLoads, tone: 'success' },
      { label: 'Cancelled', count: cancelledLoads, tone: 'danger' },
    ];

    const verificationBreakdown = [
      { label: 'Pending', count: pendingVerification, tone: 'warning' },
      { label: 'Approved', count: approvedVerification, tone: 'success' },
      { label: 'Rejected', count: rejectedVerification, tone: 'danger' },
    ];

    const userMix = [
      { label: 'Cargo', count: cargoCount },
      { label: 'Drivers', count: driverCount },
      { label: 'Admins', count: adminCount },
      { label: 'Super admins', count: superAdminCount },
    ];

    res.json({
      ok: true,
      overview: {
        users: userCount,
        threads: threadCount,
        bids: bidCount,
        averageBidAmount: averageBidAmount._avg.amount ?? 0,
        disputesOpen: openDisputes,
        disputesInReview: inReviewDisputes,
        disputesResolved: resolvedDisputes,
      },
      loadStatus: statusBreakdown,
      verification: verificationBreakdown,
      bidStatus: [
        { label: 'Pending', count: pendingBidCount },
        { label: 'Accepted', count: acceptedBidCount },
        { label: 'Completed', count: completedBidCount },
      ],
      userMix,
      monthlyLoads: monthlyLoads.map(({ label, count }) => ({ label, count })),
      topRoutes,
      recentLoads: recentLoads.map((load) => {
        const startLocation = resolveEthiopiaLocation({
          city: load.startCity ?? load.start,
          zone: load.startZone,
          region: load.startRegion,
          fallback: load.start,
        });
        const endLocation = resolveEthiopiaLocation({
          city: load.endCity ?? load.end,
          zone: load.endZone,
          region: load.endRegion,
          fallback: load.end,
        });
        return {
          id: load.id,
          message: load.message,
          start: startLocation.label || load.start,
          end: endLocation.label || load.end,
          startDisplay: startLocation.label,
          endDisplay: endLocation.label,
          routeDisplay: `${startLocation.label || startLocation.city || 'Unknown origin'} -> ${endLocation.label || endLocation.city || 'Unknown destination'}`,
          startCity: startLocation.city,
          startZone: startLocation.zone,
          startRegion: startLocation.region,
          endCity: endLocation.city,
          endZone: endLocation.zone,
          endRegion: endLocation.region,
          weight: load.weight,
          weightUnit: load.weightUnit,
          deliveryStatus: load.deliveryStatus,
          createdAt: load.createdAt,
          owner: load.owner,
          bidsCount: load._count.bids,
          disputesCount: load._count.disputes,
          bestBidAmount: load.bids[0]?.amount ?? null,
          bestBidStatus: load.bids[0]?.status ?? null,
        };
      }),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch admin dashboard';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/admin/users', requireAuth, requireAdmin, async (req, res) => {
  try {
    const search = String(req.query.search || '').trim();
    const verificationStatus = String(req.query.verificationStatus || '').trim();
    const role = String(req.query.role || '').trim().toLowerCase();
    const limitRaw = Number(req.query.limit ?? 40);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 100) : 40;

    const filters: Prisma.UserWhereInput[] = [];

    if (search) {
      filters.push({
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { email: { contains: search, mode: 'insensitive' } },
          { username: { contains: search, mode: 'insensitive' } },
          { phoneNumber: { contains: search, mode: 'insensitive' } },
        ],
      });
    }

    if (verificationStatus) {
      filters.push({ verificationStatus });
    }

    if (role === 'drivers') {
      filters.push({ userType: 'Driver' });
    } else if (role === 'cargo') {
      filters.push({ userType: 'Cargo' });
    } else if (role === 'admins') {
      filters.push({ isAdmin: true });
    } else if (role === 'superadmins') {
      filters.push({ isSuperAdmin: true });
    }

    const users = await prisma.user.findMany({
      where: filters.length > 0 ? { AND: filters } : undefined,
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: {
        id: true,
        email: true,
        name: true,
        username: true,
        phoneNumber: true,
        truckType: true,
        userType: true,
        verificationStatus: true,
        verificationNote: true,
        isAdmin: true,
        isSuperAdmin: true,
        createdAt: true,
      },
    });

    res.json({ ok: true, users });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch users';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/admin/loads', requireAuth, requireAdmin, async (req, res) => {
  try {
    const search = String(req.query.search || '').trim();
    const status = String(req.query.status || '').trim();
    const limitRaw = Number(req.query.limit ?? 40);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 100) : 40;

    const filters: Prisma.ThreadWhereInput[] = [];

    if (status) {
      filters.push({ deliveryStatus: status });
    }

    if (search) {
      filters.push({
        OR: [
          { message: { contains: search, mode: 'insensitive' } },
          { start: { contains: search, mode: 'insensitive' } },
          { end: { contains: search, mode: 'insensitive' } },
          { startCity: { contains: search, mode: 'insensitive' } },
          { startZone: { contains: search, mode: 'insensitive' } },
          { startRegion: { contains: search, mode: 'insensitive' } },
          { endCity: { contains: search, mode: 'insensitive' } },
          { endZone: { contains: search, mode: 'insensitive' } },
          { endRegion: { contains: search, mode: 'insensitive' } },
          { owner: { is: { name: { contains: search, mode: 'insensitive' } } } },
          { owner: { is: { email: { contains: search, mode: 'insensitive' } } } },
        ],
      });
    }

    const loads = await prisma.thread.findMany({
      where: filters.length > 0 ? { AND: filters } : undefined,
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: {
        id: true,
        message: true,
        start: true,
        startCity: true,
        startZone: true,
        startRegion: true,
        end: true,
        endCity: true,
        endZone: true,
        endRegion: true,
        weight: true,
        weightUnit: true,
        deliveryStatus: true,
        createdAt: true,
        updatedAt: true,
        owner: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
        _count: {
          select: {
            bids: true,
            disputes: true,
          },
        },
        bids: {
          orderBy: { amount: 'desc' },
          take: 1,
          select: {
            id: true,
            amount: true,
            status: true,
          },
        },
      },
    });

    res.json({
      ok: true,
      loads: loads.map((load) => {
        const startLocation = resolveEthiopiaLocation({
          city: load.startCity ?? load.start,
          zone: load.startZone,
          region: load.startRegion,
          fallback: load.start,
        });
        const endLocation = resolveEthiopiaLocation({
          city: load.endCity ?? load.end,
          zone: load.endZone,
          region: load.endRegion,
          fallback: load.end,
        });
        return {
          id: load.id,
          message: load.message,
          start: startLocation.label || load.start,
          end: endLocation.label || load.end,
          startDisplay: startLocation.label,
          endDisplay: endLocation.label,
          routeDisplay: `${startLocation.label || startLocation.city || 'Unknown origin'} -> ${endLocation.label || endLocation.city || 'Unknown destination'}`,
          startCity: startLocation.city,
          startZone: startLocation.zone,
          startRegion: startLocation.region,
          endCity: endLocation.city,
          endZone: endLocation.zone,
          endRegion: endLocation.region,
          weight: load.weight,
          weightUnit: load.weightUnit,
          deliveryStatus: load.deliveryStatus,
          createdAt: load.createdAt,
          updatedAt: load.updatedAt,
          owner: load.owner,
          bidsCount: load._count.bids,
          disputesCount: load._count.disputes,
          bestBidAmount: load.bids[0]?.amount ?? null,
          bestBidStatus: load.bids[0]?.status ?? null,
        };
      }),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch loads';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/admin/users/pending-verification', requireAuth, requireAdmin, async (_req, res) => {
  try {
    const users = await prisma.user.findMany({
      where: { verificationStatus: 'pending' },
      select: {
        id: true,
        email: true,
        name: true,
        userType: true,
        verificationStatus: true,
        verificationNote: true,
      },
      orderBy: { createdAt: 'asc' },
    });

    res.json({ ok: true, users });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch pending users';
    res.status(500).json({ ok: false, error: message });
  }
});

app.patch('/api/admin/users/:userId/verification', requireAuth, requireAdmin, async (req, res) => {
  try {
    const userId = asSingleParam(req.params.userId);
    const status = String(req.body?.status || '').trim();
    const note = req.body?.note == null ? null : String(req.body.note);

    if (!['pending', 'approved', 'rejected'].includes(status)) {
      res.status(400).json({ ok: false, error: 'status must be pending, approved, or rejected' });
      return;
    }

    const updated = await prisma.user.update({
      where: { id: userId },
      data: {
        verificationStatus: status,
        verificationNote: note,
      },
      select: {
        id: true,
        email: true,
        name: true,
        userType: true,
        verificationStatus: true,
        verificationNote: true,
      },
    });

    res.json({ ok: true, user: updated });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to update verification';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/admin/disputes', requireAuth, requireAdmin, async (req, res) => {
  try {
    const status = req.query.status == null ? undefined : String(req.query.status);

    const disputes = await prisma.dispute.findMany({
      where: status ? { status } : undefined,
      orderBy: { createdAt: 'desc' },
      include: {
        thread: { select: { id: true } },
      },
    });

    const normalized = disputes.map((entry) => ({
      id: entry.id,
      threadId: entry.threadId,
      reporterId: entry.reporterId,
      category: entry.category,
      details: entry.details,
      status: entry.status,
      resolutionNote: entry.resolutionNote,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    }));

    res.json({ ok: true, disputes: normalized });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch disputes';
    res.status(500).json({ ok: false, error: message });
  }
});

app.patch('/api/admin/threads/:threadId/disputes/:disputeId', requireAuth, requireAdmin, async (req, res) => {
  try {
    const threadId = asSingleParam(req.params.threadId);
    const disputeId = asSingleParam(req.params.disputeId);
    const status = String(req.body?.status || '').trim();
    const resolutionNote = req.body?.resolutionNote == null ? null : String(req.body.resolutionNote);

    if (!['open', 'in_review', 'resolved'].includes(status)) {
      res.status(400).json({ ok: false, error: 'status must be open, in_review, or resolved' });
      return;
    }

    const exists = await prisma.dispute.findFirst({ where: { id: disputeId, threadId } });
    if (!exists) {
      res.status(404).json({ ok: false, error: 'Dispute not found for thread' });
      return;
    }

    const updated = await prisma.dispute.update({
      where: { id: disputeId },
      data: {
        status,
        resolutionNote,
      },
    });

    res.json({ ok: true, dispute: updated });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to update dispute';
    res.status(500).json({ ok: false, error: message });
  }
});

app.patch('/api/admin/admins/:targetUid/claim', requireAuth, requireSuperAdmin, async (req, res) => {
  try {
    const targetUid = asSingleParam(req.params.targetUid);
    const admin = Boolean(req.body?.admin);
    const superAdmin = Boolean(req.body?.superAdmin);

    if (superAdmin && !admin) {
      res.status(400).json({ ok: false, error: 'superAdmin requires admin=true' });
      return;
    }

    const updated = await prisma.user.update({
      where: { id: targetUid },
      data: {
        isAdmin: admin,
        isSuperAdmin: superAdmin,
      },
      select: {
        id: true,
        email: true,
        name: true,
        isAdmin: true,
        isSuperAdmin: true,
      },
    });

    res.json({ ok: true, user: updated });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to update admin claim';
    res.status(500).json({ ok: false, error: message });
  }
});

if (io) {
  io.on('connection', (socket) => {
    socket.on('join_chat', (threadId: string) => {
      if (!threadId) {
        return;
      }
      socket.join(`chat_${threadId}`);
    });

    socket.on('join_tracking', (loadId: string) => {
      if (!loadId) {
        return;
      }
      socket.join(`tracking_${loadId}`);
    });

    socket.on('update_location', (data: { driverId: string; lat: number; lng: number; loadId: string }) => {
      if (!data?.loadId) {
        return;
      }
      emitRealtime(`tracking_${data.loadId}`, 'driver_location_changed', data);
    });
  });
}

if (httpServer) {
  httpServer.listen(port, () => {
    console.log(`Backend API listening on http://localhost:${port}`);
  });
}

const shutdown = async () => {
  await prisma.$disconnect();
  if (!httpServer) {
    return;
  }
  httpServer.close(() => {
    process.exit(0);
  });
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

export default app;

