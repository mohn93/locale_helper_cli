/// Returns the CLDR plural keyword forms required by [locale], in
/// canonical order (zero, one, two, few, many, other).
///
/// The table covers the common base languages; uncommon ones fall back
/// to `['one', 'other']`. Locale strings can be base codes (`'en'`),
/// hyphen-tagged (`'en-US'`), or underscore-tagged (`'en_US'`) — only
/// the base language is consulted.
List<String> cldrFormsFor(String locale) {
  final base = locale
      .replaceAll('_', '-')
      .split('-')
      .first
      .toLowerCase();
  return _table[base] ?? const ['one', 'other'];
}

/// True when [locale]'s script is right-to-left. Covers the common RTL
/// base languages (Arabic, Hebrew, Persian, Urdu, Pashto, Sindhi,
/// Kurdish, Dhivehi, Yiddish). Region tags are ignored.
bool isRtlLocale(String locale) {
  final base = locale
      .replaceAll('_', '-')
      .split('-')
      .first
      .toLowerCase();
  return const {'ar', 'he', 'fa', 'ur', 'ps', 'sd', 'ku', 'dv', 'yi', 'iw'}
      .contains(base);
}

const Map<String, List<String>> _table = {
  // Two forms — one + other
  'en': ['one', 'other'],
  'de': ['one', 'other'],
  'es': ['one', 'other'],
  'it': ['one', 'other'],
  'nl': ['one', 'other'],
  'pt': ['one', 'other'],
  'sv': ['one', 'other'],
  'da': ['one', 'other'],
  'no': ['one', 'other'],
  'nb': ['one', 'other'],
  'fi': ['one', 'other'],
  'el': ['one', 'other'],
  'tr': ['one', 'other'],
  'he': ['one', 'other'],
  'hu': ['one', 'other'],

  // One form — `other` only
  'id': ['other'],
  'ja': ['other'],
  'ko': ['other'],
  'th': ['other'],
  'vi': ['other'],
  'zh': ['other'],

  // French — uses `many` for compact decimals (CLDR v40+).
  'fr': ['one', 'many', 'other'],

  // Four forms — Polish/Russian-style
  'pl': ['one', 'few', 'many', 'other'],
  'ru': ['one', 'few', 'many', 'other'],
  'uk': ['one', 'few', 'many', 'other'],
  'be': ['one', 'few', 'many', 'other'],
  'cs': ['one', 'few', 'many', 'other'],
  'sk': ['one', 'few', 'many', 'other'],

  // Romanian — three forms
  'ro': ['one', 'few', 'other'],

  // Arabic — full six-form set
  'ar': ['zero', 'one', 'two', 'few', 'many', 'other'],

  // Welsh — six forms too
  'cy': ['zero', 'one', 'two', 'few', 'many', 'other'],
};
