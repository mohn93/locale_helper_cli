// packages/locale_helper_cli/bin/locale_helper.dart
import 'dart:io';

import 'package:locale_helper_cli/src/commands/init_command.dart';
import 'package:locale_helper_cli/src/commands/login_command.dart';
import 'package:locale_helper_cli/src/commands/logout_command.dart';
import 'package:locale_helper_cli/src/commands/publish_command.dart';
import 'package:locale_helper_cli/src/commands/pull_command.dart';
import 'package:locale_helper_cli/src/commands/signup_command.dart';
import 'package:locale_helper_cli/src/commands/status_command.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
        'Usage: locale_helper <signup|login|logout|init|publish|pull|status>',);
    exit(64);
  }
  final cmd = args.first;
  final rest = args.skip(1).toList();
  final exitCode = switch (cmd) {
    'signup' => await SignupCommand().run(rest),
    'login' => await LoginCommand().run(rest),
    'logout' => await LogoutCommand().run(rest),
    'init' => await InitCommand().run(rest),
    'publish' => await PublishCommand().run(rest),
    'pull' => await PullCommand().run(rest),
    'status' => await StatusCommand().run(rest),
    _ => () {
        stderr.writeln('Unknown command: $cmd');
        return 64;
      }(),
  };
  exit(exitCode);
}
