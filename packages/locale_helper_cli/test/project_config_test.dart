// packages/locale_helper_cli/test/project_config_test.dart
import 'dart:io';
import 'package:locale_helper_cli/src/project_config.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('cfg_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('writes and reads config', () {
    final cfg = ProjectConfig(
      backendUrl: 'https://x',
      arbGlob: 'lib/l10n/*.arb',
      sourceLocale: 'en',
    );
    final path = '${tmp.path}/.locale_helper.yaml';
    cfg.writeTo(path);
    final loaded = ProjectConfig.load(path);
    expect(loaded.backendUrl, 'https://x');
    expect(loaded.arbGlob, 'lib/l10n/*.arb');
    expect(loaded.sourceLocale, 'en');
    expect(loaded.projectId, isNull);
  });

  test('updateAfterPublish preserves other fields and writes projectId', () {
    final cfg = ProjectConfig(
      backendUrl: 'https://x',
      arbGlob: 'lib/l10n/*.arb',
      sourceLocale: 'en',
    );
    final path = '${tmp.path}/.locale_helper.yaml';
    cfg.writeTo(path);
    ProjectConfig.updateAfterPublish(path, projectId: 'p1');
    final loaded = ProjectConfig.load(path);
    expect(loaded.projectId, 'p1');
    expect(loaded.backendUrl, 'https://x');
  });

  test('writes and reads projectName field', () {
    final cfg = ProjectConfig(
      backendUrl: 'https://x',
      arbGlob: 'lib/l10n/*.arb',
      sourceLocale: 'en',
      projectName: 'my-app',
    );
    final path = '${tmp.path}/.locale_helper.yaml';
    cfg.writeTo(path);
    final loaded = ProjectConfig.load(path);
    expect(loaded.projectName, 'my-app');
  });

  test('projectName falls back to directory basename when absent', () {
    final cfg = ProjectConfig(
      backendUrl: 'https://x',
      arbGlob: 'lib/l10n/*.arb',
      sourceLocale: 'en',
    );
    final path = '${tmp.path}/.locale_helper.yaml';
    cfg.writeTo(path);
    // load without projectName field → null stored value
    final loaded = ProjectConfig.load(path);
    expect(loaded.projectName, isNull);
  });

  test('updateAfterPublish only writes projectId after v2', () {
    final cfg = ProjectConfig(
      backendUrl: 'https://x',
      arbGlob: 'lib/l10n/*.arb',
      sourceLocale: 'en',
    );
    final path = '${tmp.path}/.locale_helper.yaml';
    cfg.writeTo(path);
    ProjectConfig.updateAfterPublish(path, projectId: 'p2');
    final loaded = ProjectConfig.load(path);
    expect(loaded.projectId, 'p2');
    expect(loaded.backendUrl, 'https://x');
  });
}
