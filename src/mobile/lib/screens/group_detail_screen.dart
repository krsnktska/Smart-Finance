import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/models/account_model.dart';
import 'package:mobile/models/group_member_model.dart';
import 'package:mobile/models/user_model.dart';
import 'package:mobile/providers/accounts_provider.dart';
import 'package:mobile/providers/groups_provider.dart';
import 'package:mobile/providers/user_provider.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  List<AccountModel> _groupAccounts = [];
  bool _isLoadingAccounts = false;

  List<dynamic> _pendingInvitations = [];
  bool _isLoadingInvitations = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadGroupAccounts();
      _loadGroupInvitations();
      ref.read(accountsProvider.notifier).loadAccounts();
    });
  }

  Future<void> _loadGroupAccounts() async {
    setState(() => _isLoadingAccounts = true);
    final accounts = await ref
        .read(groupsProvider.notifier)
        .getGroupAccounts(widget.groupId);
    if (mounted) {
      setState(() {
        _groupAccounts = accounts;
        _isLoadingAccounts = false;
      });
    }
  }

  Future<void> _loadGroupInvitations() async {
    setState(() => _isLoadingInvitations = true);
    try {
      final invitations = await ref
          .read(groupsProvider.notifier)
          .getGroupInvitations(widget.groupId);
      if (mounted) {
        setState(() {
          _pendingInvitations = invitations.where((invite) {
            return invite['status'] == 'Pending';
          }).toList();
        });
      }
    } catch (e) {
      if (mounted && kDebugMode) print('Failed to load group invitations: $e');
    } finally {
      if (mounted) setState(() => _isLoadingInvitations = false);
    }
  }

  Future<void> _addMember() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        UserModel? foundUser;
        bool isSearching = false;
        String? searchError;

        return StatefulBuilder(
          builder: (context, setState) {
            final cs = Theme.of(context).colorScheme;

            Future<void> doSearch() async {
              final email = controller.text.trim();
              if (email.isEmpty) return;
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(email)) {
                setState(() => searchError = 'Enter a valid email address');
                return;
              }
              setState(() {
                isSearching = true;
                searchError = null;
                foundUser = null;
              });
              final user = await ref
                  .read(userRepositoryProvider)
                  .searchByEmail(email);
              setState(() {
                isSearching = false;
                foundUser = user;
                if (user == null) searchError = 'No user found with this email';
              });
            }

            return AlertDialog(
              title: const Text('Invite Member'),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.emailAddress,
                          onSubmitted: (_) => doSearch(),
                          decoration: InputDecoration(
                            hintText: 'User email',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.email_outlined),
                            errorText: searchError,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: isSearching ? null : doSearch,
                        icon: isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search),
                      ),
                    ],
                  ),
                  if (foundUser != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: cs.primaryContainer,
                            child: Text(
                              foundUser!.name.isNotEmpty
                                  ? foundUser!.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  foundUser!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  foundUser!.email,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.check_circle, color: cs.primary, size: 20),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: foundUser == null
                      ? null
                      : () async {
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          final csLocal = Theme.of(context).colorScheme;
                          Navigator.pop(context);

                          final success = await ref
                              .read(groupsProvider.notifier)
                              .inviteMemberByEmail(
                                groupId: widget.groupId,
                                email: foundUser!.email,
                              );

                          if (success) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Invitation sent to ${foundUser!.name}!',
                                ),
                                backgroundColor: csLocal.primary,
                              ),
                            );
                            _loadGroupInvitations();
                          } else {
                            final error = ref.read(groupsProvider).error;
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  error ?? 'Failed to send invitation',
                                ),
                                backgroundColor: csLocal.error,
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Send Invite'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editPermissions(
    String userId,
    String userName,
    GroupMemberModel member,
  ) async {
    bool canView = member.canView;
    bool canWrite = member.canWrite;
    final cs = Theme.of(context).colorScheme;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Permissions: $userName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: canView,
                onChanged: (v) => setState(() => canView = v),
                title: const Text('Can view wallet'),
                subtitle: const Text('See transactions and balance'),
                secondary: Icon(Icons.visibility_outlined, color: cs.primary),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: canWrite,
                onChanged: canView ? (v) => setState(() => canWrite = v) : null,
                title: const Text('Can write'),
                subtitle: const Text('Add and edit transactions'),
                secondary: Icon(Icons.edit_outlined, color: cs.secondary),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final success = await ref
        .read(groupsProvider.notifier)
        .updateMemberRole(
          groupId: widget.groupId,
          userId: userId,
          isOwner: member.isOwner,
          canView: canView,
          canWrite: canWrite,
        );

    if (success) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Permissions updated for $userName'),
          backgroundColor: cs.primary,
        ),
      );
      ref.read(groupsProvider.notifier).loadGroups();
    } else {
      final error = ref.read(groupsProvider).error;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to update permissions'),
          backgroundColor: cs.error,
        ),
      );
    }
  }

  Future<void> _updateRole(String userId, String userName, bool promote) async {
    final cs = Theme.of(context).colorScheme;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(promote ? 'Promote "$userName"?' : 'Demote "$userName"?'),
        content: Text(
          promote
              ? '$userName will become an owner and get full management access.'
              : '$userName will become a regular member.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(promote ? 'Promote' : 'Demote'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await ref
        .read(groupsProvider.notifier)
        .updateMemberRole(
          groupId: widget.groupId,
          userId: userId,
          isOwner: promote,
        );

    if (success) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            promote
                ? '$userName is now an owner.'
                : '$userName is now a member.',
          ),
          backgroundColor: cs.primary,
        ),
      );
      ref.read(groupsProvider.notifier).loadGroups();
    } else {
      final error = ref.read(groupsProvider).error;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to update role.'),
          backgroundColor: cs.error,
        ),
      );
    }
  }

  Future<void> _removeMember(String userId, String userName) async {
    final cs = Theme.of(context).colorScheme;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove member "$userName"?'),
        content: const Text(
          'Are you sure you want to remove this member from the group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref
          .read(groupsProvider.notifier)
          .removeMember(groupId: widget.groupId, userId: userId);

      if (success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Member removed'),
            backgroundColor: cs.primary,
          ),
        );
        ref.read(groupsProvider.notifier).loadGroups();
      } else {
        final error = ref.read(groupsProvider).error;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to remove member'),
            backgroundColor: cs.error,
          ),
        );
      }
    }
  }

  Future<void> _linkAccount() async {
    final accountsState = ref.read(accountsProvider);
    final availableAccounts = accountsState.accounts
        .where((acc) => !_groupAccounts.any((ga) => ga.id == acc.id))
        .toList();

    if (availableAccounts.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No wallets available'),
          content: const Text(
            'All of your wallets are already linked to this group or you do not have any wallets. Please create a new wallet first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    AccountModel? selectedAccount = availableAccounts.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Link Wallet to Group'),
          content: DropdownButtonFormField<AccountModel>(
            initialValue: selectedAccount,
            decoration: const InputDecoration(
              labelText: 'Select Wallet',
              border: OutlineInputBorder(),
            ),
            items: availableAccounts.map((acc) {
              return DropdownMenuItem<AccountModel>(
                value: acc,
                child: Text('${acc.name} (${acc.currency})'),
              );
            }).toList(),
            onChanged: (val) => setState(() => selectedAccount = val),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedAccount == null) return;
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final cs = Theme.of(context).colorScheme;
                navigator.pop();

                final success = await ref
                    .read(groupsProvider.notifier)
                    .addAccount(
                      groupId: widget.groupId,
                      accountId: selectedAccount!.id,
                    );

                if (success) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: const Text('Wallet linked successfully!'),
                      backgroundColor: cs.primary,
                    ),
                  );
                  _loadGroupAccounts();
                } else {
                  final error = ref.read(groupsProvider).error;
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(error ?? 'Failed to link wallet'),
                      backgroundColor: cs.error,
                    ),
                  );
                }
              },
              child: const Text('Link'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlinkAccount(String accountId, String accountName) async {
    final cs = Theme.of(context).colorScheme;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unlink wallet "$accountName"?'),
        content: const Text(
          'This wallet will no longer be visible to other group members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref
          .read(groupsProvider.notifier)
          .removeAccount(groupId: widget.groupId, accountId: accountId);

      if (success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Wallet unlinked'),
            backgroundColor: cs.primary,
          ),
        );
        _loadGroupAccounts();
      } else {
        final error = ref.read(groupsProvider).error;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to unlink wallet'),
            backgroundColor: cs.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final groupsState = ref.watch(groupsProvider);
    final userState = ref.watch(userProvider);

    final groupIndex = groupsState.groups.indexWhere(
      (g) => g.id == widget.groupId,
    );
    if (groupIndex == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Details')),
        body: const Center(child: Text('Group not found')),
      );
    }

    final group = groupsState.groups[groupIndex];
    final currentUser = userState.user;
    final isCurrentUserOwner = group.members.any(
      (m) => m.userId == currentUser?.id && m.isOwner,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(groupsProvider.notifier).loadGroups();
              _loadGroupAccounts();
              _loadGroupInvitations();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members (${group.members.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isCurrentUserOwner)
                ElevatedButton.icon(
                  onPressed: _addMember,
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Invite'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: group.members.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = group.members[index];
                final isMe = member.userId == currentUser?.id;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: member.isOwner
                        ? cs.tertiary.withValues(alpha: 0.2)
                        : cs.secondary.withValues(alpha: 0.2),
                    child: Icon(
                      member.isOwner ? Icons.star : Icons.person,
                      color: member.isOwner ? cs.tertiary : cs.secondary,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(member.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!member.isOwner) ...[
                        Tooltip(
                          message: member.canView ? 'Can view' : 'No view',
                          child: Icon(
                            member.canView
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 16,
                            color: member.canView
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: member.canWrite ? 'Can write' : 'Read only',
                          child: Icon(
                            member.canWrite ? Icons.edit : Icons.edit_off,
                            size: 16,
                            color: member.canWrite
                                ? cs.secondary
                                : cs.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: member.isOwner
                              ? cs.tertiary.withValues(alpha: 0.12)
                              : cs.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: member.isOwner
                                ? cs.tertiary.withValues(alpha: 0.4)
                                : cs.secondary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          member.isOwner ? 'Owner' : 'Member',
                          style: TextStyle(
                            color: member.isOwner ? cs.tertiary : cs.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isCurrentUserOwner &&
                          member.userId != currentUser?.id)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (val) {
                            if (val == 'promote') {
                              _updateRole(member.userId, member.name, true);
                            } else if (val == 'demote') {
                              _updateRole(member.userId, member.name, false);
                            } else if (val == 'permissions') {
                              _editPermissions(
                                member.userId,
                                member.name,
                                member,
                              );
                            } else if (val == 'remove') {
                              _removeMember(member.userId, member.name);
                            }
                          },
                          itemBuilder: (context) => [
                            if (!member.isOwner)
                              PopupMenuItem(
                                value: 'promote',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 18,
                                      color: cs.tertiary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Promote to Owner'),
                                  ],
                                ),
                              ),
                            if (member.isOwner)
                              PopupMenuItem(
                                value: 'demote',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 18,
                                      color: cs.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Demote to Member'),
                                  ],
                                ),
                              ),
                            if (!member.isOwner) ...[
                              PopupMenuItem(
                                value: 'permissions',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.tune,
                                      size: 18,
                                      color: cs.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Edit Permissions'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: cs.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Remove',
                                      style: TextStyle(color: cs.error),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          if (isCurrentUserOwner &&
              (_isLoadingInvitations || _pendingInvitations.isNotEmpty)) ...[
            const SizedBox(height: 24),
            const Text(
              'Pending Invitations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_isLoadingInvitations && _pendingInvitations.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pendingInvitations.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final invite = _pendingInvitations[index];
                    final email = invite['invitedUserEmail'] ?? 'Unknown Email';
                    final invitationId = invite['id'] ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.tertiary.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.hourglass_top_rounded,
                          color: cs.tertiary,
                        ),
                      ),
                      title: Text(
                        email,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Waiting for response...'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.tertiary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: cs.tertiary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              'Pending',
                              style: TextStyle(
                                color: cs.tertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          PopupMenuButton(
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.close,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Cancel Invitation'),
                                  ],
                                ),
                                onTap: () async {
                                  final scaffoldMessenger =
                                      ScaffoldMessenger.of(context);
                                  final cs = Theme.of(context).colorScheme;
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Cancel Invitation?'),
                                      content: Text(
                                        'Are you sure you want to cancel the invitation to $email?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('No'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                            foregroundColor: Theme.of(
                                              context,
                                            ).colorScheme.onError,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Yes, Cancel'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    final success = await ref
                                        .read(groupsProvider.notifier)
                                        .cancelInvitation(
                                          groupId: widget.groupId,
                                          invitationId: invitationId,
                                        );

                                    if (success) {
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Invitation cancelled',
                                          ),
                                          backgroundColor: cs.primary,
                                        ),
                                      );
                                      _loadGroupInvitations();
                                    } else {
                                      final error = ref
                                          .read(groupsProvider)
                                          .error;
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            error ??
                                                'Failed to cancel invitation',
                                          ),
                                          backgroundColor: cs.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Linked Wallets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (isCurrentUserOwner)
                ElevatedButton.icon(
                  onPressed: _linkAccount,
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Link Wallet'),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingAccounts)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_groupAccounts.isEmpty)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.link_off,
                      size: 36,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No wallets linked to this group yet.',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _groupAccounts.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final account = _groupAccounts[index];
                  return AppAccountListTile(
                    account: account,
                    isCurrentUserOwner: isCurrentUserOwner,
                    onUnlink: () => _unlinkAccount(account.id, account.name),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class AppAccountListTile extends StatelessWidget {
  final AccountModel account;
  final bool isCurrentUserOwner;
  final VoidCallback onUnlink;

  const AppAccountListTile({
    super.key,
    required this.account,
    required this.isCurrentUserOwner,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.account_balance_wallet, color: cs.secondary),
      title: Text(
        account.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('Currency: ${account.currency}'),
      trailing: isCurrentUserOwner
          ? IconButton(
              icon: Icon(Icons.link_off, color: cs.error),
              onPressed: onUnlink,
            )
          : null,
    );
  }
}
