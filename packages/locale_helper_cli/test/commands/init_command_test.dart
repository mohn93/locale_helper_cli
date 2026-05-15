// packages/locale_helper_cli/test/commands/init_command_test.dart
import 'dart:io';

import 'package:locale_helper_cli/src/commands/init_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('init_cmd_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  String gitignorePath() => p.join(tmp.path, '.gitignore');

  test('creates .gitignore with .locale_helper/ when none exists', () {
    expect(File(gitignorePath()).existsSync(), isFalse);

    InitCommand.ensureGitignored(tmp.path);

    final body = File(gitignorePath()).readAsStringSync();
    expect(body, contains('.locale_helper/'));
    // Ensure the entry is on its own line.
    final lines = body.split('\n').map((l) => l.trim()).toList();
    expect(lines, contains('.locale_helper/'));
  });

  test('appends .locale_helper/ when gitignore exists but lacks it', () {
    File(gitignorePath()).writeAsStringSync('build/\n*.log\n');

    InitCommand.ensureGitignored(tmp.path);

    final body = File(gitignorePath()).readAsStringSync();
    expect(body, contains('build/'));
    expect(body, contains('*.log'));
    expect(body, contains('.locale_helper/'));
    // Marker exists on its own line.
    final lines = body.split('\n').map((l) => l.trim()).toList();
    expect(lines, contains('.locale_helper/'));
  });

  test('is idempotent: does not duplicate when entry already present', () {
    File(gitignorePath()).writeAsStringSync('build/\n.locale_helper/\n*.log\n');
    final before = File(gitignorePath()).readAsStringSync();

    InitCommand.ensureGitignored(tmp.path);
    InitCommand.ensureGitignored(tmp.path);

    final after = File(gitignorePath()).readAsStringSync();
    expect(after, equals(before));
    // Exactly one occurrence of `.locale_helper/` line.
    final matches = '\n$after'.split('\n').where((l) => l.trim() == '.locale_helper/').length;
    expect(matches, 1);
  });

  test('preserves existing gitignore content when appending', () {
    const original = 'node_modules/\nbuild/\n.dart_tool/\n';
    File(gitignorePath()).writeAsStringSync(original);

    InitCommand.ensureGitignored(tmp.path);

    final body = File(gitignorePath()).readAsStringSync();
    expect(body.startsWith(original), isTrue,
        reason: 'Original content should be preserved verbatim at the top');
    expect(body, contains('.locale_helper/'));
  });

  test('handles gitignore that lacks a trailing newline', () {
    // No trailing newline — production code must insert one before appending.
    File(gitignorePath()).writeAsStringSync('build/');

    InitCommand.ensureGitignored(tmp.path);

    final body = File(gitignorePath()).readAsStringSync();
    final lines = body.split('\n').map((l) => l.trim()).toList();
    expect(lines, contains('build/'));
    expect(lines, contains('.locale_helper/'));
  });
}
