import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../data/audio_repository.dart';
import '../../songs/domain/models/song.dart';
import '../../songs/domain/models/audio_part.dart';

class AudioPlayerState {
  final AudioPart? currentPart;
  final Song? currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double playbackSpeed;
  final bool isRepeat;
  final bool isLoading;
  final String? error;

  const AudioPlayerState({
    this.currentPart,
    this.currentSong,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playbackSpeed = 1.0,
    this.isRepeat = false,
    this.isLoading = false,
    this.error,
  });

  AudioPlayerState copyWith({
    AudioPart? currentPart,
    Song? currentSong,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? playbackSpeed,
    bool? isRepeat,
    bool? isLoading,
    String? error,
  }) {
    return AudioPlayerState(
      currentPart: currentPart ?? this.currentPart,
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isRepeat: isRepeat ?? this.isRepeat,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  bool _isDisposed = false;

  @override
  AudioPlayerState build() {
    ref.onDispose(() {
      _isDisposed = true;
    });
    return const AudioPlayerState();
  }

  AudioPlayer get _player => ref.read(_audioPlayerProvider);

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('AudioPlayerNotifier has been disposed');
    }
  }

  Future<void> play(AudioPart part, Song song) async {
    _checkDisposed();
    try {
      state = state.copyWith(
        currentPart: part,
        currentSong: song,
        isLoading: true,
        position: Duration.zero,
      );
      
      await _player.setUrl(part.audioUrl);
      await _player.play();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> pause() async {
    _checkDisposed();
    await _player.pause();
  }

  Future<void> resume() async {
    _checkDisposed();
    await _player.play();
  }

  Future<void> stop() async {
    _checkDisposed();
    await _player.stop();
    state = const AudioPlayerState();
  }

  Future<void> seek(Duration position) async {
    _checkDisposed();
    await _player.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    _checkDisposed();
    await _player.setSpeed(speed);
    state = state.copyWith(playbackSpeed: speed);
  }

  void toggleRepeat() {
    _checkDisposed();
    final newRepeat = !state.isRepeat;
    state = state.copyWith(isRepeat: newRepeat);
    _player.setLoopMode(newRepeat ? LoopMode.one : LoopMode.off);
  }
}

final _audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  
  player.positionStream.listen((position) {
    // Position updates handled in play state
  });
  
  player.durationStream.listen((duration) {
    // Duration updates handled in play state  
  });
  
  player.playerStateStream.listen((playerState) {
    // Player state updates handled in play state
  });
  
  ref.onDispose(() => player.dispose());
  
  return player;
});

final audioPlayerProvider = NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(() {
  return AudioPlayerNotifier();
});

final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  return AudioRepository();
});