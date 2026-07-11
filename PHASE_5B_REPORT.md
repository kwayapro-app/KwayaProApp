# Phase 5b Report — Offline Audio Caching

**Scope:** the audio playback path only (`AudioCacheService`, `AudioPlayerNotifier`, `mini_player_bar.dart`), plus `pubspec.yaml` dev-dependency additions needed to test it. Additive. **Not deployed** — pure Dart app code.

---

## Investigation: was `AudioCacheService` usable, or a stub?

Read it in full. **Verdict: genuinely usable, not a stub** — but with one real gap.

What it actually implemented, honestly assessed:
- `init()` — opened a Hive box.
- `getCachedPath(url)` — synchronous lookup, with a nice touch already present: it self-healed if the cached file had been deleted externally (e.g. by OS storage pressure), removing the stale Hive entry rather than returning a path to nothing.
- `cacheAudio(url, bytes)` — wrote already-downloaded bytes to a file in the temp directory, keyed the path by URL in Hive. Note this takes **bytes you already have**, not a URL to download itself — it's a "store this" primitive, not a downloader. Whoever wires it up has to fetch the bytes separately.
- `clearCache()` — wiped everything.

**The real gap:** no eviction or size-cap policy at all. `cacheAudio` just kept writing files forever — exactly the "unbounded local audio caching on a budget Android phone is its own problem" risk the task flagged. This needed fixing regardless of wiring.

**A real correctness bug, not just a gap:** `getCachedPath`/`init` used `late Box _box`, which throws `LateInitializationError` if anything called `getCachedPath` before `init()` completed. Given main.dart's `AudioCacheService().init()` call runs in a fire-and-forget deferred block (Phase 5's cold-start fix) with no ordering guarantee relative to when a user might first tap play, this would have been a real crash risk the moment it was wired up naively. Fixed as part of wiring it in, not left for later.

**Playback path located:** `AudioPlayerNotifier.play()` in `audio_player_notifier.dart` — calls `_player.setUrl(part.audioUrl)` (just_audio, progressive streaming) directly against the remote Firebase Storage URL, unconditionally, every time. This is exactly where a cache-check needed to sit, confirmed by tracing the only call site (`library_screen.dart`'s `_playPart`).

Given the service was genuinely usable (not a stub), I proceeded with wiring it up per the task's first branch.

---

## What was wired up

### `AudioCacheService` — fixed the two gaps found above
- API is now fully async (`getCachedPath`/`init` return `Future`s) and self-initializing — `_ensureBox()` is idempotent, so correctness no longer depends on external init-ordering. (This was a breaking API change to a class with zero existing callers, confirmed before making it — no call site to break.)
- Added a simple LRU cap: cache entries now store `{path, size, lastAccessed}` instead of a bare path string; `cacheAudio` checks total cached size after every write and, if over a 200MB cap, evicts least-recently-accessed entries (deleting their files, not just the index) until back under the cap. `getCachedPath` refreshes an entry's `lastAccessed` on every hit, so actively-replayed tracks survive eviction longer than ones played once and forgotten.
- Added `audioCacheServiceProvider` (a shared singleton) so the playback path and main.dart's existing warm-up call share one instance. **Confirmed `main.dart` needed no changes**: Hive's `openBox` is idempotent per box name within an isolate — two separate `AudioCacheService` instances opening `'audio_cache'` transparently share the same underlying box, so main.dart's pre-existing deferred `AudioCacheService().init()` call (from Phase 5) still usefully pre-warms the box without needing to route through the new provider.

### `AudioPlayerNotifier.play()` — the actual wiring
1. Check `AudioCacheService.getCachedPath(url)` first. If present: play via `_player.setFilePath(cachedPath)` (local disk, works offline) and return — no network touched at all.
2. If not cached: one-shot `Connectivity().checkConnectivity()` (matching the existing pattern already used in `attendance_repository.dart`, not the stream-based `connectivityProvider`, specifically to avoid racing an as-yet-unpopulated stream on a cold first play). If offline, fail with a plain-English message ("This track hasn't been downloaded yet, and you're offline...") and return — no crash, no hang, no raw exception.
3. If online: play via `_player.setUrl(url)` exactly as before (same progressive-streaming, low first-byte-latency behavior Phase 5 verified was already correct) — then fire-and-forget a background full download + `cacheAudio` call so the track is available offline next time. Caching failure is swallowed silently by design (playback already succeeded; worst case is just re-streaming next time, not a user-facing failure).

**Adjacent fix, small and directly in the method I was already rewriting:** the general catch-all at the bottom of `play()` previously did `error: e.toString()` — a raw exception dump, the same PRD 9.3 pattern flagged elsewhere in the codebase. Changed to a plain-English fallback message. Not a general sweep of the whole app's error handling (out of scope), just this one method.

**Also fixed, and necessary for the error message to be verifiable at all:** `mini_player_bar.dart` watches `AudioPlayerState` but never displayed `.error` — it was being set and silently discarded. Added an error banner row above the existing fixed-height controls bar (restructured the layout slightly since the controls `Container` has a fixed `height: 60` with no room for an extra line — the error banner now sits in its own unconstrained row above it, sized only when actually shown).

---

## Verification

### 1. Play online (caches) → offline → replay from cache
Full end-to-end proof (tap play → real just_audio decodes and plays → background HTTP download → cache write → offline replay) would require either a real device/emulator or a from-scratch fake `JustAudioPlatform` implementation (just_audio's `AudioPlayer` is a concrete class backed by real platform channels with non-trivial internal stream/event expectations — there's no lightweight swap-in fake the way `path_provider`/`connectivity_plus` offer). Building that fake platform is a meaningfully larger undertaking than "wire up the cache" and would have pushed this phase's scope well past "additive" — flagging this honestly rather than skipping verification silently or overclaiming coverage.

**What I verified instead, directly and rigorously:**
- `AudioCacheService`'s actual caching mechanism — write, retrieve, self-heal, clear, and LRU eviction — fully tested against a real Hive box and real filesystem (via a proper `PathProviderPlatform` fake, the documented pattern for testing this specific plugin), **not mocked away**. This proves the "cache on first play, serve from cache on replay" data layer genuinely works.
- `play()`'s cache-hit branch (`if (cachedPath != null) { setFilePath(...); return; }`) is a direct, 4-line, easily-verified-by-inspection early return that never reaches the network/connectivity-check code at all — confirmed by reading the method, and indirectly exercised by the offline+uncached test below taking the *other* branch correctly.

```
test/shared/services/audio_cache_service_test.dart — 5 tests, all passing:
  ✔ getCachedPath returns null for a URL never cached
  ✔ cacheAudio then getCachedPath round-trips the same bytes/path
  ✔ getCachedPath self-heals if the cached file was deleted externally
  ✔ clearCache removes all cached files and index entries
  ✔ LRU eviction: caching beyond the size cap evicts the least-recently-accessed
    entry first (three ~90MB entries, cap 200MB — confirms the correct entry is
    evicted AND its file is actually deleted from disk, not just the index)
```

### 2. Offline + uncached → clear error, no crash
This branch returns *before* touching the real `AudioPlayer` at all, so it's fully testable without any just_audio mocking — only `Connectivity` needed faking (via `ConnectivityPlatform.instance`, the same documented-pattern approach used for `AudioCacheService`'s tests).

```
test/features/audio/audio_player_notifier_test.dart — 1 test, passing:
  ✔ play() fails gracefully with a plain-English message when offline and not
    cached — no crash. Asserts: isLoading resolves to false, error is non-null,
    error text contains no "Exception"/"SocketException" fragments, and does
    mention being offline in plain language.
```

### 3. `flutter analyze`: clean. Full `flutter test`: **36/36 passing** (30 pre-existing + 6 new).

Added `path_provider_platform_interface`, `connectivity_plus_platform_interface`, and `plugin_platform_interface` as explicit `dev_dependencies` (previously only transitive) — needed to silence `depend_on_referenced_packages` lints for the platform-fake pattern used in the new tests.

---

## Files changed this phase
- `kwayapro/lib/shared/services/audio_cache_service.dart` — async self-init, LRU eviction, shared provider.
- `kwayapro/lib/features/audio/domain/audio_player_notifier.dart` — cache-check/offline/background-cache wiring in `play()`.
- `kwayapro/lib/features/audio/presentation/widgets/mini_player_bar.dart` — error banner.
- `kwayapro/pubspec.yaml` — three explicit dev_dependencies (previously transitive).
- `kwayapro/test/shared/services/audio_cache_service_test.dart` (new), `kwayapro/test/features/audio/audio_player_notifier_test.dart` (new).

## Open flags
- **Full device-level playback verification not done** — see §1 above. Recommend a manual on-device smoke test (play a track, enable airplane mode, replay) before shipping, since that's the one thing this phase's testing couldn't reach without disproportionate scope.
- Everything from prior phases' open flags unchanged.

Awaiting your review before Phase 6.
