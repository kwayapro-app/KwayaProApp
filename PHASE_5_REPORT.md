# Phase 5 Report — Architecture & Performance

**Scope:** router architecture, provider wiring/disposal, controller lifecycle, unbounded listeners, cold start. No security rules, payment code, or anything from Phases 1–4b touched. **Not deployed** — pure Dart application code; ships with the next app release.

---

## Fix 1 — `Provider<GoRouter>` full-rebuild risk: **confirmed still present, now fixed**

**Status before this phase:** unfixed. `routerProvider` was still the original plain `Provider<GoRouter>` that `ref.watch`ed `authStateProvider`, `userChoirsProvider`, and `currentUserProvider` directly — every emission from any of the three (e.g. a Firestore snapshot update to the user doc, not just sign-in/out) discarded and rebuilt the entire `GoRouter` instance, and with it the `StatefulShellRoute`'s tab state.

**Verified the current API against docs before implementing**, per the instructions: `pub.dev/documentation/go_router/latest/go_router/GoRouter/GoRouter.html` confirms `refreshListenable` is `Listenable?`, and that `GoRouter` is meant to be constructed once (a stable instance), not rebuilt. No official example combines it with a `Stream` (checked `pub.dev/packages/go_router`, the package's own `redirection.dart` example, and `firebase.google.com/docs/auth/flutter/start` — none show a Stream-to-`ChangeNotifier` wrapper), confirming this really is the "well-known but not centrally documented" community pattern the task described, not something with one canonical source to copy.

**Implemented:**
- `_RouterRefreshNotifier`, a `ChangeNotifier` that uses `ref.listen` (not `ref.watch`) on the three providers and calls `notifyListeners()` on each emission — built once via its own `Provider`, disposed via `ref.onDispose`.
- `routerProvider` now only `ref.watch`es that notifier's *identity* (which never changes across its lifetime), so `routerProvider`'s build function runs exactly once. `GoRouter(refreshListenable: refreshNotifier, ...)` is constructed a single time; go_router re-runs `redirect` on every `notifyListeners()` call without discarding the router or its navigator tree.
- Inside `redirect`, provider values are now read fresh via `ref.read(...)` at call time (since the closure is no longer rebuilt, it can't rely on captured watch values) — same logic as before, just sourced correctly for a long-lived closure.

### Verification
A full widget-level "navigate deep into a tab, trigger an emission, confirm scroll position survives" test would require mocking `firebase_auth`'s `User` type, Firestore choir/membership reads, and driving `StatefulShellRoute` navigation end-to-end. Instead I wrote the direct, provable root-cause test: **does `routerProvider` hand back the identical `GoRouter` instance after the three streams emit?** If it does, the `Navigator`/`StatefulShellRoute` subtree underneath it is never torn down (Flutter only discards subtree state when widget identity/config changes), so tab state loss via this mechanism is structurally impossible — the widget-level guarantee follows from the instance-identity guarantee rather than needing separate re-proof.

```
test/core/router/router_refresh_test.dart:
  ✔ routerProvider returns the SAME GoRouter instance across auth/choir/user emissions
  ✔ routerProvider still rebuilds if the app is fully torn down and re-created (sanity check —
    confirms the test isn't trivially passing by accident)
```

---

## Fix 2 — Remaining stub providers: **re-verified, none remain**

Grepped every `*_providers.dart` file for `TODO`/`FIXME`/`stub`/`mock`/hardcoded-return patterns — none found. Specifically re-checked `rehearsal_providers.dart`: `upcomingRehearsalsProvider`, `pastRehearsalsProvider`, `myRSVPProvider`, and `rsvpCountsProvider` all call real `RehearsalRepository` Firestore-stream methods (unchanged since Phase 2b's fix, reconfirmed here). Every `Stream.value([])`/`Stream.value(null)` found anywhere in the provider layer is a legitimate null-guard fallback (no active choir/session/user yet), not a stub — checked each occurrence individually rather than pattern-matching blindly. **Confirmed: all three previously-partial features (rehearsal scheduling, RSVP, guest director) are fully wired.**

---

## Fix 3 — Controller lifecycle: **no build()-recreated controllers found; one adjacent leak fixed**

Dispatched a full re-audit of every `TextEditingController(`/`AnimationController(` instantiation in `lib/`. **Zero `AnimationController` usages exist anywhere in the codebase.** All 15 `TextEditingController` field declarations remain correctly at `State`/`ConsumerState` class level — the specific bug class this fix targets (controllers recreated on every `build()`, losing user input) is confirmed absent, matching the prior audit.

**One adjacent issue found and fixed, not the same bug class but the same lifecycle-hygiene concern:** `library_screen.dart`'s `_handleExternalUpload()` creates two `TextEditingController`s as local variables (not inside `build()` — inside a one-shot dialog-showing method) that were never disposed, leaking on every "New Song" dialog open. Added `.dispose()` calls after the dialog closes.

---

## Fix 4 — Riverpod provider disposal: **large gap found and fixed across 7 files**

Dispatched a full audit of every choir/session/song/user-keyed provider. Result: **`choir_providers.dart` was the only file where this had been fixed** (5/5 providers `.autoDispose`, from an earlier pass) — every other feature's providers were still plain `StreamProvider`/`StreamProvider.family`/`FutureProvider.family`, meaning **switching choirs in the Choir Switcher left every previously-viewed choir's Firestore listeners alive and subscribed for the rest of the app session**, and family providers (keyed by songId/sessionId/choirId) accumulated one live listener per distinct ID ever viewed, never torn down.

**Added `.autoDispose` + `ref.onDispose(() => sub.drain())`** (matching the exact pattern already established in `choir_providers.dart`, for consistency) to every affected provider:
- `song_providers.dart`: `songLibraryProvider`, `songsByVoicePartProvider`, `songSectionsProvider`, `audioPartsProvider`, `audioPartsForSectionProvider`, `isAtSongLimitProvider`, `songsWithPartsProvider`.
- `chat_providers.dart`: `chatMessagesProvider`, `pinnedMessageProvider`.
- `attendance_providers.dart`: `sessionAttendanceProvider`, `myAttendanceHistoryProvider`, `memberAttendanceRateProvider`, `lastSessionAttendanceRateProvider`.
- `rehearsal_providers.dart`: `upcomingRehearsalsProvider`, `pastRehearsalsProvider`, `myRSVPProvider`, `rsvpCountsProvider`.
- `planner_providers.dart`: `songProgramsProvider`, `publishedProgramsProvider`, `draftProgramsProvider`.
- `subscription_providers.dart`: `subscriptionProvider`, `currentSubscriptionProvider`.
- `score_providers.dart`: `songScoresProvider`.

**Also found and fixed while auditing `choir_providers.dart` for the pattern to copy:** a second, dead `songLibraryProvider` was defined there (a raw Firestore query bypassing `SongRepository` entirely — flagged as a repository-pattern violation back in `PHASE_2_REPORT.md` and never resolved). It shared its exact name with the real `songLibraryProvider` in `song_providers.dart`; the two coexisted only because Dart doesn't error on an ambiguous import until the ambiguous name is actually referenced unqualified, and nothing did (`planner_screen.dart` explicitly imports the real one via `show songLibraryProvider`). Deleted the dead copy, resolving the collision outright rather than leaving it as a landmine for whoever eventually hit it.

### Verification
```
test/features/riverpod_disposal_test.dart (using fake_cloud_firestore + real repositories,
not toy providers):
  ✔ sessionAttendanceProvider (attendance_providers.dart) disposes when its last listener is removed
  ✔ chatMessagesProvider (chat_providers.dart) disposes when its last listener is removed
  ✔ songLibraryProvider (song_providers.dart) disposes when its last listener is removed —
    directly simulates the Choir Switcher scenario via ProviderContainer.exists()
```
Each test: confirms the provider does *not* exist before anything listens, confirms it *does* exist while listened, closes the listener, and confirms it's disposed again — not just that `.autoDispose` appears in the source.

---

## Fix 5 — Unbounded Firestore listeners: **two found (both dead code today), both fixed**

Chat screen: already correctly bounded — `chat_repository.dart`'s `watchMessages` uses `.limitToLast(50)`, `watchPinnedMessage` uses `.limit(1)`. No direct Firestore access in `chat_screen.dart` itself (routes through the repository). Nothing to fix here.

Studio screen: has no direct Firestore listeners of its own at all.

**Found instead in the data layer** (the original audit's "highest-risk" finding, re-checked rather than assumed fixed): `SongRepository.watchAudioPartsByVoicePart` and `AudioRepository.watchChoirListenEvents` were **still** listening to their entire collections platform-wide (`audio_parts`, `listen_events`) with no `.where()` scoping at all, then doing an N+1 per-document read of each item's parent song to filter by `choirId` client-side. **Grepped for callers of both — neither is invoked from anywhere in the app today** (dead code, same situation as `AudioCacheService`). Fixed anyway rather than left as a landmine: both `AudioPart` and `listen_events` documents already store `choirId` directly (confirmed via the model and the sibling `watchListenEvents(userId)` method, which already filters by a direct field), so both queries now scope with `.where('choirId', isEqualTo: choirId)` at the query level — eliminating the N+1 lookups entirely as a side effect, not just bounding the read.

---

## Fix 6 — Cold start: **confirmed still blocking, now fixed**

`main.dart`'s init sequence was unchanged since the original audit flagged it: `Hive.initFlutter()` → `Firebase.initializeApp()` → `SharedPreferences.getInstance()` → `AudioCacheService().init()` → `await initFCM()` (which calls `requestPermission()`, showing a native OS prompt on iOS) — all sequential and all before `runApp()`, meaning first frame could stall indefinitely on the user responding to a permission dialog they hadn't even seen the app's UI before being asked about.

**Fixed:**
- `Firebase.initializeApp()` and `SharedPreferences.getInstance()` now run **concurrently** (independent of each other) rather than sequentially — both are genuinely needed before `runApp()` (`sharedPrefsProvider`'s override needs the value synchronously; nearly everything reads Firebase immediately).
- `Hive.initFlutter()` + `AudioCacheService().init()` deferred to run **after** `runApp()`. Re-confirmed `AudioCacheService` is still completely unused elsewhere (`getCachedPath`/`cacheAudio` have zero callers) — this was pure blocking overhead for zero benefit; deferred rather than removed, in case a future feature wires it up.
- `initFCM()` (the permission-prompt call) deferred to run **after** `runApp()`.
- **One exception, verified against current Firebase docs rather than assumed:** `FirebaseMessaging.onBackgroundMessage(handler)` registration must happen *before* `runApp()` per `firebase.google.com/docs/cloud-messaging/flutter/receive` ("The handler registration occurs in `main()` before `runApp()`... this placement ensures the handler is properly configured before your application starts, allowing it to reliably capture background messages") — this stayed before `runApp()`, but it's a synchronous call with no `await` and no user-facing UI, so it costs nothing.
- FCM token registration/refresh-listening (unchanged logic) also moved into the same deferred post-`runApp()` block, since it was already effectively fire-and-forget after `runApp()` in the original code.

---

## Verification

### 1. New tests — 5 total, all passing (shown above under each fix)
### 2. `flutter analyze`: clean. Full `flutter test` suite: **30/30 passing** (25 pre-existing + 5 new).
### 3. This report.

---

## Files changed this phase
- `kwayapro/lib/core/router/app_router.dart` — `refreshListenable` refactor.
- `kwayapro/lib/main.dart` — cold-start init sequence.
- `kwayapro/lib/features/songs/domain/song_providers.dart`, `score_providers.dart` — autoDispose.
- `kwayapro/lib/features/choir/domain/choir_providers.dart` — removed dead duplicate `songLibraryProvider`; unused imports cleaned up.
- `kwayapro/lib/features/chat/domain/chat_providers.dart`, `kwayapro/lib/features/attendance/domain/attendance_providers.dart`, `kwayapro/lib/features/rehearsal/domain/rehearsal_providers.dart`, `kwayapro/lib/features/planner/domain/planner_providers.dart`, `kwayapro/lib/features/subscription/domain/subscription_providers.dart` — autoDispose.
- `kwayapro/lib/features/songs/data/song_repository.dart` — scoped `watchAudioPartsByVoicePart`.
- `kwayapro/lib/features/audio/data/audio_repository.dart` — scoped `watchChoirListenEvents`.
- `kwayapro/lib/features/songs/presentation/library_screen.dart` — controller disposal fix.
- `kwayapro/test/core/router/router_refresh_test.dart` (new), `kwayapro/test/features/riverpod_disposal_test.dart` (new).

## Open flags
- None new from this phase. All prior phases' open flags (MTN callback auth mechanism unverified, MTN production host unverified, `paymentWebhook` removal requiring a functions deploy, `song_program.dart`'s list-casting note) still stand, unchanged.

Awaiting your review before Phase 6 (Platform & Deployment Readiness).
