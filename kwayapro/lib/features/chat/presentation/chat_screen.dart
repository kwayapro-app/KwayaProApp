import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/utils/permission_checker.dart';
import '../../auth/domain/auth_providers.dart';
import '../../choir/domain/choir_providers.dart';
import '../domain/chat_providers.dart';
import '../domain/models/chat_message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final _recorder = AudioRecorder();
  Timer? _recordingTimer;
  String? _tempRecordingPath;

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _recorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choirId = ref.watch(activeChoirIdProvider);
    final messagesAsync = ref.watch(chatMessagesProvider(choirId ?? ''));
    final pinnedAsync = ref.watch(pinnedMessageProvider(choirId ?? ''));
    final isRecording = ref.watch(chatRecordingProvider);
    final targetPart = ref.watch(messageTargetProvider);
    final membership = ref.watch(currentMembershipProvider).valueOrNull;
    final user = ref.watch(authStateProvider).valueOrNull;

    // FUNCTIONAL FIX (Leader/Director audit, Finding #6): this used to be
    // isManagement only, so a chorister granted the 'announcements'
    // permission (PRD §4.2: "send targeted push to voice parts") saw no
    // pin/target controls at all despite firestore.rules (now) allowing it.
    final isDirectorOrLeader = PermissionChecker(membership).canPostAnnouncements;

    // Leader/Director audit follow-up fix: unlike every other tab screen
    // (home_screen.dart etc.), ChatScreen had no SafeArea of its own — the
    // outer shell Scaffold (navigation_shell_screen.dart) doesn't apply one
    // either, so messages rendered flush under the status bar. bottom:false
    // because _ChatInputBar already wraps itself in a SafeArea for the
    // bottom inset; wrapping here too would double that padding.
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          pinnedAsync.when(
            data: (pinned) => pinned != null
                ? _PinnedBanner(message: pinned, onShare: () => _shareToWhatsApp(pinned))
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No messages yet', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Text('Start the conversation!', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isOwn = message.senderId == user?.uid;
                    return ChatMessageBubble(
                      message: message,
                      isOwn: isOwn,
                      isDirectorOrLeader: isDirectorOrLeader,
                      onPin: () => _togglePin(message),
                      onShare: () => _shareToWhatsApp(message),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          _ChatInputBar(
            isRecording: isRecording,
            targetPart: targetPart,
            isDirectorOrLeader: isDirectorOrLeader,
            onTargetChanged: (part) => ref.read(messageTargetProvider.notifier).state = part,
            messageController: _messageController,
            onSendText: () => _sendTextMessage(user?.uid ?? '', choirId ?? ''),
            onStartRecording: _startRecording,
            onStopRecording: () => _stopRecording(choirId ?? '', user?.uid ?? ''),
            onCancelRecording: _cancelRecording,
            recordingDuration: ref.watch(recordingDurationProvider),
          ),
        ],
      ),
    );
  }

  Future<void> _sendTextMessage(String senderId, String choirId) async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    
    final targetPart = ref.read(messageTargetProvider);
    await ref.read(chatRepositoryProvider).sendTextMessage(
      choirId: choirId,
      senderId: senderId,
      content: content,
      targetVoicePart: targetPart,
    );
    
    _messageController.clear();
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      final tempDir = await getTemporaryDirectory();
      _tempRecordingPath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _tempRecordingPath!,
      );
      
      ref.read(chatRecordingProvider.notifier).state = true;
      ref.read(recordingDurationProvider.notifier).state = 0;
      
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        ref.read(recordingDurationProvider.notifier).state++;
      });
    }
  }

  Future<void> _stopRecording(String choirId, String senderId) async {
    _recordingTimer?.cancel();
    final path = await _recorder.stop();
    
    if (path != null && _tempRecordingPath != null) {
      final url = await ref.read(chatRepositoryProvider).uploadVoiceNote(
        choirId: choirId,
        filePath: path,
        onProgress: (_) {},
      );
      
      final targetPart = ref.read(messageTargetProvider);
      await ref.read(chatRepositoryProvider).sendAudioMessage(
        choirId: choirId,
        senderId: senderId,
        audioUrl: url,
        targetVoicePart: targetPart,
      );
    }
    
    ref.read(chatRecordingProvider.notifier).state = false;
    ref.read(recordingDurationProvider.notifier).state = 0;
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await _recorder.stop();
    ref.read(chatRecordingProvider.notifier).state = false;
    ref.read(recordingDurationProvider.notifier).state = 0;
  }

  Future<void> _togglePin(ChatMessage message) async {
    final choirId = ref.read(activeChoirIdProvider) ?? '';
    if (message.pinned) {
      await ref.read(chatRepositoryProvider).unpinMessage(message.messageId);
    } else {
      await ref.read(chatRepositoryProvider).pinMessage(message.messageId, choirId);
    }
  }

  Future<void> _shareToWhatsApp(ChatMessage message) async {
    final text = message.type == MessageType.text
        ? message.content
        : message.type == MessageType.audio
            ? '[Voice Note from KwayaPro Choir Chat]'
            : '[Image from KwayaPro Choir Chat]';

    await Share.share(
      '$text\n\n— Shared from KwayaPro',
      subject: 'KwayaPro Choir Message',
    );
  }
}

class _PinnedBanner extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onShare;

  const _PinnedBanner({required this.message, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.push_pin, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share, size: 20),
            onPressed: onShare,
            tooltip: 'Share to WhatsApp',
          ),
        ],
      ),
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final bool isDirectorOrLeader;
  final VoidCallback onPin;
  final VoidCallback onShare;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isDirectorOrLeader,
    required this.onPin,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isOwn) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                child: Text(
                  message.senderId.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOwn
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isOwn ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isOwn ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContent(context),
                  if (message.targetVoicePart != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '→ ${message.targetVoicePart!.displayName}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return Text(message.content);
      case MessageType.audio:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, size: 24),
            SizedBox(width: 8),
            Text('Voice note'),
          ],
        );
      case MessageType.image:
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                message.content,
                width: 200,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 200,
                  height: 150,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
          ],
        );
    }
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDirectorOrLeader)
              ListTile(
                leading: Icon(message.pinned ? Icons.push_pin_outlined : Icons.push_pin),
                title: Text(message.pinned ? 'Unpin' : 'Pin'),
                onTap: () {
                  Navigator.pop(context);
                  onPin();
                },
              ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share to WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                onShare();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ChatInputBar extends StatelessWidget {
  final bool isRecording;
  final VoicePart? targetPart;
  final bool isDirectorOrLeader;
  final ValueChanged<VoicePart?> onTargetChanged;
  final TextEditingController messageController;
  final VoidCallback onSendText;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;
  final int recordingDuration;

  const _ChatInputBar({
    required this.isRecording,
    required this.targetPart,
    required this.isDirectorOrLeader,
    required this.onTargetChanged,
    required this.messageController,
    required this.onSendText,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
    required this.recordingDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDirectorOrLeader)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _showTargetPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'To: ${targetPart?.displayName ?? 'All'}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const Icon(Icons.arrow_drop_down, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: isRecording
                      ? _RecordingIndicator(
                          duration: recordingDuration,
                          onCancel: onCancelRecording,
                          onSend: onStopRecording,
                        )
                      : TextField(
                          controller: messageController,
                          decoration: InputDecoration(
                            hintText: 'Message the choir...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => onSendText(),
                        ),
                ),
                const SizedBox(width: 8),
                isRecording
                    ? const SizedBox.shrink()
                    : IconButton.filled(
                        icon: const Icon(Icons.mic),
                        onPressed: onStartRecording,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTargetPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('All'),
              selected: targetPart == null,
              onTap: () {
                onTargetChanged(null);
                Navigator.pop(context);
              },
            ),
            ...VoicePart.values.map((part) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(part.displayName),
                  selected: targetPart == part,
                  onTap: () {
                    onTargetChanged(part);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  final int duration;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const _RecordingIndicator({
    required this.duration,
    required this.onCancel,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = (duration ~/ 60).toString().padLeft(2, '0');
    final seconds = (duration % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$minutes:$seconds',
            style: TextStyle(
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Recording...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
            tooltip: 'Discard recording',
            onPressed: onCancel,
          ),
          IconButton.filled(
            icon: const Icon(Icons.send),
            tooltip: 'Send',
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}