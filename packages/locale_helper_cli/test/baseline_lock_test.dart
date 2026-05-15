// packages/locale_helper_cli/test/baseline_lock_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:locale_helper_cli/src/baseline_lock.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('baseline_lock_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('read() returns null when no file exists', () {
    final result = BaselineLock.read(tmp.path);
    expect(result, isNull);
  });

  test('write() creates .locale_helper/ directory and JSON file', () {
    final dir = Directory(p.join(tmp.path, '.locale_helper'));
    expect(dir.existsSync(), isFalse);

    BaselineLock.write(tmp.path, {'hello': 'Hello'});

    expect(dir.existsSync(), isTrue);
    final file = File(BaselineLock.pathFor(tmp.path));
    expect(file.existsSync(), isTrue);
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    // New nested shape: {locale: {key: value}}.
    expect(decoded['values'], {
      'en': {'hello': 'Hello'},
    });
    expect(decoded['updatedAt'], isA<String>());
    // Must parse as an ISO-8601 timestamp.
    expect(() => DateTime.parse(decoded['updatedAt'] as String), returnsNormally);
  });

  test('round-trip: write then read returns same values', () {
    final values = {
      'greeting': 'Hello world',
      'farewell': 'Goodbye',
      'empty': '',
    };
    BaselineLock.write(tmp.path, values);

    final read = BaselineLock.read(tmp.path);
    expect(read, isNotNull);
    expect(read!.values, values);
    expect(read.updatedAt, isA<DateTime>());
  });

  test('write() overwrites existing file', () {
    BaselineLock.write(tmp.path, {'k': 'v1'});
    final firstRead = BaselineLock.read(tmp.path);
    expect(firstRead!.values, {'k': 'v1'});

    BaselineLock.write(tmp.path, {'k': 'v2', 'extra': 'value'});
    final secondRead = BaselineLock.read(tmp.path);
    expect(secondRead!.values, {'k': 'v2', 'extra': 'value'});
  });
}
