import 'package:mobile/config/api_config.dart';
import 'package:mobile/models/bank_integration_model.dart';
import 'package:mobile/models/monobank_account_model.dart';
import 'package:mobile/models/transaction_model.dart';
import 'package:mobile/services/api_client.dart';

class BankIntegrationRepository {
  final ApiClient apiClient;

  BankIntegrationRepository({required this.apiClient});

  Future<List<BankIntegrationModel>> getMonobankIntegrations() async {
    final response = await apiClient.get(
      ApiConfig.bankMonobank,
      fromJson: (json) => (json as List)
          .map(
            (item) =>
                BankIntegrationModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
    return response;
  }

  Future<List<MonobankAccountModel>> listMonobankAccounts(
    String apiToken,
  ) async {
    final response = await apiClient.get(
      ApiConfig.monobankAccounts,
      queryParameters: {'apiToken': apiToken},
      fromJson: (json) => (json as List)
          .map(
            (item) =>
                MonobankAccountModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
    return response;
  }

  Future<BankIntegrationModel> setupMonobank({
    required String apiToken,
    required String accountId,
    String? bankAccountId,
  }) async {
    final response = await apiClient.post(
      ApiConfig.monobankSetup,
      data: {
        'apiToken': apiToken,
        'accountId': accountId,
        if (bankAccountId != null && bankAccountId.isNotEmpty)
          'bankAccountId': bankAccountId,
      },
      fromJson: (json) =>
          BankIntegrationModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<List<TransactionModel>> syncMonobank({
    required String integrationId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await apiClient.post(
      ApiConfig.monobankSync,
      data: {
        'integrationId': integrationId,
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
      fromJson: (json) => (json as List)
          .map(
            (item) => TransactionModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
    return response;
  }
}
