import 'package:mobile/models/user_model.dart';

class AuthModel {
  final String token;
  final String refreshToken;
  final UserModel user;

  AuthModel({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  factory AuthModel.fromJson(Map<String, dynamic> json) {
    return AuthModel(
      token: json['token'],
      refreshToken: json['refreshToken'],
      user: UserModel.fromJson(json['user']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'refreshToken': refreshToken,
      'user': user.toJson(),
    };
  }
}
