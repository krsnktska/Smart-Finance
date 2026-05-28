import 'package:mobile/services/api_client.dart';
import 'package:mobile/config/api_config.dart';
import 'package:mobile/models/account_model.dart';
import 'package:mobile/models/account_summary_model.dart';
import 'package:mobile/models/category_spending_model.dart';

class AccountRepository {
  final ApiClient apiClient;

  AccountRepository({required this.apiClient});

  Future<List<AccountModel>> getAll() async {
    final response = await apiClient.get(
      ApiConfig.accounts,
      fromJson: (json) => (json as List)
          .map((e) => AccountModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return response;
  }

  Future<AccountModel> getById(String accountId) async {
    final response = await apiClient.get(
      '${ApiConfig.accounts}/$accountId',
      fromJson: (json) => AccountModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<AccountModel> create({
    required String name,
    required String currency,
  }) async {
    final response = await apiClient.post(
      ApiConfig.accounts,
      data: {'name': name, 'currency': currency},
      fromJson: (json) => AccountModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<AccountModel> update({
    required String accountId,
    String? name,
    String? currency,
  }) async {
    final response = await apiClient.put(
      '${ApiConfig.accounts}/$accountId',
      data: {
        'name': ?name,
        'currency': ?currency,
      },
      fromJson: (json) => AccountModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<void> delete(String accountId) async {
    await apiClient.delete('${ApiConfig.accounts}/$accountId');
  }

  Future<AccountSummaryModel> getSummary({
    required String accountId,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await apiClient.get(
      '${ApiConfig.accounts}/$accountId/summary',
      queryParameters: {
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      },
      fromJson: (json) =>
          AccountSummaryModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<List<CategorySpendingModel>> getByCategory({
    required String accountId,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await apiClient.get(
      '${ApiConfig.accounts}/$accountId/by-category',
      queryParameters: {
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      },
      fromJson: (json) => (json as List)
          .map((e) => CategorySpendingModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return response;
  }
}
