# Phase 7 Report — Hygiene + Test Coverage (Final Phase)

**Scope:** cleanup and test-coverage backfill only, per your instruction. No security rules content, payment logic, or already-fixed code touched, beyond the one conflict discovered and resolved during Fix 3 (see below — a hygiene-tier change from earlier in this same phase, reverted after it was found to undo a Phase 4 protection).

---

## Fix 1 — Remaining original-audit hygiene items

Re-read `PRODUCTION_READINESS_AUDIT.md` in full and cross-referenced every `[HYGIENE]`-tagged finding against all 12 phase reports (1, 2, 2b, 2c, 3, 3b, 3c, 4, 5, 5b, 6, 6b) to find what was never explicitly addressed by name. Result, reported before fixing anything as instructed:

| # | Finding | Status found | Action this phase |
|---|---|---|---|
| 1 | Composite-ID convention duplicated | **Already fixed** (Phase 4 Fix 5) | none |
| 2 | Invite code collisions never checked | **Already fixed** (Phase 4 Fix 6) | none |
| 3 | `*.byName()` throws on a stale/renamed enum value | **Not fixed** | Fixed for 8 of 10 call sites (see below) |
| 4 | Inline role comparisons bypass `PermissionChecker` | **Not fixed** | Fixed — 6 files |
| 5 | Direct Firestore access outside repository layer | **Partially fixed** (dup `songLibraryProvider` removed in Phase 5) | `onboarding_screen.dart`'s direct batch write — **flagged, not fixed** (see below) |
| 6 | Duplicate/divergent `songLibraryProvider` | **Already fixed** (Phase 5 Fix 4) | none |
| 7 | `onboarding_screen.dart` controller leak (`_emailController`/`_passwordController` never disposed) | **Not fixed** | Fixed |
| 8 | AnimatedSwitcher/controllers-in-`build()` | **Already verified resolved** (in the original audit itself) | none |
| 9 | Dead R2 presigned-upload Cloud Function | **Not fixed** | **Flagged, not fixed** (see below) |
| 10 | Unbounded Firestore cache size | **Not fixed** | Fixed — bounded to 100MB |
| 11 | `AudioCacheService.init()` overhead for an unused feature | **Moot** — the feature is no longer unused (Phase 5b wired it up) | none |
| 12 | Wide-scope `ref.watch` in large `build()` methods | **Not fixed** | **Flagged, not fixed** (see below) |
| 13 | `Scaffold backgroundColor` set on only 2/19 screens | **Substantially improved already** (9/13 screens had it by the time this phase started — likely incidental from other screens' work) but not complete | Fixed — added to the remaining 4 |
| 14 | Icon-only buttons missing `tooltip` | **Not fixed** | Fixed on the specifically-named buttons (attendance back/save, chat delete/send, home profile) |
| 15 | `app_logger.dart` unconditional `print()` | **Not fixed** | Fixed — gated behind `kDebugMode` |
| 16 | `flutter_lints` stale | **Not fixed** | **Flagged, not fixed** (see below) |

### What was fixed

- **`*.byName()` → `asNameMap()`** in `attendance.dart`, `subscription.dart`, `choir_membership.dart`, `choir.dart`, `score_attachment.dart`, `song_program.dart`, `chat_message.dart`, and `rehearsal_repository.dart`'s inline RSVP-counting query (8 files, 10 call sites) — a present-but-unrecognized enum value (e.g. a stale value left over from a future rename) now silently falls back to a sane default instead of throwing and crashing whatever read it.
  - **Deliberately NOT applied to `audio_part.dart` / `song_section.dart`.** I applied it there first, then caught the conflict during test verification (§Fix 3 below): `SongRepository`'s `_parseSkippingBadDocs` (Phase 4 Fix 1) relies on `byName()` *throwing* on a bad enum value so the whole malformed document gets skipped and logged, rather than silently kept with a defaulted `voicePart`/`status` — which for `voicePart` specifically could put an audio recording in the wrong voice section undetected. Reverted both back to the pre-Phase-7 `byName()`-with-null-check pattern, with a comment explaining why this one hygiene pattern doesn't apply here. This is exactly the kind of "looks bigger than hygiene once you're actually looking" case your instructions asked me to flag rather than push through — caught here because the existing test suite (Phase 4's) failed immediately, not because I anticipated it in advance.
- **Inline role comparisons → `PermissionChecker`**: `chat_screen.dart`, `attendance_screen.dart`, `home_screen.dart`, `library_screen.dart`, `rehearsals_screen.dart` — replaced `membership?.role == MemberRole.leader || membership?.role == MemberRole.director` (and the chorister-only inverse) with `PermissionChecker(membership).isManagement`/`.isLeader`, which are defined with the exact same boolean logic — zero behavior change, confirmed by reading `permission_checker.dart` before editing. `members_screen.dart`'s role comparisons were deliberately left alone — those group members by role for display (a categorization, not a permission gate), a different thing than what this finding was about.
- **`onboarding_screen.dart` controller leak**: added the two missing `.dispose()` calls.
- **Firestore cache size**: `main.dart`'s `Settings.CACHE_SIZE_UNLIMITED` → `100 * 1024 * 1024` (100MB), matching the original audit's own suggested ceiling.
- **`Scaffold backgroundColor`**: added `Theme.of(context).colorScheme.surface` to the 4 screens that still lacked it (`attendance_screen.dart`, both `Scaffold`s in `planner_screen.dart`, `billing_screen.dart`, `guest_director_screen.dart`).
- **Icon tooltips**: added to the specific buttons the original audit named — attendance screen's back/save (save being the primary action, previously with zero accessible label), chat screen's discard-recording/send, home screen's profile icon.
- **`app_logger.dart`**: wrapped the three `print()` calls in `if (kDebugMode)` — they no longer leak log content into release-build device logs. `developer.log()` (the other sink) is unaffected — it was already build-mode-appropriate.

### What was flagged instead of fixed, and why

- **`onboarding_screen.dart`'s direct Firestore batch write** (§5): still writes directly via `FirebaseFirestore.instance.batch()` across `users`/`choirs`/`choir_memberships` rather than through `ChoirRepository`. I read the method in full before deciding — it's a single atomic batch tightly coupled to the onboarding flow's local state (`_pendingChoirId`, `_isCreating`, `_isJoining`), and moving it into the repository layer would mean designing a new multi-collection batch-create method on `ChoirRepository` and re-threading this critical, well-exercised flow through it. That's a real refactor with real regression risk to the single most important first-run flow in the app, not a hygiene-tier change — flagging rather than touching it.
- **Dead R2 `presignedUrlEndpoint.ts`** (§9): still deployed, still holds live R2 credentials, still has zero callers (re-confirmed via grep — unchanged since the original audit). Deleting it means an actual `firebase deploy --only functions` plus a decision about whether to retire the R2 secrets — a deploy-affecting, credential-affecting decision, not something to silently resolve in a cleanup phase. Recommend confirming intent (finish wiring it, or remove + retire the secrets) as a standalone follow-up.
- **Wide-scope `ref.watch` in large `build()` methods** (§12): `home_screen.dart` (446 lines) and `library_screen.dart` (768 lines) still watch several providers at the top of `build()`, causing full-screen rebuilds on unrelated state changes. Fixing this properly means extracting `Consumer` subwidgets around each narrowly-scoped piece of state — a real refactor of two of the app's largest, most load-bearing screens, not a quick edit. Flagged rather than attempted under a "cleanup" phase's risk budget.
- **`flutter_lints` staleness** (§16): checked via `flutter pub outdated` rather than guessing — the resolvable upgrade is `3.0.2` → `6.0.0`, a 3-major-version jump. Bumping it would very likely introduce a batch of new lint rules that would need individual fixes across the codebase to keep `flutter analyze` clean, which is exactly the kind of scope-expansion this phase was meant to avoid. Flagged for a dedicated follow-up rather than bumped blind.

---

## Fix 2 — Debug/prototype cleanup final sweep

Grepped `lib/` and `functions/src/` for `print()`/`debugPrint()`, commented-out code blocks, and `TODO`/`FIXME`/`HACK`/`XXX`, plus re-checked for any role-switcher/debug-menu/empty-states-toggle UI control.

- **Found and fixed:** `studio_screen.dart:490` had a raw `debugPrint('Error starting recording: $e')` with zero user feedback — a recording-start failure (e.g. mic access revoked after the initial permission check) silently did nothing visible. Replaced with `AppLogger.error` + a plain-English `SnackBar`, matching the error-handling pattern already used elsewhere in the same file.
- **`app_logger.dart`'s own `print()` calls**: these are the intentional, now-`kDebugMode`-gated dev console sink from Fix 1 above — correctly a match for this grep, correctly not a problem.
- **The two `TODO` comments in `functions/src/index.ts`** (both attached to `isAuthorizedWebhookRequest`, both about MTN's unverified callback authentication mechanism): these are deliberate, already-documented, already-tracked references to a known open external-verification gap (see `PHASE_3_REPORT.md`), not prototype/debug leftovers — left in place.
- **Commented-out code blocks**: none found. The one grep hit (`library_screen.dart:536`) was a prose comment, not dead code.
- **Role switcher / debug menu / empty-states toggle**: re-confirmed absent — no `kDebugMode`-gated UI, no hardcoded test bypasses, nothing matching this pattern anywhere in `lib/`. §7 of the original audit is now **fully clean**, not just "improved."

---

## Fix 3 — Test coverage backfill

### The single biggest gap found: security-critical test suites existed only as ephemeral scratch scripts

Reviewing every phase's testing section turned up a real problem: Phases 2, 2b, 3, and 3b each built and ran real Firestore/Storage rules test suites (17 → 20 → 23 → 24 tests) and real Functions-emulator integration suites (11 → 17 → more) — but every one of them explicitly said "scratch-only, not committed to the repo." That meant **zero persisted test coverage existed for security rules or payment/subscription Cloud Functions** at the start of this phase, despite them being the highest-risk code in the app. A future change to `firestore.rules` or `functions/src/index.ts` had nothing to regress against.

This was the clear highest-value fix under "prioritize by risk," so I committed both suites properly:

- **`firestore-tests/`** (new, committed): the Phase 2/2b/3/3b rules test suite (25 tests), verified byte-identical to the current live `firestore.rules`/`storage.rules` before committing, then reconfigured to read those two files **directly from the repo root** (not a copy) so the suite can never silently drift from what would actually be deployed. Run via `npm test` from that directory (needs `firebase.test.json` at the repo root — new, local-emulator-only config, never touched by `firebase deploy`, which only reads `firebase.json`). **Ran it against the real rule files: 25/25 passing.**
- **`functions/test/integration.js`** (new, committed): a consolidated integration suite covering `joinAsGuestDirector`, `initiatePayment`'s full validation chain, `mtnWebhook`'s complete auth/idempotency/state-transition logic, `cancelSubscription`, and confirmation that the removed `paymentWebhook` is genuinely gone (404) — against real Functions + Auth + Firestore emulators. **Ran it: 33/33 passing.** `functions/test/README.md` documents exactly how to run it and states its scope honestly: `initiatePayment`'s actual outbound call to MTN's Collections API is **not** exercised (needs live MTN sandbox credentials/network this environment doesn't have) — only every validation/authorization check that runs before that call. Everything else in the function (the actual state-changing logic) has no external dependency and is fully covered.

### Dart-level gap: `SubscriptionRepository` had zero test coverage

`watchSubscription`/`getSubscription` are the exact method Phase 3 fixed from a broken field-query-on-`.add()`-docs pattern to a direct `.doc(choirId)` lookup — a real regression risk with no test protecting it. Made `SubscriptionRepository` constructor-injectable (same zero-behavior-change pattern Phase 4 used for `ChatRepository`; the no-arg provider call site is unaffected) and added `test/features/subscription/data/subscription_repository_test.dart` (5 tests, `fake_cloud_firestore`) covering the doc-ID read/write path, a downgrade's status transition, and the payment-request status stream the billing UI polls. Deliberately did **not** attempt to mock `initiatePayment`/`cancelSubscription`'s HTTP-calling methods — their server-side behavior already has real, stronger coverage via the Functions integration suite above; re-mocking `package:http` here would only test request-building, a lower-value duplicate of coverage that already exists on the other side of that call.

### What still can't be meaningfully tested in this environment (restated, not re-attempted)

- **Real on-device audio playback** (Phase 5b's flag) — `just_audio` has no lightweight fake platform; still needs a manual device/emulator smoke test.
- **`initiatePayment`'s actual MTN API call** (this phase's finding above) — needs live MTN sandbox credentials.
- **Final adaptive-icon rendering** (Phase 6b's flag) — needs a real device/emulator build.
- **Android App Links end-to-end resolution** (Phase 6's flag) — needs `assetlinks.json` hosted plus a real device.

All four are consolidated with the rest of the open items in `PRODUCTION_READINESS_FINAL_SUMMARY.md`'s device-verification checklist.

### Final test counts

| Suite | Count | Result |
|---|---|---|
| `kwayapro/test/` (Dart, `flutter test`) | **41** (36 carried forward + 5 new `SubscriptionRepository` tests) | 41/41 passing |
| `firestore-tests/` (Firestore + Storage rules, newly committed) | **25** | 25/25 passing |
| `functions/test/integration.js` (Functions emulator, newly committed) | **33** | 33/33 passing |
| **Total** | **99** | **99/99 passing** |

### Coverage by feature area (brief)

- **Security rules** (`choir_memberships` self-elevation, `users` PII scoping, storage choir-scoping, freemium cap, cross-collection consistency): now persistently covered — 25 tests, committed.
- **Payments/subscriptions** (guest-director grant, MTN webhook auth/idempotency/state, cancel/downgrade, freemium enforcement, `paymentWebhook` removal, `SubscriptionRepository`'s Firestore reads): now persistently covered — 33 + 5 = 38 tests, committed. Only the literal outbound MTN API call is untested (documented, not silently skipped).
- **Data integrity** (null-safe models, malformed-doc skip-and-log, chat pin/unpin, transactional song-limit race, real-emulator concurrency): 18+ tests, Phase 4, unchanged.
- **Architecture/performance** (router instance stability, provider disposal): 5 tests, Phase 5, unchanged.
- **Offline audio caching** (LRU eviction, offline-error path): 6 tests, Phase 5b, unchanged — real on-device playback still needs a manual check, as stated above.
- **Onboarding flow**: 1 widget test (pre-existing, fixed for a stale key in an earlier ad-hoc pass).

---

## Fix 4 — Final full-repo sanity pass

1. **`flutter analyze`**: clean, 0 issues.
2. **`tsc --noEmit`** (functions): clean.
3. **`flutter test`**: **41/41 passing.**
4. **Final confirmation grep sweep** — not because anything specific was expected, but as the closing checkpoint for the whole pass:
   - Hardcoded API keys / live secret values: none found anywhere in the working tree (only `defineSecret("KEY_NAME")` name-references in `functions/src/index.ts`/`presignedUrlEndpoint.ts`, which is the correct, expected pattern).
   - Sandbox-only/hardcoded URLs: none beyond the already-flagged, already-documented MTN sandbox/production host selection (Phase 3, still open pending MTN portal access).
   - Unprotected secrets files: `set_airtel_secrets.js` re-checked — still contains only the placeholder `'dummy'` value, as established in the original audit; nothing new found.
   - Non-production Firebase references: none — `kwayapro-app` is used consistently everywhere a project ID appears.
   - `git status` reviewed line by line: every changed/new file traced to a specific fix in this or an earlier phase; the pre-existing `D` deletions (`firestore.rules`/`firestore.indexes.json`/`firebase_options.dart`/`storage.rules` under `kwayapro/`) are unrelated leftovers from Phase 1's consolidation, already fully explained, not touched this phase.

---

## Files changed this phase

**Hygiene fixes:**
`kwayapro/lib/features/chat/presentation/chat_screen.dart`, `attendance/presentation/attendance_screen.dart`, `choir/presentation/home_screen.dart`, `songs/presentation/library_screen.dart`, `rehearsal/presentation/rehearsals_screen.dart` (PermissionChecker consolidation + tooltips + backgroundColor where applicable), `auth/presentation/onboarding_screen.dart` (controller dispose), `core/utils/app_logger.dart` (kDebugMode-gated print), `main.dart` (bounded Firestore cache), `planner/presentation/planner_screen.dart`, `subscription/presentation/billing_screen.dart`, `rehearsal/presentation/guest_director_screen.dart` (backgroundColor), `studio/presentation/studio_screen.dart` (debugPrint → AppLogger + SnackBar).

**`asNameMap()` enum-safety fix (8 files):** `attendance/domain/models/attendance.dart`, `subscription/domain/models/subscription.dart`, `choir/domain/models/choir_membership.dart`, `choir/domain/models/choir.dart`, `songs/domain/models/score_attachment.dart`, `planner/domain/models/song_program.dart`, `chat/domain/models/chat_message.dart`, `rehearsal/data/rehearsal_repository.dart`. (`audio_part.dart`/`song_section.dart` deliberately excluded — see Fix 1.)

**Test coverage (new):** `firestore-tests/` (rules.test.js, package.json, firebase.json removed in favor of root `firebase.test.json`), `firebase.test.json` (repo root), `functions/test/integration.js`, `functions/test/README.md`, `functions/package.json` (`test:integration` script), `kwayapro/test/features/subscription/data/subscription_repository_test.dart`, `kwayapro/lib/features/subscription/data/subscription_repository.dart` (constructor-injectable).

## Open flags carried forward from this phase

1. **`onboarding_screen.dart`'s direct Firestore batch write** — flagged, not fixed (real refactor risk to the onboarding flow).
2. **Dead R2 `presignedUrlEndpoint.ts`** — flagged, not fixed (needs a deploy + secrets-retirement decision).
3. **Wide-scope `ref.watch` in `home_screen.dart`/`library_screen.dart`** — flagged, not fixed (real refactor of two large screens).
4. **`flutter_lints` 3.0.2 → 6.0.0** — flagged, not bumped (3-major-version jump, likely to surface many new lint violations).
5. Every open item from Phases 1–6b that required your action (secrets rotation, `assetlinks.json` hosting, Play Store assets, MTN portal verification, on-device audio/App Links/adaptive-icon checks, iOS Associated Domains) — unchanged by this phase, consolidated in full in `PRODUCTION_READINESS_FINAL_SUMMARY.md`.

This is the last phase of the production-readiness pass. See `PRODUCTION_READINESS_FINAL_SUMMARY.md` for the single consolidated summary across all 7 phases.
