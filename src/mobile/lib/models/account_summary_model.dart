class AccountSummaryModel {
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final DateTime? from;
  final DateTime? to;

  AccountSummaryModel({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    this.from,
    this.to,
  });

  factory AccountSummaryModel.fromJson(Map<String, dynamic> json) {
    return AccountSummaryModel(
      totalIncome: (json['totalIncome'] as num).toDouble(),
      totalExpense: (json['totalExpense'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
      from: json['from'] != null ? DateTime.parse(json['from']) : null,
      to: json['to'] != null ? DateTime.parse(json['to']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'balance': balance,
      'from': from?.toIso8601String(),
      'to': to?.toIso8601String(),
    };
  }
}
