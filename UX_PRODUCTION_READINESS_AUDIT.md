# Kora UX + Production Readiness Audit (Cargo + Driver)

Date: 2026-02-28  
Scope: Flutter client (`lib/`), Firebase rules, and Cloud Functions currently in repo.

---

## 1) Executive Summary

Kora has a **strong marketplace core** (post load, bid, accept, track, rate), but it is not yet production-ready for two-sided logistics operations.

### Current maturity
- **Product UX maturity:** Early beta / pilot
- **Technical production readiness:** Pre-production
- **Operational readiness:** Low

### Why
- Several core flows work, but **critical consistency gaps** exist between screens, data schema, and lifecycle states.
- There are **trust/safety, verification, and operational control gaps** that are essential for real cargo movement.
- Multiple areas rely on optimistic client behavior without robust server-side guarantees.

---

## 2) Role Journey Analysis

## 2.1 Cargo User Journey

### A) Onboarding + account creation
**What exists**
- Language + user-type flow before signup (`SignupFlowScreen`).
- Basic email/password signup and role capture (`signup.dart`).

**UX strengths**
- Simple, low-friction initial flow.
- Role-aware onboarding intent is present.

**Gaps**
- No identity/business verification gating before using marketplace.
- No explicit terms/privacy consent capture.
- No email verification requirement before posting loads.
- Password input not obscured in current login/signup form fields.
- No progressive profile completion checklist for cargo trust.

---

### B) Discover + post load
**What exists**
- Pre-feed cargo dashboard with quick actions (`pre_feed_cargo.dart`).
- Rich post form with route and freight attributes (`post_screen.dart`).

**UX strengths**
- Practical fields for logistics context (origin/destination, type, packaging, weight).
- Good empty-state prompt to create first load.

**Gaps**
- Field/schema drift across app: some screens expect different field names than post flow writes.
- Inconsistent labels and data assumptions (e.g., `description/endCity` vs `message/end`).
- No estimated price range suggestion or market guidance before posting.
- No delivery SLA/time-window fields.
- No draft restoration UX trigger despite draft-saving support.

---

### C) Evaluate bids + accept carrier
**What exists**
- Bid list in thread details (`comment_screen.dart`).
- Accept flow supports multi-carrier option.

**UX strengths**
- Clear pending/accepted/rejected status treatment.
- Shipper can manage accepted carriers post-award.

**Gaps**
- Acceptance UX can be confusing when multi-carrier is enabled.
- Status model is not fully standardized (`accepted`, `pending_bids`, delivery statuses, etc.).
- No anti-fraud/quality indicators (driver verification badge, cancellation rate, on-time score).
- No clear audit trail timeline (accepted at, pickup at, proof of delivery, etc.).

---

### D) Active shipment + completion
**What exists**
- Driver status controls, map tracking, and rating flow.

**UX strengths**
- End-to-end concept exists (track -> delivered -> rate).

**Gaps**
- Tracking reliability fallback is weak (default `(0,0)` behavior can mislead users).
- Delivery completion can happen from client-side actions without strong workflow guards.
- No proof-of-delivery artifact (photo/signature/document) enforced.
- No dispute flow, refund/escalation workflow, or shipment incident handling.

---

## 2.2 Driver Journey

### A) Onboarding + profile readiness
**What exists**
- Driver role and truck type selection.
- Document/photo fields in profile editor.

**UX strengths**
- Driver profile model includes useful logistics attributes.

**Gaps**
- No mandatory verification gate before bidding.
- No document expiry handling or review states (`pending/approved/rejected`).
- No “account readiness meter” to show what blocks bidding.

---

### B) Load discovery + bidding
**What exists**
- Feed and pre-feed suggested loads.
- Bid submission from thread/post comment UI.

**UX strengths**
- Bid placement is quick and integrated in load thread.

**Gaps**
- No route-fit filtering (truck type, capacity, preferred lanes, distance radius).
- No earnings estimate and net payout breakdown.
- No duplicate-bid guard UX.
- No robust feedback if bid rejected due to race/closed state during submission.

---

### C) Awarded shipment execution
**What exists**
- Driver status progression controls.
- Location update service to Realtime DB.

**UX strengths**
- Basic workflow for in-transit updates exists.

**Gaps**
- Status machine is not strictly enforced server-side.
- No geofence/checkpoint or ETA recalculation.
- No offline queue strategy for status/location updates.
- No in-app chat; currently depends on SMS/phone launch behavior.

---

### D) Earnings/reputation
**What exists**
- Rating storage and average tracking fields.

**Gaps**
- No payout lifecycle and ledger screen.
- No transparent rating review response system.
- No cancellation/no-show penalties surfaced.

---

## 3) Cross-Cutting UX Status (Updated)

## 3.1 Information architecture + navigation
**Implemented**
- Canonical flow is now centered on `threads` and legacy logistics shell routing was neutralized to the current `Home` flow.
- Major role journeys (cargo/driver) now use consistent thread document IDs in navigation and action screens.
- Cargo bottom navigation tab mapping (`+` vs `Track`) is now aligned so each tab opens the intended destination.

**Remaining**
- Legacy files still exist in repo (`delivery.dart`, `prehome.dart`) and should be archived/removed to reduce maintenance ambiguity.

## 3.2 Consistency + localization
**Implemented**
- Shared delivery status labeling helper is used across high-traffic screens.
- Key load-management screens now use localization keys for important labels and actions.
- Removed placeholder localization strings (`abc`) for core Oromo/Amharic actions so primary UI labels are user-readable.

**Remaining**
- Broader long-tail localization is still incomplete (many less-used screens keep hardcoded English).

## 3.3 Error handling + empty states
**Implemented**
- Core load list screens now include explicit empty/error/retry states.
- Bid and status flows include stronger friendly error messaging and recovery behavior.
- Login now has working password-reset action, password visibility toggle, and submission/loading validation feedback.

**Remaining**
- Global retry/recovery patterns are not yet fully standardized across every async screen.

## 3.4 Accessibility
**Implemented**
- Added semantics improvements via key action tooltips and clearer action labeling on critical controls.

**Remaining**
- A full accessibility audit (contrast, screen-reader flow order, large-text behavior) is still needed.

---

## 4) Production Readiness Gaps (Current)

## 4.1 Data model + schema governance (Critical) — **Mostly Addressed**
**Implemented**
- Active UX paths now consistently use `threads` and canonical thread IDs in navigation.
- Field alignment improved across posting, listing, bidding, and tracking screens.

**Remaining**
- Legacy source files remain and should be fully decommissioned or feature-flagged out.
- Formal schema versioning/migration docs are still missing.

## 4.2 Workflow integrity + server authority (Critical) — **Addressed**
**Implemented**
- Transaction-backed bid placement/update and bid acceptance logic added.
- Forward-only delivery status transitions with stricter validation implemented.
- Duplicate acceptance and invalid status jumps are blocked.

**Remaining**
- Optional next step: move sensitive orchestration to Cloud Functions for stronger backend authority.

## 4.3 Security/rules hardening (High) — **Addressed**
**Implemented**
- Firestore rules now enforce stronger invariants (identity fields, bid update scope, transition constraints).
- Rules were deployed after updates.

**Remaining**
- Storage rules still require a dedicated least-privilege hardening pass.

## 4.4 Trust, safety, compliance (Critical) — **Partially Addressed**
**Implemented**
- Terms/privacy acceptance is now captured and required in critical flows.
- Verification status gating is enforced for core transaction paths.
- Dispute reporting and PoD capture were implemented.

**Remaining**
- No in-app admin KYC/KYB review workflow yet (approve/reject queue UX).

## 4.5 Reliability + observability (High) — **Partially Addressed**
**Implemented**
- Client-side telemetry for error/event logging introduced.
- Event instrumentation added to key marketplace/shipment actions.

**Remaining**
- Crashlytics remains disabled in current workspace dependency state and should be restored.

## 4.6 QA + release discipline (High) — **Improved**
**Implemented**
- Added focused unit tests for status labels, recommendation scoring, and experiment assignment.

**Remaining**
- Wider integration/widget coverage, staging parity automation, and release checklists are still pending.

---

## 5) Severity Matrix (Implementation Status)

Legend: ✅ Implemented | 🟡 Partially Implemented | ⏳ Not Yet

## P0 (Must fix before production)
1. Unify data model and remove legacy `loads`-based flows from active UX — ✅
2. Enforce server-side state machine for load lifecycle (`pending_bids -> accepted/in_transit -> delivered`) — ✅
3. Implement mandatory verification gating for both roles before core transactions — ✅
4. Add proof-of-delivery and dispute workflow — ✅
5. Restore robust crash/error observability and key event analytics — 🟡 (event/error telemetry added; Crashlytics restore pending)
6. Harden security rules for business invariants and sensitive storage access — 🟡 (Firestore strengthened; Storage hardening pending)

## P1 (Strongly recommended before scale)
1. Improve role-specific discovery/filtering and route-fit relevance — ✅
2. Add robust offline/error recovery for bid/status/location updates — ✅
3. Expand localization coverage and standardize status/labels — 🟡 (core screens updated; long tail remains)
4. Introduce timeline/audit view for each load — ✅
5. Add payout/earnings transparency for drivers — ✅

## P2 (Optimization)
1. Personalization/recommendation for loads/drivers — ✅
2. Advanced reputation scoring and fraud detection heuristics — ✅
3. Experimentation framework for conversion improvements — ✅

## 5.1 Immediate Remaining Priority
1. Restore Crashlytics and analytics SDK integration end-to-end.
2. Complete Storage rules least-privilege hardening.
3. Add in-app verification review/admin workflow (approve/reject).
4. Finish long-tail localization and accessibility audit sweep.

---

## 6) What It Needs to Be a Proper Production App

## 6.1 Product requirements
- Canonical shipment lifecycle with explicit allowed actions per role/state.
- Verification program (documents, review states, re-verification).
- Incident/dispute handling and support tooling.
- Standardized trust indicators (verified, on-time %, completion rate).

## 6.2 UX requirements
- Single source-of-truth navigation and IA per role.
- Unified status language and in-app timeline.
- Strong validation and guided forms with inline guidance.
- Recovery-first UX for network failure and stale state.

## 6.3 Engineering requirements
- Backend-owned critical transitions (Cloud Functions or server API).
- Data schema versioning + migration process.
- End-to-end idempotency on bid acceptance and status writes.
- Analytics and crash monitoring with release channel segmentation.

## 6.4 Operations requirements
- Staging environment parity with production rules/functions.
- On-call alerts for critical marketplace failures (bid writes, status transitions, location updates).
- Release checklist including rules, indexes, functions, and app compatibility.

---

## 7) 90-Day Production Readiness Plan

## Phase 1 (Weeks 1-3): Stabilize Core
- Freeze data contract for `users`, `threads`, `bids`, `ratings`.
- Remove or feature-flag legacy `loads` collection UX paths.
- Implement backend-enforced lifecycle transitions.
- Add mandatory auth hardening (email verify, password masking, session handling).

## Phase 2 (Weeks 4-7): Trust + Reliability
- Launch verification gating for cargo + driver.
- Add PoD capture and dispute initiation flow.
- Strengthen Firestore/Storage rules with transition constraints.
- Restore Crashlytics + event analytics taxonomy.

## Phase 3 (Weeks 8-12): Scale Readiness
- Add route-fit search/filter relevance.
- Build shipment timeline + support diagnostics.
- Expand tests (unit/widget/integration + golden critical screens).
- Run pilot load with SLO tracking and incident drills.

---

## 8) Suggested Production KPIs

## Cargo-side
- Time to first posted load
- Posted load -> first bid rate
- Bid acceptance rate
- Successful delivery completion rate
- Dispute rate per 100 deliveries

## Driver-side
- Time to first bid
- Bid win rate
- Assignment -> delivered completion rate
- On-time completion rate
- Driver churn at 30/60 days

## Platform reliability
- Crash-free sessions
- Bid submission failure rate
- Status update failure/retry rate
- Tracking availability (% sessions with valid location stream)

---

## 9) Concrete Repo Findings (Evidence Anchors)

- Core role routing and pre-feed behavior: `lib/screens/home.dart`, `lib/screens/pre_feed_cargo.dart`, `lib/screens/pre_feed_driver.dart`
- Posting and bid lifecycle surfaces: `lib/screens/post_screen.dart`, `lib/screens/comment_screen.dart`, `lib/screens/post_comment_screen.dart`, `lib/utils/firestore_service.dart`
- Tracking + status controls: `lib/screens/track_driver_map_screen.dart`, `lib/widgets/driver_status_controls.dart`, `lib/widgets/active_job_controls.dart`, `lib/utils/driver_location_service.dart`
- Legacy/inconsistent flow artifacts: `lib/screens/my_loads_screen.dart`, `lib/screens/driver_loads_screen.dart`, `lib/screens/delivery.dart`
- Identity/profile and verification data capture: `lib/screens/signup.dart`, `lib/screens/profile_screen.dart`, `lib/screens/edit_profile.dart`, `lib/model/user.dart`
- Security/backend baseline: `firestore.rules`, `storage.rules`, `database.rules.json`, `functions/src/index.ts`

---

## 10) Final Verdict

Kora is promising and already demonstrates the right marketplace primitives. To be production-ready, it needs a focused hardening pass on:
1) canonical data/workflow consistency,  
2) trust + verification + dispute controls, and  
3) operational reliability/observability.

If these P0 items are addressed, the app can move from pilot quality to controlled production rollout.
