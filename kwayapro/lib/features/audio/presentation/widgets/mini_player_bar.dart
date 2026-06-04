import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/audio_player_notifier.dart';
import '../../../../shared/models/enums.dart';

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);
    final theme = Theme.of(context);
    
    if (playerState.currentPart == null) {
      return const SizedBox.shrink();
    }
    
    final song = playerState.currentSong!;
    final part = playerState.currentPart!;
    final position = playerState.position;
    final duration = playerState.duration;
    final isPlaying = playerState.isPlaying;
    final isLoading = playerState.isLoading;
    
    final progress = duration.inMilliseconds > 0 
        ? position.inMilliseconds / duration.inMilliseconds 
        : 0.0;
    
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Seek bar
          LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
          ),
          // Controls
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Song info
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Could navigate to full player
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${part.voicePart.displayName} Part',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Speed button
                  TextButton(
                    onPressed: () => _showSpeedSelector(context, ref),
                    child: Text(
                      '${playerState.playbackSpeed}x',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  
                  // Repeat toggle
                  IconButton(
                    icon: Icon(
                      Icons.repeat,
                      color: playerState.isRepeat 
                          ? theme.colorScheme.tertiary 
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      ref.read(audioPlayerProvider.notifier).toggleRepeat();
                    },
                  ),
                  
                  // Play/Pause
                  isLoading
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : IconButton.filled(
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                          onPressed: () {
                            if (isPlaying) {
                              ref.read(audioPlayerProvider.notifier).pause();
                            } else {
                              ref.read(audioPlayerProvider.notifier).resume();
                            }
                          },
                        ),
                  
                  // Close
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      ref.read(audioPlayerProvider.notifier).stop();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showSpeedSelector(BuildContext context, WidgetRef ref) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5];
    final currentSpeed = ref.read(audioPlayerProvider).playbackSpeed;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Playback Speed',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...speeds.map((speed) => ListTile(
              title: Text('${speed}x'),
              trailing: currentSpeed == speed 
                  ? const Icon(Icons.check) 
                  : null,
              onTap: () {
                ref.read(audioPlayerProvider.notifier).setSpeed(speed);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}