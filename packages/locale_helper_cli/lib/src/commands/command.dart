// packages/locale_helper_cli/lib/src/commands/command.dart
abstract class CliCommand {
  String get name;
  String get description;
  Future<int> run(List<String> args);
}
