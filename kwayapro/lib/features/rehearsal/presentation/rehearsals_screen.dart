import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/enums.dart';
import '../../choir/domain/choir_providers.dart';
import '../../../shared/utils/permission_checker.dart';
import '../domain/rehearsal_providers.dart';
import '../domain/models/rehearsal_session.dart';

class RehearsalsScreen extends ConsumerStatefulWidget {
  const RehearsalsScreen({super.key});

  @override
  ConsumerState<RehearsalsScreen> createState() => _RehearsalsScreenState();
}

class _RehearsalsScreenState extends ConsumerState<RehearsalsScreen> {
  bool _showPastRehearsals = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upcomingAsync = ref.watch(upcomingRehearsalsProvider);
    final pastAsync = ref.watch(pastRehearsalsProvider);
    final membership = ref.watch(currentMembershipProvider).valueOrNull;

    final permissionChecker = PermissionChecker(membership);
    final isManagement = permissionChecker.isManagement;
    final canMarkAttendance = permissionChecker.canMarkAttendance;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Schedule',
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            
            // Content
            Expanded(
              child: upcomingAsync.when(
                loading: () => ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 2,
                  itemBuilder: (context, index) => _buildSkeletonCard(theme),
                ),
                error: (e, st) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      const Text('Failed to load rehearsals'),
                      TextButton(onPressed: () => ref.invalidate(upcomingRehearsalsProvider), child: const Text('Retry')),
                    ],
                  ),
                ),
                data: (upcoming) {
                  if (upcoming.isEmpty) {
                    return _buildEmptyState(theme, isManagement);
                  }
                  
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Upcoming rehearsals
                      ...upcoming.asMap().entries.map((entry) {
                        final index = entry.key;
                        final session = entry.value;
                        return _RehearsalCard(
                          session: session,
                          isNext: index == 0,
                          isManagement: isManagement,
                          canMarkAttendance: canMarkAttendance,
                          onAttendanceTap: () => context.push('/attendance/${session.sessionId}'),
                          onGuestDirectorTap: () => context.push('/guest-director/${session.sessionId}'),
                        );
                      }),
                      
                      // Past rehearsals section
                      pastAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (past) {
                          if (past.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),
                              TextButton.icon(
                                onPressed: () => setState(() => _showPastRehearsals = !_showPastRehearsals),
                                icon: Icon(_showPastRehearsals ? Icons.expand_less : Icons.expand_more),
                                label: Text('Show ${past.length} past rehearsals'),
                              ),
                              if (_showPastRehearsals) ...past.map((session) => _RehearsalCard(
                                session: session,
                                isNext: false,
                                isManagement: false,
                                canMarkAttendance: false,
                                isPast: true,
                                onAttendanceTap: null,
                                onGuestDirectorTap: null,
                              )),
                            ],
                          );
                        },
                      ),
                      
                      const SizedBox(height: 80), // Space for FAB
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      
      floatingActionButton: isManagement 
          ? FloatingActionButton(
              onPressed: () => _showScheduleSheet(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSkeletonCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 192,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(32),
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
            Icon(Icons.calendar_today_outlined, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No Upcoming Rehearsals', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Your choir hasn\'t scheduled any sessions yet. Directors can schedule practices to notify members.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (isManagement) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showScheduleSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('Schedule Session'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showScheduleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _ScheduleRehearsalSheet(),
    );
  }
}

class _RehearsalCard extends ConsumerWidget {
  final RehearsalSession session;
  final bool isNext;
  final bool isManagement;
  final bool canMarkAttendance;
  final bool isPast;
  final VoidCallback? onAttendanceTap;
  final VoidCallback? onGuestDirectorTap;

  const _RehearsalCard({
    required this.session,
    required this.isNext,
    required this.isManagement,
    required this.canMarkAttendance,
    this.isPast = false,
    this.onAttendanceTap,
    this.onGuestDirectorTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myRSVP = ref.watch(myRSVPProvider(session.sessionId)).valueOrNull;
    final rsvpCounts = ref.watch(rsvpCountsProvider(session.sessionId)).valueOrNull;
    
    final currentStatus = myRSVP?.rsvp ?? RSVPStatus.pending;
    
    final borderColor = isNext ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    final backgroundColor = isPast 
        ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.85)
        : theme.colorScheme.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor, width: isNext ? 2 : 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            if (isNext) Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(width: 3, color: theme.colorScheme.primary),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(session.title, style: theme.textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDate(session.date)} • ${session.time}',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (isNext)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text('Next', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
                        ),
                    ],
                  ),
                  
                  // Location
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(session.location, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                  
                  // Management/attendance-permission actions (only for next upcoming)
                  if ((isManagement || canMarkAttendance) && isNext && !isPast) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: onAttendanceTap,
                            icon: const Icon(Icons.checklist, size: 18),
                            label: const Text('Attendance'),
                          ),
                        ),
                        // Guest-director invites remain leader/director-only —
                        // attendance_manager is scoped to attendance, not to
                        // granting temporary director access.
                        if (isManagement) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onGuestDirectorTap,
                              icon: const Icon(Icons.person_add_outlined, size: 18),
                              label: const Text('Guest'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  
                  // RSVP control (not for past)
                  if (!isPast) ...[
                    const SizedBox(height: 16),
                    _RSVPControl(
                      currentStatus: currentStatus,
                      onStatusChanged: (status) => _handleRSVP(context, ref, status),
                    ),
                    
                    // RSVP counts for management
                    if (isManagement && rsvpCounts != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Going: ${rsvpCounts[RSVPStatus.coming] ?? 0} • Maybe: ${rsvpCounts[RSVPStatus.pending] ?? 0} • No: ${rsvpCounts[RSVPStatus.notComing] ?? 0}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                  
                  // Past attendance result
                  if (isPast && myRSVP != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          myRSVP.attended ? Icons.check_circle : Icons.cancel_outlined,
                          size: 18,
                          color: myRSVP.attended ? theme.colorScheme.tertiary : theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          myRSVP.attended ? 'You attended' : 'Absent',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: myRSVP.attended ? theme.colorScheme.tertiary : theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleRSVP(BuildContext context, WidgetRef ref, RSVPStatus status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Attendance'),
        content: Text('Mark yourself as "${_statusLabel(status)}" to ${session.title}? This helps the director plan the sections.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(rehearsalRepositoryProvider).setRSVP(
                sessionId: session.sessionId,
                userId: ref.read(currentMembershipProvider).valueOrNull?.userId ?? 'unknown',
                choirId: session.choirId,
                status: status,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('RSVP updated to ${_statusLabel(status)}')),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _statusLabel(RSVPStatus status) {
    return switch (status) {
      RSVPStatus.coming => 'Going',
      RSVPStatus.notComing => 'Not Going',
      RSVPStatus.pending => 'Maybe',
    };
  }
}

class _RSVPControl extends StatelessWidget {
  final RSVPStatus currentStatus;
  final Function(RSVPStatus) onStatusChanged;

  const _RSVPControl({
    required this.currentStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _RSVPButton(
            label: 'Going',
            isSelected: currentStatus == RSVPStatus.coming,
            onTap: () => onStatusChanged(RSVPStatus.coming),
            selectedColor: theme.colorScheme.secondaryContainer,
          ),
          _RSVPButton(
            label: 'Maybe',
            isSelected: currentStatus == RSVPStatus.pending,
            onTap: () => onStatusChanged(RSVPStatus.pending),
          ),
          _RSVPButton(
            label: "Can't",
            isSelected: currentStatus == RSVPStatus.notComing,
            onTap: () => onStatusChanged(RSVPStatus.notComing),
          ),
        ],
      ),
    );
  }
}

class _RSVPButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const _RSVPButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? (selectedColor ?? theme.colorScheme.secondaryContainer) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected && label == 'Going') ...[
                Icon(Icons.check, size: 18, color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected 
                      ? theme.colorScheme.onSecondaryContainer 
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleRehearsalSheet extends ConsumerStatefulWidget {
  const _ScheduleRehearsalSheet();

  @override
  ConsumerState<_ScheduleRehearsalSheet> createState() => _ScheduleRehearsalSheetState();
}

class _ScheduleRehearsalSheetState extends ConsumerState<_ScheduleRehearsalSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  String? _selectedDirectorId;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(24),
        child: ListView(
          controller: scrollController,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text('Schedule Rehearsal', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),
            
            // Session title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Session Title',
                hintText: 'e.g., Sunday Mass Prep',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Date & Time
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) setState(() => _selectedDate = date);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (time != null) setState(() => _selectedTime = time);
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(_selectedTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Location
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'e.g., Main Parish Hall',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Notes
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any special instructions...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            
            // Save button
            FilledButton(
              onPressed: _saveRehearsal,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Schedule Rehearsal'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveRehearsal() async {
    if (_titleController.text.isEmpty || _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final choirId = ref.read(activeChoirIdProvider);
    final userId = ref.read(currentMembershipProvider).valueOrNull?.userId;
    
    if (choirId == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No choir selected')),
      );
      return;
    }

    final session = RehearsalSession(
      sessionId: const Uuid().v4(),
      choirId: choirId,
      title: _titleController.text,
      date: _selectedDate,
      time: _selectedTime.format(context),
      location: _locationController.text,
      directorId: _selectedDirectorId ?? userId,
      isGuestDirector: false,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    await ref.read(rehearsalRepositoryProvider).createSession(session);
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rehearsal scheduled. Members will be notified.')),
      );
    }
  }
}