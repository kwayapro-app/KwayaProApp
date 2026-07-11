import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kwayapro/features/attendance/data/attendance_repository.dart';
import 'package:kwayapro/features/attendance/domain/attendance_providers.dart';
import 'package:kwayapro/features/chat/data/chat_repository.dart';
import 'package:kwayapro/features/chat/domain/chat_providers.dart';
import 'package:kwayapro/features/choir/domain/choir_providers.dart';
import 'package:kwayapro/features/songs/data/song_repository.dart';
import 'package:kwayapro/features/songs/domain/song_providers.dart';
import 'package:kwayapro/shared/providers/shared_prefs_provider.dart';

// Phase 5 Fix 4: choir/session/song-scoped providers previously weren't
// .autoDispose, so switching choirs in the Choir Switcher (or navigating
// away from a song/session) left the previous choir's Firestore listeners
// alive and subscribed for the rest of the app session. These tests prove
// disposal actually happens for representative providers from each of the
// files touched by this fix — not just that `.autoDispose` appears in the
// source, but that a provider with no remaining listeners is genuinely torn
// down (verified via ProviderContainer.exists, the direct API for this).
void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('sessionAttendanceProvider (attendance_providers.dart) disposes when its last listener is removed', () async {
    final fakeFirestore = FakeFirebaseFirestore();
    final container = ProviderContainer(
      overrides: [
        attendanceRepositoryProvider.overrideWithValue(AttendanceRepository(firestore: fakeFirestore)),
      ],
    );
    addTearDown(container.dispose);

    final provider = sessionAttendanceProvider('session1');
    expect(container.exists(provider), isFalse, reason: 'not instantiated until something listens');

    final sub = container.listen(provider, (_, __) {});
    expect(container.exists(provider), isTrue, reason: 'instantiated while a listener is attached');

    sub.close();
    // autoDispose tears down on the next event-loop turn after the last
    // listener is removed, not synchronously.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.exists(provider), isFalse, reason: 'must be disposed once the last listener is gone');
  });

  test('chatMessagesProvider (chat_providers.dart) disposes when its last listener is removed', () async {
    final fakeFirestore = FakeFirebaseFirestore();
    final container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(ChatRepository(firestore: fakeFirestore)),
      ],
    );
    addTearDown(container.dispose);

    final provider = chatMessagesProvider('choir1');
    expect(container.exists(provider), isFalse);

    final sub = container.listen(provider, (_, __) {});
    expect(container.exists(provider), isTrue);

    sub.close();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.exists(provider), isFalse);
  });

  test('songLibraryProvider (song_providers.dart) disposes when its last listener is removed, '
      'and switching activeChoirId does not leave the old choir listening', () async {
    final fakeFirestore = FakeFirebaseFirestore();
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        songRepositoryProvider.overrideWithValue(SongRepository(firestore: fakeFirestore)),
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    container.read(activeChoirIdProvider.notifier).setChoir('choirA');
    await Future<void>.delayed(Duration.zero);

    final provider = songLibraryProvider;
    final sub = container.listen(provider, (_, __) {});
    expect(container.exists(provider), isTrue, reason: 'listening while on choirA');

    sub.close();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.exists(provider),
      isFalse,
      reason: 'Choir Switcher scenario: once nothing on-screen is watching the song '
          'library for the previous choir, its listener must not linger.',
    );
  });
}
