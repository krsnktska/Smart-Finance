import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/repositories/auth_repository.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/models/auth_model.dart';
import 'package:mobile/services/secure_storage.dart';

class AuthState {
  final AuthModel? auth;
  final bool isLoading;
  final bool isInitializing;
  final String? error;

  AuthState({
    this.auth,
    this.isLoading = false,
    this.isInitializing = true,
    this.error,
  });

  bool get isAuthenticated => auth != null;

  String? get token => auth?.token;

  String? get refreshToken => auth?.refreshToken;

  AuthState copyWith({
    AuthModel? auth,
    bool? isLoading,
    bool? isInitializing,
    String? error,
  }) {
    return AuthState(
      auth: auth ?? this.auth,
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
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
    _initFromStorage();
  }

  Future<void> _initFromStorage() async {
    state = state.copyWith(isInitializing: true);
    try {
      // Simulate load time for splash screen (2 seconds)
      await Future.delayed(const Duration(seconds: 2));

      final storedRefresh = await _storage.readRefreshToken();
      print('🔐 [Auth] Stored refresh token found: ${storedRefresh != null}');
      if (storedRefresh == null) {
        print('🔐 [Auth] No stored token, skipping auto-login');
        state = state.copyWith(isInitializing: false);
        return;
      }
      print('🔐 [Auth] Attempting to refresh with stored token');
      final auth = await authRepository.refreshToken(
        refreshToken: storedRefresh,
      );
      print('🔐 [Auth] Auto-login successful, token set');
      apiClient.setAuthToken(auth.token);
      // Save the new refresh token for next session
      print('🔐 [Auth] Saving new refresh token from refresh response');
      final expiry = DateTime.now().add(const Duration(days: 30));
      await _storage.saveRefreshToken(auth.refreshToken, expiry);
      print('🔐 [Auth] New refresh token saved successfully');
      state = state.copyWith(auth: auth, isInitializing: false);
    } catch (e) {
      print('🔐 [Auth] Auto-login failed: $e');
      await _storage.clear();
      state = state.copyWith(isInitializing: false);
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    bool remember = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('🔐 [Auth] Login attempt: $email (remember=$remember)');
      final auth = await authRepository.login(email: email, password: password);
      apiClient.setAuthToken(auth.token);
      print('🔐 [Auth] Login successful, token set');
      state = state.copyWith(auth: auth, isLoading: false);

      if (remember) {
        print('🔐 [Auth] Saving refresh token (remember=true)');
        final expiry = DateTime.now().add(const Duration(days: 30));
        await _storage.saveRefreshToken(auth.refreshToken, expiry);
        print('🔐 [Auth] Refresh token saved successfully');
      } else {
        print('🔐 [Auth] Clearing storage (remember=false)');
        await _storage.clear();
      }
      return true;
    } catch (e) {
      print('❌ [Auth] Login error: $e');
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
      print('🔐 [Auth] Register attempt: $email (remember=$remember)');
      final auth = await authRepository.register(
        name: name,
        email: email,
        password: password,
        birthday: birthday,
      );

      apiClient.setAuthToken(auth.token);
      print('🔐 [Auth] Registration successful, token set');
      state = state.copyWith(auth: auth, isLoading: false);
      if (remember) {
        print(
          '🔐 [Auth] Saving refresh token after registration (remember=true)',
        );
        final expiry = DateTime.now().add(const Duration(days: 30));
        await _storage.saveRefreshToken(auth.refreshToken, expiry);
        print('🔐 [Auth] Refresh token saved successfully');
      } else {
        print('🔐 [Auth] Clearing storage after registration (remember=false)');
        await _storage.clear();
      }
      return true;
    } catch (e) {
      print('❌ [Auth] Registration error: $e');
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
      print('🔐 [Auth] Logout complete, clearing state');
      state = AuthState(isInitializing: false);
    }
  }

  Future<bool> refreshAccessToken() async {
    try {
      print('🔐 [Auth] Attempting to refresh access token');
      if (state.refreshToken == null) {
        print('❌ [Auth] No refresh token available');
        return false;
      }

      print('🔐 [Auth] Refreshing with stored refresh token');
      final auth = await authRepository.refreshToken(
        refreshToken: state.refreshToken!,
      );
      apiClient.setAuthToken(auth.token);
      print('🔐 [Auth] Access token refreshed successfully');
      state = state.copyWith(auth: auth);
      return true;
    } catch (e) {
      print('❌ [Auth] Token refresh failed: $e');
      await logout();
      return false;
    }
  }
}
