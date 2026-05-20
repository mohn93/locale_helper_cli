// packages/locale_helper_cli/lib/src/usage_scanner.dart
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:path/path.dart' as p;

class UsageScanner {
  final String rootDir;
  final List<String> typePatterns;
  final int snippetContextLines;

  UsageScanner({
    required this.rootDir,
    required this.typePatterns,
    this.snippetContextLines = 2,
  });

  Future<Map<String, List<Usage>>> scan({required Set<String> keys}) async {
    final result = <String, List<Usage>>{
      for (final k in keys) k: <Usage>[],
    };
    final libDir = Directory(p.join(rootDir, 'lib'));
    if (!libDir.existsSync()) return result;

    for (final file in libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      final unit = parseString(content: source, throwIfDiagnostics: false).unit;
      final lines = source.split('\n');
      final visitor = _UsageVisitor(
        keys: keys,
        typePatterns: typePatterns,
        filePath: p.relative(file.path, from: rootDir),
        lines: lines,
        snippetContextLines: snippetContextLines,
      );
      unit.accept(visitor);
      visitor.findings.forEach((key, usages) {
        result[key]!.addAll(usages);
      });
    }
    return result;
  }
}

class _UsageVisitor extends RecursiveAstVisitor<void> {
  final Set<String> keys;
  final List<String> typePatterns;
  final String filePath;
  final List<String> lines;
  final int snippetContextLines;
  final Map<String, List<Usage>> findings = {};

  _UsageVisitor({
    required this.keys,
    required this.typePatterns,
    required this.filePath,
    required this.lines,
    required this.snippetContextLines,
  });

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _maybeRecord(node, propertyName: node.propertyName.name);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _maybeRecord(node, propertyName: node.identifier.name);
    super.visitPrefixedIdentifier(node);
  }

  void _maybeRecord(AstNode node, {required String propertyName}) {
    if (!keys.contains(propertyName)) return;
    final text = node.toString();
    if (!typePatterns.any(text.contains)) return;

    final lineNumber = _lineFor(node.offset);
    final start = (lineNumber - snippetContextLines).clamp(1, lines.length);
    final end = (lineNumber + snippetContextLines).clamp(1, lines.length);
    final snippet = lines.sublist(start - 1, end).join('\n');
    final classNode = _enclosingClassNode(node);
    final widgetName = classNode?.name.lexeme;
    final widgetCode = classNode != null ? _extractClassSource(classNode) : null;
    findings.putIfAbsent(propertyName, () => []).add(
      Usage(
        filePath: filePath,
        lineStart: start,
        lineEnd: end,
        codeSnippet: snippet,
        surroundingWidget: widgetName,
        enclosingWidgetCode: widgetCode,
        role: _detectRole(node),
      ),
    );
  }

  static const _maxWidgetCodeLength = 4000;

  String _extractClassSource(ClassDeclaration classNode) {
    final source = lines.join('\n');
    final raw = source.substring(classNode.offset, classNode.end);
    if (raw.length <= _maxWidgetCodeLength) return raw;
    return '${raw.substring(0, _maxWidgetCodeLength)}\n// ... truncated';
  }

  int _lineFor(int offset) {
    var line = 1;
    var cursor = 0;
    for (final l in lines) {
      cursor += l.length + 1;
      if (cursor > offset) return line;
      line++;
    }
    return line;
  }

  ClassDeclaration? _enclosingClassNode(AstNode node) {
    AstNode? current = node;
    while (current != null) {
      if (current is ClassDeclaration) return current;
      current = current.parent;
    }
    return null;
  }

  /// Walk up to 6 ancestors and return the first matching [Role].
  ///
  /// Priority order (most-specific wins):
  ///   1. Named-parameter context (AppBar.title, InputDecoration.labelText, etc.)
  ///   2. Button / Dialog / Tooltip / ListTile widget wrappers
  ///   3. Plain Text wrapper
  ///   4. Role.other
  ///
  /// Named-parameter context always wins because widget-wrapper roles (Text,
  /// Button, Dialog) are checked only after all NamedExpression ancestors have
  /// been evaluated.
  Role _detectRole(AstNode node) {
    // Collect ancestors (up to 6).
    final ancestors = <AstNode>[];
    AstNode? cur = node.parent;
    while (cur != null && ancestors.length < 6) {
      ancestors.add(cur);
      cur = cur.parent;
    }

    // Pass 1: named-parameter context (highest priority).
    // A NamedExpression at position i has its containing widget at i+2.
    for (var i = 0; i < ancestors.length; i++) {
      final a = ancestors[i];
      if (a is NamedExpression) {
        final paramName = a.name.label.name;
        final widgetName = _widgetNameAt(ancestors, i + 2);
        final role = _namedParamRole(paramName, widgetName);
        if (role != null) return role;
      }
    }

    // Pass 2a: high-priority widget-invocation context (Button, Dialog).
    // These override the Text wrapper.
    for (final a in ancestors) {
      if (a is MethodInvocation) {
        final role = _widgetInvocationRoleHighPriority(a.methodName.name);
        if (role != null) return role;
      }
      if (a is InstanceCreationExpression) {
        final role = _widgetInvocationRoleHighPriority(
          a.constructorName.type.name.lexeme,
        );
        if (role != null) return role;
      }
    }

    // Pass 2b: low-priority widget-invocation context (Text).
    for (final a in ancestors) {
      if (a is MethodInvocation) {
        final n = a.methodName.name;
        final bare = n.startsWith('_') ? n.substring(1) : n;
        if (bare == 'Text') return Role.text;
      }
      if (a is InstanceCreationExpression) {
        final n = a.constructorName.type.name.lexeme;
        final bare = n.startsWith('_') ? n.substring(1) : n;
        if (bare == 'Text') return Role.text;
      }
    }

    return Role.other;
  }

  /// Returns the widget name from [ancestors] at position [index], or null.
  String? _widgetNameAt(List<AstNode> ancestors, int index) {
    if (index >= ancestors.length) return null;
    final node = ancestors[index];
    if (node is MethodInvocation) return node.methodName.name;
    if (node is InstanceCreationExpression) {
      return node.constructorName.type.name.lexeme;
    }
    return null;
  }

  /// Maps a (paramName, widgetName) pair to a [Role], or null if no match.
  Role? _namedParamRole(String paramName, String? widgetName) {
    final wn = widgetName ?? '';
    switch (paramName) {
      case 'title':
        if (_matches(wn, 'AppBar')) return Role.header;
        if (_matches(wn, 'ListTile')) return Role.listItem;
        return null;
      case 'subtitle':
        if (_matches(wn, 'ListTile')) return Role.listItem;
        return null;
      case 'labelText':
        if (_matches(wn, 'InputDecoration')) return Role.fieldLabel;
        return null;
      case 'hintText':
        if (_matches(wn, 'InputDecoration')) return Role.fieldHint;
        return null;
      case 'message':
        if (_matches(wn, 'Tooltip')) return Role.tooltip;
        return null;
      case 'label':
        if (_matches(wn, 'Semantics')) return Role.a11y;
        return null;
      case 'semanticLabel':
        return Role.a11y;
      default:
        return null;
    }
  }

  /// Maps a widget invocation name to a high-priority [Role] (Button, Dialog),
  /// or null if no match. Text is handled separately at lower priority.
  Role? _widgetInvocationRoleHighPriority(String name) {
    // Strip leading underscores (shim prefix) for matching.
    final n = name.startsWith('_') ? name.substring(1) : name;

    if (_endsWithAny(n, const [
      'ElevatedButton',
      'TextButton',
      'FilledButton',
      'OutlinedButton',
      'IconButton',
      'MaterialButton',
    ])) {
      return Role.button;
    }
    if (n.contains('Dialog') || n == 'SnackBar') return Role.dialog;
    return null;
  }

  bool _matches(String widgetName, String suffix) {
    final n = widgetName.startsWith('_') ? widgetName.substring(1) : widgetName;
    return n == suffix || n.endsWith(suffix);
  }

  bool _endsWithAny(String name, List<String> suffixes) {
    return suffixes.any((s) => name == s || name.endsWith(s));
  }
}
