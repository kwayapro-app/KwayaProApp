import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import '../data/audio_repository.dart';
import '../../songs/domain/models/song.dart';
import '../../songs/domain/models/audio_part.dart';
import '../../../shared/services/audio_cache_service.dart';

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
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  AudioPlayerState build() {
    // CHORISTER AUDIT FIX: these three listeners used to be registered on
    // the AudioPlayer itself (in _audioPlayerProvider below) with empty
    // bodies — "Position/Duration/Player state updates handled in play
    // state" was a comment describing intent that was never actually
    // implemented. Nothing ever wrote position/duration/isPlaying back into
    // AudioPlayerState, so the mini-player's progress bar was permanently
    // stuck at 0 and its play/pause icon never left "play" even mid-playback.
    _positionSub = _player.positionStream.listen((position) {
      if (!_isDisposed) state = state.copyWith(position: position);
    });
    _durationSub = _player.durationStream.listen((duration) {
      if (!_isDisposed) state = state.copyWith(duration: duration ?? Duration.zero);
    });
    _playerStateSub = _player.playerStateStream.listen((playerState) {
      if (!_isDisposed) state = state.copyWith(isPlaying: playerState.playing);
    });

    ref.onDispose(() {
      _isDisposed = true;
      _positionSub?.cancel();
      _durationSub?.cancel();
      _playerStateSub?.cancel();
    });
    return const AudioPlayerState();
  }

  AudioPlayer get _player => ref.read(_audioPlayerProvider);
  AudioCacheService get _audioCache => ref.read(audioCacheServiceProvider);

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('AudioPlayerNotifier has been disposed');
    }
  }

  // Phase 5b: wires the previously-unused AudioCacheService into the actual
  // playback path. Cache is checked first (works offline, and skips the
  // network entirely on repeat plays); on a cache miss, plays by
  // progressively streaming from the remote URL as before (unchanged
  // first-byte latency), then downloads the full track in the background
  // to cache it for next time. If offline AND not cached, fails with a
  // plain-English message per PRD 9.3 instead of letting just_audio's
  // network error surface raw, or hanging.
  Future<void> play(AudioPart part, Song song) async {
    _checkDisposed();
    try {
      state = state.copyWith(
        currentPart: part,
        currentSong: song,
        isLoading: true,
        position: Duration.zero,
        error: null,
      );

      final cachedPath = await _audioCache.getCachedPath(part.audioUrl);
      if (cachedPath != null) {
        await _player.setFilePath(cachedPath);
        await _player.play();
        state = state.copyWith(isLoading: false);
        unawaited(_logListen(part, song));
        return;
      }

      // One-shot check (not the stream-based connectivityProvider) to
      // guarantee a fresh value at play-time rather than racing an
      // as-yet-unpopulated stream — matches the pattern already used in
      // attendance_repository.dart for the same reason.
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        state = state.copyWith(
          isLoading: false,
          error: "This track hasn't been downloaded yet, and you're offline. "
              'Connect to the internet to play it for the first time.',
        );
        return;
      }

      await _player.setUrl(part.audioUrl);
      await _player.play();
      state = state.copyWith(isLoading: false);
      unawaited(_logListen(part, song));

      unawaited(_cacheInBackground(part.audioUrl));
    } catch (e) {
      state = state.copyWith(
        error: "Couldn't play this track. Check your connection and try again.",
        isLoading: false,
      );
    }
  }

  // CHORISTER AUDIT FIX: AudioRepository.logListenEvent had zero call sites —
  // playing a song never recorded anything. Logs on play-start per the
  // audit's requirement; durationPlayedSeconds/completed are recorded as
  // 0/false since accurately tracking how much of a track was actually
  // heard (vs. skipped after a second) is a separate, deeper feature than
  // "logs on play" — left as a follow-up rather than guessed at here.
  Future<void> _logListen(AudioPart part, Song song) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      await ref.read(audioRepositoryProvider).logListenEvent(
            userId: userId,
            choirId: part.choirId,
            audioPartId: part.audioPartId,
            songId: song.songId,
            sectionId: part.sectionId,
            durationPlayedSeconds: 0,
            completed: false,
          );
    } catch (_) {
      // Best-effort — a failed analytics write should never block playback.
    }
  }

  Future<void> _cacheInBackground(String url) async {
    try {
      if (await _audioCache.getCachedPath(url) != null) return;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await _audioCache.cacheAudio(url, response.bodyBytes);
      }
    } catch (_) {
      // Best-effort — playback already succeeded via streaming; failing to
      // cache just means this track streams again next time instead of
      // playing from disk. Not surfaced to the user.
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
  ref.onDispose(() => player.dispose());
  return player;
});

final audioPlayerProvider = NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(() {
  return AudioPlayerNotifier();
});

final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  return AudioRepository();
});