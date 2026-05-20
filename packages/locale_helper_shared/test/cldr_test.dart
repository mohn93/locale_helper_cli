import 'package:locale_helper_shared/src/cldr.dart';
import 'package:test/test.dart';

void main() {
  group('cldrFormsFor', () {
    test('English: one, other', () {
      expect(cldrFormsFor('en'), ['one', 'other']);
    });

    test('Arabic: zero, one, two, few, many, other', () {
      expect(cldrFormsFor('ar'),
          ['zero', 'one', 'two', 'few', 'many', 'other'],);
    });

    test('Russian: one, few, many, other', () {
      expect(cldrFormsFor('ru'), ['one', 'few', 'many', 'other']);
    });

    test('Japanese: other only', () {
      expect(cldrFormsFor('ja'), ['other']);
    });

    test('French: one, many, other', () {
      // French uses `many` for compact-decimal forms in CLDR v40+.
      expect(cldrFormsFor('fr'), ['one', 'many', 'other']);
    });

    test('Unknown locale falls back to one, other', () {
      expect(cldrFormsFor('xx-YY'), ['one', 'other']);
    });

    test('Region-tagged locale matches base language', () {
      expect(cldrFormsFor('en-US'), ['one', 'other']);
      expect(cldrFormsFor('en_US'), ['one', 'other']);
    });
  });
}
