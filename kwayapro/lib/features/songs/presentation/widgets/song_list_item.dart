import 'package:flutter/material.dart';
import '../../../../shared/models/enums.dart';
import '../../domain/song_providers.dart';
import '../../domain/models/song.dart';

class SongListItem extends StatelessWidget {
  final SongWithParts songWithParts;
  final VoicePart? userVoicePart;
  final void Function(VoicePart part) onPartTap;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;
  final int colorIndex;

  const SongListItem({
    super.key,
    required this.songWithParts,
    required this.userVoicePart,
    required this.onPartTap,
    this.onTap,
    this.onMoreTap,
    this.colorIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final song = songWithParts.song;
    
    final colors = [
      theme.colorScheme.primaryContainer,
      theme.colorScheme.secondaryContainer,
      theme.colorScheme.tertiaryContainer,
    ];
    final textColors = [
      theme.colorScheme.onPrimaryContainer,
      theme.colorScheme.onSecondaryContainer,
      theme.colorScheme.onTertiaryContainer,
    ];
    final bgColor = colors[colorIndex % 3];
    final txtColor = textColors[colorIndex % 3];
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.music_note,
                  color: txtColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _buildSubtitle(song),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: VoicePart.values.map((part) {
                        final hasAudio = songWithParts.hasAudioForVoicePart(part);
                        final isUserPart = userVoicePart == part;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _VoicePartPill(
                            part: part,
                            hasAudio: hasAudio,
                            isSelected: isUserPart,
                            onTap: () => onPartTap(part),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: onMoreTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _buildSubtitle(Song song) {
    final parts = <String>[];
    if (song.category != null && song.category!.isNotEmpty) {
      parts.add(song.category!);
    }
    if (song.key != null && song.key!.isNotEmpty) {
      parts.add('Key of ${song.key}');
    }
    return parts.isEmpty ? 'No details' : parts.join(' · ');
  }
}

class _VoicePartPill extends StatelessWidget {
  final VoicePart part;
  final bool hasAudio;
  final bool isSelected;
  final VoidCallback onTap;

  const _VoicePartPill({
    required this.part,
    required this.hasAudio,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (!hasAudio) {
      return InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No ${part.displayName} audio uploaded yet.'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Text(
            part.initial,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.secondaryContainer 
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: theme.colorScheme.secondary, width: 1) : null,
        ),
        child: Text(
          part.initial,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isSelected ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}