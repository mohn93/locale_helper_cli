// packages/locale_helper_shared/test/arb_test.dart
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:test/test.dart';

void main() {
  test('parseArb preserves key order', () {
    final src = '''
{
  "@@locale": "en",
  "first": "First",
  "second": "Second",
  "@second": {"description": "Second value"},
  "third": "Third"
}
''';
    final arb = ArbFile.parse(src);
    expect(arb.keysInOrder, ['first', 'second', 'third']);
    expect(arb.locale, 'en');
    expect(arb.value('first'), 'First');
    expect(arb.metadata('second'), {'description': 'Second value'});
  });

  test('toJsonString applies replacements and preserves order + metadata', () {
    final src = '''
{
  "@@locale": "en",
  "first": "First",
  "@first": {"description": "Top"},
  "second": "Second"
}
''';
    final arb = ArbFile.parse(src).withReplacements({'first': 'FIRST'});
    final out = arb.toJsonString();

    final firstIndex = out.indexOf('"first"');
    final secondIndex = out.indexOf('"second"');
    expect(firstIndex, lessThan(secondIndex));
    expect(out, contains('"first": "FIRST"'));
    expect(out, contains('"@first"'));
    expect(out, contains('"description": "Top"'));
    expect(out, contains('"@@locale": "en"'));
  });
}
