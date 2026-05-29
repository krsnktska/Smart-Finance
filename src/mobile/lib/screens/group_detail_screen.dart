import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/models/account_model.dart';
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

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadGroupAccounts();
      ref.read(accountsProvider.notifier).loadAccounts();
    });
  }

  Future<void> _loadGroupAccounts() async {
    setState(() {
      _isLoadingAccounts = true;
    });
    final accounts = await ref.read(groupsProvider.notifier).getGroupAccounts(widget.groupId);
    if (mounted) {
      setState(() {
        _groupAccounts = accounts;
        _isLoadingAccounts = false;
      });
    }
  }

  Future<void> _addMember() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter User ID',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = controller.text.trim();
              if (userId.isEmpty) return;
              
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              navigator.pop();
              
              final success = await ref
                  .read(groupsProvider.notifier)
                  .addMember(groupId: widget.groupId, userId: userId);
              
              if (success) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Member added successfully!'), backgroundColor: Colors.green),
                );
                // Reload group data
                ref.read(groupsProvider.notifier).loadGroups();
              } else {
                final error = ref.read(groupsProvider).error;
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text(error ?? 'Failed to add member'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(String userId, String userName) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove member "$userName"?'),
        content: const Text('Are you sure you want to remove this member from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
          const SnackBar(content: Text('Member removed'), backgroundColor: Colors.green),
        );
        ref.read(groupsProvider.notifier).loadGroups();
      } else {
        final error = ref.read(groupsProvider).error;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(error ?? 'Failed to remove member'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _linkAccount() async {
    final accountsState = ref.read(accountsProvider);
    // Filter out accounts that are already linked
    final availableAccounts = accountsState.accounts.where(
      (acc) => !_groupAccounts.any((ga) => ga.id == acc.id),
    ).toList();

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
            onChanged: (val) {
              setState(() {
                selectedAccount = val;
              });
            },
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
                navigator.pop();
                
                final success = await ref
                    .read(groupsProvider.notifier)
                    .addAccount(groupId: widget.groupId, accountId: selectedAccount!.id);

                if (success) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Wallet linked successfully!'), backgroundColor: Colors.green),
                  );
                  _loadGroupAccounts();
                } else {
                  final error = ref.read(groupsProvider).error;
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text(error ?? 'Failed to link wallet'), backgroundColor: Colors.red),
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
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unlink wallet "$accountName"?'),
        content: const Text('This wallet will no longer be visible to other group members.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
          const SnackBar(content: Text('Wallet unlinked'), backgroundColor: Colors.green),
        );
        _loadGroupAccounts();
      } else {
        final error = ref.read(groupsProvider).error;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(error ?? 'Failed to unlink wallet'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsState = ref.watch(groupsProvider);
    final userState = ref.watch(userProvider);
    
    // Find this group in the state list
    final groupIndex = groupsState.groups.indexWhere((g) => g.id == widget.groupId);
    if (groupIndex == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Details')),
        body: const Center(child: Text('Group not found')),
      );
    }
    
    final group = groupsState.groups[groupIndex];
    final currentUser = userState.user;
    
    // Check if current user is owner of the group
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
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section: Members
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members (${group.members.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (isCurrentUserOwner)
                ElevatedButton.icon(
                  onPressed: _addMember,
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Add'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    backgroundColor: member.isOwner ? Colors.amber[100] : Colors.blue[50],
                    child: Icon(
                      member.isOwner ? Icons.star : Icons.person,
                      color: member.isOwner ? Colors.amber[800] : Colors.blue,
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('You', style: TextStyle(fontSize: 10)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(member.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (member.isOwner)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber[200]!),
                          ),
                          child: const Text(
                            'Owner',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isCurrentUserOwner && !member.isOwner)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _removeMember(member.userId, member.name),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Section: Shared Wallets
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
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
          else if (_groupAccounts.isEmpty)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(Icons.link_off, size: 36, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'No wallets linked to this group yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _groupAccounts.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final account = _groupAccounts[index];
                  return ListTile(
                    leading: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                    title: Text(
                      account.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Currency: ${account.currency}'),
                    trailing: isCurrentUserOwner
                        ? IconButton(
                            icon: const Icon(Icons.link_off, color: Colors.red),
                            onPressed: () => _unlinkAccount(account.id, account.name),
                          )
                        : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
