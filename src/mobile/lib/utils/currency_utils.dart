class CurrencyUtils {
  static const Map<String, String> currencyNames = {
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'UAH': 'Ukrainian Hryvnia',
    'GBP': 'British Pound',
    'CHF': 'Swiss Franc',
    'PLN': 'Polish Zloty',
    'CZK': 'Czech Koruna',
    'JPY': 'Japanese Yen',
    'AUD': 'Australian Dollar',
    'CAD': 'Canadian Dollar',
    'AED': 'UAE Dirham',
    'KZT': 'Kazakhstani Tenge',
  };

  static const List<String> supportedCurrencies = [
    'USD',
    'EUR',
    'UAH',
    'GBP',
    'CHF',
    'PLN',
    'CZK',
    'JPY',
    'AUD',
    'CAD',
    'AED',
    'KZT',
  ];

  static String displayName(String code) {
    return currencyNames[code] ?? code;
  }

  static List<String> filter(String query) {
    final lower = query.toLowerCase();
    return supportedCurrencies.where((code) {
      final name = displayName(code).toLowerCase();
      return code.toLowerCase().contains(lower) || name.contains(lower);
    }).toList();
  }
}
