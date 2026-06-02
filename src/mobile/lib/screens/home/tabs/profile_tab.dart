import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/models/account_model.dart';
import 'package:mobile/models/bank_integration_model.dart';
import 'package:mobile/models/monobank_account_model.dart';
import 'package:mobile/providers/accounts_provider.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/providers/bank_integration_provider.dart';
import 'package:mobile/providers/gmail_provider.dart';
import 'package:mobile/providers/invitations_provider.dart';
import 'package:mobile/providers/user_provider.dart';
import 'package:mobile/screens/invitations.dart';
import 'package:mobile/widgets/app_buttons.dart';
import 'package:mobile/widgets/app_text_field.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'Profile'),
              Tab(text: 'Integrations'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _ProfileSubTab(),
                _IntegrationsSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Profile sub-tab ──────────────────────────────────────────────────────────

class _ProfileSubTab extends ConsumerWidget {
  const _ProfileSubTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final invitationsAsync = ref.watch(invitationsProvider);

    if (userState.user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = userState.user!;

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 32),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Edit Profile Details'),
                      subtitle: const Text('Change name or birthday'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showEditProfileDialog(context, ref),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Change Password'),
                      subtitle: const Text('Secure your account'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showChangePasswordDialog(context, ref),
                    ),
                    if (user.birthday != null) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.cake_outlined),
                        title: const Text('Birthday'),
                        subtitle: Text(
                          '${user.birthday!.day.toString().padLeft(2, '0')}.${user.birthday!.month.toString().padLeft(2, '0')}.${user.birthday!.year}',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Pending Invitations'),
                subtitle: const Text('Accept or decline group invites'),
                trailing: invitationsAsync.maybeWhen(
                  data: (invitations) => invitations.isNotEmpty
                      ? Badge(
                          label: Text('${invitations.length}'),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                        )
                      : const Icon(Icons.check_circle_outline),
                  orElse: () => const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              const Divider(height: 1),
              invitationsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Failed to load invitations: $error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                data: (invitations) {
                  if (invitations.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No pending invitations',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }
                  return Column(
                    children: invitations.map((invite) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
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
                                const SizedBox(height: 4),
                                Text(
                                  'Invited by ${invite.invitedByUserName}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () async {
                                        final success = await ref
                                            .read(invitationsProvider.notifier)
                                            .declineInvite(invite.id);
                                        if (!context.mounted) return;
                                        if (!success) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'Unable to decline invitation',
                                              ),
                                              backgroundColor: Theme.of(context).colorScheme.error,
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Decline'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final success = await ref
                                            .read(invitationsProvider.notifier)
                                            .acceptInvite(invite.id);
                                        if (!context.mounted) return;
                                        final cs = Theme.of(context).colorScheme;
                                        if (success) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'Accepted invitation',
                                              ),
                                              backgroundColor: cs.primary,
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'Unable to accept invitation',
                                              ),
                                              backgroundColor: cs.error,
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Accept'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Open full invitations list'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InvitationsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Theme.of(
            context,
          ).colorScheme.errorContainer.withValues(alpha: 0.2),
          elevation: 0,
          child: ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Sign Out',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ),
      ],
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(userProvider).user;
    if (user == null) return;

    final nameController = TextEditingController(text: user.name);
    DateTime? selectedBirthday = user.birthday;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Profile Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: nameController,
                labelText: 'Name',
                enabled: true,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Birthday'),
                subtitle: Text(
                  selectedBirthday == null
                      ? 'Not specified'
                      : '${selectedBirthday!.day.toString().padLeft(2, '0')}.${selectedBirthday!.month.toString().padLeft(2, '0')}.${selectedBirthday!.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedBirthday ?? DateTime(2000),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedBirthday = picked;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            AppButton(
              label: 'Save',
              isLoading: ref.watch(userProvider).isLoading,
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final success = await ref
                    .read(userProvider.notifier)
                    .updateUser(name: name, birthday: selectedBirthday);

                if (!context.mounted) return;

                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Profile updated!'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                } else {
                  final error = ref.read(userProvider).error;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? 'Failed to update profile'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: currentPasswordController,
                labelText: 'Current Password',
                obscureText: true,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: newPasswordController,
                labelText: 'New Password',
                obscureText: true,
                validator: (val) {
                  if (val == null || val.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: confirmPasswordController,
                labelText: 'Confirm New Password',
                obscureText: true,
                validator: (val) {
                  if (val != newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Change',
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final success = await ref
                  .read(userProvider.notifier)
                  .changePassword(
                    currentPassword: currentPasswordController.text,
                    newPassword: newPasswordController.text,
                  );

              if (!context.mounted) return;

              if (success) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Password changed successfully!'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              } else {
                final error = ref.read(userProvider).error;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? 'Failed to change password'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── Integrations sub-tab ─────────────────────────────────────────────────────

class _IntegrationsSubTab extends ConsumerStatefulWidget {
  const _IntegrationsSubTab();

  @override
  ConsumerState<_IntegrationsSubTab> createState() =>
      _IntegrationsSubTabState();
}

class _IntegrationsSubTabState extends ConsumerState<_IntegrationsSubTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(bankIntegrationsProvider.notifier).loadIntegrations();
      ref.read(gmailIntegrationProvider.notifier).loadStatus();
      if (ref.read(accountsProvider).accounts.isEmpty) {
        ref.read(accountsProvider.notifier).loadAccounts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bankState = ref.watch(bankIntegrationsProvider);
    final gmailState = ref.watch(gmailIntegrationProvider);
    final accountsState = ref.watch(accountsProvider);

    final personalAccounts =
        accountsState.accounts.where((a) => a.groupId == null).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMonobankSection(bankState, personalAccounts, accountsState.isLoading),
        const SizedBox(height: 16),
        _buildGmailSection(gmailState, personalAccounts),
      ],
    );
  }

  Widget _buildMonobankSection(
    BankIntegrationState bankState,
    List<AccountModel> personalAccounts,
    bool accountsLoading,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            leading: Icon(Icons.account_balance),
            title: Text(
              'Monobank',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Sync your bank transactions automatically'),
          ),
          const Divider(height: 1),
          if (bankState.isLoading || accountsLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (personalAccounts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Create a personal wallet first to connect Monobank.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            ...List.generate(personalAccounts.length, (index) {
              final account = personalAccounts[index];
              BankIntegrationModel? integration;
              try {
                integration = bankState.integrations.firstWhere(
                  (i) => i.accountId == account.id,
                );
              } catch (_) {
                integration = null;
              }

              return Column(
                children: [
                  ListTile(
                    title: Text('${account.name} · ${account.currency}'),
                    subtitle: integration != null
                        ? Text(
                            integration.lastSyncedAt != null
                                ? 'Connected · Last sync: ${_formatDate(integration.lastSyncedAt!)}'
                                : 'Connected · Never synced',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                          )
                        : Text(
                            'Not connected',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                          ),
                    trailing: integration != null
                        ? PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'sync') {
                                _syncMonobank(integration!.id);
                              } else if (val == 'disconnect') {
                                _confirmDisconnect(
                                  integration!.id,
                                  account.name,
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'sync',
                                enabled: !bankState.isSyncing,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.sync,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      bankState.isSyncing
                                          ? 'Syncing...'
                                          : 'Sync now',
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'disconnect',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.link_off,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Disconnect',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : OutlinedButton(
                            onPressed: () =>
                                _showMonobankConnectDialog(account),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                            child: const Text('Connect'),
                          ),
                  ),
                  if (index < personalAccounts.length - 1)
                    const Divider(height: 1),
                ],
              );
            }),
          if (bankState.message != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                bankState.message!,
                style: TextStyle(
                  color: bankState.message!.contains('No new')
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
          if (bankState.error != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                bankState.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGmailSection(
    GmailIntegrationState gmailState,
    List<AccountModel> personalAccounts,
  ) {
    final connected = gmailState.status != null;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.email_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Gmail Receipts',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (gmailState.isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Text(
                connected
                    ? 'Connected as ${gmailState.status!.email}'
                    : 'Connect Gmail to import electronic receipts from your inbox.',
              ),
              if (connected && gmailState.status!.lastScannedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Last scanned: ${_formatDate(gmailState.status!.lastScannedAt!)}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
              if (gmailState.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  gmailState.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (gmailState.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  gmailState.message!,
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          gmailState.isLoading || personalAccounts.isEmpty
                              ? null
                              : () => _connectGmail(personalAccounts),
                      child: Text(
                        connected ? 'Reconnect Gmail' : 'Connect Gmail',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: connected &&
                              !gmailState.isScanning &&
                              personalAccounts.isNotEmpty
                          ? () => _scanGmail(personalAccounts)
                          : null,
                      child: Text(
                        gmailState.isScanning ? 'Scanning...' : 'Scan Inbox',
                      ),
                    ),
                  ),
                ],
              ),
              if (personalAccounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Create a personal wallet first.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _syncMonobank(String integrationId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;
    final success = await ref
        .read(bankIntegrationsProvider.notifier)
        .syncMonobank(integrationId: integrationId);

    if (!mounted) return;
    if (success) {
      final message =
          ref.read(bankIntegrationsProvider).message ?? 'Monobank sync completed.';
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: cs.primary),
      );
    } else {
      final rawError = ref.read(bankIntegrationsProvider).error ?? '';
      final errorMsg = rawError.contains('429') || rawError.contains('Too Many')
          ? 'Monobank rate limit: wait 60 sec and try again.'
          : rawError.contains('400') || rawError.contains('Bad Request')
              ? 'Monobank rejected the request. Token may be expired — try reconnecting.'
              : rawError.isNotEmpty
                  ? rawError
                  : 'Failed to sync Monobank.';
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: cs.error),
      );
    }
  }

  Future<void> _confirmDisconnect(
    String integrationId,
    String walletName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Monobank?'),
        content: Text(
          'Remove the Monobank connection for "$walletName"? '
          'Existing transactions will remain.',
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
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _disconnectMonobank(integrationId);
  }

  Future<void> _disconnectMonobank(String integrationId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;
    final success = await ref
        .read(bankIntegrationsProvider.notifier)
        .deleteIntegration(integrationId);

    if (!mounted) return;
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Monobank disconnected.' : 'Failed to disconnect Monobank.',
        ),
        backgroundColor: success ? cs.primary : cs.error,
      ),
    );
  }

  Future<void> _showMonobankConnectDialog(AccountModel account) async {
    final apiTokenController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (context) {
        List<MonobankAccountModel> monoAccounts = [];
        MonobankAccountModel? selectedMonoAccount;
        bool isLoading = false;
        String? fetchError;
        bool hasLoaded = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Connect ${account.name} to Monobank'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet: ${account.name} (${account.currency})',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: apiTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Monobank Token',
                      hintText: 'Enter your Monobank API token',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final token = apiTokenController.text.trim();
                            if (token.isEmpty) return;
                            setState(() {
                              isLoading = true;
                              fetchError = null;
                              hasLoaded = false;
                            });
                            try {
                              final fetched = await ref
                                  .read(bankIntegrationRepositoryProvider)
                                  .listMonobankAccounts(token);
                              setState(() {
                                monoAccounts = fetched;
                                selectedMonoAccount = fetched.isNotEmpty
                                    ? fetched.first
                                    : null;
                                hasLoaded = true;
                              });
                            } catch (e) {
                              setState(() {
                                fetchError = 'Failed to load Monobank accounts.';
                                monoAccounts = [];
                                selectedMonoAccount = null;
                                hasLoaded = true;
                              });
                            } finally {
                              setState(() => isLoading = false);
                            }
                          },
                    icon: const Icon(Icons.search),
                    label: const Text('Load Monobank Accounts'),
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (fetchError != null)
                    Text(
                      fetchError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  else if (hasLoaded && monoAccounts.isEmpty)
                    const Text(
                      'No accounts found. Check the token and try again.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  else if (monoAccounts.isNotEmpty) ...[
                    const Text(
                      'Select the Monobank account to connect:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      width: double.maxFinite,
                      child: ListView.builder(
                        itemCount: monoAccounts.length,
                        itemBuilder: (context, index) {
                          final monoAcc = monoAccounts[index];
                          return RadioListTile<MonobankAccountModel>(
                            value: monoAcc,
                            groupValue: selectedMonoAccount,
                            onChanged: (value) =>
                                setState(() => selectedMonoAccount = value),
                            title: Text(
                              monoAcc.accountName != null
                                  ? '${monoAcc.accountName} — ${monoAcc.currency}'
                                  : 'Account ${monoAcc.id.substring(0, 6)}... ${monoAcc.currency}',
                            ),
                            subtitle: Text(
                              'Balance: ${monoAcc.readableBalance}',
                            ),
                          );
                        },
                      ),
                    ),
                  ] else
                    const Text(
                      'Enter a token and load accounts before connecting.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading ||
                          monoAccounts.isEmpty ||
                          selectedMonoAccount == null
                      ? null
                      : () async {
                          final cs = Theme.of(context).colorScheme;
                          final token = apiTokenController.text.trim();
                          if (token.isEmpty) return;
                          Navigator.pop(context);
                          final success = await ref
                              .read(bankIntegrationsProvider.notifier)
                              .setupMonobank(
                                apiToken: token,
                                accountId: account.id,
                                bankAccountId: selectedMonoAccount!.id,
                              );
                          if (!mounted) return;
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Monobank connected successfully.'
                                    : 'Failed to connect Monobank.',
                              ),
                              backgroundColor:
                                  success ? cs.primary : cs.error,
                            ),
                          );
                        },
                  child: const Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<AccountModel?> _showAccountPickerDialog(
    BuildContext context,
    List<AccountModel> accounts,
    String title,
  ) {
    return showDialog<AccountModel>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return ListTile(
                title: Text(account.name),
                subtitle: Text(account.currency),
                onTap: () => Navigator.pop(context, account),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectGmail(List<AccountModel> personalAccounts) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;

    final account = personalAccounts.length == 1
        ? personalAccounts.first
        : await _showAccountPickerDialog(
            context,
            personalAccounts,
            'Select wallet for Gmail receipts',
          );

    if (account == null) return;

    try {
      final authUrl = await ref
          .read(gmailIntegrationProvider.notifier)
          .requestAuthorizationUrl(accountId: account.id);
      final uri = Uri.parse(authUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Unable to open Gmail authorization link.'),
            backgroundColor: cs.error,
          ),
        );
        return;
      }
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Gmail authorization opened. Return here after approving access.',
          ),
          backgroundColor: cs.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to start Gmail authorization: $e'),
          backgroundColor: cs.error,
        ),
      );
    }
  }

  Future<void> _scanGmail(List<AccountModel> personalAccounts) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;

    final account = personalAccounts.length == 1
        ? personalAccounts.first
        : await _showAccountPickerDialog(
            context,
            personalAccounts,
            'Import receipts into which wallet?',
          );

    if (account == null) return;

    try {
      final scanResults = await ref
          .read(gmailIntegrationProvider.notifier)
          .scanInbox(accountId: account.id);
      if (!mounted) return;
      final message = scanResults.isEmpty
          ? 'No new receipts found in Gmail.'
          : 'Imported ${scanResults.length} receipt(s) into ${account.name}.';
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: scanResults.isEmpty ? cs.tertiary : cs.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to scan Gmail inbox: $e'),
          backgroundColor: cs.error,
        ),
      );
    }
  }
}
