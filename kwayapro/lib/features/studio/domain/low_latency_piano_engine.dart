import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';

class LowLatencyPianoEngine {
  final Map<String, AudioPlayer> _pool = {};
  bool _isDisposed = false;

  Future<void> initializeNotes(List<String> notes) async {
    for (final note in notes) {
      final player = AudioPlayer();
      try {
        await player.setAsset('assets/audio/piano/$note.mp3', preload: true);
        _pool[note] = player;
      } catch (_) {
        _pool[note] = player;
      }
    }
  }

  void play(String note, bool sustain) {
    if (_isDisposed) return;
    final player = _pool[note];
    if (player != null) {
      if (player.playing) {
        player.stop();
      }
      player.setVolume(1.0);
      player.seek(Duration.zero);
      player.play();
      if (!sustain) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!_isDisposed) player.setVolume(0.0);
        });
      }
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void dispose() {
    _isDisposed = true;
    for (final player in _pool.values) {
      player.dispose();
    }
    _pool.clear();
  }
}
