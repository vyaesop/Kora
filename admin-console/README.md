# Kora Admin Console

Static admin UI for moderation and verification flows.

## Local use

From the repo root:

- `npm install`
- `npm run dev:admin`

This starts:

- backend API at `http://localhost:3000`
- admin UI at `http://localhost:4173`

## Vercel deployment

Deploy `admin-console` as its own Vercel project.

The admin project now has a tiny build step that generates `dist/config.js` from the `KORA_ADMIN_API_BASE_URL` environment variable. That means the deployed admin can already know which backend URL to use.

### Required Vercel settings

- Root Directory: `admin-console`
- Build Command: `npm run build`
- Output Directory: `dist`

### Recommended environment variable

- `KORA_ADMIN_API_BASE_URL=https://your-backend-project.vercel.app`

If this variable is empty, the admin still works and lets you enter the API base manually in the browser.

## What the admin can do

- Sign in with backend credentials
- Review pending verifications
- Approve or reject users
- Review open disputes
- Move disputes to `in_review` or `resolved`
- Grant or revoke admin and super admin claims
