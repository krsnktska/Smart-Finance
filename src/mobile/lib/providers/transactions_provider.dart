import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/repositories/transaction_repository.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/models/transaction_model.dart';

final transactionRepositoryProvider = Provider((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TransactionRepository(apiClient: apiClient);
});

class TransactionsState {
  final List<TransactionModel> transactions;
  final bool isLoading;
  final String? error;

  TransactionsState({
    this.transactions = const [],
    this.isLoading = false,
    this.error,
  });

  TransactionsState copyWith({
    List<TransactionModel>? transactions,
    bool? isLoading,
    String? error,
  }) {
    return TransactionsState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final transactionsProvider =
    StateNotifierProvider.family<
      TransactionsNotifier,
      TransactionsState,
      String
    >((ref, accountId) {
      final transactionRepository = ref.watch(transactionRepositoryProvider);
      return TransactionsNotifier(
        accountId: accountId,
        transactionRepository: transactionRepository,
      );
    });

class TransactionsNotifier extends StateNotifier<TransactionsState> {
  final String accountId;
  final TransactionRepository transactionRepository;

  TransactionsNotifier({
    required this.accountId,
    required this.transactionRepository,
  }) : super(TransactionsState());

  Future<void> loadTransactions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final transactions = await transactionRepository.getAll(
        accountId: accountId,
      );
      state = state.copyWith(transactions: transactions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createTransaction({
    required TransactionType type,
    SpecialType? specialType,
    required double value,
    required DateTime occurredAt,
    required String name,
    String? description,
    required String currency,
    List<String>? categoryIds,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final newTransaction = await transactionRepository.create(
        type: type,
        specialType: specialType,
        value: value,
        occurredAt: occurredAt,
        name: name,
        description: description,
        currency: currency,
        accountId: accountId,
        categoryIds: categoryIds,
      );
      state = state.copyWith(
        transactions: [...state.transactions, newTransaction],
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateTransaction({
    required String transactionId,
    TransactionType? type,
    SpecialType? specialType,
    double? value,
    DateTime? occurredAt,
    String? name,
    String? description,
    String? currency,
    List<String>? categoryIds,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedTransaction = await transactionRepository.update(
        transactionId: transactionId,
        type: type,
        specialType: specialType,
        value: value,
        occurredAt: occurredAt,
        name: name,
        description: description,
        currency: currency,
        categoryIds: categoryIds,
      );
      state = state.copyWith(
        transactions: state.transactions
            .map(
              (transaction) => transaction.id == transactionId
                  ? updatedTransaction
                  : transaction,
            )
            .toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteTransaction(String transactionId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await transactionRepository.delete(transactionId);
      state = state.copyWith(
        transactions: state.transactions
            .where((transaction) => transaction.id != transactionId)
            .toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}
