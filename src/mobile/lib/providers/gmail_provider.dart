import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/models/gmail_integration_model.dart';
import 'package:mobile/models/receipt_scan_model.dart';
import 'package:mobile/repositories/gmail_repository.dart';
import 'package:mobile/services/api_client.dart';

final gmailRepositoryProvider = Provider<GmailRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GmailRepository(apiClient: apiClient);
});

final gmailIntegrationProvider =
    StateNotifierProvider<GmailIntegrationNotifier, GmailIntegrationState>((
      ref,
    ) {
      final repository = ref.watch(gmailRepositoryProvider);
      return GmailIntegrationNotifier(repository: repository);
    });

class GmailIntegrationState {
  final GmailIntegrationModel? status;
  final bool isLoading;
  final bool isScanning;
  final String? error;
  final String? message;

  GmailIntegrationState({
    this.status,
    this.isLoading = false,
    this.isScanning = false,
    this.error,
    this.message,
  });

  GmailIntegrationState copyWith({
    GmailIntegrationModel? status,
    bool? isLoading,
    bool? isScanning,
    String? error,
    String? message,
  }) {
    return GmailIntegrationState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      error: error,
      message: message,
    );
  }
}

class GmailIntegrationNotifier extends StateNotifier<GmailIntegrationState> {
  final GmailRepository repository;

  GmailIntegrationNotifier({required this.repository})
    : super(GmailIntegrationState());

  Future<void> loadStatus() async {
    state = state.copyWith(isLoading: true, error: null, message: null);
    try {
      final status = await repository.getStatus();
      state = state.copyWith(status: status, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load Gmail status.',
      );
    }
  }

  Future<String> requestAuthorizationUrl({required String accountId}) async {
    state = state.copyWith(isLoading: true, error: null, message: null);
    try {
      final url = await repository.getAuthorizationUrl(accountId: accountId);
      state = state.copyWith(isLoading: false);
      return url;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to get Gmail authorization URL.',
      );
      rethrow;
    }
  }

  Future<List<ReceiptScanModel>> scanInbox({required String accountId}) async {
    state = state.copyWith(isScanning: true, error: null, message: null);
    try {
      final scans = await repository.scanInbox(accountId: accountId);
      state = state.copyWith(
        isScanning: false,
        message: scans.isEmpty
            ? 'No new receipts found in your Gmail inbox.'
            : 'Imported ${scans.length} receipt(s) from Gmail.',
      );
      return scans;
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        error: 'Failed to scan Gmail inbox.',
      );
      rethrow;
    }
  }
}
