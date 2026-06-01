import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/models/bank_integration_model.dart';
import 'package:mobile/models/transaction_model.dart';
import 'package:mobile/repositories/bank_integration_repository.dart';
import 'package:mobile/services/api_client.dart';

final bankIntegrationRepositoryProvider = Provider((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return BankIntegrationRepository(apiClient: apiClient);
});

final bankIntegrationsProvider =
    StateNotifierProvider<BankIntegrationNotifier, BankIntegrationState>((ref) {
      final repository = ref.watch(bankIntegrationRepositoryProvider);
      return BankIntegrationNotifier(repository: repository);
    });

class BankIntegrationState {
  final List<BankIntegrationModel> integrations;
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final String? message;

  BankIntegrationState({
    this.integrations = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.message,
  });

  BankIntegrationState copyWith({
    List<BankIntegrationModel>? integrations,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    String? message,
  }) {
    return BankIntegrationState(
      integrations: integrations ?? this.integrations,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
      message: message,
    );
  }
}

class BankIntegrationNotifier extends StateNotifier<BankIntegrationState> {
  final BankIntegrationRepository repository;

  BankIntegrationNotifier({required this.repository})
    : super(BankIntegrationState());

  Future<void> loadIntegrations() async {
    state = state.copyWith(isLoading: true, error: null, message: null);
    try {
      final integrations = await repository.getMonobankIntegrations();
      state = state.copyWith(
        integrations: integrations,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> setupMonobank({
    required String apiToken,
    required String accountId,
    String? bankAccountId,
  }) async {
    state = state.copyWith(isLoading: true, error: null, message: null);
    try {
      await repository.setupMonobank(
        apiToken: apiToken,
        accountId: accountId,
        bankAccountId: bankAccountId,
      );
      await loadIntegrations();
      state = state.copyWith(message: 'Monobank connected successfully.');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> syncMonobank({required String integrationId}) async {
    state = state.copyWith(isSyncing: true, error: null, message: null);
    try {
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 30));
      final syncedTransactions = await repository.syncMonobank(
        integrationId: integrationId,
        from: from,
        to: now,
      );
      await loadIntegrations();
      state = state.copyWith(
        isSyncing: false,
        message: syncedTransactions.isEmpty
            ? 'No new transactions were found in the last 30 days for this Monobank account.'
            : 'Synced ${syncedTransactions.length} transaction(s) from Monobank.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: e.toString());
      return false;
    }
  }
}
