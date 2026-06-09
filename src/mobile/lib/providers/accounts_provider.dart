import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/repositories/account_repository.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/models/account_model.dart';
import 'package:mobile/models/account_summary_model.dart';
import 'package:mobile/models/category_spending_model.dart';
import 'package:mobile/providers/groups_provider.dart';

final accountRepositoryProvider = Provider((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AccountRepository(apiClient: apiClient);
});

class AccountsState {
  final List<AccountModel> accounts;
  final bool isLoading;
  final String? error;

  AccountsState({this.accounts = const [], this.isLoading = false, this.error});

  AccountsState copyWith({
    List<AccountModel>? accounts,
    bool? isLoading,
    String? error,
  }) {
    return AccountsState(
      accounts: accounts ?? this.accounts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final accountsProvider = StateNotifierProvider<AccountsNotifier, AccountsState>(
  (ref) {
    final accountRepository = ref.watch(accountRepositoryProvider);
    return AccountsNotifier(accountRepository: accountRepository, ref: ref);
  },
);

class AccountsNotifier extends StateNotifier<AccountsState> {
  final AccountRepository accountRepository;
  final Ref ref;

  AccountsNotifier({required this.accountRepository, required this.ref})
    : super(AccountsState());

  Future<void> loadAccounts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final accounts = await accountRepository.getAll();

      await ref.read(groupsProvider.notifier).loadGroups();

      final groupsState = ref.read(groupsProvider);
      List<AccountModel> groupAccounts = [];

      for (final group in groupsState.groups) {
        try {
          final groupAccountsList = await ref
              .read(groupsProvider.notifier)
              .getGroupAccounts(group.id);
          groupAccounts.addAll(
            groupAccountsList.map((acc) {
              return AccountModel(
                id: acc.id,
                name: acc.name,
                currency: acc.currency,
                userId: acc.userId,
                groupId: group.id,
                groupName: group.name,
              );
            }),
          );
        } catch (e) {
          continue;
        }
      }

      final accountMap = <String, AccountModel>{};
      for (final account in accounts) {
        accountMap[account.id] = account;
      }
      for (final account in groupAccounts) {
        accountMap[account.id] = account;
      }

      final allAccounts = accountMap.values.toList();
      state = state.copyWith(accounts: allAccounts, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createAccount({
    required String name,
    required String currency,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final newAccount = await accountRepository.create(
        name: name,
        currency: currency,
      );
      state = state.copyWith(
        accounts: [...state.accounts, newAccount],
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateAccount({
    required String accountId,
    String? name,
    String? currency,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedAccount = await accountRepository.update(
        accountId: accountId,
        name: name,
        currency: currency,
      );
      state = state.copyWith(
        accounts: state.accounts
            .map((acc) => acc.id == accountId ? updatedAccount : acc)
            .toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteAccount(String accountId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await accountRepository.delete(accountId);
      state = state.copyWith(
        accounts: state.accounts.where((acc) => acc.id != accountId).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final accountProvider = FutureProvider.family<AccountModel, String>((
  ref,
  accountId,
) async {
  final accountRepository = ref.watch(accountRepositoryProvider);
  return accountRepository.getById(accountId);
});

final accountSummaryProvider =
    FutureProvider.family<
      AccountSummaryModel,
      ({String accountId, DateTime? from, DateTime? to})
    >((ref, params) async {
      final accountRepository = ref.watch(accountRepositoryProvider);
      return accountRepository.getSummary(
        accountId: params.accountId,
        from: params.from,
        to: params.to,
      );
    });

final categorySpendingProvider =
    FutureProvider.family<
      List<CategorySpendingModel>,
      ({String accountId, DateTime? from, DateTime? to})
    >((ref, params) async {
      final accountRepository = ref.watch(accountRepositoryProvider);
      return accountRepository.getByCategory(
        accountId: params.accountId,
        from: params.from,
        to: params.to,
      );
    });

final accountTotalBalanceProvider = FutureProvider.family<double, String>((
  ref,
  accountId,
) async {
  final accountRepository = ref.watch(accountRepositoryProvider);
  final summary = await accountRepository.getSummary(accountId: accountId);
  return summary.balance;
});
