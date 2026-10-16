// Run from the repository root with the app's existing package configuration:
// dart --packages=workout-logger/.dart_tool/package_config.json scripts/index_dart_functions.dart
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class DeclarationIndex extends RecursiveAstVisitor<void> {
  DeclarationIndex(this.lineAt);
  final int Function(int) lineAt;
  final entries = <String>[];
  String owner(AstNode node) {
    final parent = node.parent;
    if (parent is ClassDeclaration) return '${parent.name.lexeme}.';
    if (parent is EnumDeclaration) return '${parent.name.lexeme}.';
    if (parent is MixinDeclaration) return '${parent.name.lexeme}.';
    if (parent is ExtensionDeclaration) return '${parent.name?.lexeme ?? '(extension)' }.';
    return '';
  }

  void add(AstNode node, String kind, String name) {
    entries.add('| ${lineAt(node.offset)} | $kind | `$name` |');
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    add(node, node.isGetter ? 'getter' : node.isSetter ? 'setter' : 'function', node.name.lexeme);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    add(node, node.isGetter ? 'getter' : node.isSetter ? 'setter' : 'method', '${owner(node)}${node.name.lexeme}');
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final suffix = node.name == null ? '' : '.${node.name!.lexeme}';
    add(node, 'constructor', '${node.returnType}$suffix');
    super.visitConstructorDeclaration(node);
  }
}

void main() {
  final files = Directory('workout-logger/lib').listSync(recursive: true)
      .whereType<File>().where((f) => f.path.endsWith('.dart')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final body = StringBuffer();
  var declarations = 0;
  var parseErrors = 0;
  for (final file in files) {
    final result = parseString(content: file.readAsStringSync(), path: file.path, throwIfDiagnostics: false);
    parseErrors += result.errors.length;
    final index = DeclarationIndex((offset) => result.lineInfo.getLocation(offset).lineNumber);
    result.unit.accept(index);
    declarations += index.entries.length;
    body.writeln('\n## ${file.path.replaceAll('\\', '/')}\n');
    body.writeln('| Line | Kind | Declaration |\n|---|---|---|');
    body.writeln(index.entries.join('\n'));
  }
  final output = File('docs/SOURCE_FUNCTION_INDEX_2026-10-16.md');
  output.writeAsStringSync('# RepForge source function index\n\n'
      'Generated from the current Dart AST on 16 October 2026: ${files.length} library files, '
      '$declarations named functions, methods, getters/setters and constructors. '
      'Includes private helpers and interface declarations; excludes anonymous closures and implicit constructors. '
      'Line numbers refer to the source at generation time. This is a declaration inventory, not proof of runtime behavior. '
      'See [the capability analysis](APP_CAPABILITIES_AND_ICON_2026-10-16.md) for the feature and data flow review.\n'
      '$body');
  stdout.writeln('${files.length} files; $declarations declarations; $parseErrors parser diagnostics. Wrote ${output.path}.');
  if (parseErrors != 0) exitCode = 1;
}
