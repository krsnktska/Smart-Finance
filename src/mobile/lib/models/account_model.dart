class AccountModel {
  final String id;
  final String name;
  final String currency;
  final String userId;

  AccountModel({
    required this.id,
    required this.name,
    required this.currency,
    required this.userId,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'],
      name: json['name'],
      currency: json['currency'],
      userId: json['userId'],
    );
  }
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'currency': currency, 'userId': userId};
  }
}
