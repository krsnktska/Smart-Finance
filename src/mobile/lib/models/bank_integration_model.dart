class BankIntegrationModel {
  final String id;
  final String bankType;
  final String accountId;
  final String? bankAccountId;
  final DateTime? lastSyncedAt;

  BankIntegrationModel({
    required this.id,
    required this.bankType,
    required this.accountId,
    this.bankAccountId,
    this.lastSyncedAt,
  });

  factory BankIntegrationModel.fromJson(Map<String, dynamic> json) {
    return BankIntegrationModel(
      id: json['id'] as String,
      bankType: json['bankType'] as String,
      accountId: json['accountId'] as String,
      bankAccountId: json['bankAccountId'] as String?,
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.parse(json['lastSyncedAt'] as String).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bankType': bankType,
      'accountId': accountId,
      'bankAccountId': bankAccountId,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    };
  }
}
