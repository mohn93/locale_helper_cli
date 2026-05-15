// packages/locale_helper_shared/lib/src/user_dto.dart
import 'package:meta/meta.dart';

@immutable
class UserDto {
  final String id;
  final String email;
  final String? displayName;
  const UserDto({required this.id, required this.email, this.displayName});

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    if (displayName != null) 'displayName': displayName,
  };

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String?,
  );
}
