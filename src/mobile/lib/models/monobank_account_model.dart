class MonobankAccountModel {
  final String id;
  final String currency;
  final double balance;
  final String? accountName;

  MonobankAccountModel({
    required this.id,
    required this.currency,
    required this.balance,
    this.accountName,
  });

  factory MonobankAccountModel.fromJson(Map<String, dynamic> json) {
    return MonobankAccountModel(
      id: json['id'] as String,
      currency: json['currency'] as String? ?? 'UAH',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      accountName: json['name'] as String?,
    );
  }

  String get readableBalance {
    return '${balance.toStringAsFixed(2)} $currency';
  }
}
