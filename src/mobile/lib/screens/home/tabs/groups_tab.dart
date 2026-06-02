import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/providers/groups_provider.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/models/group_model.dart';
import 'package:mobile/screens/group_detail_screen.dart';

class GroupsTab extends ConsumerWidget {
  const GroupsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final groupsState = ref.watch(groupsProvider);
    final currentUserId = ref.watch(authProvider).auth?.user.id;

    return RefreshIndicator(
      onRefresh: () => ref.read(groupsProvider.notifier).loadGroups(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Groups', style: Theme.of(context).textTheme.titleLarge),
              ElevatedButton.icon(
                onPressed: () => _showCreateGroupDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (groupsState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (groupsState.error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: cs.error),
                  const SizedBox(height: 16),
                  Text('Error: ${groupsState.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(groupsProvider.notifier).loadGroups();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (groupsState.groups.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 48,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  const Text('No groups yet'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateGroupDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Group'),
                  ),
                ],
              ),
            )
          else
            ...groupsState.groups.map((group) {
              final bool isOwner = group.members.any(
                (m) => m.userId == currentUserId && m.isOwner == true,
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.group),
                  title: Text(group.name),
                  subtitle: Text('${group.members.length} members'),
                  trailing: PopupMenuButton<String>(
                    itemBuilder: (context) => isOwner
                        ? [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Rename'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ]
                        : [
                            PopupMenuItem(
                              value: 'leave',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.exit_to_app,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.tertiary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Leave Group',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.tertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditGroupDialog(context, ref, group);
                      } else if (value == 'delete') {
                        _showDeleteGroupDialog(
                          context,
                          ref,
                          group.id,
                          group.name,
                        );
                      } else if (value == 'leave') {
                        _showLeaveGroupDialog(
                          context,
                          ref,
                          group.id,
                          group.name,
                        );
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            GroupDetailScreen(groupId: group.id),
                      ),
                    ).then((_) {
                      ref.read(groupsProvider.notifier).loadGroups();
                    });
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showLeaveGroupDialog(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    String groupName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave "$groupName"?'),
        content: const Text(
          'You will lose access to this group and all its shared wallets.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              foregroundColor: Theme.of(context).colorScheme.onTertiary,
            ),
            onPressed: () async {
              final success = await ref
                  .read(groupsProvider.notifier)
                  .leaveGroup(groupId);

              if (!context.mounted) return;
              Navigator.pop(context);
              final cs = Theme.of(context).colorScheme;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('You left the group'),
                    backgroundColor: cs.primary,
                  ),
                );
              } else {
                final error = ref.read(groupsProvider).error;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? 'Could not leave group'),
                    backgroundColor: cs.error,
                  ),
                );
              }
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Group'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Group name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final success = await ref
                  .read(groupsProvider.notifier)
                  .createGroup(name: name);
              if (!context.mounted) return;
              Navigator.pop(context);
              final cs = Theme.of(context).colorScheme;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Group created'),
                    backgroundColor: cs.primary,
                  ),
                );
              } else {
                final error = ref.read(groupsProvider).error;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? 'Could not create group'),
                    backgroundColor: cs.error,
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditGroupDialog(
    BuildContext context,
    WidgetRef ref,
    GroupModel group,
  ) {
    final nameController = TextEditingController(text: group.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Group name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final success = await ref
                  .read(groupsProvider.notifier)
                  .updateGroup(groupId: group.id, name: name);
              if (!context.mounted) return;
              Navigator.pop(context);
              final cs = Theme.of(context).colorScheme;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Group renamed'),
                    backgroundColor: cs.primary,
                  ),
                );
              } else {
                final error = ref.read(groupsProvider).error;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? 'Could not rename group'),
                    backgroundColor: cs.error,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteGroupDialog(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    String groupName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$groupName"?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              final success = await ref
                  .read(groupsProvider.notifier)
                  .deleteGroup(groupId);
              if (!context.mounted) return;
              Navigator.pop(context);
              final cs = Theme.of(context).colorScheme;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Group deleted'),
                    backgroundColor: cs.primary,
                  ),
                );
              } else {
                final error = ref.read(groupsProvider).error;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? 'Could not delete group'),
                    backgroundColor: cs.error,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
