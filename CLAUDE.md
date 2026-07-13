# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo layout

This repo has three independently-built parts:

- `kwayapro/` — the Flutter app (Android/iOS/Windows). All Dart source is under `kwayapro/lib`.
- `functions/` — Firebase Cloud Functions (TypeScript), deployed as the `default` codebase (see root `firebase.json`).
- Root — Firestore/Storage security rules (`firestore.rules`, `storage.rules`, `firestore.indexes.json`) and Firebase project config (`.firebaserc` → project `kwayapro-app`).

There are two separate rules-testing setups that both run against the *same* root `firestore.rules`/`storage.rules` via emulator: `firestore-tests/` (mocha, project `kwayapro-rules-test`) and `functions/test/integration.js` (project `kwayapro-app`, exercises real Cloud Functions end-to-end). Don't confuse the two.

## Commands

### Flutter app (run from `kwayapro/`)
- `flutter pub get` — install deps
- `flutter analyze` — static analysis (uses `analysis_options.yaml`, `flutter_lints`)
- `flutter test` — run all tests
- `flutter test test/path/to/some_test.dart` — run a single test file
- `flutter test test/path/to/some_test.dart --plain-name "test description"` — run a single test case
- `flutter run` — run the app locally

### Cloud Functions (run from `functions/`)
- `npm run build` — compile TypeScript (`tsc`)
- `npm run build:watch` — compile in watch mode
- `npm run lint` — ESLint (`eslint-config-google` based)
- `npm run serve` — build, then start the Functions emulator only
- `npm run shell` — build, then open the Functions shell
- `npm run deploy` — deploy functions only (`firebase deploy --only functions`)
- `npm run logs` — tail deployed function logs
- `npm run test:integration` — build, then run `functions/test/integration.js` against real Auth/Firestore/Functions emulators (config: root `firebase.test.json`). Requires a `functions/.secret.local` with `MTN_WEBHOOK_SECRET` set (gitignored) — see `functions/test/README.md` for exact invocation and env var requirements.

### Firestore/Storage rules tests (run from `firestore-tests/`)
- `npm test` — runs `firebase emulators:exec --config ../firebase.test.json --project=kwayapro-rules-test "mocha rules.test.js --timeout 60000"` against the real root rules files.

## Architecture

### Multi-tenant model
Everything in Firestore is scoped to a **choir** (the tenant). Membership and role/permission for a user within a choir lives in `choir_memberships/{choirId}_{uid}` — not on the user doc itself. `firestore.rules` (root) is the source of truth for the authorization model:
- `hasRole` / `hasAnyRole` check the membership doc's `role` field (e.g. `leader`, `director`, chorister roles).
- `hasPermission` checks a `permissions` array on the same membership doc for granular grants independent of role (e.g. `audio_uploader`, `song_program_planner`).
- Composite checks like `canUploadAudio` / `canPlanPrograms` OR the role check with the granular permission check — this must stay in sync with the client-side equivalent in `kwayapro/lib` (`PermissionChecker` — grep for it) whenever either side changes, since a mismatch means UI that works but silently fails server-side (or vice versa).
- The freemium song cap (`isUnderSongLimit`, 3 songs on the free plan) is enforced in rules as well as client-side in the songs repository — the two are not currently transactional together (a known race, see `PRODUCTION_READINESS_AUDIT.md` §1 if touching this path).
- **Known characteristic, not a bug to "fix" per-listener:** a freshly-written doc (a new `choir_memberships` doc from a join/signup, a new `choirs` doc from creation, etc.) has a brief window where rules evaluation on a *different* concurrent listener can see it as not-yet-existent — `resource.data` evaluates null, the rule errors, and Firestore denies with `permission-denied`. A one-shot `get()` just retries next call and is unaffected, but a `.snapshots()` listener that hits this **does not self-recover** — the underlying gRPC stream terminates and Firestore's SDK never re-subscribes on its own, so a `StreamProvider` built directly on `.snapshots()` gets stuck in `AsyncError` forever with no user-visible recovery path short of restarting the app. Any *new* Firestore stream that's plausibly first-subscribed in the same beat as a related doc's creation (i.e. anything reachable right after onboarding/join/create flows) needs the same bounded-retry treatment as `ChoirRepository._watchDocWithRetry` (grep for it) — don't build a raw `.snapshots().map(...)` stream in that position and assume a rules/propagation error is transient by default.

### Flutter app structure (`kwayapro/lib`)
Feature-first, each feature under `lib/features/<name>/` split into `data/` (repositories), `domain/` (providers/business logic), `presentation/` (screens/widgets). Features: `attendance`, `audio`, `auth`, `chat`, `choir`, `planner`, `rehearsal`, `songs`, `studio`, `subscription`. Cross-feature code lives in `lib/shared/` (models, providers, repositories, services, widgets) and `lib/core/` (Firebase bootstrapping, `go_router` router, theme, logging utils).

State management is Riverpod (`flutter_riverpod` + `riverpod_annotation`/`riverpod_generator`); routing is `go_router` with a single long-lived `GoRouter` instance driven by a `refreshListenable` notifier (`core/router/app_router.dart`) — the router is intentionally built once and never recreated on auth/choir state changes, because rebuilding it would blow away `StatefulShellRoute` tab/navigator state. When touching routing/auth-redirect logic, follow that same pattern rather than watching auth providers directly in `routerProvider`.

`main.dart`'s startup sequence is deliberately staged: only Firebase init + `SharedPreferences` (run concurrently) block `runApp()`; FCM background-message registration is synchronous so it's cheap enough to also happen pre-`runApp()`; everything else (Hive/audio cache init, FCM permission prompt, FCM token registration) is deferred to fire-and-forget *after* the first frame. Don't reintroduce blocking awaits before `runApp()` without a strong reason — that regression is documented in `PRODUCTION_READINESS_AUDIT.md` §5 / `PHASE_5_REPORT.md`.

### Cloud Functions (`functions/src`)
Single `index.ts` (plus `audio/presignedUrlEndpoint.ts`) exporting: Firestore-triggered functions (`confirmAudioUpload`, `onRehearsalCreated`, `onProgramPublished`, `onUserProfileUpdated`), scheduled functions (`rehearsalReminder`, `checkGuestTokenExpiry`), and HTTP-callable-style `onRequest` endpoints for payments/invites (`getPresignedUrl`, `initiatePayment`, `cancelSubscription`, `mtnWebhook`, `joinAsGuestDirector`, `lookupChoirByInviteCode`, `checkInviteCodeAvailable`). Mobile money (MTN/Airtel) payment webhooks are the highest-risk code path in this repo — `mtnWebhook` is fail-closed on auth and idempotent against replay; see `functions/test/README.md` for what is and isn't covered by the committed integration suite (MTN's actual outbound Collections API call is not exercised — no live sandbox access).

### Historical audit/phase reports
`PRODUCTION_READINESS_AUDIT.md`, `CODEBASE_AUDIT.md`, and the numbered `PHASE_*_REPORT.md` files at the repo root are point-in-time audit records of past hardening work, referenced from inline code comments (e.g. "see PHASE_5_REPORT.md"). Treat them as historical context for *why* code looks the way it does, not as current TODO lists — check the referenced code directly before assuming an issue is still open.
