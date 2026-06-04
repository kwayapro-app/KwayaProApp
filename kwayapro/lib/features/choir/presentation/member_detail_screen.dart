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
                label: 'Score Librarian',
                description: 'Upload and manage PDF scores',
                permissionKey: 'score_librarian',
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

class _PermissionToggle extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = membership.permissions.contains(permissionKey);

    return SwitchListTile(
      title: Text(label),
      subtitle: Text(
        description,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      value: hasPermission,
      onChanged: (value) => _togglePermission(ref, value),
    );
  }

  Future<void> _togglePermission(WidgetRef ref, bool newValue) async {
    try {
      final current = List<String>.from(membership.permissions);
      if (newValue) {
        current.add(permissionKey);
      } else {
        current.remove(permissionKey);
      }
      await ref.read(choirRepositoryProvider).updateMembership(
            membership.choirId,
            membership.userId,
            {'permissions': current},
          );
    } catch (e) {
      // Handle error
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