import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/providers/invitations_provider.dart';

class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final invitationsState = ref.watch(invitationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Group Invitations'), centerTitle: true),
      body: invitationsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Failed to load invitations: $error',
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (invitations) {
          if (invitations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mail_lock_outlined,
                    size: 64,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending invitations',
                    style: TextStyle(
                      fontSize: 18,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(invitationsProvider.notifier).fetchInvitations(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: invitations.length,
              itemBuilder: (context, index) {
                final invite = invitations[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              child: Icon(
                                Icons.group,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invite.groupName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Invited by ${invite.invitedByUserName}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                final success = await ref
                                    .read(invitationsProvider.notifier)
                                    .declineInvite(invite.id);
                                if (context.mounted && !success) {
                                  _showErrorSnackBar(context);
                                }
                              },
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Decline'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.error,
                                side: BorderSide(color: cs.error),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final success = await ref
                                    .read(invitationsProvider.notifier)
                                    .acceptInvite(invite.id);
                                if (context.mounted) {
                                  if (success) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Successfully joined the group!',
                                        ),
                                        backgroundColor: cs.primary,
                                      ),
                                    );
                                  } else {
                                    _showErrorSnackBar(context);
                                  }
                                }
                              },
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Accept'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Something went wrong. Please try again.'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
