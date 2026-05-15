// packages/locale_helper_shared/lib/src/auth_dtos.dart
import 'package:meta/meta.dart';
import 'user_dto.dart';

@immutable
class SignupRequest {
  final String email;
  final String password;
  final String? displayName;
  const SignupRequest({required this.email, required this.password, this.displayName});

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    if (displayName != null) 'displayName': displayName,
  };

  factory SignupRequest.fromJson(Map<String, dynamic> json) => SignupRequest(
    email: json['email'] as String,
    password: json['password'] as String,
    displayName: json['displayName'] as String?,
  );
}

@immutable
class LoginRequest {
  final String email;
  final String password;
  const LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};

  factory LoginRequest.fromJson(Map<String, dynamic> json) => LoginRequest(
    email: json['email'] as String,
    password: json['password'] as String,
  );
}

@immutable
class AuthResponse {
  final UserDto user;
  final String token;
  const AuthResponse({required this.user, required this.token});

  Map<String, dynamic> toJson() => {'user': user.toJson(), 'token': token};

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    user: UserDto.fromJson((json['user'] as Map).cast<String, dynamic>()),
    token: json['token'] as String,
  );
}
