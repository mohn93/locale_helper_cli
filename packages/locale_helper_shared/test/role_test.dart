// packages/locale_helper_shared/test/role_test.dart
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:test/test.dart';

void main() {
  test('Role.fromWire parses every defined value', () {
    expect(Role.fromWire('text'), Role.text);
    expect(Role.fromWire('button'), Role.button);
    expect(Role.fromWire('fieldLabel'), Role.fieldLabel);
    expect(Role.fromWire('fieldHint'), Role.fieldHint);
    expect(Role.fromWire('header'), Role.header);
    expect(Role.fromWire('listItem'), Role.listItem);
    expect(Role.fromWire('dialog'), Role.dialog);
    expect(Role.fromWire('tooltip'), Role.tooltip);
    expect(Role.fromWire('a11y'), Role.a11y);
    expect(Role.fromWire('other'), Role.other);
  });

  test('Role.fromWire throws ArgumentError on unknown values', () {
    expect(() => Role.fromWire('bogus'), throwsArgumentError);
  });

  test('Role.toWire matches the wire name', () {
    expect(Role.fieldLabel.toWire(), 'fieldLabel');
    expect(Role.other.toWire(), 'other');
  });
}
