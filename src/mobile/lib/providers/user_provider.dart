import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/repositories/user_repository.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/models/user_model.dart';

final userRepositoryProvider = Provider((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UserRepository(apiClient: apiClient);
});

class UserState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  UserState({this.user, this.isLoading = false, this.error});

  UserState copyWith({UserModel? user, bool? isLoading, String? error}) {
    return UserState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return UserNotifier(userRepository: userRepository);
});

class UserNotifier extends StateNotifier<UserState> {
  final UserRepository userRepository;

  UserNotifier({required this.userRepository}) : super(UserState());

  Future<void> loadUser() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await userRepository.getMe();
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateUser({String? name, DateTime? birthday}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await userRepository.updateMe(
        name: name,
        birthday: birthday,
      );
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await userRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}
