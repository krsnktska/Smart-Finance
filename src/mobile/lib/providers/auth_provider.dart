import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/repositories/auth_repository.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/models/auth_model.dart';

class AuthState {
  final AuthModel? auth;
  final bool isLoading;
  final String? error;

  AuthState({this.auth, this.isLoading = false, this.error});

  bool get isAuthenticated => auth != null;

  String? get token => auth?.token;

  String? get refreshToken => auth?.refreshToken;

  AuthState copyWith({AuthModel? auth, bool? isLoading, String? error}) {
    return AuthState(
      auth: auth ?? this.auth,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final authRepository = AuthRepository(apiClient: apiClient);
  return AuthNotifier(authRepository: authRepository, apiClient: apiClient);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository authRepository;
  final ApiClient apiClient;

  AuthNotifier({required this.authRepository, required this.apiClient})
    : super(AuthState());

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final auth = await authRepository.login(email: email, password: password);
      apiClient.setAuthToken(auth.token);
      state = state.copyWith(auth: auth, isLoading: false);
      return true;
    } catch (e) {
      final errorMessage = e.toString();
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final auth = await authRepository.register(
        name: name,
        email: email,
        password: password,
      );

      apiClient.setAuthToken(auth.token);
      state = state.copyWith(auth: auth, isLoading: false);
      return true;
    } catch (e) {
      final errorMessage = e.toString();
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  Future<void> logout() async {
    try {
      if (state.refreshToken != null) {
        await authRepository.logout(refreshToken: state.refreshToken!);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Logout error: $e');
      }
    } finally {
      apiClient.removeAuthToken();
      state = AuthState();
    }
  }

  Future<bool> refreshAccessToken() async {
    try {
      if (state.refreshToken == null) return false;

      final auth = await authRepository.refreshToken(
        refreshToken: state.refreshToken!,
      );
      apiClient.setAuthToken(auth.token);
      state = state.copyWith(auth: auth);
      return true;
    } catch (e) {
      await logout();
      return false;
    }
  }
}
