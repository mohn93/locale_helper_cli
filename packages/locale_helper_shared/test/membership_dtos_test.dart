// packages/locale_helper_shared/test/membership_dtos_test.dart
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:test/test.dart';

void main() {
  test('MemberDto round-trips', () {
    final m = MemberDto(
      userId: 'u1', email: 'a@b.com', displayName: 'A',
      role: 'reviewer', joinedAt: DateTime.utc(2026, 5, 13),
    );
    final d = MemberDto.fromJson(m.toJson());
    expect(d.role, 'reviewer');
    expect(d.displayName, 'A');
  });

  test('InvitationDto round-trips', () {
    final i = InvitationDto(
      id: 'i1', role: 'commenter',
      createdAt: DateTime.utc(2026, 5, 13),
      revokedAt: null,
      inviteUrl: 'https://x/invite/abc',
    );
    final d = InvitationDto.fromJson(i.toJson());
    expect(d.role, 'commenter');
    expect(d.revokedAt, isNull);
  });

  test('CommentDto round-trips', () {
    final c = CommentDto(
      id: 'c1', stringKey: 'hello', userId: 'u1',
      displayName: 'Alice', body: 'feels off',
      createdAt: DateTime.utc(2026, 5, 13),
    );
    final d = CommentDto.fromJson(c.toJson());
    expect(d.body, 'feels off');
  });

  test('ProjectListItemDto round-trips', () {
    final p = ProjectListItemDto(
      id: 'p1', name: 'ls_app',
      myRole: 'owner', unreviewedCount: 12,
      updatedAt: DateTime.utc(2026, 5, 13),
    );
    final d = ProjectListItemDto.fromJson(p.toJson());
    expect(d.myRole, 'owner');
    expect(d.unreviewedCount, 12);
  });
}
