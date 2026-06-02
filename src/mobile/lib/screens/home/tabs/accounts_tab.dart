import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/models/account_model.dart';
import 'package:mobile/providers/accounts_provider.dart';
import 'package:mobile/screens/account_detail_screen.dart';
import 'package:mobile/utils/currency_utils.dart';
import 'package:mobile/utils/currency_utils.dart';

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
                  Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
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
            ..._buildAccountSections(context, ref, accountsState.accounts),
        ],
      ),
    );
  }

  List<Widget> _buildAccountSections(
    BuildContext context,
    WidgetRef ref,
    List<AccountModel> allAccounts,
  ) {
    // Separate personal and group accounts
    final personalAccounts = allAccounts
        .where((acc) => acc.groupId == null)
        .toList();
    final groupAccounts = allAccounts
        .where((acc) => acc.groupId != null)
        .toList();

    // Group accounts by group
    final groupedAccounts = <String, List<AccountModel>>{};
    for (final acc in groupAccounts) {
      final groupId = acc.groupId!;
      groupedAccounts.putIfAbsent(groupId, () => []).add(acc);
    }

    final sections = <Widget>[];

    // Add personal wallets section
    if (personalAccounts.isNotEmpty) {
      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'My Wallets',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );
      sections.addAll(
        personalAccounts.map((account) {
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
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        const Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AccountDetailScreen(account: account),
                  ),
                ).then((_) {
                  ref.read(accountsProvider.notifier).loadAccounts();
                });
              },
            ),
          );
        }),
      );
    }

    // Add group wallets sections
    groupedAccounts.forEach((groupId, accounts) {
      if (accounts.isNotEmpty) {
        final groupName = accounts.first.groupName ?? 'Unknown Group';

        // Add group header
        sections.add(
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            child: Row(
              children: [
                Icon(
                  Icons.groups,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    groupName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        // Add group accounts
        sections.addAll(
          accounts.map((account) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                title: Text(account.name),
                subtitle: Text(account.currency),
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
          }),
        );
      }
    });

    return sections;
  }

  void _showCreateAccountDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String selectedCurrency = 'USD';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Wallet'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
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
                InkWell(
                  onTap: () async {
                    final currency = await _showCurrencySelectionDialog(
                      context,
                      selectedCurrency,
                    );
                    if (currency != null) {
                      setState(() {
                        selectedCurrency = currency;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$selectedCurrency · ${CurrencyUtils.displayName(selectedCurrency)}',
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
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
                    currency: selectedCurrency,
                  );
              if (!context.mounted) return;
              Navigator.pop(context);
              final cs = Theme.of(context).colorScheme;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Wallet created!'),
                    backgroundColor: cs.primary,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Error creating wallet'),
                    backgroundColor: cs.error,
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              final success = await ref
                  .read(accountsProvider.notifier)
                  .deleteAccount(accountId);
              if (!context.mounted) return;
              Navigator.pop(context);
              final cs = Theme.of(context).colorScheme;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Wallet deleted!'),
                    backgroundColor: cs.primary,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Error deleting wallet'),
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

  Future<String?> _showCurrencySelectionDialog(
    BuildContext context,
    String selectedCurrency,
  ) async {
    final queryController = TextEditingController();
    var filteredCurrencies = CurrencyUtils.supportedCurrencies;

    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Currency'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: queryController,
                    decoration: const InputDecoration(
                      hintText: 'Search currency',
                    ),
                    onChanged: (value) {
                      setState(() {
                        filteredCurrencies = CurrencyUtils.filter(value);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.maxFinite,
                    height: 260,
                    child: ListView.builder(
                      itemCount: filteredCurrencies.length,
                      itemBuilder: (context, index) {
                        final code = filteredCurrencies[index];
                        return ListTile(
                          title: Text(
                            '$code · ${CurrencyUtils.displayName(code)}',
                          ),
                          onTap: () => Navigator.of(context).pop(code),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
