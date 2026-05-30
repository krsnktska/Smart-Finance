import 'package:mobile/config/api_config.dart';
import 'package:mobile/models/group_invitation_model.dart';
import 'package:mobile/services/api_client.dart';

class InvitationsRepository {
  final ApiClient apiClient;

  InvitationsRepository({required this.apiClient});

  Future<List<GroupInvitationModel>> getPendingInvitations() async {
    try {
      print(
        '📤 [Invitations] Fetching pending invitations from ${ApiConfig.invitations}',
      );
      final response = await apiClient.get<List<dynamic>>(
        ApiConfig.invitations,
      );
      print('📥 [Invitations] Received ${response.length} invitations');
      return response
          .map(
            (raw) => GroupInvitationModel.fromJson(raw as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print('❌ [Invitations] Error fetching pending invitations: $e');
      rethrow;
    }
  }

  Future<bool> acceptInvitation(String invitationId) async {
    try {
      await apiClient.post('${ApiConfig.invitations}/$invitationId/accept');
      return true;
    } catch (e) {
      print('❌ Error in Repository [acceptInvitation]: $e');
      return false;
    }
  }

  Future<bool> declineInvitation(String invitationId) async {
    try {
      await apiClient.post('${ApiConfig.invitations}/$invitationId/decline');
      return true;
    } catch (e) {
      print('❌ Error in Repository [declineInvitation]: $e');
      return false;
    }
  }
}
