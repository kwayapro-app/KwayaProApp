import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwayapro/features/chat/data/chat_repository.dart';

void main() {
  // Phase 4 Fix 2: previously messageId was generated via a throwaway
  // .doc().id while the message was actually persisted via .add() (which
  // assigns a DIFFERENT document ID) — pinMessage/unpinMessage's
  // .doc(message.messageId).update(...) therefore always targeted a
  // document that never existed, and would fail with not-found. This test
  // exercises the real end-to-end flow, not just that the IDs now match.
  group('ChatRepository pin/unpin (Phase 4 Fix 2)', () {
    test('sent message stores a messageId that matches its real document ID', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ChatRepository(firestore: firestore);

      await repo.sendTextMessage(choirId: 'choir1', senderId: 'user1', content: 'Hello choir');

      final snap = await firestore.collection('chat_messages').get();
      expect(snap.docs.length, 1);
      final doc = snap.docs.single;
      expect(doc.data()['messageId'], doc.id);
    });

    test('pin then unpin a freshly-sent message succeeds end-to-end', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ChatRepository(firestore: firestore);

      await repo.sendTextMessage(choirId: 'choir1', senderId: 'user1', content: 'Pin me');
      final sentDoc = (await firestore.collection('chat_messages').get()).docs.single;
      final messageId = sentDoc.data()['messageId'] as String;

      // Pin: confirm it actually sticks (not just that the call didn't throw).
      await repo.pinMessage(messageId, 'choir1');
      final afterPin = await firestore.collection('chat_messages').doc(messageId).get();
      expect(afterPin.exists, isTrue, reason: 'pinMessage must target the real document');
      expect(afterPin.data()!['pinned'], isTrue);

      final pinnedStream = await repo.watchPinnedMessage('choir1').first;
      expect(pinnedStream, isNotNull);
      expect(pinnedStream!.messageId, messageId);

      // Unpin: confirm it actually clears.
      await repo.unpinMessage(messageId);
      final afterUnpin = await firestore.collection('chat_messages').doc(messageId).get();
      expect(afterUnpin.data()!['pinned'], isFalse);

      final pinnedAfterUnpin = await repo.watchPinnedMessage('choir1').first;
      expect(pinnedAfterUnpin, isNull);
    });

    test('pinning a second message unpins the first (only one pinned message per choir)', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ChatRepository(firestore: firestore);

      await repo.sendTextMessage(choirId: 'choir1', senderId: 'user1', content: 'First');
      await repo.sendTextMessage(choirId: 'choir1', senderId: 'user1', content: 'Second');
      final docs = (await firestore.collection('chat_messages').get()).docs;
      final firstId = docs.firstWhere((d) => d.data()['content'] == 'First').data()['messageId'] as String;
      final secondId = docs.firstWhere((d) => d.data()['content'] == 'Second').data()['messageId'] as String;

      await repo.pinMessage(firstId, 'choir1');
      await repo.pinMessage(secondId, 'choir1');

      final first = await firestore.collection('chat_messages').doc(firstId).get();
      final second = await firestore.collection('chat_messages').doc(secondId).get();
      expect(first.data()!['pinned'], isFalse);
      expect(second.data()!['pinned'], isTrue);
    });
  });
}
