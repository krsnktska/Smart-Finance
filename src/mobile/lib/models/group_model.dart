import 'package:mobile/models/group_member_model.dart';

class GroupModel {
  final String id;
  final String name;
  final List<GroupMemberModel> members;

  GroupModel({
    required this.id,
    required this.name,
    required this.members,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      name: json['name'],
      members: (json['members'] as List<dynamic>)
          .map((member) => GroupMemberModel.fromJson(member))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'members': members.map((member) => member.toJson()).toList(),
    };
  }
}

