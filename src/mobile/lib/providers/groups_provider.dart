import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/config/api_config.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/repositories/group_repository.dart';
import 'package:mobile/models/group_model.dart';
import 'package:mobile/models/account_model.dart';

final groupRepositoryProvider = Provider((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GroupRepository(apiClient: apiClient);
});

class GroupsState {
  final List<GroupModel> groups;
  final bool isLoading;
  final String? error;

  GroupsState({this.groups = const [], this.isLoading = false, this.error});

  GroupsState copyWith({
    List<GroupModel>? groups,
    bool? isLoading,
    String? error,
  }) {
    return GroupsState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Скидає або оновлює помилку
    );
  }
}

final groupsProvider = StateNotifierProvider<GroupsNotifier, GroupsState>((
  ref,
) {
  final groupRepository = ref.watch(groupRepositoryProvider);
  return GroupsNotifier(groupRepository: groupRepository);
});

class GroupsNotifier extends StateNotifier<GroupsState> {
  final GroupRepository groupRepository;

  GroupsNotifier({required this.groupRepository}) : super(GroupsState());

  Future<void> loadGroups() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final groups = await groupRepository.getAll();
      state = state.copyWith(groups: groups, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createGroup({required String name}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final newGroup = await groupRepository.create(name: name);
      state = state.copyWith(
        groups: [...state.groups, newGroup],
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateGroup({
    required String groupId,
    required String name,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedGroup = await groupRepository.update(
        groupId: groupId,
        name: name,
      );
      state = state.copyWith(
        groups: state.groups
            .map((group) => group.id == groupId ? updatedGroup : group)
            .toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await groupRepository.delete(groupId);
      state = state.copyWith(
        groups: state.groups.where((group) => group.id != groupId).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<GroupModel> getGroupById(String groupId) async {
    return await groupRepository.getById(groupId);
  }

  Future<List<AccountModel>> getGroupAccounts(String groupId) async {
    try {
      return await groupRepository.getAccounts(groupId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  /// РЕАЛЬНЕ отримання інвайтів групи через репозиторій замість заглушки
  Future<List<dynamic>> getGroupInvitations(String groupId) async {
    try {
      return await groupRepository.getGroupInvitations(groupId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  /// Виправлений метод відправки інвайту через репозиторій
  Future<bool> inviteMemberByEmail({
    required String groupId,
    required String email,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Викликаємо метод репозиторію, який ми раніше написали
      final success = await groupRepository.inviteMemberByEmail(
        groupId: groupId,
        email: email,
      );

      state = state.copyWith(isLoading: false);
      if (!success) {
        state = state.copyWith(
          error: "Group not found or no user with this email exists.",
        );
      }
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> removeMember({
    required String groupId,
    required String userId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await groupRepository.removeMember(groupId: groupId, userId: userId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> addAccount({
    required String groupId,
    required String accountId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await groupRepository.addAccount(groupId: groupId, accountId: accountId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> removeAccount({
    required String groupId,
    required String accountId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await groupRepository.removeAccount(
        groupId: groupId,
        accountId: accountId,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> leaveGroup(String groupId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await groupRepository.leaveGroup(groupId);

      // Если запрос прошел успешно (204), убираем группу из локального стейта
      state = state.copyWith(
        groups: state.groups.where((group) => group.id != groupId).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      // Сюда прилетят 403 (если ты овнер), 404 или 401
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}
