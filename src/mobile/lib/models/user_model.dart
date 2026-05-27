class UserModel {
  final String id;
  final String name;
  final String email;
  final DateTime? birthday;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.birthday,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      birthday: json['birthday'] != null
          ? DateTime.parse(json['birthday'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'birthday': birthday?.toIso8601String(),
    };
  }
}
