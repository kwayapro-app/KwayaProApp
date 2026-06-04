import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/enums.dart';
import '../../choir/domain/choir_providers.dart' show activeChoirIdProvider, currentMembershipProvider;
import '../../songs/domain/models/song.dart';
import '../../songs/domain/song_providers.dart' show songLibraryProvider;
import '../../../shared/utils/permission_checker.dart';
import '../domain/models/song_program.dart';
import '../domain/planner_providers.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permissionChecker = ref.watch(permissionCheckerProvider);
    final canCreate = permissionChecker.isLeader ||
        permissionChecker.isDirector ||
        permissionChecker.canPlanPrograms;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Program Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Published'),
            Tab(text: 'Drafts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ProgramList(isPublished: true),
          _ProgramList(isPublished: false),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => context.push('/planner/new'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _ProgramList extends ConsumerWidget {
  final bool isPublished;

  const _ProgramList({required this.isPublished});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = isPublished
        ? ref.watch(publishedProgramsProvider)
        : ref.watch(draftProgramsProvider);

    return programsAsync.when(
      data: (programs) {
        if (programs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_note,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  isPublished ? 'No published programs' : 'No draft programs',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: programs.length,
          itemBuilder: (context, index) {
            final program = programs[index];
            return _ProgramListTile(program: program);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _ProgramListTile extends StatelessWidget {
  final SongProgram program;

  const _ProgramListTile({required this.program});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          program.eventName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(_formatDate(program.eventDate)),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    program.eventType.name.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Text(
                  '${program.songIds.length} songs',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: program.publishedAt != null
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.amber.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            program.publishedAt != null ? 'Published' : 'Draft',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: program.publishedAt != null ? Colors.green[700] : Colors.amber[700],
            ),
          ),
        ),
        onTap: () => context.push('/planner/${program.programId}'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class ProgramEditorScreen extends ConsumerStatefulWidget {
  final String? programId;

  const ProgramEditorScreen({super.key, this.programId});

  @override
  ConsumerState<ProgramEditorScreen> createState() => _ProgramEditorScreenState();
}

class _ProgramEditorScreenState extends ConsumerState<ProgramEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventNameController = TextEditingController();
  final _searchController = TextEditingController();
  
  EventType _selectedEventType = EventType.mass;
  DateTime _selectedDate = DateTime.now();
  List<String> _selectedSongIds = [];
  Timer? _reorderDebounce;
  List<Song> _filteredSongs = [];

  bool get isEditing => widget.programId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadProgram();
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _searchController.dispose();
    _reorderDebounce?.cancel();
    super.dispose();
  }

  void _loadProgram() {
    final programs = ref.read(songProgramsProvider).valueOrNull ?? [];
    final program = programs.where((p) => p.programId == widget.programId).firstOrNull;
    if (program != null) {
      _eventNameController.text = program.eventName;
      _selectedEventType = program.eventType;
      _selectedDate = program.eventDate;
      _selectedSongIds = List.from(program.songIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songLibraryProvider);
    final permissionChecker = ref.watch(permissionCheckerProvider);
    final canEdit = permissionChecker.isLeader ||
        permissionChecker.isDirector ||
        permissionChecker.canPlanPrograms;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(isEditing ? 'Edit Program' : 'New Program'),
        actions: [
          if (canEdit)
            TextButton(
              onPressed: _saveDraft,
              child: const Text('Save Draft'),
            ),
        ],
      ),
      body: songsAsync.when(
        data: (songs) {
          _filteredSongs = songs.where((s) => 
            s.title.toLowerCase().contains(_searchController.text.toLowerCase())
          ).toList();
          
          return Form(
            key: _formKey,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _eventNameController,
                        decoration: const InputDecoration(
                          labelText: 'Event Name',
                          hintText: 'e.g., Sunday Mass - 4th May',
                          border: OutlineInputBorder(),
                        ),
                        enabled: canEdit,
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: EventType.values.map((type) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(type.name.toUpperCase()),
                              selected: _selectedEventType == type,
                              onSelected: canEdit ? (selected) {
                                if (selected) setState(() => _selectedEventType = type);
                              } : null,
                            ),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: canEdit ? _selectDate : null,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Event Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(_formatDate(_selectedDate)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Songs (${_selectedSongIds.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (canEdit)
                        TextButton(
                          onPressed: _showAddSongsSheet,
                          child: const Text('Add Songs'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _selectedSongIds.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _selectedSongIds.removeAt(oldIndex);
                        _selectedSongIds.insert(newIndex, item);
                      });
                      _debouncedReorder();
                    },
                    itemBuilder: (context, index) {
                      final songId = _selectedSongIds[index];
                      final song = songs.firstWhere(
                        (s) => s.songId == songId,
                        orElse: () => Song(
                          songId: songId,
                          choirId: '',
                          title: 'Unknown',
                          category: '',
                          key: '',
                          language: '',
                          uploadedBy: '',
                          createdAt: DateTime.now(),
                        ),
                      );
                      return _ProgramSongRow(
                        key: ValueKey(songId),
                        index: index + 1,
                        song: song,
                        onRemove: canEdit ? () => _removeSong(songId) : null,
                      );
                    },
                  ),
                ),
                if (canEdit)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saveDraft,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Draft'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _publish,
                            icon: const Icon(Icons.share),
                            label: const Text('Publish'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  void _showAddSongsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search songs...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filteredSongs.length,
                itemBuilder: (context, index) {
                  final song = _filteredSongs[index];
                  final isSelected = _selectedSongIds.contains(song.songId);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: isSelected ? null : (value) {
                      setState(() => _selectedSongIds.add(song.songId));
                      Navigator.pop(context);
                    },
                    title: Text(song.title),
subtitle: Text(song.key != null && song.key!.isNotEmpty ? 'Key of ${song.key}' : (song.category ?? '')),
                    secondary: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeSong(String songId) {
    setState(() => _selectedSongIds.remove(songId));
  }

  void _debouncedReorder() {
    _reorderDebounce?.cancel();
    _reorderDebounce = Timer(const Duration(milliseconds: 500), () {
      if (isEditing) {
        ref.read(plannerRepositoryProvider).reorderSongs(widget.programId!, _selectedSongIds);
      }
    });
  }

  Future<void> _saveDraft() async {
    if (_eventNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event name')),
      );
      return;
    }

    try {
      final choirId = ref.read(activeChoirIdProvider);
      final user = ref.read(currentMembershipProvider).valueOrNull;

      if (choirId == null || user == null) throw Exception('Not in a choir');

      final program = SongProgram(
        programId: widget.programId ?? const Uuid().v4(),
        choirId: choirId,
        eventName: _eventNameController.text,
        eventType: _selectedEventType,
        eventDate: _selectedDate,
        songIds: _selectedSongIds,
        createdBy: user.userId,
        publishedAt: null,
      );

      if (isEditing) {
        await ref.read(plannerRepositoryProvider).updateProgram(widget.programId!, program.toJson());
      } else {
        await ref.read(plannerRepositoryProvider).createProgram(program);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Program saved as draft')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _publish() async {
    await _saveDraft();

    if (widget.programId != null || _selectedSongIds.isEmpty) {
      try {
        await ref.read(plannerRepositoryProvider).publishProgram(widget.programId ?? _eventNameController.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Program published. Choir members notified.')),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error publishing: $e')),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _ProgramSongRow extends StatelessWidget {
  final int index;
  final Song song;
  final VoidCallback? onRemove;

  const _ProgramSongRow({
    super.key,
    required this.index,
    required this.song,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index - 1,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text('$index. ${song.title}'),
        subtitle: Text(song.key != null && song.key!.isNotEmpty ? 'Key of ${song.key}' : (song.category ?? '')),
        trailing: onRemove != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              )
            : null,
      ),
    );
  }
}