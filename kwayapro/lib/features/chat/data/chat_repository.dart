import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../shared/models/enums.dart';
import '../domain/models/chat_message.dart';

class ChatRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<ChatMessage>> watchMessages(String choirId, {int limit = 50}) {
    return _db
        .collection('chat_messages')
        .where('choirId', isEqualTo: choirId)
        .orderBy('timestamp', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatMessage.fromJson(d.data())).toList());
  }

  Future<void> sendTextMessage({
    required String choirId,
    required String senderId,
    required String content,
    VoicePart? targetVoicePart,
  }) async {
    final message = ChatMessage(
      messageId: _db.collection('chat_messages').doc().id,
      choirId: choirId,
      senderId: senderId,
      type: MessageType.text,
      content: content,
      targetVoicePart: targetVoicePart,
      pinned: false,
      timestamp: DateTime.now(),
    );
    await _db.collection('chat_messages').add(message.toJson());
  }

  Future<void> sendAudioMessage({
    required String choirId,
    required String senderId,
    required String audioUrl,
    VoicePart? targetVoicePart,
  }) async {
    final message = ChatMessage(
      messageId: _db.collection('chat_messages').doc().id,
      choirId: choirId,
      senderId: senderId,
      type: MessageType.audio,
      content: audioUrl,
      targetVoicePart: targetVoicePart,
      pinned: false,
      timestamp: DateTime.now(),
    );
    await _db.collection('chat_messages').add(message.toJson());
  }

  Future<void> sendImageMessage({
    required String choirId,
    required String senderId,
    required String imageUrl,
    VoicePart? targetVoicePart,
  }) async {
    final message = ChatMessage(
      messageId: _db.collection('chat_messages').doc().id,
      choirId: choirId,
      senderId: senderId,
      type: MessageType.image,
      content: imageUrl,
      targetVoicePart: targetVoicePart,
      pinned: false,
      timestamp: DateTime.now(),
    );
    await _db.collection('chat_messages').add(message.toJson());
  }

  Future<void> pinMessage(String messageId, String choirId) async {
    final batch = _db.batch();
    
    final currentPinned = await _db
        .collection('chat_messages')
        .where('choirId', isEqualTo: choirId)
        .where('pinned', isEqualTo: true)
        .limit(1)
        .get();
    
    if (currentPinned.docs.isNotEmpty) {
      batch.update(currentPinned.docs.first.reference, {'pinned': false});
    }
    
    final messageRef = _db.collection('chat_messages').doc(messageId);
    batch.update(messageRef, {'pinned': true});
    
    await batch.commit();
  }

  Future<void> unpinMessage(String messageId) async {
    await _db.collection('chat_messages').doc(messageId).update({'pinned': false});
  }

  Stream<ChatMessage?> watchPinnedMessage(String choirId) {
    return _db
        .collection('chat_messages')
        .where('choirId', isEqualTo: choirId)
        .where('pinned', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : ChatMessage.fromJson(snap.docs.first.data()));
  }

  Future<String> uploadVoiceNote({
    required String choirId,
    required String filePath,
    void Function(double)? onProgress,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'chat/$choirId/voice_notes/$timestamp.m4a';
    
    final storageRef = _storage.ref().child(storagePath);
    final file = File(filePath);
    
    final uploadTask = storageRef.putFile(
      file,
      SettableMetadata(contentType: 'audio/m4a'),
    );
    
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress(progress);
      });
    }
    
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<String> uploadChatImage({
    required String choirId,
    required String filePath,
    void Function(double)? onProgress,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'chat/$choirId/images/$timestamp.jpg';
    
    final storageRef = _storage.ref().child(storagePath);
    final file = File(filePath);
    
    final uploadTask = storageRef.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress(progress);
      });
    }
    
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}