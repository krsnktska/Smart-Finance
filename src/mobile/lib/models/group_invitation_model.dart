class GroupInvitationModel {
  final String id;
  final String groupId;
  final String groupName;
  final String invitedUserId;
  final String invitedUserName;
  final String invitedUserEmail;
  final String invitedByUserId;
  final String invitedByUserName;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  GroupInvitationModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.invitedUserId,
    required this.invitedUserName,
    required this.invitedUserEmail,
    required this.invitedByUserId,
    required this.invitedByUserName,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory GroupInvitationModel.fromJson(Map<String, dynamic> json) {
    return GroupInvitationModel(
      id: json['id'],
      groupId: json['groupId'],
      groupName: json['groupName'],
      invitedUserId: json['invitedUserId'],
      invitedUserName: json['invitedUserName'],
      invitedUserEmail: json['invitedUserEmail'],
      invitedByUserId: json['invitedByUserId'],
      invitedByUserName: json['invitedByUserName'],
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'groupName': groupName,
      'invitedUserId': invitedUserId,
      'invitedUserName': invitedUserName,
      'invitedUserEmail': invitedUserEmail,
      'invitedByUserId': invitedByUserId,
      'invitedByUserName': invitedByUserName,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
    };
  }
}
