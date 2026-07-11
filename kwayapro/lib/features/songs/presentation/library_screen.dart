import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/enums.dart';
import '../../audio/domain/audio_player_notifier.dart';
import '../../audio/presentation/widgets/mini_player_bar.dart';
import '../../audio/data/audio_repository.dart';
import '../../choir/domain/choir_providers.dart';
import '../../../shared/utils/permission_checker.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/song_repository.dart' show SongLimitExceededException;
import '../domain/song_providers.dart';
import '../domain/models/song.dart';
import '../domain/models/song_section.dart';
import '../domain/models/audio_part.dart';
import 'widgets/song_list_item.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songsAsync = ref.watch(songsWithPartsProvider);
    final filterPart = ref.watch(libraryFilterProvider);
    final membership = ref.watch(currentMembershipProvider).valueOrNull;
    final userVoicePart = membership?.defaultVoicePart;
    final isManagement = PermissionChecker(membership).isManagement;
    
    return Scaffold(
      body: Column(
        children: [
          // Sticky header
          Container(
            color: theme.colorScheme.surface,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Library',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search songs, keys, tags...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value.toLowerCase());
                      },
                    ),
                  ),
                  
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: filterPart == null,
                          onTap: () => ref.read(libraryFilterProvider.notifier).state = null,
                        ),
                        const SizedBox(width: 8),
                        ...VoicePart.values.map((part) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: part.displayName,
                            selected: filterPart == part,
                            onTap: () => ref.read(libraryFilterProvider.notifier).state = part,
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // User part banner (for non-directors)
          if (!isManagement && userVoicePart != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'YOUR PART: ${userVoicePart.displayName.toUpperCase()} — Tap parts to listen',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Song list
          Expanded(
            child: songsAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 100),
                itemCount: 4,
                itemBuilder: (context, index) => _buildSkeletonCard(theme),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load songs',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(songsWithPartsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (songs) {
                // Apply search filter
                final filteredSongs = _searchQuery.isEmpty
                    ? songs
                    : songs.where((s) {
                        return s.song.title.toLowerCase().contains(_searchQuery) ||
                            (s.song.category?.toLowerCase().contains(_searchQuery) ?? false) ||
                            (s.song.key?.toLowerCase().contains(_searchQuery) ?? false);
                      }).toList();
                
                if (filteredSongs.isEmpty) {
                  return _buildEmptyState(theme, isManagement);
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  itemCount: filteredSongs.length,
                  itemBuilder: (context, index) {
                    final songWithParts = filteredSongs[index];
                    return SongListItem(
                      songWithParts: songWithParts,
                      userVoicePart: userVoicePart,
                      colorIndex: index,
                      onPartTap: (part) => _playPart(songWithParts, part),
                      onMoreTap: (isManagement || PermissionChecker(membership).canUploadAudio)
                          ? () => _showSongOptions(
                                songWithParts,
                                isManagement,
                                PermissionChecker(membership).canUploadAudio,
                              )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      
      // FAB - only for leaders and directors
      floatingActionButton: isManagement
          ? FloatingActionButton(
              onPressed: _showAddSongSheet,
              child: const Icon(Icons.add),
            )
          : null,
      
      // Mini player at bottom
      bottomSheet: const MiniPlayerBar(),
    );
  }

  Widget _buildSkeletonCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: 150,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(
                      4,
                      (i) => Container(
                        width: 32,
                        height: 24,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  Widget _buildEmptyState(ThemeData theme, bool isManagement) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Songs Yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Your choir\'s library is empty. Start building your digital repertoire by adding your first sheet music or audio track.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (isManagement) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _showAddSongSheet,
                icon: const Icon(Icons.add),
                label: const Text('Add First Song'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _playPart(SongWithParts songWithParts, VoicePart part) {
    final parts = songWithParts.getPartsForVoicePart(part);
    if (parts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No ${part.displayName} audio uploaded yet.')),
      );
      return;
    }
    
    // Play the first audio part for this voice part
    ref.read(audioPlayerProvider.notifier).play(
      parts.first,
      songWithParts.song,
    );
  }

  // CHORISTER AUDIT FIX: "Edit Song" and "Upload Audio" were reachable by
  // every member regardless of role — only "Delete Song" was gated. The
  // underlying Firestore rules always rejected the write for anyone without
  // canUploadAudio (management role or the audio_uploader permission), so
  // this wasn't an actual data breach, just a dead-end UI exposing a control
  // that would silently fail for choristers. Gated to match the rule.
  void _showSongOptions(SongWithParts songWithParts, bool isManagement, bool canUploadAudio) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canUploadAudio) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Song'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to edit song
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Upload Audio'),
                onTap: () {
                  Navigator.pop(context);
                  _showUploadAudioSheet(songWithParts);
                },
              ),
            ],
            if (isManagement)
              ListTile(
                leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                title: Text('Delete Song', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteSong(songWithParts);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showUploadAudioSheet(SongWithParts songWithParts) async {
    final section = await showModalBottomSheet<SongSection>(
      context: context,
      builder: (ctx) => _SectionPickerSheet(songId: songWithParts.song.songId),
    );
    if (section == null || !mounted) return;

    final part = await showModalBottomSheet<VoicePart>(
      context: context,
      builder: (ctx) => _VoicePartPickerSheet(),
    );
    if (part == null || !mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    
    if (result != null && result.files.isNotEmpty && mounted) {
      final file = result.files.first;
      final path = file.path;
      
      if (path != null) {
        final choirId = ref.read(activeChoirIdProvider);
        final userId = ref.read(currentUserIdProvider);
        if (choirId == null || userId == null) return;

        final scaffold = ScaffoldMessenger.of(context);
        scaffold.showSnackBar(SnackBar(content: Text('Uploading ${file.name}...')));

        try {
          final audioRepo = AudioRepository();
          final downloadUrl = await audioRepo.uploadExternalAudio(
            choirId: choirId,
            songId: songWithParts.song.songId,
            sectionId: section.sectionId,
            voicePart: part,
            localFilePath: path,
            onProgress: (_) {},
          );

          final audioPart = AudioPart(
            audioPartId: const Uuid().v4(),
            sectionId: section.sectionId,
            songId: songWithParts.song.songId,
            choirId: choirId,
            voicePart: part,
            audioUrl: downloadUrl,
            durationSeconds: 0,
            uploadedBy: userId,
            createdAt: DateTime.now(),
          );

          await ref.read(songRepositoryProvider).createAudioPart(audioPart);
          if (mounted) scaffold.showSnackBar(const SnackBar(content: Text('Audio uploaded successfully')));
        } catch (e) {
          if (mounted) scaffold.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        }
      }
    }
  }

  void _confirmDeleteSong(SongWithParts songWithParts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Song?'),
        content: Text('Are you sure you want to delete "${songWithParts.song.title}"? This will also delete all audio parts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(songRepositoryProvider).deleteSong(songWithParts.song.songId);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddSongSheet() async {
    // Check freemium limit first
    final isAtLimit = await ref.read(isAtSongLimitProvider.future);
    if (isAtLimit && mounted) {
      context.push('/billing');
      return;
    }
    
    // Show add song bottom sheet
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddSongSheet(
        onUploadExternal: _handleExternalUpload,
        onRecordInStudio: _navigateToStudio,
      ),
    );
  }

  void _handleExternalUpload() async {
    final titleCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    String? category;
    String? language;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Song'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Song Title', hintText: 'e.g. Mungu Ni Pendo')),
              const SizedBox(height: 12),
              TextField(controller: keyCtrl, decoration: const InputDecoration(labelText: 'Key (optional)', hintText: 'e.g. Bb, C, Dm')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ['Worship', 'Praise', 'Offertory', 'Communion', 'Other']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => category = v,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: language,
                decoration: const InputDecoration(labelText: 'Language'),
                items: ['English', 'Swahili', 'Luganda', 'Latin', 'Other']
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => language = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, {'title': titleCtrl.text, 'key': keyCtrl.text, 'category': category, 'language': language}), child: const Text('Create')),
        ],
      ),
    );
    // Phase 5 Fix 3 (adjacent finding): these two controllers back the
    // dialog's TextFields but were never disposed — a small leak on every
    // "New Song" dialog open. Not the build()-recreation bug class Fix 3
    // was scoped to (this method isn't build()), but the same lifecycle
    // hygiene concern.
    titleCtrl.dispose();
    keyCtrl.dispose();

    if (result == null || !mounted) return;
    final title = result['title'] as String? ?? '';
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Song title is required')));
      return;
    }

    final choirId = ref.read(activeChoirIdProvider);
    final userId = ref.read(currentUserIdProvider);
    if (choirId == null || userId == null) return;

    try {
      final songRepo = ref.read(songRepositoryProvider);
      final song = Song(
        songId: const Uuid().v4(),
        choirId: choirId,
        title: title,
        key: result['key'] as String?,
        language: result['language'] as String?,
        category: result['category'] as String?,
        uploadedBy: userId,
        createdAt: DateTime.now(),
      );
      await songRepo.createSong(song);

      // Create default sections
      const defaultSections = ['Verse', 'Chorus', 'Bridge'];
      for (var i = 0; i < defaultSections.length; i++) {
        await songRepo.createSection(SongSection(
          sectionId: const Uuid().v4(),
          songId: song.songId,
          choirId: choirId,
          title: defaultSections[i],
          order: i,
          status: SectionStatus.comingSoon,
        ));
      }

      // Now pick and upload audio
      final audioResult = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false);
      if (audioResult != null && audioResult.files.isNotEmpty && mounted) {
        final file = audioResult.files.first;
        if (file.path != null) {
          final sections = await songRepo.watchSections(song.songId).first;
          if (sections.isNotEmpty) {
            final section = sections.first;
            final audioRepo = AudioRepository();
            final url = await audioRepo.uploadExternalAudio(
              choirId: choirId, songId: song.songId, sectionId: section.sectionId,
              voicePart: VoicePart.S, localFilePath: file.path!, onProgress: (_) {},
            );
            await songRepo.createAudioPart(AudioPart(
              audioPartId: const Uuid().v4(), sectionId: section.sectionId,
              songId: song.songId, choirId: choirId, voicePart: VoicePart.S,
              audioUrl: url, durationSeconds: 0, uploadedBy: userId, createdAt: DateTime.now(),
            ));
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Song created with audio')));
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Song created. Add audio parts from the song menu.')));
      }
    } on SongLimitExceededException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        context.push('/billing');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create song: $e')));
    }
  }

  void _navigateToStudio() {
    Navigator.pop(context);
    context.push('/studio');
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      selectedColor: theme.colorScheme.secondaryContainer,
      checkmarkColor: theme.colorScheme.onSecondaryContainer,
    );
  }
}

class _AddSongSheet extends StatelessWidget {
  final VoidCallback onUploadExternal;
  final VoidCallback onRecordInStudio;

  const _AddSongSheet({
    required this.onUploadExternal,
    required this.onRecordInStudio,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Song',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            
            // Option A: Upload external file
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.upload_file,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: const Text('Upload Audio File'),
              subtitle: const Text('MP3, WAV, M4A, AAC'),
              onTap: onUploadExternal,
            ),
            const SizedBox(height: 16),
            
            // Option B: Record in studio
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.mic,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
              title: const Text('Record in Studio'),
              subtitle: const Text('Use virtual keyboard + mic'),
              onTap: onRecordInStudio,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionPickerSheet extends ConsumerWidget {
  final String songId;
  const _SectionPickerSheet({required this.songId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(songSectionsProvider(songId));
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Section', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            sections.when(
              data: (secs) => Column(
                children: secs.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ListTile(
                      title: Text(s.title),
                      trailing: Icon(s.status == SectionStatus.ready ? Icons.check_circle : Icons.hourglass_empty, color: s.status == SectionStatus.ready ? Colors.green : theme.colorScheme.outline),
                      onTap: () => Navigator.pop(context, s),
                    ),
                  ),
                )).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error loading sections'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoicePartPickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Voice Part', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            ...VoicePart.values.map((part) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(context, part),
                  child: Text(part.displayName),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}