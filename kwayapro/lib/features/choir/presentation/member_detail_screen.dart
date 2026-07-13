import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/enums.dart';
import '../../attendance/domain/attendance_providers.dart';
import '../domain/choir_providers.dart';
import '../domain/models/choir_membership.dart';

class MemberDetailScreen extends ConsumerWidget {
  final String userId;

  const MemberDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(choirMembersProvider);
    final attendanceRateAsync = ref.watch(memberAttendanceRateProvider(userId));

    return membersAsync.when(
      data: (members) {
        final membership = members.where((m) => m.userId == userId).firstOrNull;
        if (membership == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: const Text('Manage Member'),
            ),
            body: const Center(child: Text('Member not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: const Text('Manage Member'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _IdentityCard(membership: membership),
              const SizedBox(height: 24),
              if (membership.role != MemberRole.leader) ...[
                _RoleSection(membership: membership),
                const SizedBox(height: 24),
              ],
              _VoicePartSection(membership: membership),
              const SizedBox(height: 24),
              _PermissionsSection(membership: membership),
              const SizedBox(height: 24),
              _AttendanceStatsCard(
                rate: attendanceRateAsync.valueOrNull ?? 0.0,
                isLoading: attendanceRateAsync.isLoading,
              ),
              const SizedBox(height: 32),
              _DangerZone(membership: membership),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final ChoirMembership membership;

  const _IdentityCard({required this.membership});

  @override
  Widget build(BuildContext context) {
    final initials = membership.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: _getPartColor(membership.defaultVoicePart),
              child: Text(
                initials.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    membership.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          membership.role.name.toUpperCase(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        membership.defaultVoicePart.displayName,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPartColor(VoicePart part) {
    return switch (part) {
      VoicePart.S => Colors.pink,
      VoicePart.A => Colors.purple,
      VoicePart.T => Colors.teal,
      VoicePart.B => Colors.red,
    };
  }
}

// FUNCTIONAL FIX (Leader/Director audit, Finding #8): PRD §5.2 lists
// "Change a member's default voice part" as a Choir Leader capability, but
// no screen exposed it anywhere. Mirrors attendance_screen.dart's
// _VoicePartOverrideSheet pattern (same bottom-sheet shape/M3 tokens), but
// writes defaultVoicePart on the membership itself rather than a
// session-only override.
class _VoicePartSection extends ConsumerWidget {
  final ChoirMembership membership;

  const _VoicePartSection({required this.membership});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.record_voice_over),
        title: const Text('Default Voice Part'),
        subtitle: Text(membership.defaultVoicePart.displayName),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showVoicePartSheet(context, ref),
      ),
    );
  }

  void _showVoicePartSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Container(
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
              'Change Default Voice Part',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            Text(
              membership.name,
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            ...VoicePart.values.map((part) => ListTile(
                  leading: part == membership.defaultVoicePart
                      ? Icon(Icons.check_circle, color: Theme.of(sheetContext).colorScheme.primary)
                      : const Icon(Icons.circle_outlined),
                  title: Text(part.displayName),
                  selected: part == membership.defaultVoicePart,
                  selectedTileColor: Theme.of(sheetContext).colorScheme.secondaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () => _selectPart(context, ref, part),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _selectPart(BuildContext context, WidgetRef ref, VoicePart part) async {
    try {
      await ref.read(choirRepositoryProvider).updateMembership(
            membership.choirId,
            membership.userId,
            {'defaultVoicePart': part.name},
          );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${membership.name}\'s default voice part set to ${part.displayName}')),
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

// FUNCTIONAL FIX (Leader/Director on-device audit, task #29): there was no
// way to permanently assign the Director role at all — see
// ChoirRepository.assignMemberRole for why this calls a Cloud Function
// instead of writing the membership doc directly (firestore.rules makes
// `role` immutable client-side by design).
class _RoleSection extends ConsumerWidget {
  final ChoirMembership membership;

  const _RoleSection({required this.membership});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDirector = membership.role == MemberRole.director;
    return Card(
      child: ListTile(
        leading: Icon(isDirector ? Icons.workspace_premium : Icons.person_outline),
        title: const Text('Role'),
        subtitle: Text(isDirector ? 'Director' : 'Chorister'),
        // NOTE: deliberately not FilledButton/ElevatedButton here — this
        // app's ButtonThemeData sets minimumSize: Size.fromHeight(48),
        // which forces width: double.infinity. That's fine inside a Column
        // but crashes (BoxConstraints forces an infinite width) when a
        // button-style-button's intrinsic width is queried by a
        // non-Expanded parent like ListTile.trailing or a bare Row — see
        // the billing_screen.dart fix earlier this session. Material+InkWell
        // sizes to its child's actual content instead.
        trailing: Material(
          color: Theme.of(context).colorScheme.secondaryContainer,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => _confirmRoleChange(context, ref, isDirector),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                isDirector ? 'Demote to Chorister' : 'Promote to Director',
                style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmRoleChange(BuildContext context, WidgetRef ref, bool isDirector) {
    final newRole = isDirector ? MemberRole.chorister : MemberRole.director;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isDirector ? 'Demote to Chorister?' : 'Promote to Director?'),
        content: Text(
          isDirector
              ? '${membership.name} will lose Director-level access (audio upload, attendance, voice-part overrides, announcements) and become a regular chorister.'
              : '${membership.name} will gain full Director-level access: audio upload, attendance management, voice-part overrides, and announcements.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(choirRepositoryProvider).assignMemberRole(
                      membership.choirId,
                      membership.userId,
                      newRole,
                    );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _PermissionsSection extends ConsumerWidget {
  final ChoirMembership membership;

  const _PermissionsSection({required this.membership});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'GRANT PERMISSIONS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 1,
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              _PermissionToggle(
                label: 'Song Program Planner',
                description: 'Create and publish event programs',
                permissionKey: 'song_program_planner',
                membership: membership,
              ),
              const Divider(height: 1),
              _PermissionToggle(
                label: 'Audio Uploader',
                description: 'Upload voice part recordings',
                permissionKey: 'audio_uploader',
                membership: membership,
              ),
              const Divider(height: 1),
              _PermissionToggle(
                label: 'Attendance Manager',
                description: 'Mark attendance for rehearsals',
                permissionKey: 'attendance_manager',
                membership: membership,
              ),
              const Divider(height: 1),
              _PermissionToggle(
                label: 'Score Librarian',
                description: 'Upload and manage score PDFs/images',
                permissionKey: 'score_librarian',
                membership: membership,
              ),
              const Divider(height: 1),
              _PermissionToggle(
                label: 'Announcements',
                description: 'Post pinned messages to chat',
                permissionKey: 'announcements',
                membership: membership,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionToggle extends ConsumerStatefulWidget {
  final String label;
  final String description;
  final String permissionKey;
  final ChoirMembership membership;

  const _PermissionToggle({
    required this.label,
    required this.description,
    required this.permissionKey,
    required this.membership,
  });

  @override
  ConsumerState<_PermissionToggle> createState() => _PermissionToggleState();
}

class _PermissionToggleState extends ConsumerState<_PermissionToggle> {
  // Leader/Director audit follow-up fix: the switch used to bind `value`
  // straight to the stream-backed membership.permissions, and the update
  // call's catch block was empty — a rejected write (e.g. security rules
  // blocking a leader from granting a permission to themselves) left the
  // switch showing "on" with no error, even though the write never
  // persisted. _pendingValue makes the toggle optimistic-but-correctable: it
  // shows the tapped state immediately, then snaps back to the real
  // (stream-backed) value and surfaces the actual error if the write fails.
  bool? _pendingValue;

  @override
  Widget build(BuildContext context) {
    final hasPermission = widget.membership.permissions.contains(widget.permissionKey);
    final displayedValue = _pendingValue ?? hasPermission;

    return SwitchListTile(
      title: Text(widget.label),
      subtitle: Text(
        widget.description,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      value: displayedValue,
      onChanged: (value) => _togglePermission(value),
    );
  }

  Future<void> _togglePermission(bool newValue) async {
    setState(() => _pendingValue = newValue);
    try {
      final current = List<String>.from(widget.membership.permissions);
      if (newValue) {
        current.add(widget.permissionKey);
      } else {
        current.remove(widget.permissionKey);
      }
      await ref.read(choirRepositoryProvider).updateMembership(
            widget.membership.choirId,
            widget.membership.userId,
            {'permissions': current},
          );
      if (mounted) setState(() => _pendingValue = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pendingValue = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update "${widget.label}": $e')),
      );
    }
  }
}

class _AttendanceStatsCard extends StatelessWidget {
  final double rate;
  final bool isLoading;

  const _AttendanceStatsCard({required this.rate, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.analytics,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: isLoading
                  ? const LinearProgressIndicator()
                  : Text(
                      '${(rate * 100).round()}% attendance',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerZone extends ConsumerWidget {
  final ChoirMembership membership;

  const _DangerZone({required this.membership});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'DANGER ZONE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
              letterSpacing: 1,
            ),
          ),
        ),
        Card(
          color: Colors.red[50],
          child: ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red[700]),
            title: Text(
              'Remove from Choir',
              style: TextStyle(color: Colors.red[700]),
            ),
            subtitle: const Text('Attendance history will be preserved'),
            onTap: () => _confirmRemove(context, ref),
          ),
        ),
      ],
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove ${membership.name} from the choir? Their attendance history will be preserved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(choirRepositoryProvider).deleteMembership(
                      membership.choirId,
                      membership.userId,
                    );
                if (context.mounted) {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${membership.name} removed from choir.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}