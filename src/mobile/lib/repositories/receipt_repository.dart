import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/config/api_config.dart';
import 'package:mobile/models/receipt_scan_model.dart';
import 'package:mobile/services/api_client.dart';

class ReceiptRepository {
  final ApiClient apiClient;

  ReceiptRepository({required this.apiClient});

  Future<ReceiptScanModel> scanReceipt({
    required String accountId,
    required String imagePath,
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imagePath,
        filename: imagePath.split('/').last,
      ),
    });

    try {
      final response = await apiClient.post(
        '${ApiConfig.receipts}/scan',
        queryParameters: {'accountId': accountId},
        data: formData,
        fromJson: (json) =>
            ReceiptScanModel.fromJson(json as Map<String, dynamic>),
      );

      return response;
    } catch (e) {
      // Fallback: use `http.MultipartRequest` to ensure proper multipart boundary handling
      try {
        final uri = Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.receipts}/scan',
        ).replace(queryParameters: {'accountId': accountId});
        final request = http.MultipartRequest('POST', uri);
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            imagePath,
            filename: imagePath.split('/').last,
          ),
        );

        final auth = apiClient.authHeader;
        if (auth != null) request.headers['Authorization'] = auth;

        final streamed = await request.send();
        final resp = await http.Response.fromStream(streamed);
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final json = jsonDecode(resp.body) as Map<String, dynamic>;
          return ReceiptScanModel.fromJson(json);
        }
        throw ApiException(
          message: 'Fallback upload failed: ${resp.statusCode} ${resp.body}',
          statusCode: resp.statusCode,
        );
      } catch (ex) {
        rethrow;
      }
    }
  }

  Future<ReceiptScanModel> scrapeReceipt({
    required String accountId,
    required String url,
  }) async {
    final response = await apiClient.post(
      '${ApiConfig.receipts}/scrape',
      data: {'url': url, 'accountId': accountId},
      fromJson: (json) =>
          ReceiptScanModel.fromJson(json as Map<String, dynamic>),
    );

    return response;
  }
}
