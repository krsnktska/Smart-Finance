import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/repositories/receipt_repository.dart';
import 'package:mobile/services/api_client.dart';

final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReceiptRepository(apiClient: apiClient);
});
