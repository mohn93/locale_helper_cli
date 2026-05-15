// packages/locale_helper_cli/lib/src/project_config.dart
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

class ProjectConfig {
  final String backendUrl;

  /// Glob pattern matching the project's ARB files, e.g. `lib/l10n/app_*.arb`.
  /// Used by the publish/pull commands to discover every locale at once.
  ///
  /// On disk this is stored as `arb_pattern`. For backwards compatibility,
  /// configs written by older versions used `arb_glob` (a single-file path);
  /// when reading we accept either key and treat the legacy single-file value
  /// as the pattern unchanged.
  final String arbPattern;
  final String sourceLocale;
  final String? projectId;
  final String? projectName;

  ProjectConfig({
    required this.backendUrl,
    String? arbPattern,
    @Deprecated('Use arbPattern') String? arbGlob,
    required this.sourceLocale,
    this.projectId,
    this.projectName,
  })  : assert(arbPattern != null || arbGlob != null,
            'Either arbPattern or arbGlob must be provided'),
        arbPattern = arbPattern ?? arbGlob!;

  /// Backwards-compatible getter for callers that still reference `arbGlob`.
  @Deprecated('Use arbPattern')
  String get arbGlob => arbPattern;

  static const defaultPath = '.locale_helper.yaml';

  static ProjectConfig load(String path) {
    final source = File(path).readAsStringSync();
    final yaml = loadYaml(source) as Map;
    // Accept both new (`arb_pattern`) and legacy (`arb_glob`) keys.
    final pattern = (yaml['arb_pattern'] as String?) ??
        (yaml['arb_glob'] as String?);
    if (pattern == null) {
      throw FormatException(
        'Project config at $path is missing `arb_pattern` (or legacy `arb_glob`).',
      );
    }
    return ProjectConfig(
      backendUrl: yaml['backend_url'] as String,
      arbPattern: pattern,
      sourceLocale: yaml['source_locale'] as String,
      projectId: yaml['project_id'] as String?,
      projectName: yaml['project_name'] as String?,
    );
  }

  void writeTo(String path) {
    final buf = StringBuffer()
      ..writeln('# locale_helper project config')
      ..writeln('backend_url: $backendUrl')
      ..writeln('arb_pattern: $arbPattern')
      ..writeln('source_locale: $sourceLocale');
    if (projectId != null) buf.writeln('project_id: $projectId');
    if (projectName != null) buf.writeln('project_name: $projectName');
    File(path).writeAsStringSync(buf.toString());
  }

  static void updateAfterPublish(
    String path, {
    required String projectId,
  }) {
    final editor = YamlEditor(File(path).readAsStringSync())
      ..update(['project_id'], projectId);
    File(path).writeAsStringSync(editor.toString());
  }
}
