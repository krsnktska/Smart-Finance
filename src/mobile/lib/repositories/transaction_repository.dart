import 'package:mobile/services/api_client.dart';
import 'package:mobile/config/api_config.dart';
import 'package:mobile/models/transaction_model.dart';

class TransactionRepository {
  final ApiClient apiClient;

  TransactionRepository({required this.apiClient});

  Future<List<TransactionModel>> getAll({required String accountId}) async {
    final response = await apiClient.get(
      ApiConfig.transactions,
      queryParameters: {'accountId': accountId},
      fromJson: (json) => (json as List)
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return response;
  }

  Future<TransactionModel> getById(String transactionId) async {
    final response = await apiClient.get(
      '${ApiConfig.transactions}/$transactionId',
      fromJson: (json) =>
          TransactionModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<TransactionModel> create({
    required TransactionType type,
    SpecialType? specialType,
    required double value,
    required DateTime occurredAt,
    required String name,
    String? description,
    required String currency,
    required String accountId,
    List<String>? categoryIds,
  }) async {
    final response = await apiClient.post(
      ApiConfig.transactions,
      data: {
        // 👇 Шлем инты (.index) вместо строк, так как бэк ждет числа
        'type': type.index,
        if (specialType != null) 'specialType': specialType.index,
        'value': value,
        // 👇 Принудительно гоним дату в UTC для базы данных
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        'currency': currency,
        'accountId': accountId,
        if (categoryIds != null && categoryIds.isNotEmpty)
          'categoryIds': categoryIds,
      },
      fromJson: (json) =>
          TransactionModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<TransactionModel> update({
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
    final data = <String, dynamic>{};

    // 👇 Тут тоже переводим на индексы и UTC
    if (type != null) data['type'] = type.index;
    if (specialType != null) data['specialType'] = specialType.index;
    if (value != null) data['value'] = value;
    if (occurredAt != null)
      data['occurredAt'] = occurredAt.toUtc().toIso8601String();
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (currency != null) data['currency'] = currency;
    if (categoryIds != null) data['categoryIds'] = categoryIds;

    final response = await apiClient.put(
      '${ApiConfig.transactions}/$transactionId',
      data: data,
      fromJson: (json) =>
          TransactionModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<void> delete(String transactionId) async {
    await apiClient.delete('${ApiConfig.transactions}/$transactionId');
  }
}
