# Admin Option 3 Implementation Progress

Date started: 2026-02-28
Goal: Build admin side using Firebase Cloud Functions APIs + Vercel-hosted frontend at zero additional platform cost.

## Scope
- Secure admin API endpoints in `functions/`.
- Minimal Vercel-ready admin frontend to call those endpoints.
- Keep auth and authorization aligned with existing Firebase user model.

## Progress Checklist
- [x] Create progress tracker file
- [x] Review existing backend and auth patterns
- [x] Implement admin authorization helper
- [x] Implement admin endpoints (KYC approve/reject, disputes list/update)
- [x] Add endpoint input validation + consistent error responses
- [x] Add minimal Vercel admin frontend shell
- [x] Wire frontend to Firebase Auth + admin APIs
- [x] Add setup and deployment instructions

## Implemented Endpoints (`functions/src/index.ts`)
- `GET /users/pending-verification`
- `PATCH /users/{uid}/verification`
- `GET /disputes?status=open`
- `PATCH /threads/{threadId}/disputes/{disputeId}`
- `PATCH /admins/{uid}/claim`

## Admin Auth Model
- Uses Firebase ID token from `Authorization: Bearer <token>`
- Grants admin access when one of these is true:
	- custom claim `admin: true`
	- `users/{uid}.role == "admin"`
	- `users/{uid}.userType == "Admin"`
	- `users/{uid}.isAdmin == true`

## Frontend Scaffold
- `admin-console/index.html`
- `admin-console/app.js`
- `admin-console/styles.css`
- `admin-console/vercel.json`
- `admin-console/README.md`

## Immediate Next Steps
- Replace Firebase config placeholders in `admin-console/app.js`
- Deploy functions and set API base URL in the admin UI
- Create or mark at least one admin account in Firestore

## Added in this pass
- Claim management API route added for custom claim assignment (`admin`, `superAdmin`)
- Admin UI controls added for claim updates
- Expanded README with full use + test + Vercel deployment flow

## Execution Runbook
1. Update Firebase config placeholders in `admin-console/app.js`.
2. Build and deploy functions:
	- `cd functions`
	- `npm install`
	- `npm run build`
	- `firebase deploy --only functions`
3. Deploy admin UI to Vercel with project root set to `admin-console`.
4. Open deployed admin URL and sign in with bootstrap admin account.
5. Save API base URL in the UI:
	- `https://<region>-<project-id>.cloudfunctions.net/adminApi`
6. Verify operations:
	- pending verification list loads
	- approve/reject updates user document
	- disputes list loads and updates status
	- admin claim updates work for target UID

## Validation
- Functions TypeScript build: ✅ passed (`npm install; npm run build` in `functions/`)
- Note: local Node is `v22`, functions engine expects `node 20` (warning only in local build)
- Functions lint: ✅ passed (`npm run lint`)

## Notes
- Prefers Option 3 (API + hosted frontend)
- Hosting target: Vercel
- Constraint: 0-cost stack choices

## Change Log
- 2026-02-28: Tracker initialized.
- 2026-02-28: Added secure `adminApi` with CORS, auth checks, verification/dispute routes.
- 2026-02-28: Added Vercel-ready static `admin-console` frontend and setup guide.
- 2026-02-28: Installed functions deps and confirmed TypeScript compile success.
- 2026-02-28: Added admin claim management endpoint and UI controls.
