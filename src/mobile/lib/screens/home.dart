import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/providers/user_provider.dart';
import 'package:mobile/providers/accounts_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final accountsState = ref.watch(accountsProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartFinance'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: userState.user != null
                ? Tooltip(
                    message: userState.user!.email,
                    child: Center(
                      child: Text(
                        userState.user!.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  )
                : const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                },
                child: const Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Выход'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(accountsState),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Categories',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Groups'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildBody(AccountsState accountsState) {
    switch (_selectedIndex) {
      case 0:
        return _buildAccountsTab(accountsState);
      case 1:
        return _buildCategoriesTab();
      case 2:
        return _buildGroupsTab();
      case 3:
        return _buildProfileTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildAccountsTab(AccountsState accountsState) {
    if (accountsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (accountsState.error != null) {
      return Center(
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
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(accountsProvider.notifier).loadAccounts(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Заголовок
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Wallets',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _showCreateAccountDialog();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Список кошельков
          if (accountsState.accounts.isEmpty)
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
                      _showCreateAccountDialog();
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
                          _showDeleteAccountDialog(account.id);
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
                  onTap: () {},
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return const Center(child: Text('Categories (soon)'));
  }

  Widget _buildGroupsTab() {
    return const Center(child: Text('Groups (soon)'));
  }

  Widget _buildProfileTab() {
    final userState = ref.watch(userProvider);

    if (userState.user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person, size: 64),
          const SizedBox(height: 16),
          Text(
            userState.user!.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            userState.user!.email,
            style: const TextStyle(color: Colors.grey),
          ),
          if (userState.user!.birthday != null) ...[
            const SizedBox(height: 8),
            Text(
              'Дата рождения: ${userState.user!.birthday?.toLocal().toString().split(' ')[0]}',
            ),
          ],
        ],
      ),
    );
  }

  void _showCreateAccountDialog() {
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
              if (!mounted) return;
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

  void _showDeleteAccountDialog(String accountId) {
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
              if (!mounted) return;
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
