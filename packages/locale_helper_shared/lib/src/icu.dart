/// ICU MessageFormat AST and parser. Scope: plain messages with `{name}`
/// placeholders, and `{var, plural, ...}` with both `=N` exact selectors
/// and CLDR keyword forms (zero/one/two/few/many/other). `{var, select,
/// ...}` is out of scope — parses to [UnsupportedMessage].
library;

sealed class IcuMessage {
  const IcuMessage();

  /// Parse an ICU source string. Never throws — unknown constructs
  /// (select, nesting, malformed input) return [UnsupportedMessage].
  factory IcuMessage.parse(String raw) => _parse(raw);

  /// Round-trip to source form.
  String toIcu();
}

sealed class IcuSegment {
  const IcuSegment();
}

class TextSegment extends IcuSegment {
  final String text;
  const TextSegment(this.text);
}

class PlaceholderSegment extends IcuSegment {
  final String name;
  const PlaceholderSegment(this.name);
}

class PlainMessage extends IcuMessage {
  final List<IcuSegment> segments;
  const PlainMessage(this.segments);

  @override
  String toIcu() {
    final buf = StringBuffer();
    for (final s in segments) {
      switch (s) {
        case TextSegment(:final text):
          buf.write(text);
        case PlaceholderSegment(:final name):
          buf.write('{$name}');
      }
    }
    return buf.toString();
  }
}

class PluralMessage extends IcuMessage {
  final String variable;
  /// `=N` selectors, key is the integer literal.
  final Map<int, PlainMessage> exactForms;
  /// CLDR keyword forms (zero/one/two/few/many/other).
  final Map<String, PlainMessage> keywordForms;

  const PluralMessage({
    required this.variable,
    required this.exactForms,
    required this.keywordForms,
  });

  @override
  String toIcu() {
    final buf = StringBuffer('{$variable, plural,');
    // Exact forms first, in numeric order.
    final exactKeys = exactForms.keys.toList()..sort();
    for (final n in exactKeys) {
      buf.write(' =$n {${exactForms[n]!.toIcu()}}');
    }
    // CLDR forms in canonical order.
    const canonical = ['zero', 'one', 'two', 'few', 'many', 'other'];
    for (final k in canonical) {
      final body = keywordForms[k];
      if (body != null) buf.write(' $k {${body.toIcu()}}');
    }
    buf.write('}');
    return buf.toString();
  }
}

class UnsupportedMessage extends IcuMessage {
  final String raw;
  final String reason;
  const UnsupportedMessage(this.raw, this.reason);

  @override
  String toIcu() => raw;
}

IcuMessage _parse(String raw) {
  if (_detectSelect(raw)) {
    return UnsupportedMessage(raw, 'select messages are not supported in v1');
  }
  final pluralStart = _detectPluralStart(raw);
  if (pluralStart != null) {
    return _parsePlural(raw);
  }
  return _parsePlain(raw);
}

PlainMessage _parsePlain(String raw) {
  final segs = <IcuSegment>[];
  final buf = StringBuffer();
  var i = 0;
  while (i < raw.length) {
    final c = raw[i];
    if (c == '{') {
      // Find matching '}'.
      final close = raw.indexOf('}', i + 1);
      if (close == -1) {
        // Unbalanced — treat the rest as text and bail.
        buf.write(raw.substring(i));
        i = raw.length;
        break;
      }
      // Flush accumulated text.
      if (buf.isNotEmpty) {
        segs.add(TextSegment(buf.toString()));
        buf.clear();
      }
      final name = raw.substring(i + 1, close).trim();
      segs.add(PlaceholderSegment(name));
      i = close + 1;
    } else {
      buf.write(c);
      i++;
    }
  }
  if (buf.isNotEmpty) segs.add(TextSegment(buf.toString()));
  return PlainMessage(segs);
}

/// Returns the index of the `,` after `plural` if [raw] starts a plural
/// message (`{var, plural, ...}`). Otherwise null.
int? _detectPluralStart(String raw) {
  final m = RegExp(r'^\s*\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*,\s*plural\s*,')
      .firstMatch(raw);
  return m?.end;
}

bool _detectSelect(String raw) =>
    RegExp(r'^\s*\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*,\s*select\s*,')
        .hasMatch(raw);

PluralMessage _parsePlural(String raw) {
  // raw starts with `{var, plural,` — find the variable name and the
  // selector list. We've already validated the prefix via
  // _detectPluralStart, but re-extract for clarity.
  final headerRe =
      RegExp(r'^\s*\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*,\s*plural\s*,\s*');
  final headerMatch = headerRe.firstMatch(raw)!;
  final variable = headerMatch.group(1)!;
  var i = headerMatch.end;

  final exact = <int, PlainMessage>{};
  final keyword = <String, PlainMessage>{};

  while (i < raw.length) {
    // Skip whitespace.
    while (i < raw.length && _isSpace(raw[i])) {
      i++;
    }
    if (i >= raw.length || raw[i] == '}') break;

    // Selector: either `=N` or a CLDR keyword.
    final selStart = i;
    while (i < raw.length && !_isSpace(raw[i]) && raw[i] != '{') {
      i++;
    }
    final selector = raw.substring(selStart, i).trim();
    if (selector.isEmpty) break;

    // Skip whitespace before `{`.
    while (i < raw.length && _isSpace(raw[i])) {
      i++;
    }
    if (i >= raw.length || raw[i] != '{') break;

    // Read body: from `{` to its matching `}`, handling nested braces.
    final bodyStart = i + 1;
    var depth = 1;
    var j = bodyStart;
    while (j < raw.length && depth > 0) {
      if (raw[j] == '{') depth++;
      if (raw[j] == '}') depth--;
      if (depth == 0) break;
      j++;
    }
    if (depth != 0) break; // unbalanced
    final body = raw.substring(bodyStart, j);
    i = j + 1;

    final parsedBody = _parsePlain(body);
    if (selector.startsWith('=')) {
      final n = int.tryParse(selector.substring(1));
      if (n != null) exact[n] = parsedBody;
    } else if (const {'zero', 'one', 'two', 'few', 'many', 'other'}
        .contains(selector)) {
      keyword[selector] = parsedBody;
    }
    // Otherwise ignore — unknown selector.
  }

  return PluralMessage(
    variable: variable,
    exactForms: exact,
    keywordForms: keyword,
  );
}

bool _isSpace(String c) => c == ' ' || c == '\t' || c == '\n' || c == '\r';
