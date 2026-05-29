import 'package:mobile/services/api_client.dart';
import 'package:mobile/config/api_config.dart';
import 'package:mobile/models/group_model.dart';
import 'package:mobile/models/account_model.dart';

class GroupRepository {
  final ApiClient apiClient;

  GroupRepository({required this.apiClient});

  Future<List<GroupModel>> getAll() async {
    final response = await apiClient.get(
      ApiConfig.groups,
      fromJson: (json) => (json as List)
          .map((e) => GroupModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return response;
  }

  Future<GroupModel> getById(String groupId) async {
    final response = await apiClient.get(
      '${ApiConfig.groups}/$groupId',
      fromJson: (json) => GroupModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<GroupModel> create({required String name}) async {
    final response = await apiClient.post(
      ApiConfig.groups,
      data: {'name': name},
      fromJson: (json) => GroupModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<GroupModel> update({
    required String groupId,
    required String name,
  }) async {
    final response = await apiClient.put(
      '${ApiConfig.groups}/$groupId',
      data: {'name': name},
      fromJson: (json) => GroupModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<void> delete(String groupId) async {
    await apiClient.delete('${ApiConfig.groups}/$groupId');
  }

  Future<void> addMember({
    required String groupId,
    required String userId,
  }) async {
    await apiClient.post('${ApiConfig.groups}/$groupId/members/$userId');
  }

  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    await apiClient.delete('${ApiConfig.groups}/$groupId/members/$userId');
  }

  Future<List<AccountModel>> getAccounts(String groupId) async {
    final response = await apiClient.get(
      '${ApiConfig.groups}/$groupId/accounts',
      fromJson: (json) => (json as List)
          .map((e) => AccountModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return response;
  }

  Future<void> addAccount({
    required String groupId,
    required String accountId,
  }) async {
    await apiClient.post('${ApiConfig.groups}/$groupId/accounts/$accountId');
  }

  Future<void> removeAccount({
    required String groupId,
    required String accountId,
  }) async {
    await apiClient.delete('${ApiConfig.groups}/$groupId/accounts/$accountId');
  }
}
