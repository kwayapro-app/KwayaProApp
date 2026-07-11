import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Shared singleton so main.dart's startup warm-up and the audio playback
// path (AudioPlayerNotifier) use the exact same instance/Hive box rather
// than each opening their own.
final audioCacheServiceProvider = Provider<AudioCacheService>((ref) {
  return AudioCacheService();
});

/// Phase 5b: this was previously a complete-looking but entirely unwired
/// implementation (confirmed zero callers in Phase 5/5b). Two real gaps
/// were fixed while wiring it up:
///
/// 1. `getCachedPath`/`init` used a `late Box _box` that threw
///    `LateInitializationError` if anything called it before `init()`
///    completed — now self-initializing (idempotent `_ensureBox()`), so
///    correctness no longer depends on main.dart's init ordering.
/// 2. There was no eviction/size-cap policy at all — `cacheAudio` just kept
///    writing files forever. Added a simple LRU cap (`_maxCacheBytes`):
///    every cache write records size + last-accessed time, and if the
///    total exceeds the cap, least-recently-accessed entries are evicted
///    until it doesn't. Unbounded local audio caching on a budget Android
///    phone is its own problem — see PHASE_5B_REPORT.md.
class AudioCacheService {
  static const _boxName = 'audio_cache';

  // 200MB — generous enough for a genuinely useful offline cache (dozens of
  // choir-recording-length tracks) without being able to fill a budget
  // phone's storage on its own.
  static const _maxCacheBytes = 200 * 1024 * 1024;

  Future<Box>? _initFuture;

  Future<Box> _ensureBox() {
    return _initFuture ??= Hive.openBox(_boxName);
  }

  Future<void> init() => _ensureBox();

  Future<String?> getCachedPath(String url) async {
    final box = await _ensureBox();
    final entry = box.get(url) as Map?;
    final path = entry?['path'] as String?;
    if (path == null) return null;

    if (!File(path).existsSync()) {
      await box.delete(url);
      return null;
    }

    // Refresh last-accessed so this entry survives future LRU eviction
    // passes as long as it keeps being played.
    await box.put(url, {
      'path': path,
      'size': entry!['size'],
      'lastAccessed': DateTime.now().millisecondsSinceEpoch,
    });
    return path;
  }

  Future<String> cacheAudio(String url, List<int> bytes) async {
    final box = await _ensureBox();
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/audio_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final hash = url.hashCode.toString();
    final ext = url.split('.').last.split('?').first;
    final filePath = '${cacheDir.path}/$hash.$ext';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await box.put(url, {
      'path': filePath,
      'size': bytes.length,
      'lastAccessed': DateTime.now().millisecondsSinceEpoch,
    });

    await _evictIfOverCap(box);
    return filePath;
  }

  Future<void> _evictIfOverCap(Box box) async {
    final entries = box.keys
        .map((key) => MapEntry(key, box.get(key) as Map))
        .toList();

    var totalSize = entries.fold<int>(0, (sum, e) => sum + ((e.value['size'] as int?) ?? 0));
    if (totalSize <= _maxCacheBytes) return;

    entries.sort(
      (a, b) => (a.value['lastAccessed'] as int? ?? 0).compareTo(b.value['lastAccessed'] as int? ?? 0),
    );

    for (final entry in entries) {
      if (totalSize <= _maxCacheBytes) break;
      final path = entry.value['path'] as String?;
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      totalSize -= (entry.value['size'] as int?) ?? 0;
      await box.delete(entry.key);
    }
  }

  Future<void> clearCache() async {
    final box = await _ensureBox();
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/audio_cache');
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
    await box.clear();
  }
}
