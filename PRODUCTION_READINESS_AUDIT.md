# KwayaPro — Production Readiness Audit

**Date:** 2026-07-09
**Scope:** Full repo at commit `23bbe28` + working-tree changes (see `git status`)
**Method:** Direct code inspection (file/line citations below), cross-checked against prior `CODEBASE_AUDIT.md` (2026-06-16), plus external verification against Flutter/Firebase/MTN MoMo docs where noted.
**Status:** Audit only. No code was modified.

---

## 1. Executive Summary

| Severity | Count |
|---|---|
| BLOCKER | 10 |
| PRE-LAUNCH | 18 |
| HYGIENE | 11 |
| POST-BETA (deferred) | 5 |

**Prior-audit reconciliation:** of 12 tracked findings from `CODEBASE_AUDIT.md`, **8 CONFIRMED FIXED**, **2 PARTIALLY FIXED / introduced new dangling-reference risk**, **2 NOT FIXED**, and **0 clean regressions** — but the fixes to the duplicate-file problems (rules/indexes/firebase_options) introduced **2 new BLOCKER-severity deploy-configuration risks** that the prior audit could not have caught. Full table in §10.

**Headline risk:** the payment system is not production-safe in either direction. It cannot process a real MTN MoMo payment (hardcoded sandbox host, a response-double-send bug that crashes the function on every call), and its webhook trust model is broken such that an unauthenticated request can either be silently accepted (secret unset → free Pro upgrade for any choir) or every genuine MTN callback is rejected (secret set → 403 on real payments), with no idempotency check either way. This alone blocks beta launch of the billing feature. Independently, a plaintext file at the repo root (`set_secrets.js`) currently holds live-looking MTN and Cloudflare R2 credentials one `git add .` away from being committed, and the root `storage.rules` (the file `.firebaserc` actually deploys) is `allow read, write: if false` — deploying from the repo root as currently configured would brick all audio/photo storage in production.

The rehearsal/RSVP/guest-director "3 partial features" from the prior audit are now genuinely wired to Firestore — this is real, verified progress. Test coverage, however, has not grown at all despite substantial new logic (rehearsal wiring, router fix, new Studio/audio code).

---

## 2. Findings by Section

### Section 1 — Data Integrity & Model Safety

**[BLOCKER] Hard-cast fields in `audio_part.dart`, `score_attachment.dart`, `song_section.dart` will crash on any legacy/malformed document**
`kwayapro/lib/features/songs/domain/models/audio_part.dart:29-37`, `score_attachment.dart:26-35`, `song_section.dart:21-28` — every field uses `json['x'] as String`/`as int`/`as Timestamp` with no nullable fallback, unlike every other model in the codebase (`app_user.dart`, `attendance.dart`, `choir.dart`, etc., which were evidently patched after the original `AppUser.onboardingComplete` incident but these three were missed). `song_repository.dart:112-155` maps every doc through these constructors with no per-doc try/catch inside `watchSections`/`watchAudioParts`/`watchAudioPartsByVoicePart` — **one bad document takes down the stream for every listener** (e.g. every chorister viewing that song's voice-part audio).
*Fix:* apply the same `as Type? ?? default` pattern used in `app_user.dart:26-33` to all fields in these three models; wrap the per-doc `fromJson` call in `snapshot.docs.map(...)` with a try/catch that skips and logs the bad doc instead of throwing.

**[PRE-LAUNCH] Chat message pin/unpin is structurally broken**
`kwayapro/lib/features/chat/data/chat_repository.dart:27-38` — `messageId` is generated via `.doc().id` (a throwaway random ID) but the message is actually persisted via `.add()`, which assigns a *different* auto-generated document ID. `pinMessage`/`unpinMessage` (`:78,98`) then call `.doc(message.messageId).update(...)` against an ID that was never the real document ID, so pin/unpin will always fail with `not-found`.
*Fix:* use `final docRef = _db.collection('chat_messages').doc(); message.copyWith(messageId: docRef.id); await docRef.set(...)` instead of `.add()`, so the stored `messageId` matches the real document ID.

**[PRE-LAUNCH] Freemium song-limit check-then-act race**
`kwayapro/lib/features/songs/data/song_repository.dart:159-177` — `isAtSongLimit` (read) and `incrementSongCount` (atomic increment) are two independent, non-transactional steps invoked from `library_screen.dart:469,556`. Two concurrent uploads at `songCount == 2` can both pass the limit check, breaching the free-tier cap. Compounded by no server-side enforcement (see Section 8).
*Fix:* wrap the check-and-create in a `runTransaction` that reads `songCount` and the new song doc atomically, or enforce the cap in a Firestore rule/Cloud Function (see Section 8 fix).

**[PRE-LAUNCH] Subscription double-submit race**
`kwayapro/lib/features/subscription/data/subscription_repository.dart:29-59` — `createSubscription` uses plain `.add()` with no check for an existing pending/active subscription for the choir; `updateSubscriptionStatus` matches by `txRef` via an unordered, unlimited-order `.limit(1)` query. A double-tap or client retry can create two `pending` docs, and which one later "wins" active status is nondeterministic. Currently masked by `firestore.rules` blocking all client writes to `subscriptions` (see Section 8), but the application logic itself is unsafe.
*Fix:* dedupe by a deterministic doc ID (e.g. `choirId` or `txRef` as doc ID) instead of `.add()`.

**[HYGIENE] Composite-ID convention duplicated, not shared**
`attendance_repository.dart:21,32,90` and `rehearsal_repository.dart:104,114` both independently rebuild the `${sessionId}_${userId}` string. Currently consistent, but a future edit to one without the other would silently create orphaned docs.
*Fix:* extract a single `AttendanceIds.compositeId(sessionId, userId)` helper used by both repositories.

**[HYGIENE] Invite code collisions are never checked**
`choir_repository.dart:26-29`, `onboarding_screen.dart:366-375` — invite codes are generated and written without a uniqueness check or transaction. Low probability with 6-char random codes, but undetectable if it happens.
*Fix:* check-then-set inside a transaction, or add a Firestore rule enforcing invite-code uniqueness isn't practical — instead, retry generation on a post-write existence check.

**[HYGIENE] `*.byName()` calls will throw on a stale/renamed enum value**
e.g. `attendance.dart:23,27`, `choir.dart:36`, `subscription.dart:27,30,36`, `audio_part.dart`'s `VoicePart.values.byName(...)`. Not currently a problem (no enum renames have happened), but any future enum rename without a data migration will crash `fromJson` for old documents.
*Fix:* use `VoicePart.values.asNameMap()[value] ?? VoicePart.defaultValue` pattern going forward.

---

### Section 2 — Security & Permissions

**[BLOCKER] `paymentWebhook` allows unauthenticated Pro upgrades**
`functions/src/index.ts:216-259` — signature verification is conditional on the header being present at all: `if (signature) { ...verify... }` — if `x-webhook-signature` is simply omitted from the request, verification is skipped entirely and the function proceeds to `db.collection('subscriptions').doc(choirId).set({plan:'pro', status:'active'}, {merge:true})` and `db.collection('choirs').doc(choirId).update({plan:'pro'})`. This is a public `onRequest` HTTPS endpoint. Anyone who knows a `choirId` (choir IDs are not secret — they appear in invite-code flows and deep links) can POST `{status:"completed", choirId:"<target>"}` with no headers and upgrade that choir to Pro for free.
*Fix:* reject any request missing the signature header (fail closed, not fail open); verify via true HMAC-SHA256 of the raw request body using a shared secret, not a static string equality check.

**[BLOCKER] `mtnWebhook` signature check is a no-op or blocks all real traffic — and has no idempotency guard**
`functions/src/index.ts:339-384` — same `if (expected && signature !== expected)` fail-open pattern: if `MTN_WEBHOOK_SECRET` isn't configured, verification is skipped. If it is configured, the check compares against a literal header MTN's actual Collections API callback format does not send (public/community documentation reviewed shows no `x-webhook-signature`-style header in MTN's callback payload — see §5 doc appendix), meaning **every genuine MTN callback would be rejected with 403** once the secret is set. There is also no dedupe/idempotency check before extending `endDate` by 30 days and marking `payment_requests` completed — a replayed or forged callback (trivial in the fail-open configuration) can be resent indefinitely to keep a choir on Pro forever.
*Fix:* determine MTN's actual callback authentication mechanism (see §5 appendix — requires authenticated portal access to confirm definitively), implement it correctly, and add an idempotency check (`payment_requests.status == 'completed'` already ⇒ no-op) before applying any state change.

**[BLOCKER] `initiatePayment` sends two HTTP responses on every MTN call**
`functions/src/index.ts:262-336` — the `provider === "mtn"` branch calls `res.json(...)` inside its try/catch, then execution falls through unconditionally to `res.status(400).json({error: "Unsupported provider (Airtel disabled)"})` right after the `if` block (not in an `else`). This throws `ERR_HTTP_HEADERS_SENT` on every successful MTN payment initiation.
*Fix:* add `return` after the first `res.json(...)` call, or restructure as `if/else if/else`.

**[BLOCKER] MTN integration is hardcoded to the sandbox host**
`functions/src/index.ts` ~lines 277, 295, 301 — `https://sandbox.momodeveloper.mtn.com/...` is a literal string; only `X-Target-Environment` is configurable via secret. Flipping `MTN_TARGET_ENV` to production does not change which host is called — the function cannot process real payments without a code change.
*Fix:* derive the base URL from `mtnTargetEnv.value()` (e.g. `sandbox` → sandbox host, `production` → `https://proxy.momoapi.mtn.com` or MTN's documented production host — confirm exact host via authenticated portal access).

**[BLOCKER] Live-looking credentials committed in plaintext at repo root**
`set_secrets.js` (untracked, **not gitignored**) contains literal values for `MTN_API_KEY`, `MTN_SUBSCRIPTION_KEY`, `MTN_WEBHOOK_SECRET`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`. This is one `git add .` away from being pushed to the remote, and may already be in shell history. Contrast with `set_airtel_secrets.js`, which only writes placeholder `'dummy'` values.
*Fix:* rotate all listed MTN and R2 credentials immediately; delete `set_secrets.js` from disk or move it outside the repo; add `set_secrets.js` to `.gitignore` as defense-in-depth; use `firebase functions:secrets:set` interactively instead of a script holding literal values.

**[BLOCKER] Root `storage.rules` is deny-all and is the file that actually gets deployed**
Root `storage.rules` = `allow read, write: if false` for all paths. `.firebaserc` lives at repo root, and root `firebase.json` references root `storage.rules`. `kwayapro/storage.rules` has the real working rules (per-user avatar access, per-choir audio access) but is not the file `.firebaserc`/root `firebase.json` will deploy. Running `firebase deploy` from the repo root as currently configured would push a deny-all storage ruleset to production, breaking all audio upload/playback and profile photos app-wide.
*Fix:* consolidate to a single `storage.rules` (keep the kwayapro/ working version), delete the root deny-all copy, and verify `firebase.json` at the deploy root points to the correct file before any deploy.

**[BLOCKER] `kwayapro/firebase.json` references deleted `firestore.rules`/`firestore.indexes.json`**
`git status` confirms `kwayapro/firestore.rules` and `kwayapro/firestore.indexes.json` were deleted (consolidating to the root copies — a good move), but `kwayapro/firebase.json` still has `"firestore": {"rules": "firestore.rules", "indexes": "firestore.indexes.json"}` pointing at now-nonexistent local files. Any deploy invoked with `kwayapro/` as the active Firebase config directory will fail outright or silently apply stale/cached rules.
*Fix:* either delete `kwayapro/firebase.json`'s firestore stanza (rely on root config only) or update its paths to point at the root files (`../firestore.rules`), and confirm which `firebase.json` is actually used by the team's deploy process.

**[BLOCKER] `choir_memberships` create rule permits client-controlled self-elevation to `director`**
Root `firestore.rules` — the `choir_memberships` create rule allows `request.resource.data.role in ['chorister', 'director']`. Combined with open `choirs` creation and a membership-owner self-update rule, a user can create their own membership document with `role: 'director'` directly (bypassing any leader-granted promotion), gaining director-level write access to songs, rehearsals, and programs for that choir.
*Fix:* restrict self-serve join creation to `role == 'chorister'` only; require a leader/director-authored write (checked via `hasAnyRole`) for any membership doc with `role in ['director']`.

**[BLOCKER] `users/{userId}` read rule exposes all users' PII to any authenticated account**
Root `firestore.rules` — `match /users/{userId} { allow read: if isAuthenticated(); }` has no choir-scoping; any signed-in user (even one with zero shared choirs) can read any other user's `phone`, `name`, `profilePhotoUrl` by doc ID.
*Fix:* scope reads to the requesting user's own doc, or to users who share at least one choir membership with the requester (via a `get()` check against `choir_memberships`).

**[PRE-LAUNCH] Guest director token expiry is best-effort, not real-time enforced**
`functions/src/index.ts:171-186` `checkGuestTokenExpiry` runs on a 30-minute schedule and deletes expired tokens — this is cleanup, not access control. No Firestore rule references `guestToken`/`guestTokenExpiry` at write time (`rehearsal_sessions` writes are gated only by `hasAnyRole`), so a captured/stale guest token can remain functionally valid for up to 30 minutes past its intended expiry with no rule blocking it in real time.
*Fix:* add a rule condition checking `guestTokenExpiry > request.time` wherever guest-director write access is granted, rather than relying solely on scheduled cleanup.

**[HYGIENE] Inline role comparisons bypass `PermissionChecker`**
`attendance_screen.dart:94`, `rehearsals_screen.dart:27-28`, `chat_screen.dart:46-47`, `home_screen.dart:196,202,213`, `library_screen.dart:42` all re-implement `isManagement`/`isLeader` logic inline instead of calling `PermissionChecker`. Currently consistent with the centralized logic, but a drift risk if the permission model changes — Firestore rules remain the real enforcement boundary, so this is not an active bypass.
*Fix:* replace inline comparisons with `permissionCheckerProvider` calls for consistency and single-source-of-truth.

**[HYGIENE] Direct Firestore access outside the repository layer**
`onboarding_screen.dart:6,343` writes directly to `users`/`choirs`/`choir_memberships` from a UI screen; `choir_providers.dart:1,96-105` (`songLibraryProvider`) builds a raw Firestore query in a domain/provider file instead of calling `SongRepository`. Not a security hole (still subject to the same rules) but breaks the audited repository pattern and duplicates logic.
*Fix:* route both through `ChoirRepository`/`SongRepository`.

---

### Section 3 — State Management & Architecture

**[PRE-LAUNCH] `Provider<GoRouter>` is recreated on every auth/choir stream emission**
`kwayapro/lib/core/router/app_router.dart:27-29` — `routerProvider` is a plain `Provider<GoRouter>` that `ref.watch`es `authStateProvider`, `userChoirsProvider`, and `currentUserProvider`. GoRouter is recreated (not just refreshed) on every emission from any of these three streams — e.g. every Firestore snapshot update to the user doc, not just sign-in/out. This is architecturally the exact `refreshListenable`-shaped problem go_router's docs exist to solve, and it is not implemented here.
*Fix:* per go_router's documented pattern, create a single stable `GoRouter` instance (e.g. in a `Provider` with no watched dependencies, constructed once) and pass a `GoRouterRefreshStream` (a `ChangeNotifier` wrapping the auth/choir streams) as `refreshListenable`, using `redirect` logic to react to state changes without discarding the router.

**[PRE-LAUNCH] Studio screen has no Director-only access enforcement**
`kwayapro/lib/features/studio/presentation/studio_screen.dart` and the `/studio` route in `app_router.dart:88-107` — no `PermissionChecker` check or route guard exists. Any authenticated member (including choristers) can navigate to `/studio` (e.g., via a deep link) and record/upload audio for a song section, contrary to the "Director-only" requirement.
*Fix:* add a route-level redirect guard checking `currentMembershipProvider.role`, and/or an in-screen check that pops back with a clear message if the user isn't a director.

**[PRE-LAUNCH] Choir/session-scoped family providers never `.autoDispose`**
`songLibraryProvider`, `songsByVoicePartProvider`, `songsWithPartsProvider` (song_providers.dart), `chatMessagesProvider`/`pinnedMessageProvider`, `sessionAttendanceProvider`/`myAttendanceHistoryProvider`, `songScoresProvider`, `songProgramsProvider`/`publishedProgramsProvider`/`draftProgramsProvider`, `subscriptionProvider`/`currentSubscriptionProvider`, and all four rehearsal providers are not `.autoDispose`. Every distinct choir/session/song a user ever views during the app's lifetime keeps a live Firestore listener and cached value in memory permanently.
*Fix:* add `.autoDispose` to all `.family` providers keyed by an entity ID that changes across navigation (choir switch, song list scroll, etc.).

**[HYGIENE] Duplicate, divergent `songLibraryProvider` definitions**
Defined once in `choir_providers.dart:89` (raw Firestore query, autoDispose) and again in `song_providers.dart:15` (delegates to `SongRepository`, not autoDispose). Both files are imported unqualified in `library_screen.dart`; currently no direct reference to the bare name avoids a compile conflict, but this is fragile.
*Fix:* delete the `choir_providers.dart` copy; standardize on the repository-backed version.

**[HYGIENE] Minor controller leak**
`onboarding_screen.dart:65-78` `dispose()` never disposes `_emailController`/`_passwordController` (declared at lines 39-40).
*Fix:* add both to `dispose()`.

**[HYGIENE — VERIFIED RESOLVED]** AnimatedSwitcher key collisions (previously flagged bug) and controllers-created-inside-`build()` were both checked exhaustively and found already fixed/absent — no `AnimationController` usage exists anywhere in the app, and every step's `ValueKey` in `onboarding_screen.dart` now encodes its full sub-state.

---

### Section 4 — Offline & Reliability

**[PRE-LAUNCH] No functioning offline audio playback despite dedicated cache infrastructure**
`kwayapro/lib/shared/services/audio_cache_service.dart` exists and is initialized at app startup (`main.dart:54-55`) but `getCachedPath()`/`cacheAudio()` are never called anywhere else in the codebase. `AudioPlayerNotifier.play()` streams directly from the remote Storage URL every time, including replays of the same track. This is a direct gap against PRD 9.1–9.2 (offline audio via caching).
*Fix:* wire `AudioCacheService` into `AudioPlayerNotifier.play()` — check cache first, stream-and-cache on miss — or remove the unused service if offline audio is being deferred (and update the PRD/roadmap accordingly).

**[PRE-LAUNCH] Silent no-op writes when offline in attendance repository**
`attendance_repository.dart:66-68` (`batchMarkRSVPAttended`) and `:90-93` (`setVoicePartOverride`) return early with no queuing and no user feedback when offline, unlike `markAttendance` in the same file, which correctly branches to a merge-set. The user has no indication the action was dropped rather than saved.
*Fix:* apply the same offline-merge-set pattern used in `markAttendance`, or surface an explicit "will sync when online" state to the UI.

**[PRE-LAUNCH] No retry/backoff on Storage uploads**
`audio_repository.dart:14-65` and `chat_repository.dart:112-164` call `ref.putFile(...)` once with no retry or resumable-upload recovery. A transient connectivity drop mid-upload permanently loses the attempt; `studio_screen.dart:520-531` does surface the failure via SnackBar (not silent), but there's no automatic retry as required by the PRD's "failed uploads retry automatically" language.
*Fix:* wrap uploads in a retry-with-backoff helper (2-3 attempts), and only show a permanent-failure notification after retries are exhausted.

**[HYGIENE] Dead R2 presigned-upload Cloud Function**
`functions/src/audio/presignedUrlEndpoint.ts` implements a full presigned-URL flow with live R2 secrets, but nothing in the Flutter app calls it (grep for `presigned` returns zero client-side matches — uploads go straight to Firebase Storage instead). This is either orphaned infrastructure or an unfinished migration; either way it's a deployed function holding live credentials with no known caller.
*Fix:* confirm intent with the team — either finish wiring the client to use R2, or remove the function and rotate/retire its secrets.

**[HYGIENE] Unbounded Firestore cache size**
`main.dart:36-39` sets `cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED` — reasonable for beta scale but should be revisited (a fixed ceiling, e.g. 100MB) before long-lived production installs accumulate unbounded local cache.

**[HYGIENE — VERIFIED]** Firestore offline persistence is explicitly enabled (`main.dart:36-39`); the main practical gap is audio caching (above), not the Firestore layer itself.

---

### Section 5 — Performance

**[PRE-LAUNCH] `initFCM()` awaited before `runApp()` blocks first frame on the OS permission dialog**
`main.dart:57` / `fcm_handler.dart:6-17` — `await initFCM()` calls `await messaging.requestPermission(...)`, which on iOS suspends until the user responds to the native permission prompt. Since this runs before `runApp()`, the user can see a blank screen for an indefinite period (until they interact with the OS dialog), directly risking the PRD's 3-second cold-start target.
*Fix:* call `runApp()` first, then request notification permission asynchronously (fire-and-forget or deferred to after first frame / after onboarding).

**[PRE-LAUNCH] Two unbounded, platform-wide Firestore listeners with N+1 reads**
`song_repository.dart:140-152` `watchAudioPartsByVoicePart` has no `.where('choirId', ...)` and no `.limit()` — it listens to every `audio_parts` document across every choir on the platform, and re-fetches the parent `songs` doc individually for each one on every emission. `audio_repository.dart:108-122` `watchChoirListenEvents` has the identical pattern. Cost and latency scale with total platform-wide document count, not the caller's choir, and every unrelated choir's activity re-triggers the fan-out for every listening client.
*Fix:* add `.where('choirId', isEqualTo: choirId)` to both queries; batch the parent-song lookups (e.g. a single `whereIn` on distinct `songId`s) instead of per-doc awaits inside `asyncMap`.

**[HYGIENE] `AudioCacheService.init()` runs at startup for a feature that's unused (see §4) — pure cold-start overhead with no benefit today.**

**[HYGIENE] Wide-scope `ref.watch` at top of large `build()` methods**
`home_screen.dart:26-33` watches 6 providers (including full member-list and rehearsal streams) at the top of a 446-line build; `library_screen.dart:38-42` watches `currentMembershipProvider` at the top of a 768-line build purely to gate a small control. Both cause full-screen rebuilds on unrelated state changes.
*Fix:* wrap the narrowly-scoped state (member list, rehearsal card, the management-gated control) in their own `Consumer` widgets so only that subtree rebuilds.

**[HYGIENE — VERIFIED]** Audio playback correctly streams (not download-then-play) via `just_audio`'s `setUrl`, which is the right pattern for first-byte latency; bundled asset size is negligible (~7KB total, no binary payloads currently checked in) so the 50MB install-size constraint is not at risk today. `flutter analyze` runs clean with zero issues.

---

### Section 6 — UI/UX & Platform Correctness

**[HYGIENE] `Scaffold backgroundColor` set on only 2 of 19 screens**
Only `onboarding_screen.dart:433` and `studio_screen.dart:148` explicitly set `backgroundColor`; the other 17 (`attendance_screen.dart`, `home_screen.dart`, `members_screen.dart`, `member_detail_screen.dart`, `planner_screen.dart`, `guest_director_screen.dart`, `rehearsals_screen.dart`, `library_screen.dart`, `billing_screen.dart`, `profile_screen.dart`) rely on the M3 default. Not currently broken (M3 default is `colorScheme.surface`, not black), but the two explicit overrides suggest an awareness of a past issue that wasn't applied consistently.
*Fix:* set `backgroundColor: Theme.of(context).colorScheme.surface` (or omit deliberately) consistently across all screens as a matter of policy, and document the decision.

**[PRE-LAUNCH] Studio screen Director-only gap** — see Section 3 (architecture-level fix, listed once).

**[HYGIENE] Icon-only buttons missing `tooltip`/`Semantics` labels**
`home_screen.dart:120-123` (profile), `attendance_screen.dart:30-33` (back) and `:54-57` (save — the primary action on the screen, with zero accessible label), `chat_screen.dart:603-609` (delete/send). `chat_screen.dart:244-247` shows the correct pattern is known (`tooltip: 'Share to WhatsApp'`) but inconsistently applied elsewhere.
*Fix:* add `tooltip:` to every icon-only `IconButton`, prioritizing primary actions (attendance save) first.

**[PRE-LAUNCH] Raw exception text surfaced to end users across ~15 screens**
`member_detail_screen.dart:64,355`, `onboarding_screen.dart:154,186,425`, `planner_screen.dart:124,404,523,546`, `studio_screen.dart:530`, `attendance_screen.dart:81,84,214,231,433`, `members_screen.dart:126`, `library_screen.dart:435,596`, `chat_screen.dart:104`, `billing_screen.dart:178`, `profile_screen.dart:42`, `guest_director_screen.dart:202` all interpolate `$e`/exception `.toString()` directly into `Text`/`SnackBar` widgets — this violates PRD 9.3 (plain-English error messages) and can leak internal details (Firestore error codes, collection paths).
*Fix:* introduce a shared `friendlyErrorMessage(Object e)` mapper (e.g. in `shared/utils/`) that translates known `FirebaseException` codes and generic errors to plain-English copy, and route every catch block's user-facing text through it.

**[HYGIENE — VERIFIED]** Modals/bottom sheets are correctly scoped (`SafeArea` + `mainAxisSize.min` + `isScrollControlled` where needed) — no `Positioned.fill`/sizing bugs found, including the Choir Switcher. Landscape lock and mic-permission-denial handling in the Studio screen are correctly implemented. Tap-count targets are met: RSVP (2 taps), play a song (2 taps); marking attendance is 3 taps (open session → open attendance → save), one over the PRD's "2 taps" language if that target is meant to include the save action — worth confirming intended interpretation with product.

---

### Section 7 — Prototype/Debug Cleanup

**[HYGIENE] No prototype-only controls, debug menus, role switchers, or `kDebugMode`-gated UI found anywhere in the app** — this section of the prior audit's claim ("zero matches") holds up under a fresh, broader grep (also checked `TODO`/`FIXME`/`HACK`, hardcoded test phone numbers, `isAuthenticated = true` bypasses — all zero matches).

**[HYGIENE] `app_logger.dart` uses raw `print()` unconditionally**
`kwayapro/lib/core/utils/app_logger.dart:61,64,68` — these run in all build modes (not gated by `kDebugMode`), so they'll appear in release-build device logs. Not a functional bug, minor noise/info-leak surface.
*Fix:* gate with `if (kDebugMode)` or switch to a logging package with build-mode-aware sinks.

**[NOTE]** The one genuinely sensitive "hardcoded credential" item for this section is `set_secrets.js`, already covered as a BLOCKER in Section 2 — not duplicated here.

---

### Section 8 — Payments (MTN MoMo / Airtel)

*(Signature/idempotency/sandbox-host findings already listed as BLOCKERs in Section 2; not repeated here.)*

**[BLOCKER] The billing UI is entirely disconnected from the real payment backend**
`billing_screen.dart:140-181` `_processPayment()` never calls `initiatePayment` or any Cloud Function — it writes directly to Firestore (`createSubscription` → `Future.delayed(2s)` → `updateSubscriptionStatus(active)`), simulating a successful payment client-side with no phone number entry, no MTN API call, no server round-trip at all.
*Mitigating factor:* `firestore.rules` blocks all client writes to `subscriptions` (`allow write: if false`), so today this flow fails with `PERMISSION_DENIED` rather than granting free Pro — checkout is simply broken, not exploitable, **as currently configured**. But it is one relaxed rule away (e.g. "temporarily" loosened for testing) from becoming a trivial free-upgrade exploit, and it means billing does not work at all today.
*Fix:* wire `_processPayment()` to call the `initiatePayment` Cloud Function with the user's phone number, poll/await the real webhook-driven status update, and remove the client-side `updateSubscriptionStatus(active)` call entirely (subscription status should only ever be set server-side).

**[PRE-LAUNCH] Freemium 3-song limit has no server-side enforcement**
Confirmed via `firestore.rules` — the `songs` `create` rule checks only `isTenantMember` + role, never reads `choirs/{choirId}.songCount`/`.plan`. `isAtSongLimit()` in `song_repository.dart:159-165` is consulted only by the UI (`library_screen.dart:469`) before allowing an add — trivially bypassed by any direct Firestore write.
*Fix:* add a `get()`-based check in the `songs` create rule (the rules file already uses this pattern elsewhere for role lookups) validating `songCount < 3 || plan == 'pro'` before allowing creation, or move song creation through a Cloud Function that enforces the cap server-side.

**[PRE-LAUNCH] Airtel Money is selectable in the UI with no "coming soon" gating**
`billing_screen.dart` ~lines 355-361 renders Airtel Money as a fully selectable `_ProviderCard`, visually and interactively identical to MTN, with no disabled state or badge. Backend explicitly rejects it (`"Unsupported provider (Airtel disabled)"`), but the current fake client-side flow means selecting Airtel today silently "succeeds" via the same broken mock path as MTN (see above) rather than erroring — once the real backend is wired, users who pick Airtel will hit a generic failure with no explanation of why.
*Fix:* gray out / disable the Airtel option with a "Coming soon" label until the integration is real.

---

### Section 9 — Build & Deployment Readiness

**[PRE-LAUNCH] iOS Firebase config still uses a placeholder App ID**
`kwayapro/lib/core/firebase/firebase_options.dart:31-38` — `ios.appId: '1:432531236139:ios:placeholder'`. iOS builds will crash on Firebase initialization. (Confirmed still present; prior audit's finding was NOT fixed.)
*Fix:* register a real iOS app in the Firebase console and regenerate `firebase_options.dart` via `flutterfire configure`.

**[PRE-LAUNCH] No production app icon — Play Store asset requirement unmet**
`android/app/src/main/res/mipmap-*/ic_launcher.png` are still the stock Flutter template placeholder icons (e.g. `mipmap-mdpi/ic_launcher.png` is 442 bytes). No rasterized 512×512 PNG exists anywhere in the repo (`kwayapro/assets/icons/` only has SVGs).
*Fix:* generate branded launcher icons (all mipmap densities) and a 512×512 PNG for Play Store listing, e.g. via `flutter_launcher_icons`.

**[PRE-LAUNCH] iOS Universal Links are not configured at all**
Android App Links are correctly set up (`AndroidManifest.xml:27-32`, `autoVerify="true"`, host `kwayapro.app`, matching the `/join/:inviteCode` and `/rehearsal-invite/:token` router paths). iOS has no Associated Domains entitlement referencing `kwayapro.app` anywhere in `Runner.entitlements`/`Info.plist` — invite/rehearsal deep links will not work on iOS at all.
*Fix:* add the `applinks:kwayapro.app` Associated Domain entitlement and host `apple-app-site-association` at the domain, alongside the existing Android `assetlinks.json` requirement (also not present in-repo — verify it's hosted server-side).

**[HYGIENE] Test coverage has not grown despite significant new logic** — see §10 item 12; still 4 test files, <5% estimated coverage, no tests for the newly-wired rehearsal/RSVP/guest-director flows, router redirect logic, or the new Studio/audio code.

**[HYGIENE] `flutter_lints: ^3.0.0` is stale** (current upstream major is newer) — present, which is good, but worth bumping.

**[VERIFIED CLEAN]** `flutter analyze` runs with **zero issues**. No emulator/localhost references found anywhere in `lib/`. `pubspec.yaml` has no unconstrained (`any`) dependency ranges; pre-1.0 packages (`just_audio`, `audio_session`, `rxdart`) are properly caret-locked, just inherently less stable upstream — acceptable, monitor for breaking 0.x bumps.

---

## Section 10 — Prior Audit Reconciliation

| Prior Finding | Prior Claimed Status | Actual Current Status | Evidence (file/line) | Notes |
|---|---|---|---|---|
| Duplicate `firebase_options.dart` | Issue (duplicate) | **CONFIRMED FIXED** | `kwayapro/lib/firebase_options.dart` deleted; `main.dart:11` imports only `core/firebase/firebase_options.dart` | Clean. |
| Duplicate `firestore.rules` (hasAnyRole vs isLeader) | Issue (duplicate) | **PARTIALLY FIXED — new risk introduced** | `kwayapro/firestore.rules` deleted; root survives with `hasAnyRole()`. `kwayapro/firebase.json` still points at the now-deleted local file | New BLOCKER: dangling deploy reference — see §2. |
| Duplicate `firestore.indexes.json` | Issue (duplicate; prior audit claimed root had more indexes incl. song_sections/audio_parts) | **PARTIALLY FIXED / prior claim inaccurate** | Root `firestore.indexes.json` now has only `chat_messages` + `rehearsal_sessions` entries — no song_sections/audio_parts indexes ever existed in either copy per `git diff` | Duplicate removed (good); the specific prior claim about index contents doesn't hold up against either the old or new file. Low practical risk since the underlying queries are single-field subcollection orderings. |
| iOS placeholder appId | Issue | **NOT FIXED** | `firebase_options.dart:31-38`, `ios.appId: 'ios:placeholder'` | Still blocks iOS deploy. |
| Rehearsal providers were 4 stubs | Issue | **CONFIRMED FIXED** | `rehearsal_providers.dart:13-33` — all four call real `RehearsalRepository` Firestore stream methods | Genuine wiring, verified. |
| Guest director stub-to-Firestore wiring | Partial | **CONFIRMED FIXED** | `guest_director_screen.dart:192,239`, `rehearsal_repository.dart:76,147`, `app_router.dart:401-409` | End-to-end token generate→validate→join flow implemented, though expiry enforcement is only scheduled cleanup — see §2. |
| GoRouter mid-flow redirect bug (kicks user out of onboarding step 4→5) | Confirmed bug | **CONFIRMED FIXED** | `app_router.dart:67-76` now checks `user.onboardingComplete` instead of `choirs.isNotEmpty`, with an explicit comment documenting the fix | Verified correct. |
| `AppUser.onboardingComplete` null-cast crash | Implied risk | **CONFIRMED FIXED** | `app_user.dart:32` — `json['onboardingComplete'] as bool? ?? false` | All fields in this model are null-safe. |
| `debugLogDiagnostics: true` left in production | Issue | **CONFIRMED FIXED** | `app_router.dart:53` — `debugLogDiagnostics: kDebugMode` | Correctly gated. |
| Airtel MoMo secrets commented out | Issue (disabled) | **NOT FIXED** | `functions/src/index.ts:20-22` still commented; `:331` rejects non-MTN provider; `:386` bare comment | New `set_airtel_secrets.js` only sets placeholder `'dummy'` values — no functional change. |
| 20/24 implemented, 3 partial (rehearsal, RSVP, guest director) | Partial | **UPGRADED — effectively 23/24**, only iOS deployability remains a true gap | Per rows above | Real, verified feature-completeness progress. |
| Test coverage <5%, 4 test files | Issue | **NOT FIXED / unchanged** | `kwayapro/test/` — same 4 files as before | No new tests despite substantial new logic; coverage gap effectively worse in relative terms. |

**New issues found since the prior audit (regressions/side-effects of its own fixes):**
1. **Hardcoded live secrets in `set_secrets.js`** at repo root, untracked and not gitignored (BLOCKER — §2).
2. **Root `storage.rules` is deny-all** while `kwayapro/storage.rules` has the real rules, and `.firebaserc` deploys from root — a direct regression risk not previously flagged (prior audit only noted "no copy in kwayapro/," not that the root copy is a functional deny-all) (BLOCKER — §2).
3. **`kwayapro/firebase.json` dangling reference** to deleted `firestore.rules`/`firestore.indexes.json` (BLOCKER — §2), a direct side effect of the (otherwise correct) de-duplication fix.
4. New, previously-unreviewed code — `functions/src/audio/presignedUrlEndpoint.ts` and `kwayapro/lib/features/studio/domain/low_latency_piano_engine.dart` — is now covered in this audit (§4, §2) but wasn't in scope for the prior one.

**Reconciliation summary:** 8 confirmed fixed / 2 partially fixed (each introducing a new blocker) / 2 not fixed / 0 clean regressions of tracked items — but 3 brand-new BLOCKER-severity deploy-configuration issues were introduced as side effects of the fixes, and must be treated as blockers regardless of their novelty.

---

## 3. Prioritized Action List

**Execute in this order — blockers and regressions first, regardless of section:**

1. Fix `kwayapro/firebase.json` dangling `firestore.rules`/`firestore.indexes.json` reference (§2/§10) — prevents any safe deploy today.
2. Consolidate `storage.rules` to the working `kwayapro/storage.rules` version; delete the root deny-all copy (§2/§10) — prevents bricking storage on next deploy.
3. Rotate MTN/R2 credentials exposed in `set_secrets.js`; delete the file from disk; gitignore it (§2/§10).
4. Fix `choir_memberships` create rule to prevent self-elevation to `director` (§2).
5. Fix `users/{userId}` read rule to scope by shared-choir membership, not global auth (§2).
6. Fix `paymentWebhook` and `mtnWebhook` fail-open signature checks; add idempotency guard (§2/§8) — do not ship billing without this.
7. Fix `initiatePayment` double-response bug and hardcoded sandbox host (§8).
8. Wire `billing_screen.dart` to the real `initiatePayment` Cloud Function; remove client-side `updateSubscriptionStatus(active)` (§8).
9. Fix hard-cast fields in `audio_part.dart`, `score_attachment.dart`, `song_section.dart` (§1).
10. Add server-side (rule or Cloud Function) enforcement of the 3-song freemium cap (§1/§8).
11. Add Director-only route guard to `/studio` (§3/§6).
12. Fix `GoRouter` recreation via `refreshListenable` (§3).
13. Fix chat pin/unpin `messageId` mismatch (§1).
14. Add `.autoDispose` to choir/session-scoped family providers (§3).
15. Scope the two unbounded platform-wide Firestore listeners (`watchAudioPartsByVoicePart`, `watchChoirListenEvents`) by `choirId` (§5).
16. Move `initFCM()` permission request to after `runApp()` (§5).
17. Register a real iOS Firebase app; generate production launcher icons and 512×512 PNG; add iOS Associated Domains (§9) — required before any Play/App Store submission.
18. Wire `AudioCacheService` into playback or remove it; add retry/backoff to Storage uploads; fix silent offline no-ops in attendance repository (§4).
19. Route all user-facing error text through a plain-English mapper (§6).
20. Gate the Airtel option in `billing_screen.dart` as "coming soon" (§8).
21. Address remaining HYGIENE items (icon tooltips, Scaffold backgroundColor consistency, inline permission checks, duplicate `songLibraryProvider`, controller-dispose gap, `app_logger.dart` print gating, composite-ID helper extraction) opportunistically alongside related feature work.
22. Backfill test coverage for the newly-wired rehearsal/RSVP/guest-director flows and the router redirect logic (§9) — currently zero tests protect this logic despite it being the subject of a recent bug fix.

---

## 4. Verified-Against-Official-Docs Appendix

| Claim | Doc source consulted | Result |
|---|---|---|
| MTN MoMo Collections API callback signature/HMAC mechanism | `momodeveloper.mtn.com`, `momoapi.mtn.com/api-documentation/callback` (WebFetch) | **Could not access** — both are JS-rendered/gated portals; only navigation chrome returned, no technical content. Findings on callback shape and lack of a documented signature header are sourced from third-party/community material (public SDK repos, integration write-ups, MTN community forum snippets returned via WebSearch) — **not an authoritative live spec citation**. Flagged explicitly in §2/§8 as needing direct authenticated-portal confirmation before the webhook fix ships.
| go_router `refreshListenable` pattern for auth-state-driven redirects | Not independently re-fetched this session; recommendation is based on go_router's well-established, versioned public API (`GoRouter(refreshListenable: ...)`) which is unchanged across the `go_router: ^14.8.0` version pinned in `pubspec.yaml` | Recommendation stated with high confidence but not re-verified against a freshly fetched doc page in this session — verify against `pub.dev/packages/go_router` before implementing if in doubt. |
| Firestore offline persistence / `Settings.CACHE_SIZE_UNLIMITED` semantics | Not independently re-fetched this session | Based on stable, long-standing `cloud_firestore` API surface matching the pinned `^5.6.0` version; recommend a quick confirmation against `firebase.flutter.dev` before changing the cache-size configuration. |

**Recommendation:** before implementing the webhook fix (action item #6), obtain direct MTN MoMo Developer Portal access (login required) and pull the actual Collections API "Callback/Webhook" specification page rather than relying on the third-party sources used here — this is the single highest-value doc-verification gap in the audit, given it underlies the highest-severity finding.
