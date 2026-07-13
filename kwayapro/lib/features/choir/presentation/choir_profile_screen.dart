import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/choir_providers.dart';

// Leader/Director audit follow-up fix: choir_repository.dart's updateChoir()
// and the Choir.inviteCode field were both already fully wired server-side
// (firestore.rules' choirs update rule, leader-only) with no UI ever calling
// updateChoir or displaying/sharing inviteCode. This is the missing entry
// point — reached from home_screen.dart's leader-only Management chips.
class ChoirProfileScreen extends ConsumerStatefulWidget {
  const ChoirProfileScreen({super.key});

  @override
  ConsumerState<ChoirProfileScreen> createState() => _ChoirProfileScreenState();
}

class _ChoirProfileScreenState extends ConsumerState<ChoirProfileScreen> {
  final _nameController = TextEditingController();
  final _churchNameController = TextEditingController();
  bool _isSaving = false;
  bool _controllersInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _churchNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final choirAsync = ref.watch(activeChoirProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Choir Profile'),
      ),
      body: choirAsync.when(
        data: (choir) {
          if (choir == null) {
            return const Center(child: Text('Choir not found'));
          }
          // Only seed the controllers once (first successful load) — a
          // rebuild from a later Firestore snapshot shouldn't clobber
          // in-progress edits the leader hasn't saved yet.
          if (!_controllersInitialized) {
            _nameController.text = choir.name;
            _churchNameController.text = choir.churchName;
            _controllersInitialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INVITE CODE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  color: theme.colorScheme.primaryContainer,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            choir.inviteCode,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.share, color: theme.colorScheme.onPrimaryContainer),
                          tooltip: 'Share invite code',
                          onPressed: () => _shareInviteCode(choir.name, choir.inviteCode),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'CHOIR DETAILS',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Choir Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _churchNameController,
                  decoration: const InputDecoration(
                    labelText: 'Church Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : () => _save(choir.choirId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Changes'),
                    ),
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

  void _shareInviteCode(String choirName, String inviteCode) {
    Share.share(
      'Join $choirName on KwayaPro! Use invite code: $inviteCode',
      subject: 'KwayaPro — Choir Invite Code',
    );
  }

  Future<void> _save(String choirId) async {
    final name = _nameController.text.trim();
    final churchName = _churchNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choir name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final scaffold = ScaffoldMessenger.of(context);
    try {
      await ref.read(choirRepositoryProvider).updateChoir(choirId, {
        'name': name,
        'churchName': churchName,
      });
      if (mounted) scaffold.showSnackBar(const SnackBar(content: Text('Choir profile updated')));
    } catch (e) {
      if (mounted) scaffold.showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
