import 'package:locale_helper_shared/src/icu.dart';
import 'package:test/test.dart';

void main() {
  group('IcuMessage.parse — plain', () {
    test('plain text with no placeholders', () {
      final m = IcuMessage.parse('Hello');
      expect(m, isA<PlainMessage>());
      final p = m as PlainMessage;
      expect(p.segments, hasLength(1));
      expect(p.segments.first, isA<TextSegment>());
      expect((p.segments.first as TextSegment).text, 'Hello');
    });

    test('plain text with one placeholder', () {
      final m = IcuMessage.parse('Hello, {name}!');
      expect(m, isA<PlainMessage>());
      final p = m as PlainMessage;
      expect(p.segments, hasLength(3));
      expect((p.segments[0] as TextSegment).text, 'Hello, ');
      expect((p.segments[1] as PlaceholderSegment).name, 'name');
      expect((p.segments[2] as TextSegment).text, '!');
    });

    test('two adjacent placeholders', () {
      final m = IcuMessage.parse('{a}{b}');
      final p = m as PlainMessage;
      expect(p.segments, hasLength(2));
      expect((p.segments[0] as PlaceholderSegment).name, 'a');
      expect((p.segments[1] as PlaceholderSegment).name, 'b');
    });

    test('empty string', () {
      final m = IcuMessage.parse('');
      expect((m as PlainMessage).segments, isEmpty);
    });
  });

  group('IcuMessage.parse — plural', () {
    test('simple plural with one + other', () {
      final m = IcuMessage.parse(
          '{count, plural, one {{count} item} other {{count} items}}',);
      expect(m, isA<PluralMessage>());
      final p = m as PluralMessage;
      expect(p.variable, 'count');
      expect(p.exactForms, isEmpty);
      expect(p.keywordForms.keys, ['one', 'other']);
      final one = p.keywordForms['one']!;
      expect(one.segments, hasLength(2));
      expect((one.segments[0] as PlaceholderSegment).name, 'count');
      expect((one.segments[1] as TextSegment).text, ' item');
    });

    test('plural with =0 exact match and CLDR forms', () {
      final m = IcuMessage.parse(
          '{count, plural, =0 {No items} one {{count} item} other {{count} items}}',);
      final p = m as PluralMessage;
      expect(p.exactForms.keys, [0]);
      final zero = p.exactForms[0]!;
      expect(zero.segments, hasLength(1));
      expect((zero.segments[0] as TextSegment).text, 'No items');
    });

    test('plural with multiple =N exact matches', () {
      final m = IcuMessage.parse(
          '{n, plural, =0 {zero} =1 {one literal} =42 {forty two} other {other}}',);
      final p = m as PluralMessage;
      expect(p.exactForms.keys, containsAll([0, 1, 42]));
      expect(p.exactForms[42]!.toIcu(), 'forty two');
    });

    test('select message returns UnsupportedMessage', () {
      final m = IcuMessage.parse(
          '{g, select, male {He} female {She} other {They}}',);
      expect(m, isA<UnsupportedMessage>());
    });
  });

  group('IcuMessage round-trip', () {
    test('plain round-trips', () {
      const s = 'Hello, {name}! You have {count} items.';
      expect(IcuMessage.parse(s).toIcu(), s);
    });

    test('plural round-trips with exact + keyword forms', () {
      final p = PluralMessage(
        variable: 'count',
        exactForms: {
          0: PlainMessage([TextSegment('No items')]),
          1: PlainMessage([TextSegment('One item special')]),
        },
        keywordForms: {
          'one': PlainMessage([
            PlaceholderSegment('count'),
            TextSegment(' item'),
          ]),
          'other': PlainMessage([
            PlaceholderSegment('count'),
            TextSegment(' items'),
          ]),
        },
      );
      const expected =
          '{count, plural, =0 {No items} =1 {One item special} one {{count} item} other {{count} items}}';
      expect(p.toIcu(), expected);
    });

    test('parse(toIcu(p)) == p for a normalised plural', () {
      const s =
          '{count, plural, =0 {No items} one {{count} item} other {{count} items}}';
      final reparsed = IcuMessage.parse(IcuMessage.parse(s).toIcu());
      expect(reparsed, isA<PluralMessage>());
      expect(reparsed.toIcu(), s);
    });
  });
}
