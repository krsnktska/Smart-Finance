import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/models/group_invitation_model.dart';
import 'package:mobile/repositories/invitations_repository.dart';
import 'package:mobile/services/api_client.dart';

final invitationsRepositoryProvider = Provider<InvitationsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InvitationsRepository(apiClient: apiClient);
});

final invitationsProvider =
    StateNotifierProvider<
      InvitationsNotifier,
      AsyncValue<List<GroupInvitationModel>>
    >((ref) {
      final repository = ref.watch(invitationsRepositoryProvider);
      return InvitationsNotifier(repository: repository);
    });

class InvitationsNotifier
    extends StateNotifier<AsyncValue<List<GroupInvitationModel>>> {
  final InvitationsRepository _repository;

  InvitationsNotifier({required InvitationsRepository repository})
    : _repository = repository,
      super(const AsyncValue.loading()) {
    fetchInvitations();
  }

  Future<void> fetchInvitations() async {
    try {
      state = const AsyncValue.loading();
      final invitations = await _repository.getPendingInvitations();
      state = AsyncValue.data(invitations);
    } catch (e, stackTrace) {
      print('🚨 Error fetching invitations: $e');
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<bool> acceptInvite(String inviteId) async {
    final success = await _repository.acceptInvitation(inviteId);
    if (!success) return false;

    if (state.hasValue) {
      final currentList = state.value!;
      state = AsyncValue.data(
        currentList.where((invite) => invite.id != inviteId).toList(),
      );
    }
    return true;
  }

  Future<bool> declineInvite(String inviteId) async {
    final success = await _repository.declineInvitation(inviteId);
    if (!success) return false;

    if (state.hasValue) {
      final currentList = state.value!;
      state = AsyncValue.data(
        currentList.where((invite) => invite.id != inviteId).toList(),
      );
    }
    return true;
  }
}
