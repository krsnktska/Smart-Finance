class GroupMemberModel {
  final String userId;
  final String name;
  final String email;
  final bool isOwner;

  GroupMemberModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.isOwner,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      userId: json['userId'],
      name: json['name'],
      email: json['email'],
      isOwner: json['isOwner'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'isOwner': isOwner,
    };
  }
}
