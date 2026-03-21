# Kora Backend

Node + Express + Prisma API for the Kora app.

## Local setup

1. Install dependencies:
   - `npm install`
2. Create an env file:
   - `copy .env.example .env`
3. Fill in the required values:
   - `DATABASE_URL`
   - `JWT_SECRET`
   - `SUPER_ADMIN_EMAIL`
   - `CORS_ORIGINS`
4. Generate Prisma client and push schema:
   - `npm run prisma:generate`
   - `npm run prisma:push`
5. Start locally:
   - `npm run dev`

## Vercel deployment

This backend is now compatible with Vercel's Express deployment model:

- `src/index.ts` exports the Express app for Vercel
- local `npm run dev` still starts a normal server
- Prisma client generation runs during install via `postinstall`
- `vercel.json` sets a 30 second function duration for the backend entrypoint

Important:

- Vercel Functions do not provide a persistent WebSocket server, so the existing Socket.IO hooks are disabled automatically on Vercel
- the REST API continues to work normally on Vercel

## Required Vercel environment variables

- `DATABASE_URL`
- `JWT_SECRET`
- `SUPER_ADMIN_EMAIL`
- `CORS_ORIGINS`

Optional but recommended:

- `APP_BASE_URL` (your public app URL that serves `/reset-password`)
- `APP_DEEPLINK_SCHEME`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- `SMTP_PASS`
- `SMTP_FROM`

## First production deploy checklist

1. Deploy the backend project from the `backend` root directory in Vercel
2. Add the environment variables in Project Settings -> Environment Variables
3. Redeploy after adding env vars
4. Run `npx prisma db push` against your production database from your machine or CI once
5. Test:
   - `GET /health`
   - `POST /api/auth/login`
   - `GET /api/auth/me`

## Admin API

Admin endpoints require a JWT for an admin user:

- `GET /api/admin/users/pending-verification`
- `PATCH /api/admin/users/:userId/verification`
- `GET /api/admin/disputes?status=open`
- `PATCH /api/admin/threads/:threadId/disputes/:disputeId`
- `PATCH /api/admin/admins/:targetUid/claim`
