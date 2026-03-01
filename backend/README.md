# Kora Backend (Neon Postgres)

This backend replaces Firebase admin/data flows with a Node + Express + Prisma API using Neon PostgreSQL.

## Setup

1. Install dependencies:
   - `npm install`
2. Create environment file:
   - `copy .env.example .env`
3. Configure `.env`:
   - `DATABASE_URL` (Neon connection string)
   - `JWT_SECRET` (strong random secret)
   - `SUPER_ADMIN_EMAIL` (bootstrap super admin user email)
   - `CORS_ORIGINS` (comma-separated allowed origins, use `*` only for local testing)
   - `PORT` (optional, default `3000`)
4. Generate Prisma client and push schema:
   - `npm run prisma:generate`
   - `npm run prisma:push`

## Run

- Development: `npm run dev`
- Build: `npm run build`
- Production: `npm run start`

## Connectivity troubleshooting

- If Prisma returns `P1001` (`Can't reach database server`), verify the Neon project is active and your database/password are still valid.
- If your Neon credentials were shared publicly, rotate them immediately and update `DATABASE_URL`.
- Confirm outbound access to `*.neon.tech:5432` is allowed from your runtime environment.

## API Summary

- `GET /health`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `GET /api/threads`
- `POST /api/threads`

Admin endpoints (JWT + admin role required):

- `GET /api/admin/users/pending-verification`
- `PATCH /api/admin/users/:userId/verification`
- `GET /api/admin/disputes?status=open`
- `PATCH /api/admin/threads/:threadId/disputes/:disputeId`
- `PATCH /api/admin/admins/:targetUid/claim` (super admin only)

## Admin Console

`admin-console/app.js` is now JWT-based and no longer depends on Firebase SDK.

- Set `API base` to backend URL (for example `http://localhost:3000`).
- Login uses `POST /api/auth/login`.
- Admin actions call `/api/admin/*` endpoints.
