// packages/locale_helper_shared/lib/src/string_entry.dart
import 'package:meta/meta.dart';
import 'review_state_dto.dart';
import 'role.dart';
import 'usage.dart';

enum IcuKind {
  plain,
  placeholder,
  plural,
  unsupported;

  static IcuKind fromWire(String? s) {
    return switch (s) {
      'placeholder' => IcuKind.placeholder,
      'plural' => IcuKind.plural,
      'unsupported' => IcuKind.unsupported,
      _ => IcuKind.plain,
    };
  }

  String toWire() => name;
}

class PlaceholderMeta {
  final String name;

  /// Type hint from the source ARB's `@key.placeholders` (e.g. 'int',
  /// 'String', 'DateTime'). Null when unspecified.
  final String? type;
  const PlaceholderMeta({required this.name, this.type});

  Map<String, dynamic> toJson() => {
        'name': name,
        if (type != null) 'type': type,
      };

  factory PlaceholderMeta.fromJson(Map<String, dynamic> json) =>
      PlaceholderMeta(
        name: json['name'] as String,
        type: json['type'] as String?,
      );
}

/// One string in the bundle. The string lives in every locale the project
/// tracks; `values` maps locale → translation. A locale may map to null when
/// no translation exists yet (the reviewer is being asked to translate from
/// scratch).
///
/// `sourceValue` is a convenience accessor for `values[sourceLocale]` and is
/// also serialized in the JSON for backwards compatibility — older clients
/// that don't know about `values` keep working.
@immutable
class StringEntry {
  final String key;
  final Map<String, String?> values;
  final Map<String, dynamic> arbMetadata;
  final List<Usage> usages;
  final String? aiDescription;
  final Role role;
  final ReviewStateDto? myReviewState;
  final int? commentCount;
  final IcuKind icuKind;
  final Map<String, PlaceholderMeta> placeholders;

  /// The locale that this entry treats as canonical (for `sourceValue`).
  /// Carried so DTOs round-trip cleanly without needing to thread the
  /// bundle's sourceLocale through every call site.
  final String sourceLocale;

  const StringEntry({
    required this.key,
    required this.sourceLocale,
    required this.values,
    this.arbMetadata = const {},
    this.usages = const [],
    this.aiDescription,
    this.role = Role.other,
    this.myReviewState,
    this.commentCount,
    this.icuKind = IcuKind.plain,
    this.placeholders = const {},
  });

  String get sourceValue => values[sourceLocale] ?? '';

  String? valueFor(String locale) => values[locale];

  factory StringEntry.fromJson(
    Map<String, dynamic> json, {
    required String sourceLocale,
  }) {
    final raw = json['arbMetadata'];
    final metadata = raw is Map
        ? Map<String, dynamic>.from(raw.cast<String, dynamic>())
        : const <String, dynamic>{};
    final reviewRaw = json['myReviewState'];
    final valuesRaw = json['values'];
    Map<String, String?> values;
    if (valuesRaw is Map) {
      values = {
        for (final e in valuesRaw.entries)
          e.key as String: e.value as String?,
      };
    } else {
      // Legacy bundle.json without `values` map — synthesize one with just
      // the source locale.
      values = {sourceLocale: json['sourceValue'] as String?};
    }
    return StringEntry(
      key: json['key'] as String,
      sourceLocale: sourceLocale,
      values: values,
      arbMetadata: metadata,
      usages: ((json['usages'] as List?) ?? const [])
          .map((u) => Usage.fromJson((u as Map).cast<String, dynamic>()))
          .toList(growable: false),
      aiDescription: json['aiDescription'] as String?,
      role: json['role'] is String
          ? Role.fromWire(json['role'] as String)
          : Role.other,
      myReviewState: reviewRaw is Map
          ? ReviewStateDto.fromJson((reviewRaw).cast<String, dynamic>())
          : null,
      commentCount: json['commentCount'] as int?,
      icuKind: IcuKind.fromWire(json['icuKind'] as String?),
      placeholders: (json['placeholders'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(
                  k, PlaceholderMeta.fromJson(v as Map<String, dynamic>),),) ??
          const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'sourceValue': sourceValue,
        'values': values,
        if (arbMetadata.isNotEmpty) 'arbMetadata': arbMetadata,
        'usages': usages.map((u) => u.toJson()).toList(growable: false),
        if (aiDescription != null) 'aiDescription': aiDescription,
        'role': role.toWire(),
        if (myReviewState != null) 'myReviewState': myReviewState!.toJson(),
        if (commentCount != null) 'commentCount': commentCount,
        if (icuKind != IcuKind.plain) 'icuKind': icuKind.toWire(),
        if (placeholders.isNotEmpty)
          'placeholders': {
            for (final e in placeholders.entries) e.key: e.value.toJson(),
          },
      };

  StringEntry copyWith({
    Map<String, String?>? values,
    String? sourceValue,
    String? aiDescription,
    Role? role,
    ReviewStateDto? myReviewState,
    int? commentCount,
    IcuKind? icuKind,
    Map<String, PlaceholderMeta>? placeholders,
  }) {
    Map<String, String?> nextValues;
    if (values != null) {
      nextValues = values;
    } else if (sourceValue != null) {
      nextValues = {...this.values, sourceLocale: sourceValue};
    } else {
      nextValues = this.values;
    }
    return StringEntry(
      key: key,
      sourceLocale: sourceLocale,
      values: nextValues,
      arbMetadata: arbMetadata,
      usages: usages,
      aiDescription: aiDescription ?? this.aiDescription,
      role: role ?? this.role,
      myReviewState: myReviewState ?? this.myReviewState,
      commentCount: commentCount ?? this.commentCount,
      icuKind: icuKind ?? this.icuKind,
      placeholders: placeholders ?? this.placeholders,
    );
  }

  /// Returns a new entry with `values[locale] = value`. If [value] is empty,
  /// stores null instead so "empty" and "missing" share one representation.
  StringEntry withLocaleValue(String locale, String? value) {
    final normalized = (value == null || value.isEmpty) ? null : value;
    return copyWith(values: {...values, locale: normalized});
  }
}
