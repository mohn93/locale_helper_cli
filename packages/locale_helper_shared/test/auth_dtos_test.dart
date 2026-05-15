// packages/locale_helper_shared/test/auth_dtos_test.dart
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:test/test.dart';

void main() {
  test('UserDto round-trips', () {
    final u = UserDto(id: 'u1', email: 'a@b.com', displayName: 'Alice');
    final d = UserDto.fromJson(u.toJson());
    expect(d.id, 'u1');
    expect(d.email, 'a@b.com');
    expect(d.displayName, 'Alice');
  });

  test('SignupRequest round-trips with optional displayName', () {
    final r = const SignupRequest(email: 'a@b.com', password: 'pw');
    final d = SignupRequest.fromJson(r.toJson());
    expect(d.email, 'a@b.com');
    expect(d.displayName, isNull);
  });

  test('AuthResponse round-trips', () {
    final r = AuthResponse(
      user: UserDto(id: 'u1', email: 'a@b.com', displayName: null),
      token: 'opaque',
    );
    final d = AuthResponse.fromJson(r.toJson());
    expect(d.token, 'opaque');
    expect(d.user.email, 'a@b.com');
  });
}
