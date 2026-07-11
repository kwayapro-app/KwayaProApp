import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:kwayapro/shared/services/audio_cache_service.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this._tempPath);
  final String _tempPath;

  @override
  Future<String?> getTemporaryPath() async => _tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory hiveDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kwayapro_audio_cache_');
    hiveDir = await Directory.systemTemp.createTemp('kwayapro_hive_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    Hive.init(hiveDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
    if (await hiveDir.exists()) await hiveDir.delete(recursive: true);
  });

  group('AudioCacheService (Phase 5b)', () {
    test('getCachedPath returns null for a URL never cached', () async {
      final service = AudioCacheService();
      expect(await service.getCachedPath('https://example.com/a.m4a'), isNull);
    });

    test('cacheAudio then getCachedPath round-trips the same bytes/path', () async {
      final service = AudioCacheService();
      const url = 'https://example.com/song.m4a';
      final bytes = List<int>.generate(1024, (i) => i % 256);

      final path = await service.cacheAudio(url, bytes);
      expect(File(path).existsSync(), isTrue);
      expect(await File(path).readAsBytes(), bytes);

      final cachedPath = await service.getCachedPath(url);
      expect(cachedPath, path);
    });

    test('getCachedPath self-heals if the cached file was deleted externally', () async {
      final service = AudioCacheService();
      const url = 'https://example.com/gone.m4a';
      final path = await service.cacheAudio(url, [1, 2, 3]);

      await File(path).delete();

      expect(await service.getCachedPath(url), isNull);
    });

    test('clearCache removes all cached files and index entries', () async {
      final service = AudioCacheService();
      final path1 = await service.cacheAudio('https://example.com/1.m4a', [1]);
      final path2 = await service.cacheAudio('https://example.com/2.m4a', [2]);

      await service.clearCache();

      expect(File(path1).existsSync(), isFalse);
      expect(File(path2).existsSync(), isFalse);
      expect(await service.getCachedPath('https://example.com/1.m4a'), isNull);
      expect(await service.getCachedPath('https://example.com/2.m4a'), isNull);
    });

    test('LRU eviction: caching beyond the size cap evicts the least-recently-accessed entry first', () async {
      final service = AudioCacheService();
      // Three ~90MB entries: none alone exceeds the 200MB cap, but all
      // three together (270MB) do, forcing an eviction.
      final chunk = List<int>.filled(90 * 1024 * 1024, 7);

      final pathA = await service.cacheAudio('https://example.com/a.m4a', chunk);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final pathB = await service.cacheAudio('https://example.com/b.m4a', chunk);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Touch A (after both A and B exist) so A is now more recently
      // accessed than B.
      expect(await service.getCachedPath('https://example.com/a.m4a'), pathA);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Caching C pushes total past the 200MB cap; A (just touched) should
      // survive, B should be the one evicted since it's now the
      // least-recently-accessed of the three.
      await service.cacheAudio('https://example.com/c.m4a', chunk);

      expect(await service.getCachedPath('https://example.com/a.m4a'), pathA, reason: 'recently-touched entry should survive eviction');
      expect(await service.getCachedPath('https://example.com/b.m4a'), isNull, reason: 'least-recently-accessed entry should be evicted');
      expect(File(pathB).existsSync(), isFalse, reason: 'evicted entry\'s file should be deleted from disk, not just the index');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
