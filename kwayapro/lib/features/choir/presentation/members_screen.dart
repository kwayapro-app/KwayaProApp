import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/utils/permission_checker.dart';
import '../domain/choir_providers.dart';
import '../domain/models/choir_membership.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(choirMembersProvider);
    final permissionChecker = ref.watch(permissionCheckerProvider);
    final canManage = permissionChecker.canManageMembers;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search members...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : const Text('Members & Roles'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shield,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Granular permissions allow leaders to grant specific capabilities to choristers.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: membersAsync.when(
              data: (members) {
                final searchQuery = _searchController.text.toLowerCase();
                final filteredMembers = searchQuery.isEmpty
                    ? members
                    : members.where((m) => m.name.toLowerCase().contains(searchQuery)).toList();

                final leaders = filteredMembers.where((m) => m.role == MemberRole.leader).toList();
                final directors = filteredMembers.where((m) => m.role == MemberRole.director).toList();
                final choristers = filteredMembers.where((m) => m.role == MemberRole.chorister).toList();

                return ListView(
                  children: [
                    if (leaders.isNotEmpty) ...[
                      const _SectionHeader(title: 'LEADERSHIP'),
                      ...leaders.map((m) => _MemberRow(
                            membership: m,
                            onTap: canManage ? () => context.push('/members/${m.userId}') : null,
                          )),
                    ],
                    if (directors.isNotEmpty) ...[
                      const _SectionHeader(title: 'DIRECTORS'),
                      ...directors.map((m) => _MemberRow(
                            membership: m,
                            onTap: canManage ? () => context.push('/members/${m.userId}') : null,
                          )),
                    ],
                    if (choristers.isNotEmpty) ...[
                      const _SectionHeader(title: 'CHORISTERS'),
                      ...choristers.map((m) => _MemberRow(
                            membership: m,
                            onTap: canManage ? () => context.push('/members/${m.userId}') : null,
                          )),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final ChoirMembership membership;
  final VoidCallback? onTap;

  const _MemberRow({required this.membership, this.onTap});

  @override
  Widget build(BuildContext context) {
    final initials = membership.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join();

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: _getPartColor(membership.defaultVoicePart),
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(membership.name),
      subtitle: Row(
        children: [
          Text(
            membership.defaultVoicePart.displayName,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          if (membership.permissions.isNotEmpty) ...[
            const SizedBox(width: 8),
            ...membership.permissions.take(2).map((p) => Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getPermissionLabel(p),
                    style: const TextStyle(fontSize: 10),
                  ),
                )),
          ],
        ],
      ),
      trailing: Container(
        width: 4,
        height: 40,
        decoration: BoxDecoration(
          color: _getPartColor(membership.defaultVoicePart),
          borderRadius: BorderRadius.circular(2),
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

  String _getPermissionLabel(String permission) {
    return switch (permission) {
      'song_program_planner' => 'Planner',
      'audio_uploader' => 'Audio',
      'attendance_manager' => 'Attend',
      'score_librarian' => 'Scores',
      'announcements' => 'Announce',
      _ => permission,
    };
  }
}