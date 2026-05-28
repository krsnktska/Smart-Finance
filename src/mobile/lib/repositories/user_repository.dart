import 'package:mobile/services/api_client.dart';
import 'package:mobile/config/api_config.dart';
import 'package:mobile/models/user_model.dart';

class UserRepository {
  final ApiClient apiClient;

  UserRepository({required this.apiClient});


  Future<UserModel> getMe() async {
    final response = await apiClient.get(
      '${ApiConfig.users}/me',
      fromJson: (json) => UserModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<UserModel> updateMe({String? name, DateTime? birthday}) async {
    final response = await apiClient.put(
      '${ApiConfig.users}/me',
      data: {
        'name': ?name,
        if (birthday != null) 'birthday': birthday.toIso8601String(),
      },
      fromJson: (json) => UserModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await apiClient.put(
      '${ApiConfig.users}/me/password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }
}
