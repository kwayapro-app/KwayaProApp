import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AudioCacheService {
  static const _boxName = 'audio_cache';
  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  String? getCachedPath(String url) {
    final localPath = _box.get(url) as String?;
    if (localPath != null && File(localPath).existsSync()) {
      return localPath;
    }
    if (localPath != null) {
      _box.delete(url);
    }
    return null;
  }

  Future<String> cacheAudio(String url, List<int> bytes) async {
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

    await _box.put(url, filePath);
    return filePath;
  }

  Future<void> clearCache() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/audio_cache');
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
    await _box.clear();
  }
}
