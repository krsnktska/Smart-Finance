import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/providers/accounts_provider.dart';
import 'package:mobile/screens/account_detail_screen.dart';

class AccountsTab extends ConsumerWidget {
  const AccountsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsState = ref.watch(accountsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(accountsProvider.notifier).loadAccounts(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Wallets', style: Theme.of(context).textTheme.titleLarge),
              ElevatedButton.icon(
                onPressed: () {
                  _showCreateAccountDialog(context, ref);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (accountsState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (accountsState.error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${accountsState.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(accountsProvider.notifier).loadAccounts();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (accountsState.accounts.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.wallet_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text('No wallets available'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showCreateAccountDialog(context, ref);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Wallet'),
                  ),
                ],
              ),
            )
          else
            ...accountsState.accounts.map((account) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    Icons.account_balance_wallet,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(account.name),
                  subtitle: Text(account.currency),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        onTap: () {
                          _showDeleteAccountDialog(
                            context,
                            ref,
                            account.id,
                            account.name,
                          );
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AccountDetailScreen(account: account),
                      ),
                    ).then((_) {
                      ref.read(accountsProvider.notifier).loadAccounts();
                    });
                  },
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  void _showCreateAccountDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final currencyController = TextEditingController(text: 'USD');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: currencyController,
              decoration: InputDecoration(
                hintText: 'Currency (USD, EUR, UAH...)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await ref
                  .read(accountsProvider.notifier)
                  .createAccount(
                    name: nameController.text,
                    currency: currencyController.text,
                  );
              if (!context.mounted) return;
              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Wallet created !'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error creating wallet'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Create '),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    WidgetRef ref,
    String accountId,
    String accountName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wallet?'),
        content: const Text(
          'This action cannot be undone. All transactions in this wallet will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await ref
                  .read(accountsProvider.notifier)
                  .deleteAccount(accountId);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Wallet deleted !'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error deleting wallet'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
