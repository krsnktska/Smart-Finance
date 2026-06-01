import 'package:mobile/config/api_config.dart';
import 'package:mobile/models/gmail_integration_model.dart';
import 'package:mobile/models/receipt_scan_model.dart';
import 'package:mobile/services/api_client.dart';

class GmailRepository {
  final ApiClient apiClient;

  GmailRepository({required this.apiClient});

  Future<String> getAuthorizationUrl({required String accountId}) async {
    final response = await apiClient.get(
      ApiConfig.gmailAuth,
      queryParameters: {'accountId': accountId},
      fromJson: (json) => (json as Map<String, dynamic>)['authUrl'] as String,
    );
    return response;
  }

  Future<GmailIntegrationModel?> getStatus() async {
    try {
      final response = await apiClient.get(
        ApiConfig.gmailStatus,
        fromJson: (json) =>
            GmailIntegrationModel.fromJson(json as Map<String, dynamic>),
      );
      return response;
    } catch (_) {
      return null;
    }
  }

  Future<List<ReceiptScanModel>> scanInbox({required String accountId}) async {
    final response = await apiClient.post(
      ApiConfig.gmailScan,
      queryParameters: {'accountId': accountId},
      fromJson: (json) => (json as List)
          .map(
            (item) => ReceiptScanModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
    return response;
  }
}
