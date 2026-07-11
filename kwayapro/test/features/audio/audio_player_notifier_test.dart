import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:kwayapro/features/audio/domain/audio_player_notifier.dart';
import 'package:kwayapro/features/songs/domain/models/audio_part.dart';
import 'package:kwayapro/features/songs/domain/models/song.dart';
import 'package:kwayapro/shared/models/enums.dart';
import 'package:kwayapro/shared/services/audio_cache_service.dart';

class _FakeConnectivityPlatform extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  _FakeConnectivityPlatform(this.result);
  final ConnectivityResult result;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [result];
}

class _EmptyAudioCacheService extends AudioCacheService {
  @override
  Future<String?> getCachedPath(String url) async => null;
}

// Phase 5b: verifies the offline + not-yet-cached path added to
// AudioPlayerNotifier.play() — this branch returns before ever touching the
// real just_audio AudioPlayer (which needs a real platform channel/device
// to test meaningfully — see PHASE_5B_REPORT.md for why a full
// just_audio-platform fake was judged out of proportion for this phase), so
// it's fully exercisable here with only Connectivity and AudioCacheService
// faked.
void main() {
  test('play() fails gracefully with a plain-English message when offline and not cached — no crash', () async {
    ConnectivityPlatform.instance = _FakeConnectivityPlatform(ConnectivityResult.none);

    final container = ProviderContainer(
      overrides: [
        audioCacheServiceProvider.overrideWithValue(_EmptyAudioCacheService()),
      ],
    );
    addTearDown(container.dispose);

    final part = AudioPart(
      audioPartId: 'ap1',
      sectionId: 'sec1',
      songId: 'song1',
      choirId: 'choir1',
      voicePart: VoicePart.S,
      audioUrl: 'https://example.com/never-cached.m4a',
      durationSeconds: 120,
      uploadedBy: 'user1',
      createdAt: DateTime.now(),
    );
    final song = Song(
      songId: 'song1',
      choirId: 'choir1',
      title: 'Test Song',
      uploadedBy: 'user1',
      createdAt: DateTime.now(),
    );

    // Must not throw — this is the "doesn't crash" requirement.
    await container.read(audioPlayerProvider.notifier).play(part, song);

    final state = container.read(audioPlayerProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isNotNull);
    expect(state.error, isNot(contains('Exception')), reason: 'must be plain English, not a raw exception dump');
    expect(state.error, isNot(contains('SocketException')));
    expect(state.error!.toLowerCase(), contains('offline'));
  });
}
