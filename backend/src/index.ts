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
import {
  createTelebirrWebCheckout,
  hasTelebirrConfig,
  type TelebirrConfig,
} from './telebirr';

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
const telegramBotToken = process.env.TELEGRAM_BOT_TOKEN;
const telegramBotUsername = process.env.TELEGRAM_BOT_USERNAME?.replace(/^@/, '').trim();
const telegramWebhookSecret = process.env.TELEGRAM_WEBHOOK_SECRET;
const otpSecret = process.env.OTP_SECRET || jwtSecret;
const corsOrigins = (process.env.CORS_ORIGINS || '*')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);
const verificationSubmittedStatuses = ['submitted', 'pending'] as const;
const verificationReviewableStatuses = [
  'not_submitted',
  'submitted',
  'pending',
  'approved',
  'rejected',
] as const;
const walletCurrency = 'ETB';
const topUpMinimumAmount = 10;

const telebirrConfig: TelebirrConfig = {
  baseUrl:
    process.env.TELEBIRR_BASE_URL ||
    'https://developerportal.ethiotelebirr.et:38443/apiaccess/payment/gateway',
  webBaseUrl:
    process.env.TELEBIRR_WEB_BASE_URL ||
    'https://developerportal.ethiotelebirr.et:38443/payment/web/paygate?',
  fabricAppId: process.env.TELEBIRR_FABRIC_APP_ID || '',
  appSecret: process.env.TELEBIRR_APP_SECRET || '',
  merchantAppId: process.env.TELEBIRR_MERCHANT_APP_ID || '',
  merchantCode: process.env.TELEBIRR_MERCHANT_CODE || '',
  privateKey: process.env.TELEBIRR_PRIVATE_KEY || '',
  notifyUrl:
    process.env.TELEBIRR_NOTIFY_URL ||
    `${appBaseUrl.replace(/\/$/, '')}/api/payments/telebirr/notify`,
  redirectUrl:
    process.env.TELEBIRR_REDIRECT_URL ||
    `${appDeepLinkScheme}://wallet/topup-complete`,
};

const verificationUserSelect = {
  id: true,
  email: true,
  name: true,
  username: true,
  phoneNumber: true,
  truckType: true,
  address: true,
  verificationStatus: true,
  verificationNote: true,
  verificationSubmittedAt: true,
  verificationReviewedAt: true,
  userType: true,
  tinNumber: true,
  libre: true,
  licensePlate: true,
  idPhoto: true,
  licenseNumberPhoto: true,
  tradeLicensePhoto: true,
  tradeRegistrationCertificatePhoto: true,
  isAdmin: true,
  isSuperAdmin: true,
} satisfies Prisma.UserSelect;

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
app.use(express.json({ limit: '12mb' }));
app.use(express.urlencoded({ extended: true }));

const toJsonRecord = (value: unknown): Record<string, unknown> => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
};

const stringifyMetadata = (value: unknown) => JSON.stringify(value ?? null);
const asJsonValue = (value: unknown) => value as Prisma.InputJsonValue;

const parseBidNote = (value: unknown): Record<string, unknown> => {
  if (value == null) return {};
  const raw = String(value).trim();
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw) as unknown;
    return toJsonRecord(parsed);
  } catch {
    return { note: raw };
  }
};

const isSuccessStatus = (value: unknown) =>
  ['success', 'completed', 'paid', 'finished'].includes(
    String(value || '').trim().toLowerCase(),
  );

const formatWalletAmount = (value: number) => `${value.toFixed(2)} ${walletCurrency}`;

const ensureWallet = async (userId: string) =>
  prisma.wallet.upsert({
    where: { userId },
    update: {},
    create: {
      userId,
      currency: walletCurrency,
    },
  });

const createNotification = async ({
  userId,
  type,
  title,
  body,
  entityType,
  entityId,
  route,
  metadata,
}: {
  userId: string;
  type: string;
  title: string;
  body: string;
  entityType?: string;
  entityId?: string;
  route?: string;
  metadata?: Prisma.InputJsonValue;
}) => {
  await prisma.appNotification.create({
    data: {
      userId,
      type,
      title,
      body,
      entityType,
      entityId,
      route,
      metadata,
    },
  });
  const unreadCount = await prisma.appNotification.count({
    where: { userId, isRead: false },
  });
  emitRealtime(`user_${userId}`, 'notification_created', {
    userId,
    type,
    title,
    body,
    entityType,
    entityId,
    route,
    unreadCount,
    at: new Date().toISOString(),
  });
};

const createWalletTransaction = async ({
  walletId,
  userId,
  kind,
  direction,
  status = 'completed',
  amount,
  title,
  description,
  referenceType,
  referenceId,
  provider,
  providerRef,
  metadata,
}: {
  walletId: string;
  userId: string;
  kind: string;
  direction: string;
  status?: string;
  amount: number;
  title: string;
  description?: string | null;
  referenceType?: string;
  referenceId?: string;
  provider?: string;
  providerRef?: string;
  metadata?: Prisma.InputJsonValue;
}) =>
  prisma.walletTransaction.create({
    data: {
      walletId,
      userId,
      kind,
      direction,
      status,
      amount,
      currency: walletCurrency,
      title,
      description,
      referenceType,
      referenceId,
      provider,
      providerRef,
      metadata,
    },
  });

const reserveWalletFunds = async ({
  userId,
  amount,
  threadId,
  bidId,
}: {
  userId: string;
  amount: number;
  threadId: string;
  bidId: string;
}) => {
  const wallet = await ensureWallet(userId);
  const availableBalance = wallet.balance - wallet.reservedBalance;
  if (availableBalance < amount) {
    throw new Error(
      `Insufficient wallet balance. Available ${formatWalletAmount(availableBalance)}, required ${formatWalletAmount(amount)}.`,
    );
  }

  const updatedWallet = await prisma.wallet.update({
    where: { id: wallet.id },
    data: { reservedBalance: { increment: amount } },
  });

  await createWalletTransaction({
    walletId: wallet.id,
    userId,
    kind: 'escrow_hold',
    direction: 'hold',
    amount,
    title: 'Funds reserved for accepted load',
    description: 'Reserved from your wallet until delivery is completed.',
    referenceType: 'thread',
    referenceId: threadId,
    metadata: { bidId },
  });

  return updatedWallet;
};

const releaseEscrowToDriver = async ({
  ownerId,
  driverId,
  amount,
  threadId,
  bidId,
}: {
  ownerId: string;
  driverId: string;
  amount: number;
  threadId: string;
  bidId: string;
}) => {
  const [ownerWallet, driverWallet, existingRelease] = await Promise.all([
    ensureWallet(ownerId),
    ensureWallet(driverId),
    prisma.walletTransaction.findFirst({
      where: {
        referenceType: 'bid',
        referenceId: bidId,
        kind: 'settlement_credit',
      },
      select: { id: true },
    }),
  ]);

  if (existingRelease) {
    return { ownerWallet, driverWallet, settled: false };
  }

  if (ownerWallet.reservedBalance < amount) {
    throw new Error('Reserved wallet balance is lower than the settlement amount.');
  }

  const { updatedOwnerWallet, updatedDriverWallet } = await prisma.$transaction(
    async (tx) => {
      const ownerWalletNext = await tx.wallet.update({
        where: { id: ownerWallet.id },
        data: {
          reservedBalance: { decrement: amount },
          balance: { decrement: amount },
        },
      });
      const driverWalletNext = await tx.wallet.update({
        where: { id: driverWallet.id },
        data: {
          balance: { increment: amount },
        },
      });
      await tx.walletTransaction.create({
        data: {
          walletId: ownerWallet.id,
          userId: ownerId,
          kind: 'settlement_release',
          direction: 'debit',
          status: 'completed',
          amount,
          currency: walletCurrency,
          title: 'Delivery settled from escrow',
          description: 'Reserved funds were released to the assigned driver.',
          referenceType: 'bid',
          referenceId: bidId,
          metadata: { threadId, driverId },
        },
      });
      await tx.walletTransaction.create({
        data: {
          walletId: driverWallet.id,
          userId: driverId,
          kind: 'settlement_credit',
          direction: 'credit',
          status: 'completed',
          amount,
          currency: walletCurrency,
          title: 'Delivery earnings received',
          description: 'Funds from the completed load were added to your wallet.',
          referenceType: 'bid',
          referenceId: bidId,
          metadata: { threadId, ownerId },
        },
      });
      return {
        updatedOwnerWallet: ownerWalletNext,
        updatedDriverWallet: driverWalletNext,
      };
    },
  );

  await Promise.all([
    createNotification({
      userId: ownerId,
      type: 'wallet_settlement_released',
      title: 'Delivery payment released',
      body: `Escrow funds for this load were released to the driver.`,
      entityType: 'thread',
      entityId: threadId,
      route: '/wallet',
      metadata: { bidId, amount },
    }),
    createNotification({
      userId: driverId,
      type: 'wallet_settlement_received',
      title: 'Delivery earnings added',
      body: `${formatWalletAmount(amount)} was added to your wallet for the completed load.`,
      entityType: 'thread',
      entityId: threadId,
      route: '/wallet',
      metadata: { bidId, amount },
    }),
  ]);

  return {
    ownerWallet: updatedOwnerWallet,
    driverWallet: updatedDriverWallet,
    settled: true,
  };
};

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

const normalizePhoneNumber = (raw: string) => {
  const trimmed = raw.trim();
  if (!trimmed) return '';
  const leadingPlus = trimmed.startsWith('+');
  const digits = trimmed.replace(/[^0-9]/g, '');
  return leadingPlus ? `+${digits}` : digits;
};

const generateOtp = () => String(crypto.randomInt(1000, 9999));

const hashOtp = (phoneNumber: string, code: string) =>
  crypto.createHash('sha256').update(`${phoneNumber}:${code}:${otpSecret}`).digest('hex');

type TelegramSignupLinkPayload = JwtPayload & {
  purpose: 'telegram_signup_link';
  phoneNumber: string;
};

type SignupPhoneVerificationPayload = JwtPayload & {
  purpose: 'signup_phone_verified';
  phoneNumber: string;
};

const signTelegramSignupLinkToken = (phoneNumber: string) =>
  jwt.sign({ purpose: 'telegram_signup_link', phoneNumber }, otpSecret, { expiresIn: '10m' });

const readTelegramSignupLinkToken = (token: string) => {
  try {
    const payload = jwt.verify(token, otpSecret) as TelegramSignupLinkPayload;
    if (payload.purpose !== 'telegram_signup_link') {
      return null;
    }
    const phoneNumber = normalizePhoneNumber(String(payload.phoneNumber || ''));
    return phoneNumber ? { phoneNumber } : null;
  } catch {
    return null;
  }
};

const signSignupPhoneVerificationToken = (phoneNumber: string) =>
  jwt.sign({ purpose: 'signup_phone_verified', phoneNumber }, otpSecret, { expiresIn: '20m' });

const readSignupPhoneVerificationToken = (token: string) => {
  try {
    const payload = jwt.verify(token, otpSecret) as SignupPhoneVerificationPayload;
    if (payload.purpose !== 'signup_phone_verified') {
      return null;
    }
    const phoneNumber = normalizePhoneNumber(String(payload.phoneNumber || ''));
    return phoneNumber ? { phoneNumber } : null;
  } catch {
    return null;
  }
};

const sendTelegramMessage = async (chatId: string, text: string, replyMarkup?: unknown) => {
  if (!telegramBotToken) {
    throw new Error('Telegram bot token is not configured');
  }
  const res = await fetch(`https://api.telegram.org/bot${telegramBotToken}/sendMessage`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      chat_id: chatId,
      text,
      reply_markup: replyMarkup,
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Telegram send failed: ${res.status} ${body}`);
  }
};

const upsertTelegramContact = async ({
  phoneNumber,
  chatId,
  telegramUserId,
  firstName,
  lastName,
}: {
  phoneNumber: string;
  chatId: string;
  telegramUserId?: string | null;
  firstName?: string | null;
  lastName?: string | null;
}) =>
  prisma.telegramContact.upsert({
    where: { phoneNumber },
    update: {
      chatId,
      telegramUserId: telegramUserId ?? undefined,
      firstName: firstName ?? undefined,
      lastName: lastName ?? undefined,
    },
    create: {
      phoneNumber,
      chatId,
      telegramUserId: telegramUserId ?? undefined,
      firstName: firstName ?? undefined,
      lastName: lastName ?? undefined,
    },
  });

const issueTelegramOtp = async ({
  phoneNumber,
  chatId,
  intro,
}: {
  phoneNumber: string;
  chatId: string;
  intro?: string;
}) => {
  const code = generateOtp();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
  await prisma.phoneOtp.create({
    data: {
      phoneNumber,
      codeHash: hashOtp(phoneNumber, code),
      expiresAt,
    },
  });

  const message = intro?.trim()
    ? `${intro.trim()}\n\nYour verification code is ${code}. It expires in 10 minutes.`
    : `Your verification code is ${code}. It expires in 10 minutes.`;

  await sendTelegramMessage(chatId, message);
};

const sanitizeUser = (user: {
  id: string;
  email: string;
  name: string;
  username?: string | null;
  phoneNumber?: string | null;
  truckType?: string | null;
  address?: string | null;
  verificationStatus?: string | null;
  verificationNote?: string | null;
  verificationSubmittedAt?: Date | null;
  verificationReviewedAt?: Date | null;
  tinNumber?: string | null;
  libre?: string | null;
  licensePlate?: string | null;
  idPhoto?: string | null;
  licenseNumberPhoto?: string | null;
  tradeLicensePhoto?: string | null;
  tradeRegistrationCertificatePhoto?: string | null;
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
  address: user.address ?? null,
  verificationStatus: user.verificationStatus ?? 'not_submitted',
  verificationNote: user.verificationNote ?? null,
  verificationSubmittedAt: user.verificationSubmittedAt?.toISOString() ?? null,
  verificationReviewedAt: user.verificationReviewedAt?.toISOString() ?? null,
  tinNumber: user.tinNumber ?? null,
  libre: user.libre ?? null,
  licensePlate: user.licensePlate ?? null,
  idPhoto: user.idPhoto ?? null,
  licenseNumberPhoto: user.licenseNumberPhoto ?? null,
  tradeLicensePhoto: user.tradeLicensePhoto ?? null,
  tradeRegistrationCertificatePhoto: user.tradeRegistrationCertificatePhoto ?? null,
  userType: user.userType,
  isAdmin: user.isAdmin,
  isSuperAdmin: user.isSuperAdmin,
});

const asSingleParam = (value: string | string[] | undefined): string =>
  Array.isArray(value) ? value[0] ?? '' : value ?? '';

const isVerificationApproved = (status: string | null | undefined) =>
  String(status || '')
    .trim()
    .toLowerCase() === 'approved';

const requiredVerificationMessage = (userType: string) =>
  userType === 'Driver'
    ? 'Complete your verification in Profile > Verification with your TIN number, libre, vehicle plate number, national ID, driver\'s license, and trade licence photo before bidding.'
    : 'Complete your verification in Profile > Verification with your TIN number, national ID, trade registration certificate photo, and trade licence photo before posting loads.';

const getRequiredVerificationDocs = (userType: string) =>
  userType === 'Driver'
    ? ['tin_number', 'libre', 'vehicle_plate_number', 'national_id', 'driver_license', 'trade_licence_photo']
    : ['tin_number', 'national_id', 'trade_registration_certificate_photo', 'trade_licence_photo'];

const requireApprovedVerification = async ({
  userId,
  expectedUserType,
  res,
}: {
  userId: string;
  expectedUserType: 'Cargo' | 'Driver';
  res: Response;
}) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      userType: true,
      verificationStatus: true,
    },
  });

  if (!user) {
    res.status(404).json({ ok: false, error: 'User not found' });
    return null;
  }

  if (user.userType !== expectedUserType) {
    res.status(403).json({ ok: false, error: `Only ${expectedUserType.toLowerCase()} accounts can perform this action.` });
    return null;
  }

  if (!isVerificationApproved(user.verificationStatus)) {
    res.status(403).json({
      ok: false,
      error: requiredVerificationMessage(user.userType),
      code: 'VERIFICATION_REQUIRED',
      verificationStatus: user.verificationStatus ?? 'not_submitted',
      requiredDocuments: getRequiredVerificationDocs(user.userType),
    });
    return null;
  }

  return user;
};

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
    const rawPhone = String(req.body?.phoneNumber || '');
    const phoneNumber = normalizePhoneNumber(rawPhone);
    const password = String(req.body?.password || '');
    const name = String(req.body?.name || '').trim();
    const userType = String(req.body?.userType || 'Cargo').trim();
    const username = String(req.body?.username || '').trim();
    const truckType = String(req.body?.truckType || '').trim();
    const address = String(req.body?.address || '').trim();

    if (!phoneNumber || !password || !name) {
      res.status(400).json({ ok: false, error: 'phoneNumber, password, and name are required' });
      return;
    }

    const existing = await prisma.user.findFirst({
      where: {
        OR: [
          { email: phoneNumber.toLowerCase() },
          { phoneNumber },
        ],
      },
    });
    if (existing) {
      res.status(409).json({ ok: false, error: 'Phone number already exists' });
      return;
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const email = phoneNumber.toLowerCase();
    const user = await prisma.$transaction(async (tx) => {
      const created = await tx.user.create({
        data: {
          email,
          passwordHash,
          name,
          userType,
          username: username.length === 0 ? null : username,
          phoneNumber,
          truckType: truckType.length === 0 ? null : truckType,
          address: address.length === 0 ? null : address,
          verificationStatus: 'not_submitted',
        },
        select: verificationUserSelect,
      });
      await tx.wallet.create({
        data: {
          userId: created.id,
          currency: walletCurrency,
        },
      });
      return created;
    });

    const token = signUserToken({ userId: user.id, email: user.email });
    await createNotification({
      userId: user.id,
      type: 'welcome',
      title: 'Welcome to Kora',
      body:
        user.userType === 'Driver'
          ? 'Complete your verification, explore open loads, and keep an eye on return opportunities.'
          : 'Top up your wallet, post your first load, and manage bids from one place.',
      route: '/profile',
    });
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
    const rawIdentifier = String(req.body?.phoneNumber || req.body?.email || '').trim();
    const phoneNumber = normalizePhoneNumber(rawIdentifier);
    const email = rawIdentifier.toLowerCase();
    const password = String(req.body?.password || '');

    if (!rawIdentifier || !password) {
      res.status(400).json({ ok: false, error: 'phoneNumber/email and password are required' });
      return;
    }

    const found = await prisma.user.findFirst({
      where: {
        OR: [
          ...(phoneNumber.length == 0 ? [] : [{ phoneNumber }]),
          { email },
        ],
      },
    });
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
    const rawPhone = String(req.body?.phoneNumber || '');
    const phoneNumber = normalizePhoneNumber(rawPhone);
    if (!phoneNumber) {
      res.status(400).json({ ok: false, error: 'phoneNumber is required' });
      return;
    }

    const user = await prisma.user.findFirst({
      where: {
        OR: [
          { phoneNumber },
          { email: phoneNumber.toLowerCase() },
        ],
      },
      select: { id: true },
    });

    if (!user) {
      res.status(404).json({ ok: false, error: 'Phone number not found' });
      return;
    }

    const contact = await prisma.telegramContact.findUnique({
      where: { phoneNumber },
      select: { chatId: true },
    });
    if (!contact) {
      res.status(404).json({
        ok: false,
        error: 'Phone number not linked. Ask the user to share it with the bot.',
      });
      return;
    }

    const code = generateOtp();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
    await prisma.phoneOtp.create({
      data: {
        phoneNumber,
        codeHash: hashOtp(phoneNumber, code),
        expiresAt,
      },
    });

    await sendTelegramMessage(
      contact.chatId,
      `Your password reset code is ${code}. It expires in 10 minutes.`,
    );

    res.json({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to start reset';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/auth/reset-password', async (req: Request, res: Response) => {
  try {
    const rawPhone = String(req.body?.phoneNumber || '');
    const phoneNumber = normalizePhoneNumber(rawPhone);
    const code = String(req.body?.code || '').trim();
    const newPassword = String(req.body?.password || '');

    if (!phoneNumber || !code || !newPassword) {
      res.status(400).json({
        ok: false,
        error: 'phoneNumber, code, and password are required',
      });
      return;
    }

    const user = await prisma.user.findFirst({
      where: {
        OR: [
          { phoneNumber },
          { email: phoneNumber.toLowerCase() },
        ],
      },
      select: { id: true },
    });
    if (!user) {
      res.status(400).json({ ok: false, error: 'Invalid reset code' });
      return;
    }

    const reset = await prisma.phoneOtp.findFirst({
      where: {
        phoneNumber,
        codeHash: hashOtp(phoneNumber, code),
        usedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
      select: { id: true },
    });

    if (!reset) {
      res.status(400).json({ ok: false, error: 'Invalid or expired reset code' });
      return;
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);

    await prisma.$transaction([
      prisma.user.update({
        where: { id: user.id },
        data: { passwordHash },
      }),
      prisma.phoneOtp.update({
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
      select: verificationUserSelect,
    });

    if (!user) {
      res.status(404).json({ ok: false, error: 'User not found' });
      return;
    }

    await ensureWallet(user.id);

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
        verificationStatus: true,
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
    const callerId = req.auth?.userId;

    if (!callerId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    const caller = await prisma.user.findUnique({
      where: { id: callerId },
      select: { isAdmin: true, isSuperAdmin: true },
    });
    const includeSensitiveVerification =
      callerId === userId || Boolean(caller?.isAdmin || caller?.isSuperAdmin);

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        email: true,
        phoneNumber: true,
        username: true,
        userType: true,
        profileImageUrl: true,
        bio: true,
        link: true,
        truckType: true,
        address: true,
        licensePlate: true,
        licenseNumber: true,
        libre: true,
        tradeLicense: true,
        tinNumber: true,
        idPhoto: true,
        licenseNumberPhoto: true,
        tradeLicensePhoto: true,
        tradeRegistrationCertificatePhoto: true,
        verificationStatus: true,
        verificationNote: true,
        verificationSubmittedAt: true,
        verificationReviewedAt: true,
        ratingAverage: true,
        ratingCount: true,
      },
    });

    if (!user) {
      res.status(404).json({ ok: false, error: 'User not found' });
      return;
    }

    res.json({
      ok: true,
      user: {
        ...user,
        idPhoto: includeSensitiveVerification ? user.idPhoto : null,
        licenseNumberPhoto: includeSensitiveVerification ? user.licenseNumberPhoto : null,
        tinNumber: includeSensitiveVerification ? user.tinNumber : null,
        libre: includeSensitiveVerification ? user.libre : null,
        tradeLicensePhoto: includeSensitiveVerification ? user.tradeLicensePhoto : null,
        tradeRegistrationCertificatePhoto: includeSensitiveVerification
          ? user.tradeRegistrationCertificatePhoto
          : null,
        verificationNote: includeSensitiveVerification ? user.verificationNote : null,
        verificationSubmittedAt: includeSensitiveVerification
          ? user.verificationSubmittedAt
          : null,
        verificationReviewedAt: includeSensitiveVerification
          ? user.verificationReviewedAt
          : null,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to fetch user';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/notifications/summary', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    const unreadCount = await prisma.appNotification.count({
      where: { userId, isRead: false },
    });

    res.json({ ok: true, unreadCount });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to load notification summary';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/notifications', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;
    const limitRaw = Number(req.query.limit ?? 40);
    const offsetRaw = Number(req.query.offset ?? 0);
    const unreadOnly = String(req.query.unreadOnly || '').trim() === 'true';
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 100) : 40;
    const offset = Number.isFinite(offsetRaw) && offsetRaw >= 0 ? Math.floor(offsetRaw) : 0;

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    const notifications = await prisma.appNotification.findMany({
      where: {
        userId,
        ...(unreadOnly ? { isRead: false } : {}),
      },
      orderBy: { createdAt: 'desc' },
      skip: offset,
      take: limit + 1,
    });

    const unreadCount = await prisma.appNotification.count({
      where: { userId, isRead: false },
    });

    const hasMore = notifications.length > limit;
    const items = hasMore ? notifications.slice(0, limit) : notifications;

    res.json({
      ok: true,
      notifications: items,
      unreadCount,
      pagination: {
        limit,
        offset,
        hasMore,
        nextOffset: hasMore ? offset + items.length : null,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to load notifications';
    res.status(500).json({ ok: false, error: message });
  }
});

app.patch('/api/notifications/:notificationId/read', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;
    const notificationId = asSingleParam(req.params.notificationId);

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    const notification = await prisma.appNotification.findUnique({
      where: { id: notificationId },
      select: { id: true, userId: true, isRead: true },
    });

    if (!notification || notification.userId !== userId) {
      res.status(404).json({ ok: false, error: 'Notification not found' });
      return;
    }

    const updated = notification.isRead
      ? notification
      : await prisma.appNotification.update({
          where: { id: notificationId },
          data: { isRead: true, readAt: new Date() },
        });

    const unreadCount = await prisma.appNotification.count({
      where: { userId, isRead: false },
    });

    res.json({ ok: true, notification: updated, unreadCount });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to update notification';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/notifications/read-all', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    await prisma.appNotification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });

    res.json({ ok: true, unreadCount: 0 });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to mark notifications as read';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/wallet', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    const wallet = await ensureWallet(userId);
    const pendingOrders = await prisma.paymentOrder.findMany({
      where: {
        userId,
        type: 'wallet_topup',
        status: { in: ['pending', 'requires_action'] },
      },
      orderBy: { createdAt: 'desc' },
      take: 6,
      select: {
        id: true,
        type: true,
        status: true,
        provider: true,
        amount: true,
        currency: true,
        checkoutUrl: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    res.json({
      ok: true,
      wallet: {
        ...wallet,
        availableBalance: wallet.balance - wallet.reservedBalance,
      },
      pendingOrders,
      telebirrConfigured: hasTelebirrConfig(telebirrConfig),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to load wallet';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/wallet/transactions', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;
    const limitRaw = Number(req.query.limit ?? 40);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 100) : 40;

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    await ensureWallet(userId);
    const transactions = await prisma.walletTransaction.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    res.json({ ok: true, transactions });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to load wallet transactions';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/wallet/topups', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;
    const amount = Number(req.body?.amount);

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    if (!Number.isFinite(amount) || amount < topUpMinimumAmount) {
      res.status(400).json({
        ok: false,
        error: `amount must be at least ${topUpMinimumAmount} ${walletCurrency}`,
      });
      return;
    }

    if (!hasTelebirrConfig(telebirrConfig)) {
      res.status(503).json({
        ok: false,
        error: 'Telebirr is not configured yet. Add merchant credentials on the backend first.',
      });
      return;
    }

    const wallet = await ensureWallet(userId);
    const merchOrderId = `KORA-${Date.now()}-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
    const checkout = await createTelebirrWebCheckout({
      config: telebirrConfig,
      title: 'Kora wallet top-up',
      amount,
      merchOrderId,
      metadata: {
        short_code: telebirrConfig.merchantCode,
      },
    });

    const order = await prisma.paymentOrder.create({
      data: {
        userId,
        walletId: wallet.id,
        type: 'wallet_topup',
        status: 'requires_action',
        provider: 'telebirr',
        amount,
        currency: walletCurrency,
        merchOrderId: checkout.merchOrderId,
        providerOrderId: checkout.merchOrderId,
        prepayId: checkout.prepayId,
        checkoutUrl: checkout.checkoutUrl,
        rawRequest: checkout.rawRequest,
        providerPayload: asJsonValue(toJsonRecord(checkout.providerPayload)),
      },
    });

    await createWalletTransaction({
      walletId: wallet.id,
      userId,
      kind: 'topup_initiated',
      direction: 'pending',
      status: 'pending',
      amount,
      title: 'Wallet top-up started',
      description: 'Complete the Telebirr checkout to add funds to your wallet.',
      referenceType: 'payment_order',
      referenceId: order.id,
      provider: 'telebirr',
      providerRef: checkout.prepayId,
      metadata: asJsonValue({ merchOrderId }),
    });

    await createNotification({
      userId,
      type: 'wallet_topup_started',
      title: 'Wallet top-up started',
      body: `Continue in Telebirr to add ${formatWalletAmount(amount)} to your wallet.`,
      entityType: 'payment_order',
      entityId: order.id,
      route: '/wallet',
      metadata: asJsonValue({ checkoutUrl: checkout.checkoutUrl }),
    });

    res.status(201).json({ ok: true, order });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to create top-up order';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/payments/:orderId', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;
    const orderId = asSingleParam(req.params.orderId);

    if (!userId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    const order = await prisma.paymentOrder.findUnique({
      where: { id: orderId },
    });

    if (!order || order.userId !== userId) {
      res.status(404).json({ ok: false, error: 'Payment order not found' });
      return;
    }

    res.json({ ok: true, order });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to load payment order';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/payments/telebirr/notify', async (req: Request, res: Response) => {
  try {
    const payload = {
      ...toJsonRecord(req.body),
      ...(req.query ? Object.fromEntries(Object.entries(req.query)) : {}),
    };
    const bizContent = toJsonRecord(payload.biz_content);
    const merchOrderId = String(
      payload.merch_order_id ??
        payload.merchOrderId ??
        payload.out_trade_no ??
        bizContent.merch_order_id ??
        bizContent.merchOrderId ??
        '',
    ).trim();

    if (!merchOrderId) {
      res.status(400).json({ ok: false, error: 'merch_order_id is required' });
      return;
    }

    const order = await prisma.paymentOrder.findUnique({
      where: { merchOrderId },
    });

    if (!order) {
      res.status(404).json({ ok: false, error: 'Payment order not found' });
      return;
    }

    const statusSource =
      payload.trade_status ??
      payload.status ??
      payload.order_status ??
      bizContent.trade_status ??
      bizContent.status ??
      bizContent.order_status;

    const succeeded =
      isSuccessStatus(statusSource) ||
      isSuccessStatus(payload.result) ||
      String(payload.code || bizContent.code || '').trim() === '0';

    const wallet = order.walletId
      ? await prisma.wallet.findUnique({ where: { id: order.walletId } })
      : null;

    if (succeeded && order.status !== 'completed' && wallet) {
      await prisma.$transaction(async (tx) => {
        await tx.paymentOrder.update({
          where: { id: order.id },
          data: {
            status: 'completed',
            completedAt: new Date(),
            providerPayload: asJsonValue(payload),
          },
        });
        await tx.wallet.update({
          where: { id: wallet.id },
          data: { balance: { increment: order.amount } },
        });
        await tx.walletTransaction.updateMany({
          where: {
            referenceType: 'payment_order',
            referenceId: order.id,
            kind: 'topup_initiated',
          },
          data: { status: 'completed' },
        });
        await tx.walletTransaction.create({
          data: {
            walletId: wallet.id,
            userId: order.userId,
            kind: 'topup_completed',
            direction: 'credit',
            status: 'completed',
            amount: order.amount,
            currency: walletCurrency,
            title: 'Telebirr top-up completed',
            description: 'Your wallet balance was updated after a successful Telebirr payment.',
            referenceType: 'payment_order',
            referenceId: order.id,
            provider: 'telebirr',
            providerRef: order.prepayId ?? order.providerOrderId ?? undefined,
            metadata: asJsonValue(payload),
          },
        });
      });

      await createNotification({
        userId: order.userId,
        type: 'wallet_topup_completed',
        title: 'Wallet top-up completed',
        body: `${formatWalletAmount(order.amount)} was added to your wallet.`,
        entityType: 'payment_order',
        entityId: order.id,
        route: '/wallet',
      });
    } else if (!succeeded && order.status !== 'completed') {
      await prisma.paymentOrder.update({
        where: { id: order.id },
        data: {
          status: 'failed',
          failureReason: stringifyMetadata(payload),
          providerPayload: asJsonValue(payload),
        },
      });
    }

    res.json({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to process Telebirr notification';
    res.status(500).json({ ok: false, error: message });
  }
});

app.put('/api/users/:userId/verification-documents', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = asSingleParam(req.params.userId);
    const callerId = req.auth?.userId;
    const tinNumber = String(req.body?.tinNumber || '').trim();
    const libre = String(req.body?.libre || '').trim();
    const vehiclePlateNumber = String(req.body?.vehiclePlateNumber || '').trim();
    const nationalIdPhoto = String(req.body?.nationalIdPhoto || '').trim();
    const driverLicensePhoto = String(req.body?.driverLicensePhoto || '').trim();
    const tradeLicensePhoto = String(req.body?.tradeLicensePhoto || '').trim();
    const tradeRegistrationCertificatePhoto = String(
      req.body?.tradeRegistrationCertificatePhoto || '',
    ).trim();
    const submitForReview = Boolean(req.body?.submitForReview);

    if (!callerId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    if (callerId !== userId) {
      res.status(403).json({ ok: false, error: 'You can only update your own verification documents.' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        userType: true,
        verificationStatus: true,
        verificationNote: true,
        verificationSubmittedAt: true,
        verificationReviewedAt: true,
      },
    });

    if (!user) {
      res.status(404).json({ ok: false, error: 'User not found' });
      return;
    }

    if (submitForReview) {
      if (!nationalIdPhoto) {
        res.status(400).json({ ok: false, error: 'National ID is required before submission.' });
        return;
      }

      if (!tinNumber) {
        res.status(400).json({ ok: false, error: 'TIN number is required before submission.' });
        return;
      }

      if (!tradeLicensePhoto) {
        res.status(400).json({ ok: false, error: 'Trade licence photo is required before submission.' });
        return;
      }

      if (user.userType === 'Driver') {
        if (!libre) {
          res.status(400).json({ ok: false, error: 'Libre is required before submission.' });
          return;
        }

        if (!vehiclePlateNumber) {
          res.status(400).json({ ok: false, error: 'Vehicle plate number is required before submission.' });
          return;
        }

        if (!driverLicensePhoto) {
          res.status(400).json({ ok: false, error: 'Driver\'s license is required before submission.' });
          return;
        }
      } else if (!tradeRegistrationCertificatePhoto) {
        res.status(400).json({
          ok: false,
          error: 'Trade registration certificate photo is required before submission.',
        });
        return;
      }
    }

    const shouldKeepApproved = isVerificationApproved(user.verificationStatus) && !submitForReview;
    const nextStatus = submitForReview
      ? 'submitted'
      : shouldKeepApproved
          ? 'approved'
          : 'not_submitted';

    const updated = await prisma.user.update({
      where: { id: userId },
      data: {
        tinNumber: tinNumber || null,
        libre: user.userType === 'Driver' ? (libre || null) : null,
        licensePlate: user.userType === 'Driver' ? (vehiclePlateNumber || null) : null,
        idPhoto: nationalIdPhoto || null,
        licenseNumberPhoto: user.userType === 'Driver'
          ? (driverLicensePhoto || null)
          : null,
        tradeLicensePhoto: tradeLicensePhoto || null,
        tradeRegistrationCertificatePhoto: user.userType === 'Cargo'
          ? (tradeRegistrationCertificatePhoto || null)
          : null,
        verificationStatus: nextStatus,
        verificationNote: submitForReview
          ? 'Submitted for admin review'
          : shouldKeepApproved
              ? user.verificationNote
              : null,
        verificationSubmittedAt: submitForReview
          ? new Date()
          : shouldKeepApproved
              ? user.verificationSubmittedAt
              : null,
        verificationReviewedAt: submitForReview
          ? null
          : shouldKeepApproved
              ? user.verificationReviewedAt
              : null,
      },
      select: verificationUserSelect,
    });

    await createNotification({
      userId,
      type: submitForReview ? 'verification_submitted' : 'verification_saved',
      title: submitForReview ? 'Verification submitted' : 'Verification draft updated',
      body: submitForReview
        ? 'Your documents were sent for admin review.'
        : 'Your verification details were saved. Submit them when you are ready.',
      route: '/profile',
    });

    res.json({ ok: true, user: sanitizeUser(updated) });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to update verification documents';
    res.status(500).json({ ok: false, error: message });
  }
});

app.get('/api/users/:userId/threads', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const userId = asSingleParam(req.params.userId);
    const limitRaw = Number(req.query.limit ?? 20);
    const offsetRaw = Number(req.query.offset ?? 0);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 50) : 20;
    const offset = Number.isFinite(offsetRaw) && offsetRaw >= 0 ? Math.floor(offsetRaw) : 0;

    const threads = await prisma.thread.findMany({
      where: { ownerId: userId },
      orderBy: { createdAt: 'desc' },
      skip: offset,
      take: limit + 1,
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

    const limitRaw = Number(req.query.limit ?? 20);
    const offsetRaw = Number(req.query.offset ?? 0);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 50) : 20;
    const offset = Number.isFinite(offsetRaw) && offsetRaw >= 0 ? Math.floor(offsetRaw) : 0;

    const bids = await prisma.bid.findMany({
      where: { driverId: userId },
      orderBy: { createdAt: 'desc' },
      skip: offset,
      take: limit + 1,
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

    const hasMore = bids.length > limit;
    const items = hasMore ? bids.slice(0, limit) : bids;

    res.json({
      ok: true,
      bids: items,
      pagination: {
        limit,
        offset,
        hasMore,
        nextOffset: hasMore ? offset + items.length : null,
      },
    });
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

    const verifiedCargoUser = await requireApprovedVerification({
      userId,
      expectedUserType: 'Cargo',
      res,
    });
    if (!verifiedCargoUser) {
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
        ownerId: verifiedCargoUser.id,
        message: String(req.body?.message || ''),
        weight: req.body?.weight == null ? null : Number(req.body.weight),
        category: req.body?.category ?? null,
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

app.get('/api/threads/:threadId/return-load-suggestions', requireAuth, async (req: AuthedRequest, res: Response) => {
  try {
    const threadId = asSingleParam(req.params.threadId);
    const limitRaw = Number(req.query.limit ?? 8);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 20) : 8;

    const thread = await prisma.thread.findUnique({
      where: { id: threadId },
      select: {
        id: true,
        start: true,
        end: true,
        endCity: true,
        endZone: true,
        endRegion: true,
      },
    });

    if (!thread) {
      res.status(404).json({ ok: false, error: 'Thread not found' });
      return;
    }

    const destination = resolveEthiopiaLocation({
      city: thread.endCity ?? thread.end,
      zone: thread.endZone,
      region: thread.endRegion,
      fallback: thread.end,
    });
    const destinationCity = (destination.city || thread.end || '').trim();
    if (!destinationCity) {
      res.json({ ok: true, suggestions: [] });
      return;
    }

    const suggestions = await prisma.thread.findMany({
      where: {
        id: { not: threadId },
        deliveryStatus: 'pending_bids',
        OR: [
          { startCity: { equals: destinationCity, mode: 'insensitive' } },
          { start: { contains: destinationCity, mode: 'insensitive' } },
        ],
      },
      include: {
        owner: {
          select: { id: true, name: true, profileImageUrl: true, userType: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    res.json({ ok: true, suggestions });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to load return suggestions';
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

    const verifiedDriver = await requireApprovedVerification({
      userId,
      expectedUserType: 'Driver',
      res,
    });
    if (!verifiedDriver) {
      return;
    }

    if (!Number.isFinite(amount) || amount <= 0) {
      res.status(400).json({ ok: false, error: 'amount must be greater than 0' });
      return;
    }

    const thread = await prisma.thread.findUnique({
      where: { id: threadId },
      select: {
        id: true,
        deliveryStatus: true,
        ownerId: true,
        start: true,
        end: true,
      },
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
        driverId: verifiedDriver.id,
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
            driverId: verifiedDriver.id,
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

    await createNotification({
      userId: thread.ownerId,
      type: existing ? 'bid_updated' : 'bid_received',
      title: existing ? 'A bid was updated' : 'A new bid arrived',
      body: existing
        ? `A driver updated their offer for ${thread.start || 'this load'} -> ${thread.end || 'destination'}.`
        : `A driver placed a bid for ${thread.start || 'this load'} -> ${thread.end || 'destination'}.`,
      entityType: 'thread',
      entityId: threadId,
      route: `/loads/${threadId}`,
      metadata: { bidId: bid.id, amount },
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
      select: {
        id: true,
        ownerId: true,
        deliveryStatus: true,
        message: true,
        start: true,
        end: true,
      },
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

    const ownerWallet = await ensureWallet(thread.ownerId);
    const availableBalance = ownerWallet.balance - ownerWallet.reservedBalance;
    if (availableBalance < finalPrice) {
      res.status(409).json({
        ok: false,
        error: `Insufficient wallet balance. Available ${formatWalletAmount(availableBalance)}, required ${formatWalletAmount(finalPrice)}.`,
        code: 'WALLET_TOPUP_REQUIRED',
        wallet: {
          balance: ownerWallet.balance,
          reservedBalance: ownerWallet.reservedBalance,
          availableBalance,
          currency: walletCurrency,
        },
      });
      return;
    }

    const otherPendingBids = await prisma.bid.findMany({
      where: {
        loadId: threadId,
        id: { not: bidId },
        status: 'pending',
      },
      select: { id: true, driverId: true },
    });

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
      await tx.wallet.update({
        where: { id: ownerWallet.id },
        data: {
          reservedBalance: { increment: finalPrice },
        },
      });
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
      await tx.walletTransaction.create({
        data: {
          walletId: ownerWallet.id,
          userId: thread.ownerId,
          kind: 'escrow_hold',
          direction: 'hold',
          status: 'completed',
          amount: finalPrice,
          currency: walletCurrency,
          title: 'Funds reserved for accepted load',
          description: 'The accepted load amount was held from your wallet until delivery is completed.',
          referenceType: 'bid',
          referenceId: bidId,
          metadata: { threadId, driverId: acceptedCarrierId },
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

    await Promise.all([
      createNotification({
        userId: acceptedCarrierId,
        type: 'bid_accepted',
        title: 'Your bid was accepted',
        body: `You won the load from ${thread.start || 'pickup'} to ${thread.end || 'destination'}.`,
        entityType: 'thread',
        entityId: threadId,
        route: `/loads/${threadId}`,
        metadata: { bidId, finalPrice },
      }),
      createNotification({
        userId: thread.ownerId,
        type: 'wallet_escrow_held',
        title: 'Funds reserved for this load',
        body: `${formatWalletAmount(finalPrice)} was reserved from your wallet for the accepted bid.`,
        entityType: 'thread',
        entityId: threadId,
        route: '/wallet',
        metadata: { bidId },
      }),
      ...otherPendingBids.map((entry) =>
        createNotification({
          userId: entry.driverId,
          type: 'bid_rejected',
          title: 'Another bid was selected',
          body: `The load from ${thread.start || 'pickup'} to ${thread.end || 'destination'} has been awarded to another driver.`,
          entityType: 'thread',
          entityId: threadId,
          route: `/loads/${threadId}`,
          metadata: { bidId: entry.id },
        }),
      ),
    ]);

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
    let receiverId = req.body?.receiverId == null ? null : String(req.body.receiverId);
    const text = String(req.body?.text || '').trim();

    if (!senderId) {
      res.status(401).json({ ok: false, error: 'Unauthorized' });
      return;
    }

    if (!text) {
      res.status(400).json({ ok: false, error: 'text is required' });
      return;
    }

    if (!receiverId) {
      const thread = await prisma.thread.findUnique({
        where: { id: threadId },
        select: { ownerId: true },
      });
      if (thread) {
        if (thread.ownerId !== senderId) {
          receiverId = thread.ownerId;
        } else {
          const acceptedBid = await prisma.bid.findFirst({
            where: { loadId: threadId, status: { in: ['accepted', 'completed'] } },
            orderBy: { createdAt: 'desc' },
            select: { driverId: true },
          });
          receiverId = acceptedBid?.driverId ?? null;
        }
      }
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

    if (receiverId && receiverId !== senderId) {
      await createNotification({
        userId: receiverId,
        type: 'chat_message',
        title: 'New message on a load',
        body: text.length > 90 ? `${text.slice(0, 87)}...` : text,
        entityType: 'thread',
        entityId: threadId,
        route: `/loads/${threadId}`,
      });
    }

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
      select: { id: true, driverId: true, amount: true, note: true },
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

      const note = parseBidNote(acceptedBid.note);
      const finalPrice = Number(note.finalPrice ?? acceptedBid.amount);
      if (Number.isFinite(finalPrice) && finalPrice > 0) {
        await releaseEscrowToDriver({
          ownerId: thread.ownerId,
          driverId: acceptedBid.driverId,
          amount: finalPrice,
          threadId,
          bidId: acceptedBid.id,
        });
      }
    }

    emitRealtime(`tracking_${threadId}`, 'delivery_status_changed', {
      threadId,
      from: currentStatus,
      to: nextStatus,
      by: userId,
      at: new Date().toISOString(),
    });

    await createNotification({
      userId: thread.ownerId,
      type: 'delivery_status_changed',
      title: 'Delivery status updated',
      body: `The driver moved this load from ${currentStatus.replace(/_/g, ' ')} to ${nextStatus.replace(/_/g, ' ')}.`,
      entityType: 'thread',
      entityId: threadId,
      route: `/loads/${threadId}`,
      metadata: { from: currentStatus, to: nextStatus },
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

    const allowed = new Set(['accepted', 'driving_to_location', 'picked_up', 'on_the_road', 'delivered']);
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

    const finalPrice = Number(parsedNote.finalPrice);
    if (Number.isFinite(finalPrice) && finalPrice > 0) {
      await releaseEscrowToDriver({
        ownerId: thread.ownerId,
        driverId: bid.driverId,
        amount: finalPrice,
        threadId,
        bidId,
      });
    }

    await createNotification({
      userId: bid.driverId,
      type: 'delivery_confirmed',
      title: 'Delivery confirmed',
      body: 'The load owner confirmed delivery and attached proof of delivery details.',
      entityType: 'thread',
      entityId: threadId,
      route: `/loads/${threadId}`,
      metadata: { bidId },
    });

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

    await createNotification({
      userId: driverId,
      type: 'driver_rated',
      title: 'You received a new rating',
      body: comment != null && comment.trim().length > 0
        ? `A load owner rated you ${rating}/5 and left a note.`
        : `A load owner rated you ${rating}/5.`,
      route: '/profile',
      metadata: asJsonValue({ bidId, rating }),
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
      notSubmittedVerification,
      submittedVerification,
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
      prisma.user.count({ where: { verificationStatus: 'not_submitted' } }),
      prisma.user.count({ where: { verificationStatus: { in: [...verificationSubmittedStatuses] } } }),
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
      const start = startLocation.city ?? 'Unknown departure';
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
      { label: 'Not submitted', count: notSubmittedVerification, tone: 'neutral' },
      { label: 'In review', count: submittedVerification, tone: 'warning' },
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
          routeDisplay: `${startLocation.label || startLocation.city || 'Unknown departure'} -> ${endLocation.label || endLocation.city || 'Unknown destination'}`,
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
      if (verificationStatus === 'submitted') {
        filters.push({
          verificationStatus: {
            in: [...verificationSubmittedStatuses],
          },
        });
      } else {
        filters.push({ verificationStatus });
      }
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
        address: true,
        userType: true,
        verificationStatus: true,
        verificationNote: true,
        verificationSubmittedAt: true,
        verificationReviewedAt: true,
        tinNumber: true,
        libre: true,
        licensePlate: true,
        idPhoto: true,
        licenseNumberPhoto: true,
        tradeLicensePhoto: true,
        tradeRegistrationCertificatePhoto: true,
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
          routeDisplay: `${startLocation.label || startLocation.city || 'Unknown departure'} -> ${endLocation.label || endLocation.city || 'Unknown destination'}`,
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
      where: {
        verificationStatus: {
          in: [...verificationSubmittedStatuses],
        },
      },
      select: {
        id: true,
        email: true,
        name: true,
        phoneNumber: true,
        userType: true,
        verificationStatus: true,
        verificationNote: true,
        verificationSubmittedAt: true,
        verificationReviewedAt: true,
        tinNumber: true,
        libre: true,
        licensePlate: true,
        idPhoto: true,
        licenseNumberPhoto: true,
        tradeLicensePhoto: true,
        tradeRegistrationCertificatePhoto: true,
      },
      orderBy: { verificationSubmittedAt: 'asc' },
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

    if (!verificationReviewableStatuses.includes(status as (typeof verificationReviewableStatuses)[number])) {
      res.status(400).json({ ok: false, error: 'status must be not_submitted, submitted, approved, or rejected' });
      return;
    }

    const updated = await prisma.user.update({
      where: { id: userId },
      data: {
        verificationStatus: status,
        verificationNote: note,
        verificationReviewedAt: status === 'approved' || status === 'rejected'
          ? new Date()
          : null,
      },
      select: {
        id: true,
        email: true,
        name: true,
        userType: true,
        verificationStatus: true,
        verificationNote: true,
        verificationSubmittedAt: true,
        verificationReviewedAt: true,
        tinNumber: true,
        libre: true,
        licensePlate: true,
        idPhoto: true,
        licenseNumberPhoto: true,
        tradeLicensePhoto: true,
        tradeRegistrationCertificatePhoto: true,
      },
    });

    await createNotification({
      userId: updated.id,
      type: `verification_${status}`,
      title:
        status === 'approved'
          ? 'Verification approved'
          : status === 'rejected'
            ? 'Verification needs attention'
            : 'Verification updated',
      body:
        status === 'approved'
          ? 'Your account is now approved for marketplace actions.'
          : status === 'rejected'
            ? note?.trim() || 'Review the feedback and resubmit your documents.'
            : `Your verification status is now ${status}.`,
      route: '/profile',
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

app.post('/api/admin/users/:userId/wallet/topups', requireAuth, requireSuperAdmin, async (req, res) => {
  try {
    const rawIdentifier = asSingleParam(req.params.userId);
    const amount = Number(req.body?.amount ?? 0);
    const note = req.body?.note == null ? null : String(req.body.note).trim();

    if (!Number.isFinite(amount) || amount <= 0) {
      res.status(400).json({ ok: false, error: 'amount must be greater than zero' });
      return;
    }

    let user = await prisma.user.findUnique({ where: { id: rawIdentifier } });
    if (!user) {
      const normalizedPhone = normalizePhoneNumber(rawIdentifier);
      if (normalizedPhone) {
        const digitsOnly = normalizedPhone.startsWith('+') ? normalizedPhone.slice(1) : normalizedPhone;
        user = await prisma.user.findFirst({
          where: {
            OR: [
              { phoneNumber: normalizedPhone },
              { phoneNumber: digitsOnly },
            ],
          },
        });
      }
    }

    if (!user) {
      res.status(404).json({ ok: false, error: 'User not found by UID or phone number' });
      return;
    }

    const wallet = await ensureWallet(user.id);
    const updatedWallet = await prisma.wallet.update({
      where: { id: wallet.id },
      data: { balance: { increment: amount } },
    });

    await createWalletTransaction({
      walletId: wallet.id,
      userId: user.id,
      kind: 'manual_credit',
      direction: 'credit',
      status: 'completed',
      amount,
      title: 'Manual wallet top-up',
      description: note || 'Funds added by super admin.',
    });

    await createNotification({
      userId: user.id,
      type: 'wallet_manual_topup',
      title: 'Wallet funds added',
      body: `${formatWalletAmount(amount)} was added to your wallet by a super admin.`, 
      route: '/wallet',
    });

    res.json({
      ok: true,
      wallet: {
        ...updatedWallet,
        availableBalance: updatedWallet.balance - updatedWallet.reservedBalance,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to add wallet funds';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/telegram/webhook', async (req: Request, res: Response) => {
  try {
    const provided =
      req.headers['x-telegram-bot-api-secret-token'] ??
      req.headers['x-telegram-bot-api-secret-token'.toLowerCase()];
    if (telegramWebhookSecret) {
      const token = Array.isArray(provided) ? provided[0] : provided;
      if (!token || token !== telegramWebhookSecret) {
        res.status(403).json({ ok: false, error: 'Forbidden' });
        return;
      }
    }

    const update = req.body ?? {};
    const message = update.message ?? update.edited_message ?? null;
    if (!message) {
      res.json({ ok: true });
      return;
    }

    const chatId = message?.chat?.id?.toString();
    if (!chatId) {
      res.json({ ok: true });
      return;
    }

    if (message.contact?.phone_number) {
      const phoneNumber = normalizePhoneNumber(String(message.contact.phone_number));
      if (phoneNumber) {
        await upsertTelegramContact({
          phoneNumber,
          chatId,
          telegramUserId: message.contact.user_id?.toString(),
          firstName: message.contact.first_name?.toString(),
          lastName: message.contact.last_name?.toString(),
        });
        await sendTelegramMessage(
          chatId,
          'Phone number saved. You can now request a verification code in the app.',
        );
      }
      res.json({ ok: true });
      return;
    }

    const text = String(message.text || '').trim();
    const [command = '', payload = ''] = text.split(/\s+/, 2);
    if (command === '/start' || text.toLowerCase() === 'start') {
      const signupLink = payload ? readTelegramSignupLinkToken(payload) : null;
      if (signupLink) {
        await upsertTelegramContact({
          phoneNumber: signupLink.phoneNumber,
          chatId,
          telegramUserId: message.from?.id?.toString(),
          firstName: message.from?.first_name?.toString(),
          lastName: message.from?.last_name?.toString(),
        });
        await issueTelegramOtp({
          phoneNumber: signupLink.phoneNumber,
          chatId,
          intro: `This Telegram chat is now linked to ${signupLink.phoneNumber}.`,
        });
        res.json({ ok: true });
        return;
      }

      await sendTelegramMessage(chatId, 'Please share your phone number to link this chat.', {
        keyboard: [[{ text: 'Share phone number', request_contact: true }]],
        one_time_keyboard: true,
        resize_keyboard: true,
      });
      res.json({ ok: true });
      return;
    }

    await sendTelegramMessage(
      chatId,
      'Use the app to request a verification code. If you have not shared your phone number yet, type /start.',
    );
    res.json({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Telegram webhook error';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/otp/telegram/request', async (req: Request, res: Response) => {
  try {
    const rawPhone = String(req.body?.phoneNumber || '').trim();
    const phoneNumber = normalizePhoneNumber(rawPhone);
    if (!phoneNumber) {
      res.status(400).json({ ok: false, error: 'phoneNumber is required' });
      return;
    }

    const contact = await prisma.telegramContact.findUnique({
      where: { phoneNumber },
    });
    if (!contact) {
      if (!telegramBotUsername) {
        res.status(409).json({
          ok: false,
          error: 'Telegram bot username is not configured',
        });
        return;
      }

      const setupToken = signTelegramSignupLinkToken(phoneNumber);
      res.status(202).json({
        ok: true,
        phoneNumber,
        requiresTelegramLink: true,
        setupUrl: `https://t.me/${telegramBotUsername}?start=${encodeURIComponent(setupToken)}`,
      });
      return;
    }

    await issueTelegramOtp({ phoneNumber, chatId: contact.chatId });

    res.json({ ok: true, phoneNumber, requiresTelegramLink: false });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to send OTP';
    res.status(500).json({ ok: false, error: message });
  }
});

app.post('/api/otp/telegram/verify', async (req: Request, res: Response) => {
  try {
    const rawPhone = String(req.body?.phoneNumber || '').trim();
    const code = String(req.body?.code || '').trim();
    const phoneNumber = normalizePhoneNumber(rawPhone);
    if (!phoneNumber || !code) {
      res.status(400).json({ ok: false, error: 'phoneNumber and code are required' });
      return;
    }

    const now = new Date();
    const latest = await prisma.phoneOtp.findFirst({
      where: {
        phoneNumber,
        usedAt: null,
        expiresAt: { gt: now },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!latest || latest.codeHash !== hashOtp(phoneNumber, code)) {
      res.status(400).json({ ok: false, error: 'Invalid or expired code' });
      return;
    }

    await prisma.phoneOtp.update({
      where: { id: latest.id },
      data: { usedAt: new Date() },
    });

    res.json({
      ok: true,
      phoneNumber,
      verificationToken: signSignupPhoneVerificationToken(phoneNumber),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to verify OTP';
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

