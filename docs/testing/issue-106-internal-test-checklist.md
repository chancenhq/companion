# Issue #106 — Internal Testing Checklist
**Build:** v0.7.2-alpha.1 · **Staging:** https://companion-staging.chancen.tech · **Date:** 2026-10-07

This checklist maps to the stories in Issue #106 and the superseded PR #107. Each section covers one epic or wave. Mark **Pass / Fail / Blocked** and add notes where something is off.

---

## Wave 0 — Security Pre-work

These shipped in #109, #110, #111 before the main epics. Should already be stable.

| # | What to test | Expected | Result |
|---|---|---|---|
| W0-1 | Sign up using an invitation **token** from an emailed invite link | Succeeds, user lands in family | |
| W0-2 | Try to sign up for a family by email only, with no token and no bulk seat reserved | Blocked — invite-only error shown | |
| W0-3 | Reset password, then try signing in on a device that had the old session | Old session invalidated, must re-authenticate | |
| W0-4 | Sign in with Apple using an email that doesn't match the Apple-signed email | Sign-in refused | |

---

## Epic A — Email Verification & Country Routing

### A-1 · Server: email verification gate

| # | What to test | Expected | Result |
|---|---|---|---|
| A1-1 | Sign up with email/password (no SSO) | Verification email received | |
| A1-2 | Before verifying email, open the app and try to view ISA data / account balances | 403 returned — app shows verification prompt, not data | |
| A1-3 | Open the verification link from email | Email marked verified; ISA data now loads | |
| A1-4 | Sign up via Google or Apple SSO | Email auto-verified — no prompt, ISA data loads immediately | |
| A1-5 | Bot/chat accessible before email verification | Chat responds normally (not blocked) | |

### A-2 · Mobile: verification UX

| # | What to test | Expected | Result |
|---|---|---|---|
| A2-1 | After email sign-up, app shows verification screen | Verification screen with resend option | |
| A2-2 | Tap "Resend" on verification screen | Confirmation shown; new email arrives | |
| A2-3 | Tap "Continue anyway" (if shown) | Chat accessible; ISA screens show locked state | |
| A2-4 | Verify email on another device, then return to app | App detects verification and unlocks data (next refresh or reopen) | |

### A-3 · Country routing (server + mobile)

| # | What to test | Expected | Result |
|---|---|---|---|
| A3-1 | Complete onboarding as a new KE user | Country picker shown; KE selected | |
| A3-2 | Complete onboarding as a new RW user | Country picker shown; RW selected | |
| A3-3 | After selecting country, ask the bot about escalation | Bot cites correct country team name and email (e.g. `support.ke@chancen.org` for KE) | |
| A3-4 | Ask bot ISA question as KE user | Bot uses Kenya-specific ISA content source | |
| A3-5 | User with no country set asks bot about escalation | Bot says "the Chancen team" — does not default to Kenya | |
| A3-6 | Change country in profile | Updated country reflected in bot escalation guidance on next message | |

### A-4 · "Continue with email" sign-in choice

| # | What to test | Expected | Result |
|---|---|---|---|
| A4-1 | Open app on a fresh install | Google, Apple, and "Continue with email" shown as three equal options | |
| A4-2 | Tap "Continue with email" | Email/password form expands below the SSO buttons | |
| A4-3 | Tap back / dismiss email form | Returns to three-option view | |
| A4-4 | Sign in with Google | SSO flow completes; lands in app | |
| A4-5 | Sign in with Apple (iOS only) | SSO flow completes; lands in app | |

---

## Epic B — Invitation Seat Management

### B1 · Bulk invite seats

| # | What to test | Expected | Result |
|---|---|---|---|
| B1-1 | Admin bulk-invites a list of new (unknown) emails | Each gets `invited` status in results; no email sent (seats reserved) | |
| B1-2 | One of those emails signs up on the app | User lands in the correct family without needing a token | |
| B1-3 | Admin bulk-invites an email that already has an account | Result shows `accepted`; user moved to family | |
| B1-4 | Admin bulk-invites an email already invited to the same family | Error returned for that email; others succeed | |

---

## Known gaps / out of scope for this build

- **Bulk invite UX**: no confirmation shown when an existing user would be moved across families — noted, tracked separately
- **Seven-tap dev menu on onboarding screen**: not wired up on the country/consent screen; use the login screen tap after first onboarding completes
- **OpenAPI docs**: not regenerated in this build (Linux machine task, tracked)

---

## Environment notes

| Item | Value |
|---|---|
| Staging URL | https://companion-staging.chancen.tech |
| Android | Download APK from GitHub Release for this tag |
| iOS | TestFlight — check internal testers group |
| Default backend | Staging (baked into this build) |
| Server version | v0.7.2-alpha.1 |
