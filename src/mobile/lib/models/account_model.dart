class AccountModel {
  final String id;
  final String name;
  final String currency;
  final String userId;
  final String? groupId;
  final String? groupName;

  AccountModel({
    required this.id,
    required this.name,
    required this.currency,
    required this.userId,
    this.groupId,
    this.groupName,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'],
      name: json['name'],
      currency: json['currency'],
      userId: json['userId'],
      groupId: json['groupId'],
      groupName: json['groupName'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'currency': currency,
      'userId': userId,
      'groupId': groupId,
      'groupName': groupName,
    };
  }
}
