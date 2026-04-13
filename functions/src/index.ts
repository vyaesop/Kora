import { onRequest } from 'firebase-functions/v2/https';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';
import * as admin from 'firebase-admin';
import type { Request, Response } from 'express';

admin.initializeApp();

export const health = onRequest((req, res) => {
  logger.info('health check', { method: req.method, path: req.path });
  res.status(200).send('ok');
});

const allowedOrigins = new Set([
  'http://localhost:3000',
  'http://localhost:5173',
  'https://localhost:3000',
]);

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return 'unknown_error';
}

type AdminAuthContext = {
  uid: string;
  isSuperAdmin: boolean;
  hasAdminClaim: boolean;
};

type BidSnapshotData = {
  status?: string;
  price?: number;
};

function applyCors(req: Request, res: Response): boolean {
  const origin = req.get('origin');
  if (origin && (allowedOrigins.has(origin) || origin.endsWith('.vercel.app'))) {
    res.set('Access-Control-Allow-Origin', origin);
    res.set('Vary', 'Origin');
  }
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.set('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return true;
  }

  return false;
}

async function requireAdmin(req: Request): Promise<AdminAuthContext> {
  const auth = req.get('authorization');
  if (!auth || !auth.startsWith('Bearer ')) {
    throw new Error('unauthorized');
  }

  const token = auth.slice(7);
  const decoded = await admin.auth().verifyIdToken(token);
  const uid = decoded.uid;
  const userDoc = await admin.firestore().collection('users').doc(uid).get();
  const userData = userDoc.data() ?? {};

  const isAdmin =
    decoded.admin === true ||
    userData.role === 'admin' ||
    userData.userType === 'Admin' ||
    userData.isAdmin === true;

  if (!isAdmin) {
    throw new Error('forbidden');
  }

  const isSuperAdmin = decoded.superAdmin === true || userData.superAdmin === true;
  return { uid, isSuperAdmin, hasAdminClaim: decoded.admin === true };
}

function sendError(res: Response, status: number, message: string) {
  res.status(status).json({ ok: false, error: message });
}

export const adminApi = onRequest(async (req, res) => {
  if (applyCors(req, res)) return;

  let authContext: AdminAuthContext;
  try {
    authContext = await requireAdmin(req);
  } catch (e: unknown) {
    if (getErrorMessage(e) === 'forbidden') {
      sendError(res, 403, 'forbidden');
      return;
    }
    sendError(res, 401, 'unauthorized');
    return;
  }

  const db = admin.firestore();
  const path = (req.path || '').replace(/\/+$/, '');

  try {
    if (req.method === 'GET' && path === '/users/pending-verification') {
      const limitRaw = Number(req.query.limit ?? 25);
      const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 100) : 25;
      const snap = await db
        .collection('users')
        .where('verificationStatus', '==', 'pending')
        .limit(limit)
        .get();

      const users = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
      res.status(200).json({ ok: true, users });
      return;
    }

    if (req.method === 'PATCH' && path.startsWith('/users/') && path.endsWith('/verification')) {
      const uid = path.split('/')[2];
      const status = (req.body?.status ?? '').toString().toLowerCase();
      const note = (req.body?.note ?? '').toString().trim();

      if (!uid) {
        sendError(res, 400, 'missing_uid');
        return;
      }
      if (!['approved', 'rejected', 'pending'].includes(status)) {
        sendError(res, 400, 'invalid_status');
        return;
      }

      await db.collection('users').doc(uid).update({
        verificationStatus: status,
        verificationReviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        verificationReviewNote: note,
        verificationReviewedBy: authContext.uid,
      });

      res.status(200).json({ ok: true });
      return;
    }

    if (req.method === 'GET' && path === '/disputes') {
      const status = (req.query.status ?? 'open').toString();
      const limitRaw = Number(req.query.limit ?? 25);
      const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 100) : 25;

      const disputesSnap = await db
        .collectionGroup('disputes')
        .where('status', '==', status)
        .limit(limit)
        .get();

      const disputes = disputesSnap.docs.map((doc) => ({
        id: doc.id,
        threadId: doc.ref.parent.parent?.id ?? null,
        ...doc.data(),
      }));

      res.status(200).json({ ok: true, disputes });
      return;
    }

    if (req.method === 'PATCH' && path.startsWith('/threads/') && path.includes('/disputes/')) {
      const parts = path.split('/');
      const threadId = parts[2];
      const disputeId = parts[4];
      const nextStatus = (req.body?.status ?? '').toString().toLowerCase();
      const resolutionNote = (req.body?.resolutionNote ?? '').toString().trim();

      if (!threadId || !disputeId) {
        sendError(res, 400, 'missing_thread_or_dispute_id');
        return;
      }
      if (!['open', 'in_review', 'resolved', 'rejected'].includes(nextStatus)) {
        sendError(res, 400, 'invalid_status');
        return;
      }

      await db
        .collection('threads')
        .doc(threadId)
        .collection('disputes')
        .doc(disputeId)
        .update({
          status: nextStatus,
          resolutionNote,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedBy: authContext.uid,
        });

      res.status(200).json({ ok: true });
      return;
    }

    if (req.method === 'PATCH' && path.startsWith('/admins/') && path.endsWith('/claim')) {
      if (!authContext.isSuperAdmin && !authContext.hasAdminClaim) {
        sendError(res, 403, 'insufficient_admin_privilege');
        return;
      }

      const targetUid = path.split('/')[2];
      const setAdmin = req.body?.admin === true;
      const setSuperAdmin = req.body?.superAdmin === true;

      if (!targetUid) {
        sendError(res, 400, 'missing_uid');
        return;
      }

      if (setSuperAdmin && !authContext.isSuperAdmin) {
        sendError(res, 403, 'only_super_admin_can_set_super_admin');
        return;
      }

      await admin.auth().setCustomUserClaims(targetUid, {
        admin: setAdmin,
        superAdmin: setSuperAdmin,
      });

      await db.collection('users').doc(targetUid).set(
        {
          isAdmin: setAdmin,
          superAdmin: setSuperAdmin,
          role: setAdmin ? 'admin' : 'user',
          adminUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          adminUpdatedBy: authContext.uid,
        },
        { merge: true }
      );

      res.status(200).json({ ok: true, targetUid, admin: setAdmin, superAdmin: setSuperAdmin });
      return;
    }

    sendError(res, 404, 'not_found');
  } catch (e: unknown) {
    logger.error('adminApi error', { message: getErrorMessage(e), path, method: req.method });
    sendError(res, 500, 'internal_error');
  }
});

// Keep a lightweight counter and finalPrice on the parent thread document
// when bids are created/updated/deleted under threads/{threadId}/bids/{bidId}
export const onBidWrite = onDocumentWritten('threads/{threadId}/bids/{bidId}', async (event) => {
  const threadId = event.params?.threadId;
  if (!threadId) return null;

  const db = admin.firestore();
  const bidsCol = db.collection('threads').doc(threadId).collection('bids');

  try {
    const bidsSnap = await bidsCol.get();
    const bidsCount = bidsSnap.size;

    // Find accepted bid if any (assumes a `status` field and `price` on bid documents)
    let finalPrice: number | null = null;
    for (const doc of bidsSnap.docs) {
      const data = doc.data() as BidSnapshotData;
      if (data && data.status === 'accepted' && data.price != null) {
        finalPrice = Number(data.price);
        break;
      }
    }

    const updateData: Record<string, unknown> = { bids_count: bidsCount };
    if (finalPrice !== null) updateData.finalPrice = finalPrice; else updateData.finalPrice = admin.firestore.FieldValue.delete();

    await db.collection('threads').doc(threadId).update(updateData);
    logger.log(`Updated thread ${threadId} with bids_count=${bidsCount} finalPrice=${finalPrice}`);
  } catch (err) {
    logger.error('Error updating bids_count for thread', { threadId, err });
  }

  return null;
});
