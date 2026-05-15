// packages/locale_helper_shared/test/edit_test.dart
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:test/test.dart';

void main() {
  test('Edit round-trips through JSON', () {
    final edit = Edit(
      id: 'e1',
      projectId: 'p1',
      key: 'welcome',
      locale: 'en',
      proposedValue: 'Welcome back!',
      comment: 'Feels warmer',
      authorUserId: 'u1',
      displayName: 'Sara',
      status: EditStatus.pending,
      createdAt: DateTime.utc(2026, 5, 12),
    );
    final decoded = Edit.fromJson(edit.toJson());
    expect(decoded.id, 'e1');
    expect(decoded.status, EditStatus.pending);
    expect(decoded.comment, 'Feels warmer');
    expect(decoded.authorUserId, 'u1');
    expect(decoded.displayName, 'Sara');
  });

  test('Edit omits null optional fields from JSON', () {
    final edit = Edit(
      id: 'e2',
      projectId: 'p2',
      key: 'k',
      locale: 'en',
      proposedValue: 'v',
      status: EditStatus.accepted,
      createdAt: DateTime.utc(2026, 5, 12),
    );
    final json = edit.toJson();
    expect(json.containsKey('comment'), isFalse);
    expect(json.containsKey('authorUserId'), isFalse);
    expect(json.containsKey('displayName'), isFalse);
    expect(json.containsKey('reviewerAlias'), isFalse);
  });

  test('EditStatus parses every defined value', () {
    expect(EditStatus.fromWire('pending'), EditStatus.pending);
    expect(EditStatus.fromWire('accepted'), EditStatus.accepted);
    expect(EditStatus.fromWire('rejected'), EditStatus.rejected);
    expect(() => EditStatus.fromWire('bad'), throwsArgumentError);
  });
}
