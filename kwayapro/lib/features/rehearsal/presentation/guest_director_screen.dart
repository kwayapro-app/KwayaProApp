import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/rehearsal_providers.dart';
import '../domain/models/rehearsal_session.dart';

class GuestDirectorScreen extends ConsumerStatefulWidget {
  final String sessionId;
  
  const GuestDirectorScreen({super.key, required this.sessionId});

  @override
  ConsumerState<GuestDirectorScreen> createState() => _GuestDirectorScreenState();
}

class _GuestDirectorScreenState extends ConsumerState<GuestDirectorScreen> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upcoming = ref.watch(upcomingRehearsalsProvider);
    
    // Find the specific session
    final session = upcoming.whenOrNull(
      data: (sessions) {
        try {
          return sessions.firstWhere((s) => s.sessionId == widget.sessionId);
        } catch (_) {
          return null;
        }
      },
    );

    final hasExistingToken = session?.guestToken != null;
    final isTokenValid = session?.guestTokenExpiry != null && 
        session!.guestTokenExpiry!.isAfter(DateTime.now());

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Guest Director'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero section
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.link,
                    size: 40,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Center(
                child: Text(
                  'Invite a Guest Director',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Generate a one-time invite link for someone to temporarily serve as director for this rehearsal.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Permissions card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What they can access:',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    const _PermissionRow(icon: Icons.people, label: 'Full member list and voice parts'),
                    const _PermissionRow(icon: Icons.library_music, label: 'Complete audio library'),
                    const _PermissionRow(icon: Icons.checklist, label: 'Mark attendance'),
                    const _PermissionRow(icon: Icons.mic, label: 'Upload voice part audio'),
                    const SizedBox(height: 12),
                    Text(
                      'What they cannot access:',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    const _PermissionRow(icon: Icons.lock_outline, label: 'Choir admin settings', isDenied: true),
                    const _PermissionRow(icon: Icons.person_remove, label: 'Member management', isDenied: true),
                    const _PermissionRow(icon: Icons.credit_card, label: 'Billing & payments', isDenied: true),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Expiry info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasExistingToken && isTokenValid
                            ? 'Active link expires at ${_formatTime(session.guestTokenExpiry!)}'
                            : 'Link auto-expires when rehearsal ends',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Action button
              if (hasExistingToken && isTokenValid) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isGenerating ? null : _revokeToken,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Revoke'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isGenerating ? null : () => _shareLink(session),
                        icon: const Icon(Icons.share),
                        label: const Text('Share Again'),
                      ),
                    ),
                  ],
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isGenerating ? null : () => _generateAndShare(),
                    icon: _isGenerating 
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: Text(_isGenerating ? 'Generating...' : 'Generate Invite Link'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _generateAndShare() async {
    setState(() => _isGenerating = true);
    
    try {
      final token = await ref.read(rehearsalRepositoryProvider).generateGuestToken(widget.sessionId);
      // Phase 6 Fix 2: this previously pointed at a Firebase Dynamic Links
      // (*.page.link) URL — that product was shut down 2025-08-25 (all
      // *.page.link links have returned HTTP 404 since), so every invite
      // generated via this screen has been dead on arrival regardless of
      // any App Links configuration. Switched to the app's own Android App
      // Links domain (kwayapro.app, declared in AndroidManifest.xml and
      // matching app_router.dart's /rehearsal-invite/:token route), which
      // is what should have been used from the start rather than a
      // separate third-party-style link shortener.
      final link = 'https://kwayapro.app/rehearsal-invite/$token';
      
      await Share.share(
        'You\'ve been invited as Guest Director for this rehearsal.\n\nTap to join: $link',
        subject: 'KwayaPro — Guest Director Invite',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate link: $e')),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _shareLink(RehearsalSession session) async {
    final token = session.guestToken;
    if (token == null) return;

    // See _generateAndShare above — kwayapro.page.link (Firebase Dynamic
    // Links) has been dead since 2025-08-25; using the app's real App
    // Links domain instead.
    final link = 'https://kwayapro.app/rehearsal-invite/$token';
    
    await Share.share(
      'You\'ve been invited as Guest Director for this rehearsal.\n\nTap to join: $link',
      subject: 'KwayaPro — Guest Director Invite',
    );
  }

  void _revokeToken() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Invite Link?'),
        content: const Text('Anyone with this link will no longer be able to join as guest director.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(rehearsalRepositoryProvider).revokeGuestToken(widget.sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite link revoked')),
        );
      }
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDenied;

  const _PermissionRow({
    required this.icon,
    required this.label,
    this.isDenied = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isDenied ? Icons.close : Icons.check,
            size: 18,
            color: isDenied ? theme.colorScheme.outline : theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDenied ? theme.colorScheme.outline : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}