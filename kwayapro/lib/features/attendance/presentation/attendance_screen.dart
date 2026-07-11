import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../shared/models/enums.dart';
import '../../choir/domain/choir_providers.dart';
import '../../choir/domain/models/choir_membership.dart';
import '../../../shared/utils/permission_checker.dart';
import '../../rehearsal/domain/rehearsal_providers.dart';
import '../domain/attendance_providers.dart';
import '../domain/models/attendance.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const AttendanceScreen({super.key, required this.sessionId});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(sessionAttendanceProvider(widget.sessionId));
    final membersAsync = ref.watch(choirMembersProvider);
    final rehearsalAsync = ref.watch(upcomingRehearsalsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: attendanceAsync.when(
          data: (attendance) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rehearsalAsync.valueOrNull
                        ?.firstWhere((s) => s.sessionId == widget.sessionId, orElse: () => throw Exception()).title ??
                    'Attendance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${attendance.where((a) => a.attended).length}/${membersAsync.valueOrNull?.length ?? 0} PRESENT',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Attendance'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle),
            tooltip: 'Save attendance',
            onPressed: _saveAttendance,
          ),
        ],
      ),
      body: Column(
        children: [
          _OfflineNetworkAlertStrip(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              'Tap a name to mark present. Tap part badge to override.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 12,
              ),
            ),
          ),
          _buildBatchActionRow(),
          Expanded(
            child: attendanceAsync.when(
              data: (attendance) => membersAsync.when(
                data: (members) => _buildMemberList(members, attendance),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchActionRow() {
    final membership = ref.watch(currentMembershipProvider).valueOrNull;
    if (membership == null || !PermissionChecker(membership).isManagement) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _batchMarkAttended,
            icon: const Icon(Icons.playlist_add_check, size: 18),
            label: const Text('Mark all RSVPed as present'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList(List<ChoirMembership> members, List<Attendance> attendance) {
    final grouped = _groupByEffectivePart(members, attendance);

    if (grouped.isEmpty) {
      return const Center(child: Text('No members found'));
    }

    return ListView(
      children: VoicePart.values.map((part) {
        final partMembers = grouped[part] ?? [];
        if (partMembers.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPartColor(part).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      part.displayName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getPartColor(part),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${partMembers.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            ...partMembers.map((m) => _AttendanceMemberRow(
                  membership: m.membership,
                  attendance: m.attendance,
                  sessionId: widget.sessionId,
                  onPartOverride: () => _showPartOverrideSheet(m.membership),
                )),
          ],
        );
      }).toList(),
    );
  }

  Map<VoicePart, List<_MemberAttendance>> _groupByEffectivePart(
    List<ChoirMembership> members,
    List<Attendance> attendance,
  ) {
    final Map<VoicePart, List<_MemberAttendance>> grouped = {};

    for (final member in members) {
      final att = attendance.where((a) => a.userId == member.userId).firstOrNull;
      final effectivePart = att?.voicePartOverride ?? member.defaultVoicePart;

      grouped.putIfAbsent(effectivePart, () => []);
      grouped[effectivePart]!.add(_MemberAttendance(membership: member, attendance: att));
    }

    return grouped;
  }

  Color _getPartColor(VoicePart part) {
    return switch (part) {
      VoicePart.S => Colors.pink,
      VoicePart.A => Colors.purple,
      VoicePart.T => Colors.teal,
      VoicePart.B => Colors.red,
    };
  }

  void _showPartOverrideSheet(ChoirMembership member) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _VoicePartOverrideSheet(
        member: member,
        sessionId: widget.sessionId,
      ),
    );
  }

  Future<void> _saveAttendance() async {
    try {
      await ref.read(attendanceRepositoryProvider).batchMarkRSVPAttended(widget.sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _batchMarkAttended() async {
    try {
      await ref.read(attendanceRepositoryProvider).batchMarkRSVPAttended(widget.sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All RSVPs marked as attended')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _MemberAttendance {
  final ChoirMembership membership;
  final Attendance? attendance;

  const _MemberAttendance({required this.membership, this.attendance});
}

class _AttendanceMemberRow extends ConsumerWidget {
  final ChoirMembership membership;
  final Attendance? attendance;
  final String sessionId;
  final VoidCallback onPartOverride;

  const _AttendanceMemberRow({
    required this.membership,
    this.attendance,
    required this.sessionId,
    required this.onPartOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAttended = attendance?.attended ?? false;
    final rsvp = attendance?.rsvp ?? RSVPStatus.pending;

    return InkWell(
      onTap: () => _toggleAttendance(ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isAttended ? Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3) : null,
        child: Row(
          children: [
            Checkbox(
              value: isAttended,
              onChanged: (_) => _toggleAttendance(ref),
            ),
            Expanded(
              child: Row(
                children: [
                  Text(
                    membership.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (rsvp == RSVPStatus.coming)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    )
                  else if (rsvp == RSVPStatus.notComing)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: onPartOverride,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (attendance?.voicePartOverride ?? membership.defaultVoicePart).initial,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAttendance(WidgetRef ref) async {
    try {
      await ref.read(attendanceRepositoryProvider).markAttendance(
            sessionId: sessionId,
            userId: membership.userId,
            attended: !(attendance?.attended ?? false),
          );
    } catch (e) {
      // Handle error
    }
  }
}

class _VoicePartOverrideSheet extends ConsumerWidget {
  final ChoirMembership member;
  final String sessionId;

  const _VoicePartOverrideSheet({
    required this.member,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(sessionAttendanceProvider(sessionId));
    final currentOverride = attendanceAsync.valueOrNull
        ?.firstWhere((a) => a.userId == member.userId, orElse: () => throw Exception())
        .voicePartOverride;
    final effectivePart = currentOverride ?? member.defaultVoicePart;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Override Voice Part',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            member.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SESSION-SPECIFIC OVERRIDE — This assignment applies to this rehearsal only. Their default part in the Library remains unchanged.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...VoicePart.values.map((part) => ListTile(
                leading: part == effectivePart
                    ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                    : const Icon(Icons.circle_outlined),
                title: Text(part.displayName),
                selected: part == effectivePart,
                selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () => _selectPart(context, ref, part),
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _selectPart(BuildContext context, WidgetRef ref, VoicePart part) async {
    try {
      await ref.read(attendanceRepositoryProvider).setVoicePartOverride(
            sessionId: sessionId,
            userId: member.userId,
            voicePart: part,
          );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.name} assigned to ${part.displayName} for this session')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _OfflineNetworkAlertStrip extends StatefulWidget {
  @override
  State<_OfflineNetworkAlertStrip> createState() => _OfflineNetworkAlertStripState();
}

class _OfflineNetworkAlertStripState extends State<_OfflineNetworkAlertStrip> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then((result) {
      if (mounted) setState(() => _isOffline = result.contains(ConnectivityResult.none));
    });
    Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) setState(() => _isOffline = result.contains(ConnectivityResult.none));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.errorContainer,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 16, color: Theme.of(context).colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "You're offline. Attendance changes will sync when reconnected.",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      crossFadeState: _isOffline ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 300),
    );
  }
}