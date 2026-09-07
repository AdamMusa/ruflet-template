import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

enum Design { material, cupertino }

/// A conservative *owned-source* import/export audit, not a Dart linker or a
/// proof about third-party packages. Every local edge is followed, including
/// exports, conditional alternatives, unused imports and protocol-registry
/// cycles. The only executable edge pruned is one whose entire imported-symbol
/// use is inside the other design's proven lazy dispatcher branch.
class PlatformDependencyGraph {
  PlatformDependencyGraph(this.sources, {this.packageName = 'ruflet'}) {
    for (final entry in sources.entries) {
      final result = parseString(content: entry.value, path: entry.key);
      if (result.errors.isNotEmpty) {
        throw FormatException('${entry.key}: ${result.errors.join(', ')}');
      }
      units[entry.key] = result.unit;
    }
  }

  factory PlatformDependencyGraph.read(Directory directory) {
    final sources = <String, String>{};
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      if (file.path.endsWith('.dart')) {
        sources[p.posix
                .join('lib', p.relative(file.path, from: directory.path))] =
            file.readAsStringSync();
      }
    }
    return PlatformDependencyGraph(sources);
  }

  final Map<String, String> sources;
  final String packageName;
  final Map<String, CompilationUnit> units = {};
  final Map<String, Set<String>> _symbols = {};
  final Set<String> externalDependencies = {};
  final Set<String> prunedBranches = {};
  final Set<String> iconDataLibraries = {};

  static const _renderer = 'lib/src/widgets/platform_control_renderer.dart';
  static const _pageDesign = 'lib/src/models/page_design.dart';
  static const _platformDesign = 'lib/src/widgets/platform_design.dart';

  /// The sole constructor-dispatch boundary is itself checked: storing two
  /// builders must be side-effect free and build must call exactly one of them.
  bool get canonicalDispatcherIsLazy {
    final unit = units[_renderer];
    if (unit == null ||
        !_importsSymbol(_renderer, _pageDesign, 'PageDesign') ||
        !_importsSymbol(_renderer, _platformDesign, 'effectivePageDesign')) {
      return false;
    }
    final classes = unit.declarations.whereType<ClassDeclaration>().where(
        (declaration) => declaration.name.lexeme == 'PlatformControlRenderer');
    if (classes.length != 1) return false;
    final members = classes.single.members;
    final fields = members.whereType<FieldDeclaration>().toList();
    final constructors = members.whereType<ConstructorDeclaration>().toList();
    final methods = members.whereType<MethodDeclaration>().toList();
    if (members.length != 4 ||
        fields.length != 2 ||
        constructors.length != 1 ||
        methods.length != 1 ||
        fields.any((field) =>
            !field.fields.isFinal ||
            field.fields.type?.toSource() != 'WidgetBuilder' ||
            field.fields.variables.length != 1 ||
            field.fields.variables.single.initializer != null) ||
        !fields
            .map((field) => field.fields.variables.single.name.lexeme)
            .toSet()
            .containsAll({'material', 'cupertino'})) {
      return false;
    }
    final constructor = constructors.single;
    if (constructor.constKeyword == null ||
        constructor.factoryKeyword != null ||
        constructor.initializers.isNotEmpty ||
        constructor.body is! EmptyFunctionBody) {
      return false;
    }
    final method = methods.single;
    if (method.name.lexeme != 'build' || method.body is! BlockFunctionBody) {
      return false;
    }
    final statements = (method.body as BlockFunctionBody).block.statements;
    if (statements.length != 1 || statements.single is! ReturnStatement) {
      return false;
    }
    final expression = (statements.single as ReturnStatement).expression;
    if (expression is! ConditionalExpression) return false;
    final condition = expression.condition;
    return condition is BinaryExpression &&
        condition.operator.lexeme == '==' &&
        _call(condition.leftOperand, 'effectivePageDesign') &&
        condition.rightOperand.toSource() == 'PageDesign.cupertino' &&
        _call(expression.thenExpression, 'cupertino') &&
        _call(expression.elseExpression, 'material');
  }

  bool _call(Expression expression, String name) =>
      expression is MethodInvocation &&
      expression.target == null &&
      expression.methodName.name == name &&
      expression.argumentList.arguments.length == 1 &&
      expression.argumentList.arguments.single.toSource() == 'context';

  Iterable<UriBasedDirective> _directives(String path) =>
      units[path]!.directives.whereType<UriBasedDirective>();

  List<String> _uris(UriBasedDirective directive) => [
        if (directive.uri.stringValue case final String uri) uri,
        if (directive is NamespaceDirective)
          for (final configuration in directive.configurations)
            if (configuration.uri.stringValue case final String uri) uri,
      ];

  String? _local(String source, String uri) {
    if (uri.startsWith('package:$packageName/')) {
      return 'lib/${uri.substring('package:$packageName/'.length)}';
    }
    if (Uri.parse(uri).hasScheme) return null;
    return p.posix.normalize(p.posix.join(p.posix.dirname(source), uri));
  }

  Set<Design> directDesigns(String path) => {
        for (final directive in _directives(path))
          for (final uri in _uris(directive))
            for (final design in Design.values)
              if (uri == 'package:flutter/${design.name}.dart' ||
                  uri.startsWith('package:flutter/src/${design.name}/'))
                design,
      };

  List<String> get mixedDesignLibraries => [
        for (final path in units.keys)
          if (directDesigns(path).length > 1) path,
      ];

  /// Only a library consisting of typed IconData lists and static icon
  /// constants qualifies. No functions, classes, constructors, other initializers
  /// or executable helpers are exempted, regardless of the file's name.
  bool isIconDataLibrary(String path) {
    final unit = units[path]!;
    if (directDesigns(path).length != 1 || unit.declarations.isEmpty) {
      return false;
    }
    final family = directDesigns(path).single == Design.material
        ? 'Icons'
        : 'CupertinoIcons';
    if (unit.directives.any((directive) =>
        directive is! ImportDirective ||
        directive.uri.stringValue !=
            'package:flutter/${directDesigns(path).single.name}.dart' ||
        directive.prefix != null ||
        directive.configurations.isNotEmpty)) {
      return false;
    }
    for (final declaration in unit.declarations) {
      if (declaration is! TopLevelVariableDeclaration ||
          declaration.metadata.isNotEmpty ||
          declaration.variables.type?.toSource() != 'List<IconData>') {
        return false;
      }
      for (final variable in declaration.variables.variables) {
        final initializer = variable.initializer;
        if (initializer is! ListLiteral || initializer.elements.isEmpty) {
          return false;
        }
        for (final element in initializer.elements) {
          if (element is! PrefixedIdentifier ||
              element.prefix.name != family ||
              element.identifier.name.startsWith('_')) {
            return false;
          }
        }
      }
    }
    iconDataLibraries.add(path);
    return true;
  }

  Set<String> _exportedSymbols(String path, [Set<String>? visiting]) {
    if (_symbols[path] case final symbols?) return symbols;
    final seen = {...?visiting};
    if (!seen.add(path)) return {};
    final unit = units[path];
    if (unit == null) return {};
    final symbols = <String>{};
    for (final declaration in unit.declarations) {
      if (declaration is NamedCompilationUnitMember) {
        symbols.add(declaration.name.lexeme);
      } else if (declaration is TopLevelVariableDeclaration) {
        symbols
            .addAll(declaration.variables.variables.map((v) => v.name.lexeme));
      } else if (declaration is ExtensionDeclaration) {
        if (declaration.name case final name?) symbols.add(name.lexeme);
      }
      // Imported extensions can be used through instance method/property names,
      // with no reference to their (possibly absent) declaration name.
      if (declaration is ExtensionDeclaration) {
        for (final member in declaration.members) {
          if (member is MethodDeclaration) symbols.add(member.name.lexeme);
          if (member is FieldDeclaration) {
            symbols.addAll(member.fields.variables.map((v) => v.name.lexeme));
          }
        }
      }
    }
    for (final export in unit.directives.whereType<ExportDirective>()) {
      for (final uri in _uris(export)) {
        final target = _local(path, uri);
        if (target != null) {
          symbols.addAll(_filtered(_exportedSymbols(target, seen), export));
        }
      }
    }
    symbols.removeWhere((name) => name.startsWith('_'));
    // Do not cache an incomplete cycle's public namespace.
    if (visiting == null) _symbols[path] = symbols;
    return symbols;
  }

  Set<String> _filtered(Set<String> symbols, NamespaceDirective directive) {
    var result = {...symbols};
    for (final combinator in directive.combinators) {
      if (combinator is ShowCombinator) {
        result = result
            .intersection(combinator.shownNames.map((n) => n.name).toSet());
      } else if (combinator is HideCombinator) {
        result.removeAll(combinator.hiddenNames.map((n) => n.name));
      }
    }
    return result;
  }

  bool _importsSymbol(String path, String target, String name) =>
      units[path]!.directives.whereType<ImportDirective>().any((directive) =>
          directive.prefix == null &&
          _uris(directive).every((uri) => _local(path, uri) == target) &&
          _filtered({name}, directive).contains(name));

  List<_Branch> _branches(String path) {
    final unit = units[path]!;
    final declarations = _DeclaredNames();
    unit.accept(declarations);
    bool trusted(String target, String name) =>
        _importsSymbol(path, target, name) &&
        !declarations.names.contains(name);
    final visitor = _DispatchBranches(
      renderer: canonicalDispatcherIsLazy &&
          trusted(_renderer, 'PlatformControlRenderer'),
      pageDesign: trusted(_pageDesign, 'PageDesign'),
      effectivePageDesign: trusted(_platformDesign, 'effectivePageDesign'),
      designVariables: declarations.pageDesignVariables
          .difference(declarations.unsafeDesignVariables),
    );
    unit.accept(visitor);
    return visitor.branches;
  }

  bool _otherBranchOnly(
      String source, String target, ImportDirective directive, Design design) {
    final branches = _branches(source);
    if (branches.isEmpty) return false;
    final names = directive.prefix != null
        ? {directive.prefix!.name}
        : _filtered(_exportedSymbols(target), directive);
    if (names.isEmpty) return false;
    final uses = _NameUses(names);
    // Tokens, not source substrings: comments/string contents cannot establish
    // branch membership. Conservatively count declarations as uses as well.
    for (final declaration in units[source]!.declarations) {
      declaration.accept(uses);
    }
    final offsets = uses.offsets;
    if (offsets.isEmpty) return false;
    final other =
        design == Design.material ? Design.cupertino : Design.material;
    return offsets.every((offset) => branches.any((branch) =>
        branch.design == other &&
        offset >= branch.start &&
        offset < branch.end));
  }

  /// Returns shortest discovered import chains reaching the opposite design.
  /// The visited set is per design, so registry/backend cycles never suppress
  /// the other design's independent traversal.
  List<String> violations(Iterable<String> roots, Design design) {
    final queue = [
      for (final root in roots) [root]
    ];
    final visited = <String>{};
    final failures = <String>[];
    for (var index = 0; index < queue.length; index++) {
      final chain = queue[index];
      final path = chain.last;
      if (!visited.add(path)) continue;
      if (!units.containsKey(path)) {
        failures.add('${chain.join(' -> ')} (missing owned source)');
        continue;
      }
      if (directDesigns(path).any((direct) => direct != design) &&
          !isIconDataLibrary(path)) {
        failures.add('${chain.join(' -> ')} [${design.name} reaches '
            '${directDesigns(path).map((d) => d.name).join(', ')}]');
        continue;
      }
      for (final directive in _directives(path)) {
        for (final uri in _uris(directive)) {
          final target = _local(path, uri);
          if (target == null) {
            if (!uri.startsWith('dart:') &&
                !uri.startsWith('package:flutter/')) {
              externalDependencies.add(uri);
            }
            continue;
          }
          if (directive is ImportDirective &&
              _otherBranchOnly(path, target, directive, design)) {
            prunedBranches.add('$path -> $target (${design.name})');
            continue;
          }
          queue.add([...chain, target]);
        }
      }
    }
    return failures;
  }
}

class _Branch {
  _Branch(this.design, AstNode node)
      : start = node.offset,
        end = node.end;
  final Design design;
  final int start;
  final int end;
}

class _NameUses extends GeneralizingAstVisitor<void> {
  _NameUses(this.names);
  final Set<String> names;
  final List<int> offsets = [];

  @override
  void visitNode(AstNode node) {
    for (final entity in node.childEntities) {
      if (entity is Token && names.contains(entity.lexeme)) {
        offsets.add(entity.offset);
      }
    }
    super.visitNode(node);
  }
}

class _DeclaredNames extends RecursiveAstVisitor<void> {
  final Set<String> names = {};
  final Set<String> pageDesignVariables = {};
  final Set<String> unsafeDesignVariables = {};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    names.add(node.name.lexeme);
    final list = node.parent as VariableDeclarationList;
    if (list.type?.toSource() == 'PageDesign' &&
        list.parent is FieldDeclaration &&
        list.isFinal &&
        node.initializer == null) {
      pageDesignVariables.add(node.name.lexeme);
    } else {
      unsafeDesignVariables.add(node.name.lexeme);
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    if (node.name case final name?) {
      names.add(name.lexeme);
      if (node.type?.toSource() == 'PageDesign') {
        pageDesignVariables.add(name.lexeme);
      } else {
        unsafeDesignVariables.add(name.lexeme);
      }
    }
    super.visitSimpleFormalParameter(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    names.add(node.name.lexeme);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (node.leftHandSide is SimpleIdentifier) {
      unsafeDesignVariables.add((node.leftHandSide as SimpleIdentifier).name);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitFunctionTypedFormalParameter(FunctionTypedFormalParameter node) {
    names.add(node.name.lexeme);
    unsafeDesignVariables.add(node.name.lexeme);
    super.visitFunctionTypedFormalParameter(node);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    names.add(node.name.lexeme);
    super.visitGenericTypeAlias(node);
  }

  @override
  void visitTypeParameter(TypeParameter node) {
    names.add(node.name.lexeme);
    super.visitTypeParameter(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    names.add(node.name.lexeme);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    names.add(node.name.lexeme);
    super.visitClassDeclaration(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    names.add(node.name.lexeme);
    super.visitEnumDeclaration(node);
  }
}

class _DispatchBranches extends RecursiveAstVisitor<void> {
  _DispatchBranches(
      {required this.renderer,
      required this.pageDesign,
      required this.effectivePageDesign,
      required this.designVariables});
  final bool renderer;
  final bool pageDesign;
  final bool effectivePageDesign;
  final Set<String> designVariables;
  final List<_Branch> branches = [];

  void _rendererBranches(ArgumentList arguments) {
    final choices = arguments.arguments.whereType<NamedExpression>().where(
        (argument) =>
            Design.values.any((d) => argument.name.label.name == d.name));
    if (choices.length != 2 ||
        choices.any((argument) => argument.expression is! FunctionExpression)) {
      return;
    }
    for (final argument in choices) {
      final design = Design.values.byName(argument.name.label.name);
      branches.add(_Branch(design, argument.expression));
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (renderer &&
        node.target == null &&
        node.methodName.name == 'PlatformControlRenderer') {
      _rendererBranches(node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (renderer &&
        node.constructorName.type.toSource() == 'PlatformControlRenderer' &&
        node.constructorName.name == null) {
      _rendererBranches(node.argumentList);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    if (pageDesign &&
        _knownSelector(node.expression) &&
        node.cases.length == 2 &&
        node.cases.every((c) => c.guardedPattern.whenClause == null) &&
        node.cases
            .map((c) => c.guardedPattern.pattern.toSource())
            .toSet()
            .containsAll({'PageDesign.material', 'PageDesign.cupertino'})) {
      for (final branch in node.cases) {
        branches.add(_Branch(
            Design.values.byName(
                branch.guardedPattern.pattern.toSource().split('.').last),
            branch.expression));
      }
    }
    super.visitSwitchExpression(node);
  }

  bool _knownSelector(Expression selector) => selector is SimpleIdentifier
      ? designVariables.contains(selector.name)
      : effectivePageDesign &&
          selector is MethodInvocation &&
          selector.target == null &&
          selector.methodName.name == 'effectivePageDesign';

  @override
  void visitSwitchStatement(SwitchStatement node) {
    String? designOf(SwitchMember member) => switch (member) {
          SwitchPatternCase() when member.guardedPattern.whenClause == null =>
            member.guardedPattern.pattern.toSource(),
          SwitchCase() => member.expression.toSource(),
          _ => null,
        };
    if (pageDesign &&
        _knownSelector(node.expression) &&
        node.members.length == 2 &&
        node.members
            .map(designOf)
            .toSet()
            .containsAll({'PageDesign.material', 'PageDesign.cupertino'}) &&
        node.members.every((member) =>
            member.labels.isEmpty &&
            member.statements.length == 1 &&
            member.statements.single is ReturnStatement)) {
      for (final member in node.members) {
        branches.add(_Branch(
            Design.values.byName(designOf(member)!.split('.').last),
            member.statements.single));
      }
    }
    super.visitSwitchStatement(node);
  }
}
