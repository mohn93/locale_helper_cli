// packages/locale_helper_shared/lib/src/role.dart
enum Role {
  text,
  button,
  fieldLabel,
  fieldHint,
  header,
  listItem,
  dialog,
  tooltip,
  a11y,
  other;

  String toWire() => name;

  static Role fromWire(String s) {
    for (final v in Role.values) {
      if (v.name == s) return v;
    }
    throw ArgumentError.value(s, 'Role', 'unknown value');
  }
}
