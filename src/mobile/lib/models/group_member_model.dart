class GroupMemberModel {
  final String userId;
  final String name;
  final String email;
  final bool isOwner;
  final bool canView;
  final bool canWrite;

  GroupMemberModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.isOwner,
    required this.canView,
    required this.canWrite,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      userId: json['userId'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      isOwner: json['isOwner'] as bool,
      canView: (json['canView'] as bool?) ?? true,
      canWrite: (json['canWrite'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'isOwner': isOwner,
      'canView': canView,
      'canWrite': canWrite,
    };
  }
}
