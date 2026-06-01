class GmailIntegrationModel {
  final String email;
  final DateTime? lastScannedAt;

  GmailIntegrationModel({required this.email, required this.lastScannedAt});

  factory GmailIntegrationModel.fromJson(Map<String, dynamic> json) {
    final emailValue = json['gmailAddress'] ?? json['email'];
    return GmailIntegrationModel(
      email: emailValue as String,
      lastScannedAt: json['lastScannedAt'] != null
          ? DateTime.parse(json['lastScannedAt'] as String).toLocal()
          : null,
    );
  }
}
