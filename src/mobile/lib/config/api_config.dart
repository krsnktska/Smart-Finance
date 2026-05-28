class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:5050/api';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration sendTimeout = Duration(seconds: 10);

  // Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';
  static const String revoke = '/auth/revoke';

  static const String users = '/users';
  static const String accounts = '/accounts';
  static const String transactions = '/transactions';
  static const String categories = '/categories';
  static const String groups = '/groups';
  static const String statistics = '/statistics';
}
