class ApiConfig {
  static const String baseUrl = 'https://smart-finance-1-yrin.onrender.com/api';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration sendTimeout = Duration(seconds: 60);

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
  static const String receipts = '/receipts';
  static const String statistics = '/statistics';
  static const String invitations = '/invitations';
  static const String bankMonobank = '/bank/monobank';
  static const String monobankSetup = '/bank/monobank/setup';
  static const String monobankSync = '/bank/monobank/sync';
  static const String monobankAccounts = '/bank/monobank/accounts';
  static String monobankIntegration(String id) => '/bank/monobank/$id';

  static const String gmailAuth = '/gmail/auth';
  static const String gmailStatus = '/gmail/status';
  static const String gmailScan = '/gmail/scan';
}
