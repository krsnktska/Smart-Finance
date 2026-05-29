import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/repositories/auth_repository.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/models/auth_model.dart';
import 'package:mobile/services/secure_storage.dart';

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
  final SecureStorageService _storage = SecureStorageService();

  AuthNotifier({required this.authRepository, required this.apiClient})
    : super(AuthState()) {
    // Try to restore tokens from secure storage
    _initFromStorage();
  }

  Future<void> _initFromStorage() async {
    final storedRefresh = await _storage.readRefreshToken();
    if (storedRefresh == null) return;
    try {
      final auth = await authRepository.refreshToken(
        refreshToken: storedRefresh,
      );
      apiClient.setAuthToken(auth.token);
      state = state.copyWith(auth: auth);
    } catch (e) {
      await _storage.clear();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    bool remember = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final auth = await authRepository.login(email: email, password: password);
      apiClient.setAuthToken(auth.token);
      state = state.copyWith(auth: auth, isLoading: false);
      if (remember) {
        final expiry = DateTime.now().add(const Duration(days: 30));
        await _storage.saveRefreshToken(auth.refreshToken, expiry);
      } else {
        await _storage.clear();
      }
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
    DateTime? birthday,
    bool remember = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final auth = await authRepository.register(
        name: name,
        email: email,
        password: password,
        birthday: birthday,
      );

      apiClient.setAuthToken(auth.token);
      state = state.copyWith(auth: auth, isLoading: false);
      if (remember) {
        final expiry = DateTime.now().add(const Duration(days: 30));
        await _storage.saveRefreshToken(auth.refreshToken, expiry);
      } else {
        await _storage.clear();
      }
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
      await _storage.clear();
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
