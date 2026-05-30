import 'package:mobile/services/api_client.dart';
import 'package:mobile/config/api_config.dart';
import 'package:mobile/models/auth_model.dart';

class AuthRepository {
  final ApiClient apiClient;

  AuthRepository({required this.apiClient});

  Future<AuthModel> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post(
      ApiConfig.login,
      data: {'email': email, 'password': password},
      fromJson: (json) => AuthModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<AuthModel> register({
    required String name,
    required String email,
    required String password,
    DateTime? birthday,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
    };
    if (birthday != null) {
      data['birthday'] = birthday.toIso8601String().split('T').first;
    }

    final response = await apiClient.post(
      ApiConfig.register,
      data: data,
      fromJson: (json) => AuthModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<AuthModel> refreshToken({required String refreshToken}) async {
    final response = await apiClient.post(
      ApiConfig.refresh,
      data: {'refreshToken': refreshToken},
      fromJson: (json) => AuthModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<void> logout({required String refreshToken}) async {
    await apiClient.post(
      ApiConfig.revoke,
      data: {'refreshToken': refreshToken},
    );
  }
}
