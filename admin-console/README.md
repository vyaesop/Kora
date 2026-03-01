# Kora Admin Console (Postgres + Neon)

This is a minimal Vercel-ready static admin UI that calls the custom Node backend (`backend`) using JWT auth.

## 1) Start backend + admin UI together (one command)
From project root:
- `npm install`
- `npm run dev:admin`

This starts:
- backend API at `http://localhost:3000`
- admin UI at `http://localhost:4173`

## 2) Backend first-time setup (one time)
From project root:
- `cd backend`
- `npm install`
- `copy .env.example .env`
- set real values in `.env` (`DATABASE_URL`, `JWT_SECRET`, `SUPER_ADMIN_EMAIL`)
- `npm run prisma:generate`
- `npm run prisma:push`

## 3) Bootstrap admin access
Use the email configured as `SUPER_ADMIN_EMAIL` in `.env`, then sign in once through the admin console.
On first login, this user is promoted to super admin automatically.

## 4) Deploy admin UI on Vercel
Option A: Deploy `admin-console` directory as its own Vercel project.
Option B: Import repo and set root directory to `admin-console`.

## 5) Runtime setup in UI
In the admin page:
- Sign in with backend credentials (`/api/auth/login`).
- Set API base URL to backend host, for example:
  - `http://localhost:3000`
  - `https://your-backend-domain.com`

The app supports:
- View pending verifications
- Approve/reject users
- View open disputes
- Mark disputes in-review/resolved
- Grant/revoke admin and super-admin claims

## API Routes (backend)
- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `GET /api/admin/users/pending-verification`
- `PATCH /api/admin/users/{uid}/verification`
- `GET /api/admin/disputes?status=open`
- `PATCH /api/admin/threads/{threadId}/disputes/{disputeId}`
- `PATCH /api/admin/admins/{uid}/claim`

## Security Notes
- Rotate the exposed Neon password and JWT secret before production.
- Only super admins should grant/revoke claims.
- Keep backend CORS restricted to your app domains in production.
