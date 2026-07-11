# KwayaPro Production Readiness — Final Summary

**Covers:** the full production-readiness pass, Phases 1 through 7 (including sub-phases 2b, 2c, 3b, 3c, 5b, 6b), run against the original `PRODUCTION_READINESS_AUDIT.md` (2026-07-09).
**Status as of this document:** all fixes are in the working tree. **Nothing has been deployed at any point in this pass** — every phase explicitly stopped short of `firebase deploy` per your standing instruction; you review and deploy manually.
**Purpose:** one authoritative document instead of cross-referencing 12 separate phase reports. Individual `PHASE_N_REPORT.md` files remain in the repo root with full technical detail for anything summarized here.

---

## 1. What was found, and what shipped

The original audit found **10 BLOCKER**, **18 PRE-LAUNCH**, **11 HYGIENE**, and 5 deferred POST-BETA findings. Every BLOCKER and PRE-LAUNCH finding was fixed. Of the 11 HYGIENE findings, 7 were fixed across various phases, 3 were fixed in Phase 7, and 4 were explicitly flagged rather than fixed (real refactor risk vs. cleanup-phase budget) — see §4.

### Deploy safety & secrets (Phase 1)
- Fixed `kwayapro/firebase.json`'s dangling reference to already-deleted `firestore.rules`/`firestore.indexes.json` files — would have failed or silently applied stale rules on deploy.
- Root `storage.rules` was a deny-all (`if false`) — the file `.firebaserc` would actually have deployed. Replaced with the real working ruleset; deleted the redundant `kwayapro/storage.rules` copy.
- Found `set_secrets.js` at repo root holding live MTN/Cloudflare R2 credentials in plaintext, ungitignored. **Confirmed never committed to git history** (checked via `git log --all --full-history` and content-based `-S` searches). Moved to `~/kwayapro-secrets/set_secrets.js`, gitignored the filename as defense in depth.

### Security rules hardening (Phase 2, 2b, 2c)
- `choir_memberships` create rule allowed self-elevation to `director` — closed; self-serve create now only permits `chorister`, or `leader` gated by proof of choir ownership. Also closed the same hole via `update` (a chorister could previously self-promote by updating instead of creating).
- `users/{userId}` read rule exposed every user's PII (phone, name, photo) to any authenticated account — scoped to owner-only.
- `storage.rules` had zero choir-scoping on `/audio`, `/scores`, `/chat` — any signed-in user could read/write any choir's files. Fixed via Firestore-membership cross-checks.
- Found and fixed a **pre-existing bug**: invalid `let`-in-`match`-block syntax meant `firestore.rules` could not have compiled/deployed successfully before this phase, regardless of anything else.
- The rules fix broke the guest-director join flow by necessity (no way to distinguish the legitimate case from the vulnerability in the data model) — replaced with a proper Cloud Function (`joinAsGuestDirector`) that validates server-side and grants via the Admin SDK, also fixing the "guest token expiry only enforced by 30-minute scheduled cleanup" finding for real, and making guest links genuinely single-use for the first time.
- The `users/{userId}` fix broke live member-name lookups — fixed by denormalizing real names onto `choir_memberships` at write time (was previously hardcoded to literal `'Member'`/`'Leader'` placeholders in practice, since phone-OTP auth rarely populates `displayName`) plus an `onUserProfileUpdated` trigger to keep it in sync going forward. A one-time backfill script for existing placeholder data was written but **not run — needs your action** (see §3).

### Payment integrity (Phase 3, 3b, 3c)
- `paymentWebhook` and `mtnWebhook` both had a fail-**open** signature check (skipped entirely if the header was simply omitted) — any request could grant free Pro to any choir. Fixed to fail closed via a shared-secret query parameter embedded in the callback URL MTN is given, with idempotency checks against replay.
- `initiatePayment` sent two HTTP responses on every call (a hard crash on `ERR_HTTP_HEADERS_SENT`) — fixed with explicit early returns.
- MTN integration was hardcoded to the sandbox host with no way to reach production — now derives the host from a secret-backed target-environment flag.
- The billing UI was entirely disconnected from the real backend — it faked a successful payment client-side after a 2-second delay. Rewired to call the real `initiatePayment` function and watch server-driven state; the client can no longer set its own subscription to active.
- Added server-side enforcement of the freemium 3-song cap (previously client-side-only, trivially bypassed by a direct write) via a Firestore rule, then closed the remaining check-then-act race with a real Firestore transaction (Phase 4) — verified against a genuine multi-transaction contention scenario on the real emulator, not just unit-tested in isolation.
- Airtel Money is now visibly gated "Coming soon" in the UI and rejected server-side.
- `paymentWebhook` was confirmed dead/orphaned (nothing ever called it) and removed entirely in Phase 3b.
- Built `cancelSubscription` for the previously-nonexistent Pro→Free downgrade path — takes effect immediately (confirmed by tracing the data model: MTN payments are one-time charges, nothing tracks a "current paid period" to honor a delayed downgrade against). Confirmed via test that a downgraded, over-cap choir keeps all its existing songs — only new creates are blocked.
- Live-curl-verified (Phase 3c) that every Cloud Function URL used in the app actually resolves to the correct, currently-deployed function.

### Data integrity & core bugs (Phase 4)
- Three models (`audio_part.dart`, `score_attachment.dart`, `song_section.dart`) hard-cast every field with no null safety — would crash the entire audio/scores stream on one legacy document. Fixed with the same null-safe pattern the rest of the codebase already used, plus a skip-and-log wrapper so one malformed document can no longer take down a stream for every listener.
- Chat pin/unpin was structurally broken — the stored `messageId` never matched the real document ID, so pin/unpin always failed. Fixed by reserving the document reference before writing.
- Fixed the invite-code collision gap and extracted a shared composite-ID helper (both original-audit hygiene items).

### Architecture & performance (Phase 5, 5b)
- `GoRouter` was fully rebuilt (discarding all navigation/tab state) on every single auth/choir Firestore emission, not just sign-in/out — fixed via the documented `refreshListenable` pattern, verified to preserve router instance identity across emissions.
- Found the Director-only `/studio` gap was **not actually present** — re-verified, no fix needed.
- Found and fixed a large gap: only one feature's providers had `.autoDispose` — every other choir/session/song-scoped provider leaked a live Firestore listener for the rest of the app session on every distinct entity ever viewed. Fixed across 7 files.
- Found and fixed two unbounded, platform-wide Firestore listeners with N+1 per-document reads (both dead code today, fixed anyway).
- Fixed cold-start blocking: FCM permission prompt and Hive/audio-cache init no longer block the first frame.
- `AudioCacheService` existed but was never wired to actual playback — wired into `AudioPlayerNotifier`, with a real LRU eviction policy added (there was none) and a real crash-risk bug fixed (`late Box` used before async init could complete).

### Platform & deployment readiness (Phase 6, 6b)
- Found the guest-director invite link generator was building **Firebase Dynamic Links** URLs — a service that **shut down 2025-08-25**. Every invite link had been dead for nearly a year, independent of anything about the Android App Links configuration. Fixed to use the app's real App Links domain.
- Generated the missing 512×512 Play Store icon, and — in Phase 6b — real Android adaptive launcher icons (separate foreground/background layers) from the brand SVG, replacing the stock Flutter placeholder, with the background color sourced from the documented brand identity file (not guessed) and transparency programmatically verified (not assumed).
- Found and relocated a **second** exposed-secrets file, `kwayapro/.env.local` (R2 + MTN credentials), same treatment as Phase 1's finding — confirmed never committed to git history.
- Upgraded the Cloud Functions Node runtime twice over the course of the pass (24 → 20 → 22), fixing a real, reproducible Functions Emulator crash along the way (the legacy `admin.firestore.FieldValue`/`.Timestamp` namespace access) and keeping ahead of Google's runtime deprecation schedule.

### Hygiene + test coverage (Phase 7, final)
- See `PHASE_7_REPORT.md` for full detail. Headline: **committed persistent test coverage for security rules and payment Cloud Functions for the first time** — every prior phase's rules/functions testing (Phases 2, 2b, 3, 3b) existed only as ephemeral scratch scripts, meaning there was zero regression protection for the highest-risk code in the app. Also closed 3 hygiene items (enum-safety pattern, `PermissionChecker` consolidation, remaining `Scaffold`/tooltip/controller-leak/print-gating items), and flagged 4 more as real refactors rather than pushing them through under a cleanup phase's risk budget.

---

## 2. Final test coverage

| Suite | Location | Count | Status |
|---|---|---|---|
| Dart unit/widget tests | `kwayapro/test/` (`flutter test`) | 41 | 41/41 passing |
| Firestore + Storage security rules | `firestore-tests/` (new, Phase 7) | 25 | 25/25 passing |
| Cloud Functions integration | `functions/test/` (new, Phase 7) | 33 | 33/33 passing |
| **Total** | | **99** | **99/99 passing** |

`flutter analyze`: clean. `tsc --noEmit` (functions): clean. All three suites are now committed to the repo and re-runnable by anyone with the Firebase CLI and Java installed — not one-off scratch runs.

**What still cannot be meaningfully tested from this environment** (stated honestly rather than papered over):
- `initiatePayment`'s actual outbound call to MTN's Collections API (needs live MTN sandbox credentials/network).
- Real on-device audio playback (`just_audio` has no lightweight fake platform).
- Final adaptive-icon rendering (needs a real device/emulator build).
- Android App Links end-to-end resolution (needs `assetlinks.json` actually hosted, plus a real device).

---

## 3. Everything that needs YOUR action before/around launch

Grouped by what kind of action it needs.

### A. Credential rotation (your dashboards, not this environment)
1. **`~/kwayapro-secrets/set_secrets.js`** (Phase 1) — MTN and Cloudflare R2 credentials. Confirmed never committed to git history; rotation is precautionary.
2. **`~/kwayapro-secrets/kwayapro-env.local`** (Phase 6) — a second, independently-discovered R2/MTN credentials file. Same situation: never committed, rotation precautionary.

### B. Firebase console / deploy actions
3. **Confirm which `firestore.rules`/`storage.rules` are actually live today** (Phase 2/2b) — Phase 2 discovered the committed rules file had a syntax error that would have blocked any deploy, meaning whatever is live in production may predate or differ from everything in this repo. Check Firebase Console → Firestore/Storage → Rules → version history before assuming continuity.
4. **Run the membership-name backfill script** (Phase 2b): `node functions/scripts/backfill-membership-names.js --dry-run` first, review, then without the flag — fixes existing placeholder `'Member'`/`'Leader'`/`'Guest Director'` names sitting in production data today (the `onUserProfileUpdated` trigger only fixes this going forward, not retroactively).
5. **Deploy is required for several fixes to take effect on the live project** — none of this pass has been deployed. Specifically worth calling out: `paymentWebhook`'s removal (Phase 3b) doesn't retract the live function until `firebase deploy --only functions` runs or you delete it explicitly — **check Cloud Functions logs for any real recent traffic to it first**, in case something outside this repo still targets it.
6. **Host `assetlinks.json`** at `https://kwayapro.app/.well-known/assetlinks.json` (Phase 6) — no hosting config exists in this repo yet (Firebase Hosting is the natural fit). Android App Links cannot verify without it.

### C. External verification (MTN, requires portal access this environment doesn't have)
7. **MTN's real callback authentication mechanism** (Phase 3) — could not be confirmed against an authoritative source (`momodeveloper.mtn.com`/`momoapi.mtn.com` are both gated/JS-rendered portals). The current interim scheme (a shared secret embedded in the callback URL) is sound reasoning but unverified against MTN's actual spec — confirm before trusting it for real production payment volume.
8. **MTN's production Collections API host** (`momoapi.mtn.com`, Phase 3) — sourced from third-party integration references, not an authoritative MTN doc page. Confirm before flipping `MTN_TARGET_ENV` to production.

### D. Store listing assets (need real product/design content, not fabricated here)
9. **Play Store feature graphic** (1024×500) — entirely missing.
10. **Play Store screenshots** (min. 2, ideally 4+) — entirely missing.

### E. Real device / emulator verification (the "look at your phone" batch — do these together, per your instruction)
11. **Play a track online, enable airplane mode, replay it from cache** (Phase 5b) — confirms the offline audio caching wiring actually works end-to-end on a real player, not just the data layer (which is tested).
12. **Tap a real rehearsal-invite / choir-join App Link on a device** (Phase 6) — confirms Android App Links actually resolve once `assetlinks.json` (item 6) is hosted; can't be verified from this environment even after hosting it.
13. **Install the app and look at the launcher icon** (Phase 6b) — confirms the real Android adaptive-icon rendering (OS mask shape, any launcher-specific cropping) matches intent; static file inspection already confirmed the underlying assets are correct, but only a real device/launcher shows the final composited result.

### F. Platform gaps still open (larger, pre-existing scope)
14. **iOS**: still has a placeholder Firebase `appId` (`ios.appId: '...:placeholder'`) and no Associated Domains / Universal Links entitlement at all — iOS builds will crash on Firebase init today, and iOS deep links don't work. Requires registering a real iOS app in the Firebase console and running `flutterfire configure`.

### G. Flagged-not-fixed from Phase 7 (real refactors, not cleanup-tier)
15. **`onboarding_screen.dart`'s direct Firestore batch write** — bypasses the repository layer; fixing it means redesigning `ChoirRepository` around a multi-collection batch-create and re-threading the app's most critical first-run flow through it.
16. **Dead R2 `presignedUrlEndpoint.ts`** — deployed, holds live R2 credentials, zero callers. Needs a decision: finish wiring the client to use it, or remove it and retire its secrets.
17. **Wide-scope `ref.watch` in `home_screen.dart`/`library_screen.dart`** — causes full-screen rebuilds on unrelated state changes; fixing it means extracting `Consumer` subwidgets around two of the app's largest screens.
18. **`flutter_lints` 3.0.2 → 6.0.0** — a 3-major-version jump likely to surface many new lint violations; not bumped blind.

---

## 4. Everything explicitly investigated and found NOT to be a problem

Worth stating plainly so these don't get re-investigated later:
- Rehearsal scheduling, RSVP, and guest-director flows are genuinely wired to Firestore, not stubs (re-verified Phase 5).
- No prototype-only controls, debug menus, role switchers, or `kDebugMode`-gated UI exist anywhere in the app (re-verified Phase 7, after also being clean in the original audit).
- No hardcoded test credentials, emulator-host references, or `isAuthenticated = true`-style bypasses exist anywhere.
- `flutter analyze` and `tsc --noEmit` are clean throughout the entire pass, every phase, start to finish.
- Modals/bottom sheets, landscape lock, and mic-permission handling in the Studio screen were all independently verified correct (Phase 6 report, §6 of the original audit).
- Bundled asset size is negligible; audio playback correctly streams rather than downloads-then-plays.

---

## 5. How to read the rest of this repo

- `PRODUCTION_READINESS_AUDIT.md` — the original, full audit this whole pass was based on.
- `CODEBASE_AUDIT.md` — the audit that preceded the original audit (reconciled against it in §10 of `PRODUCTION_READINESS_AUDIT.md`).
- `PHASE_1_REPORT.md` through `PHASE_7_REPORT.md` (plus 2B, 2C, 3B, 3C, 5B, 6B) — full technical detail, file/line citations, and verification evidence for every fix summarized above.
- `firestore-tests/` and `functions/test/` — the newly-committed, newly-persistent test suites for security rules and payment functions.

This is the final phase of this production-readiness pass. No further phases are planned unless you direct otherwise.
