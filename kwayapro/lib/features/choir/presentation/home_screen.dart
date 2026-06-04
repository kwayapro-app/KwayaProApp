import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/enums.dart' show ChoirPlan, MemberRole, VoicePart;
import '../domain/choir_providers.dart';
import '../../rehearsal/domain/rehearsal_providers.dart';
import '../../attendance/domain/attendance_providers.dart';
import '../../../shared/utils/permission_checker.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showChoirSwitcher(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _ChoirSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choir = ref.watch(activeChoirProvider).value;
    final membership = ref.watch(currentMembershipProvider).value;
    final members = ref.watch(choirMembersProvider).value ?? [];
    final rehearsals = ref.watch(upcomingRehearsalsProvider).value ?? [];
    final nextRehearsal = rehearsals.isNotEmpty ? rehearsals.first : null;

    if (choir == null || membership == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showChoirSwitcher(context, ref),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  choir.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Riverpod will automatically refresh streams, but we can invalidate if needed
          ref.invalidate(activeChoirProvider);
          ref.invalidate(currentMembershipProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Hero Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            choir.plan == ChoirPlan.pro ? 'PRO TIER' : 'FREE TIER',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          membership.role.name.toUpperCase(),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      choir.name,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricInfo(context, '${members.length}', 'Members'),
                        _buildMetricInfo(context, '${choir.songCount}', 'Songs'),
                        _buildAttendanceMetric(context, ref, membership),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Voice Part Distribution (Leader/Director only)
            if (membership.role == MemberRole.leader || membership.role == MemberRole.director) ...[
              _buildVoicePartDistribution(context, members),
              const SizedBox(height: 24),
            ],

            // Quick Actions based on Role
            if (membership.role == MemberRole.leader || membership.role == MemberRole.director) ...[
              Text(
                'Management',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildActionChip(context, Icons.event_note, 'Programs', () => context.push('/planner')),
                    if (membership.role == MemberRole.leader) ...[
                      const SizedBox(width: 12),
                      _buildActionChip(context, Icons.people, 'Members', () => context.push('/members')),
                      const SizedBox(width: 12),
                      _buildActionChip(context, Icons.payment, 'Billing', () => context.push('/billing')),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Next Rehearsal
            Text(
              'Upcoming Rehearsal',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (nextRehearsal == null)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text('No upcoming rehearsals scheduled.'),
                  ),
                ),
              )
            else
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  title: Text(nextRehearsal.location),
                  subtitle: Text('${nextRehearsal.date.day}/${nextRehearsal.date.month} at ${nextRehearsal.time}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/home/rehearsals'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricInfo(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceMetric(BuildContext context, WidgetRef ref, dynamic membership) {
    final permissionChecker = ref.read(permissionCheckerProvider);
    
    if (permissionChecker.isLeader || permissionChecker.isDirector) {
      final attendanceRate = ref.watch(lastSessionAttendanceRateProvider);
      return attendanceRate.when(
        data: (rate) => _buildMetricInfo(context, '${(rate * 100).round()}%', 'Attend'),
        loading: () => _buildMetricInfo(context, '...', 'Attend'),
        error: (_, __) => _buildMetricInfo(context, '--', 'Attend'),
      );
    } else {
      final myAttendance = ref.watch(myAttendanceHistoryProvider);
      return myAttendance.when(
        data: (history) {
          if (history.isEmpty) return _buildMetricInfo(context, '--', 'Yours');
          final attended = history.where((a) => a.attended).length;
          final rate = attended / history.length;
          return Column(
            children: [
              Text(
                '${(rate * 100).round()}%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                'Yours',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
        loading: () => _buildMetricInfo(context, '...', 'Yours'),
        error: (_, __) => _buildMetricInfo(context, '--', 'Yours'),
      );
    }
  }

  Widget _buildVoicePartDistribution(BuildContext context, List members) {
    final counts = <VoicePart, int>{};
    for (final m in members) {
      final part = m.defaultVoicePart;
      counts[part] = (counts[part] ?? 0) + 1;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPartPill('S', counts[VoicePart.S] ?? 0, Colors.pink),
        const SizedBox(width: 8),
        _buildPartPill('A', counts[VoicePart.A] ?? 0, Colors.purple),
        const SizedBox(width: 8),
        _buildPartPill('T', counts[VoicePart.T] ?? 0, Colors.teal),
        const SizedBox(width: 8),
        _buildPartPill('B', counts[VoicePart.B] ?? 0, Colors.red),
      ],
    );
  }

  Widget _buildPartPill(String part, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$part: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionChip(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSecondaryContainer),
      label: Text(label),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onPressed: onTap,
    );
  }
}

class _ChoirSwitcherSheet extends ConsumerWidget {
  const _ChoirSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userChoirs = ref.watch(userChoirsProvider).value ?? [];
    final activeChoirId = ref.watch(activeChoirIdProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Switch Choir',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          if (userChoirs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('You are not in any choirs yet.'),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: userChoirs.length,
                itemBuilder: (context, index) {
                  final cw = userChoirs[index];
                  final isActive = cw.choir.choirId == activeChoirId;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Text(
                        cw.choir.name[0].toUpperCase(),
                        style: TextStyle(
                          color: isActive ? Theme.of(context).colorScheme.onPrimary : null,
                        ),
                      ),
                    ),
                    title: Text(cw.choir.name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : null)),
                    subtitle: Text(cw.membership.role.name.toUpperCase()),
                    trailing: isActive ? const Icon(Icons.check, color: Colors.green) : null,
                    onTap: () {
                      ref.read(activeChoirIdProvider.notifier).setChoir(cw.choir.choirId);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Join or Create another Choir'),
            onTap: () {
              Navigator.pop(context);
              // Handle flow for joining/creating another choir - maybe go to onboarding logic
              context.push('/onboarding');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
