// The control-core contract rules (C1–C8) as reusable checks. Static rules
// are pure functions over parsed sources so adversarial fixtures can prove
// they catch what they claim; runtime rules render a manifest entry.
import 'dart:convert';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/core/control_core.dart';
import 'package:ruflet/src/core/control_spec.dart';

import '../architecture/core_manifest.dart';
import '../architecture/platform_dependency_graph.dart';
import 'control_harness.dart';
import 'control_snapshot.dart';

// ------------------------------------------------------------------ keys

/// Keys the framework handles for every control (never in a spec).
const frameworkKeys = {'key', 'data', 'visible', 'disabled', 'col', 'adaptive'};

/// Common Ruby layout keywords applied by `LayoutControl` (base_controls.dart,
/// platform_badge.dart, platform_tooltip.dart).
const layoutControlKeys = {
  'opacity', 'animate_opacity', 'on_animation_end', 'tooltip', 'rtl', //
  'width', 'height', 'animate_size', 'rotate', 'animate_rotation', 'scale',
  'animate_scale', 'offset', 'animate_offset', 'flip', 'transform',
  'aspect_ratio', 'align', 'animate_align', 'margin', 'animate_margin',
  'left', 'top', 'right', 'bottom', 'animate_position', 'badge',
  'on_size_change', 'size_change_interval', 'expand', 'expand_loose',
};

/// Common Ruby layout keywords applied by `BaseControl`.
const baseControlKeys = {
  'opacity', 'animate_opacity', 'on_animation_end', 'tooltip', 'rtl', //
  'expand', 'expand_loose',
};

Set<String> layoutKeysFor(LayoutWrap wrap) => switch (wrap) {
      LayoutWrap.layout => layoutControlKeys,
      LayoutWrap.base => baseControlKeys,
      LayoutWrap.none => const {},
    };

// ------------------------------------------------------------------ C3

/// The Ruby control surface exported by the ruflet repo
/// (`tools/control_surface.rb`), checked in at
/// test/contract/ruflet_control_surface.json.
class RubySurface {
  RubySurface(this.json);

  factory RubySurface.read(File file) =>
      RubySurface(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);

  final Map<String, dynamic> json;

  int get contractVersion => json['contract_version'] as int;

  Set<String> get commonAttributes =>
      {...(json['common_attributes'] as List? ?? const []).cast<String>()};

  Map<String, dynamic> get wireTypes =>
      (json['wire_types'] as Map).cast<String, dynamic>();

  /// Every keyword any Ruby class sending [wireType] accepts, or null when
  /// Ruby has no such wire type. The factory-wide [commonAttributes] (flip,
  /// transform) are not included: every control accepts them and
  /// `LayoutControl` applies them, so they are never part of a spec.
  Set<String>? keywords(String wireType) {
    final entry = wireTypes[wireType] as Map?;
    if (entry == null) return null;
    return {...(entry['keywords'] as List).cast<String>()};
  }
}

/// C3: the spec declares exactly what Ruby can send for its wire type.
List<String> specRubyProblems(ControlSpec spec, RubySurface surface) {
  final problems = <String>[];
  final ruby = surface.keywords(spec.wireType);
  if (ruby == null) {
    return ['${spec.wireType}: Ruby has no control sending this wire type'];
  }
  final layout = layoutKeysFor(spec.layout);
  if (spec.layout == LayoutWrap.none) {
    final declaredLayout = ruby.intersection(layoutControlKeys);
    if (declaredLayout.isNotEmpty) {
      problems.add('${spec.wireType}: layout is none but Ruby declares layout '
          'keys ${_sorted(declaredLayout)}');
    }
  }
  final expected = ruby.difference(frameworkKeys).difference(layout
      .difference(spec.ownedLayoutKeys)
      .difference(spec.sharedLayoutKeys));
  final declared = <String>{
    for (final prop in spec.props) prop.key,
    for (final event in spec.events) 'on_${event.name}',
    ...spec.children.keys,
  };
  final missing = expected.difference(declared);
  final extra = declared.difference(expected);
  if (missing.isNotEmpty) {
    problems.add('${spec.wireType}: Ruby sends ${_sorted(missing)} but the '
        'spec does not declare them');
  }
  if (extra.isNotEmpty) {
    problems.add('${spec.wireType}: the spec declares ${_sorted(extra)} but '
        'Ruby cannot send them (or they belong to the layout wrapper)');
  }
  final propKeys = {for (final prop in spec.props) prop.key};
  for (final (kind, keys) in [
    ('owned', spec.ownedLayoutKeys),
    ('shared', spec.sharedLayoutKeys),
  ]) {
    final undeclared = keys.difference(propKeys);
    if (undeclared.isNotEmpty) {
      problems.add('${spec.wireType}: $kind layout keys ${_sorted(undeclared)} '
          'are not declared as props');
    }
    final notLayout = keys.difference(layout);
    if (notLayout.isNotEmpty) {
      problems.add('${spec.wireType}: $kind layout keys ${_sorted(notLayout)} '
          'are not keys its layout wrapper applies');
    }
  }
  final both = spec.ownedLayoutKeys.intersection(spec.sharedLayoutKeys);
  if (both.isNotEmpty) {
    problems.add('${spec.wireType}: ${_sorted(both)} cannot be both owned '
        'and shared');
  }
  for (final prop in spec.props) {
    if (prop.skins.length != Skin.values.length &&
        (prop.reason ?? '').trim().isEmpty) {
      problems.add('${spec.wireType}.${prop.key}: single-skin prop without a '
          'reason');
    }
    if (prop.skins.isEmpty) {
      problems.add('${spec.wireType}.${prop.key}: no skin consumes it');
    }
  }
  for (final event in spec.events) {
    if (event.skins.length != Skin.values.length &&
        (event.reason ?? '').trim().isEmpty) {
      problems.add('${spec.wireType}.on_${event.name}: single-skin event '
          'without a reason');
    }
    if (event.source == EventSource.skin && event.field == null) {
      problems.add('${spec.wireType}.on_${event.name}: a skin-sourced event '
          'needs a core callback field');
    }
  }
  final keys = <String>{};
  for (final prop in spec.props) {
    if (!keys.add(prop.key)) {
      problems.add('${spec.wireType}: "${prop.key}" is declared twice');
    }
  }
  for (final child in spec.children.values) {
    problems.addAll(specRubyProblems(child, surface));
  }
  return problems;
}

// ------------------------------------------------------------------ resolution

String? resolveLocal(String source, String uri, {String package = 'ruflet'}) {
  if (uri.startsWith('package:$package/')) {
    return 'lib/${uri.substring('package:$package/'.length)}';
  }
  if (Uri.parse(uri).hasScheme) return null;
  return p.posix.normalize(p.posix.join(p.posix.dirname(source), uri));
}

Iterable<(NamespaceDirective, String)> _localNamespaceDirectives(
    PlatformDependencyGraph graph, String path) sync* {
  for (final directive
      in graph.units[path]!.directives.whereType<NamespaceDirective>()) {
    final uris = [
      if (directive.uri.stringValue case final String uri) uri,
      for (final c in directive.configurations)
        if (c.uri.stringValue case final String uri) uri,
    ];
    for (final uri in uris) {
      final target = resolveLocal(path, uri);
      if (target != null) yield (directive, target);
    }
  }
}

/// Names of the `extension … on Control` declarations a library declares or
/// (transitively) exports.
Set<String> controlExtensionsExposedBy(
    PlatformDependencyGraph graph, String path,
    [Set<String>? visiting]) {
  final seen = visiting ?? <String>{};
  if (!seen.add(path)) return {};
  final unit = graph.units[path];
  if (unit == null) return {};
  final names = <String>{
    for (final declaration
        in unit.declarations.whereType<ExtensionDeclaration>())
      if (declaration.onClause?.extendedType.toSource() == 'Control')
        declaration.name?.lexeme ?? '<unnamed>',
  };
  for (final (directive, target) in _localNamespaceDirectives(graph, path)) {
    if (directive is ExportDirective) {
      names.addAll(controlExtensionsExposedBy(graph, target, seen));
    }
  }
  return names;
}

// ------------------------------------------------------------------ C1, C2b

/// Libraries that hand out the Control or wrap it; skins and cores never
/// import them.
const bannedSkinImports = {
  'lib/ruflet.dart',
  'lib/src/models/control.dart',
  'lib/src/extensions/control.dart',
  'lib/src/controls/control_widget.dart',
  'lib/src/controls/base_controls.dart',
  'lib/src/widgets/control_route.dart',
  'lib/src/widgets/control_inherited_notifier.dart',
};

/// Tokens that name the Control, read keys, fire events, register invoke
/// listeners or wrap layout; `dynamic` would reach the same members untyped.
const bannedSkinTokens = {
  'Control',
  'dynamic',
  'triggerEvent',
  'triggerEventWithoutSubscribers',
  'updateProperties',
  'addInvokeMethodListener',
  'removeInvokeMethodListener',
  'LayoutControl',
  'BaseControl',
  'ControlWidget',
  'presentControlRoute',
  'closeControlRoute',
};

List<String> _controlIsolationProblems(
    PlatformDependencyGraph graph, String path) {
  final unit = graph.units[path];
  if (unit == null) return ['$path: no such library'];
  final problems = <String>[];
  for (final (directive, target) in _localNamespaceDirectives(graph, path)) {
    if (bannedSkinImports.contains(target)) {
      problems.add('$path: imports $target');
      continue;
    }
    final extensions = controlExtensionsExposedBy(graph, target);
    if (extensions.isEmpty) continue;
    final shows = directive.combinators.whereType<ShowCombinator>().toList();
    if (shows.isEmpty) {
      problems.add('$path: imports $target, which declares extensions on '
          'Control ${_sorted(extensions)}, without a show list');
    } else {
      final shown = {
        for (final s in shows)
          for (final n in s.shownNames) n.name
      };
      final leaked = shown.intersection(extensions);
      if (leaked.isNotEmpty) {
        problems.add('$path: shows Control extensions ${_sorted(leaked)} '
            'from $target');
      }
    }
  }
  for (Token? token = unit.beginToken;
      token != null && !token.isEof;
      token = token.next) {
    if ((token.type == TokenType.IDENTIFIER || token.isKeyword) &&
        bannedSkinTokens.contains(token.lexeme)) {
      final line = unit.lineInfo.getLocation(token.offset).lineNumber;
      problems.add('$path:$line uses ${token.lexeme}');
    }
  }
  return problems;
}

/// C1: a skin library never reaches the Control: no Control-facing imports,
/// no extension-on-Control library without a `show` list naming only other
/// declarations, and none of the tokens that read keys, fire events, register
/// invoke listeners or wrap layout.
List<String> skinIsolationProblems(
        PlatformDependencyGraph graph, String skin) =>
    _controlIsolationProblems(graph, skin);

/// The kernel library (control_core.dart and its parts) is the only code
/// that may hold a Control.
bool isKernelLibrary(PlatformDependencyGraph graph, String path) =>
    path == 'lib/src/core/control_core.dart' ||
    (graph.units[path]?.directives.whereType<PartOfDirective>().isNotEmpty ??
        false);

/// C2b: a core (a manifest `*_core.dart` or a non-kernel `lib/src/core`
/// library) follows C1 too, so it cannot keep the Control it is constructed
/// with, and every core class constructor only forwards `super.` parameters
/// (no initializers, no use of them in a body), so it cannot capture it
/// untyped either.
List<String> coreIsolationProblems(PlatformDependencyGraph graph, String core) {
  final problems = _controlIsolationProblems(graph, core);
  final unit = graph.units[core];
  if (unit == null) return problems;
  for (final declaration in unit.declarations) {
    final (name, superclass, members) = switch (declaration) {
      ClassDeclaration c => (
          c.name.lexeme,
          c.extendsClause?.superclass.name.lexeme,
          c.members
        ),
      MixinDeclaration m => (
          m.name.lexeme,
          m.onClause?.superclassConstraints.firstOrNull?.name.lexeme,
          m.members
        ),
      _ => ('', null, const <ClassMember>[]),
    };
    if (superclass == null || !superclass.endsWith('Core')) continue;
    // Nothing outside the core may write into it (an entry could otherwise
    // inject wire data after construction).
    for (final member in members) {
      if (member is FieldDeclaration &&
          !member.isStatic &&
          !member.fields.isFinal &&
          !member.fields.isConst) {
        for (final variable in member.fields.variables) {
          if (!variable.name.lexeme.startsWith('_')) {
            problems.add('$core: $name has a public mutable field '
                '"${variable.name.lexeme}"');
          }
        }
      }
      if (member is MethodDeclaration &&
          member.isSetter &&
          !member.name.lexeme.startsWith('_')) {
        problems
            .add('$core: $name has a public setter "${member.name.lexeme}"');
      }
    }
    if (declaration is! ClassDeclaration) continue;
    for (final constructor
        in declaration.members.whereType<ConstructorDeclaration>()) {
      final where = '$core: $name constructor';
      if (constructor.factoryKeyword != null) {
        problems.add('$where must not be a factory');
      }
      final forwarded = <String>{};
      for (final parameter in constructor.parameters.parameters) {
        final formal = parameter is DefaultFormalParameter
            ? parameter.parameter
            : parameter;
        if (formal is SuperFormalParameter) {
          forwarded.add(formal.name.lexeme);
        } else {
          problems.add('$where takes "${formal.name?.lexeme}": a core may '
              'only forward super parameters');
        }
      }
      if (constructor.initializers.isNotEmpty) {
        problems.add('$where has initializers: a core may only forward '
            'super parameters');
      }
      final bodyRefs = _References();
      constructor.body.accept(bodyRefs);
      final leaked = bodyRefs.names.intersection(forwarded);
      if (leaked.isNotEmpty) {
        problems.add('$where uses ${_sorted(leaked)} in its body');
      }
    }
  }
  return problems;
}

// ------------------------------------------------------------------ C1e

/// A constructor or widget call `Name(...)` / `Name<T>(...)` /
/// `new Name(...)`, as [name] plus its argument list.
(String, ArgumentList)? _construction(Expression expression) =>
    switch (expression) {
      MethodInvocation(target: null) => (
          expression.methodName.name,
          expression.argumentList
        ),
      InstanceCreationExpression() => (
          expression.constructorName.type.name.lexeme,
          expression.argumentList
        ),
      _ => null,
    };

Map<String, Expression> _namedArguments(ArgumentList arguments) => {
      for (final argument in arguments.arguments.whereType<NamedExpression>())
        argument.name.label.name: argument.expression,
    };

Expression? _closureResult(Expression expression) {
  if (expression is! FunctionExpression) return null;
  final body = expression.body;
  if (body is ExpressionFunctionBody) return body.expression;
  if (body is BlockFunctionBody &&
      body.block.statements.length == 1 &&
      body.block.statements.single is ReturnStatement) {
    return (body.block.statements.single as ReturnStatement).expression;
  }
  return null;
}

/// A skin construction with only `core:` (the [core] variable) and `key:`.
bool _isSkin(Expression expression, String core) {
  final construction = _construction(expression);
  if (construction == null) return false;
  final (_, arguments) = construction;
  final named = _namedArguments(arguments);
  final coreArgument = named['core'];
  return arguments.arguments.every((a) => a is NamedExpression) &&
      named.keys.every((name) => name == 'core' || name == 'key') &&
      coreArgument is SimpleIdentifier &&
      coreArgument.name == core;
}

/// A skin, or a choice between skins made only on the core.
bool _isSkinChoice(Expression expression, String core) {
  if (expression is ParenthesizedExpression) {
    return _isSkinChoice(expression.expression, core);
  }
  if (expression is ConditionalExpression) {
    return _isSkinChoice(expression.thenExpression, core) &&
        _isSkinChoice(expression.elseExpression, core);
  }
  return _isSkin(expression, core);
}

/// A host key built only from the Control's identity (N7: a key carrying
/// wire data would reach any skin that finds its ancestor host):
/// `ValueKey("…${control.id}…")`, optionally with `control.canonicalType`.
bool _isIdKey(Expression key) {
  final construction = _construction(key);
  if (construction == null || construction.$1 != 'ValueKey') return false;
  final arguments = construction.$2.arguments;
  if (arguments.length != 1) return false;
  final value = arguments.single;
  if (value is SimpleStringLiteral) return true;
  if (value is! StringInterpolation) return false;
  return value.elements.whereType<InterpolationExpression>().every((part) {
    final expression = part.expression;
    return expression is PrefixedIdentifier &&
        expression.prefix.name == 'control' &&
        const {'id', 'canonicalType'}.contains(expression.identifier.name);
  });
}

/// C2b, kernel side: no member of a kernel class (fields, getters and
/// methods, public or not reachable by name) hands out a Control, so a skin
/// that finds its ancestor CoreHost (N5) or builds one with
/// `CoreHost.adopt` (N6) cannot reach the Control through it. Only
/// library-private members and constructors/static helpers may mention it.
List<String> kernelExposureProblems(PlatformDependencyGraph graph) {
  final problems = <String>[];
  final control = RegExp(r'\bControl\b');
  for (final path in graph.units.keys) {
    if (!isKernelLibrary(graph, path)) continue;
    for (final declaration in graph.units[path]!.declarations) {
      final (name, members) = switch (declaration) {
        ClassDeclaration c => (c.name.lexeme, c.members),
        MixinDeclaration m => (m.name.lexeme, m.members),
        _ => ('', const <ClassMember>[]),
      };
      for (final member in members) {
        if (member is FieldDeclaration && !member.isStatic) {
          final type = member.fields.type?.toSource() ?? '';
          for (final variable in member.fields.variables) {
            if (!variable.name.lexeme.startsWith('_') &&
                control.hasMatch(type)) {
              problems.add('$path: $name.${variable.name.lexeme} exposes '
                  'a Control ($type)');
            }
          }
        }
        if (member is MethodDeclaration &&
            !member.isStatic &&
            !member.name.lexeme.startsWith('_') &&
            control.hasMatch(member.returnType?.toSource() ?? '')) {
          problems.add('$path: $name.${member.name.lexeme} exposes a '
              'Control (${member.returnType})');
        }
      }
    }
  }
  return problems;
}

/// C1e for a sized entry: a control a scaffold sizes before building it (the
/// AppBar: `Scaffold`/`CupertinoPageScaffold` read the `PreferredSizeWidget`
/// they are handed, and only a Cupertino class can be an
/// `ObstructingPreferredSizeWidget`), so its skin must be the outermost
/// widget. The entry builds no CoreHost; a static `resolve` has exactly two
/// statements: `final core = XCore(control);` (one constructor call with the
/// Control as its only argument) and `return switch (design) {...}` over
/// `PageDesign.material` and `PageDesign.cupertino`, no guards, each arm
/// building a skin with only `core:` and `key:`. Each skin then hosts that
/// core with `CoreHost.adopt` (C5 finds the host). Besides those uses,
/// `control` may only be the `control:` argument of a `resolve(...)` call and
/// appear in `debugPrint`. Returns null when the entry declares no static
/// `resolve` (it is then simply missing its CoreHost).
List<String>? sizedEntryProblems(
    CompilationUnit unit, String entry, List<(int, int)> allowed) {
  MethodDeclaration? resolve;
  for (final declaration in unit.declarations.whereType<ClassDeclaration>()) {
    for (final method in declaration.members.whereType<MethodDeclaration>()) {
      if (method.isStatic && method.name.lexeme == 'resolve') resolve = method;
    }
  }
  if (resolve == null) return null;
  final problems = <String>[];
  final body = resolve.body;
  final statements =
      body is BlockFunctionBody ? body.block.statements : const <Statement>[];

  String? core;
  final first = statements.isNotEmpty ? statements.first : null;
  if (first is VariableDeclarationStatement &&
      first.variables.isFinal &&
      first.variables.variables.length == 1) {
    final variable = first.variables.variables.single;
    final initializer = variable.initializer;
    final construction =
        initializer == null ? null : _construction(initializer);
    final arguments = construction?.$2.arguments ?? const <Expression>[];
    if (construction != null &&
        construction.$1.endsWith('Core') &&
        arguments.length == 1 &&
        arguments.single is SimpleIdentifier &&
        (arguments.single as SimpleIdentifier).name == 'control') {
      core = variable.name.lexeme;
      allowed.add((arguments.single.offset, arguments.single.end));
    }
  }
  if (statements.length != 2 || core == null) {
    problems.add('$entry: resolve must be `final core = XCore(control);` '
        'followed by the switch over PageDesign');
  }

  final last = statements.length == 2 ? statements.last : null;
  final returned = last is ReturnStatement ? last.expression : null;
  final designs = returned is SwitchExpression
      ? returned.cases.map((c) => c.guardedPattern.pattern.toSource()).toSet()
      : const <String>{};
  if (returned is! SwitchExpression ||
      returned.expression is! SimpleIdentifier ||
      returned.cases.length != 2 ||
      !designs.containsAll({'PageDesign.material', 'PageDesign.cupertino'}) ||
      returned.cases.any((c) => c.guardedPattern.whenClause != null)) {
    problems.add('$entry: resolve must return an exhaustive switch over '
        'PageDesign.material and PageDesign.cupertino');
  } else if (core != null) {
    for (final arm in returned.cases) {
      if (!_isSkinChoice(arm.expression, core)) {
        problems.add('$entry: the ${arm.guardedPattern.pattern} arm must '
            'build its skin with only core: $core and key:, choosing between '
            'skins only on the core');
      }
    }
  }

  unit.accept(_Calls((name, arguments) {
    if (name != 'resolve') return;
    final control = _namedArguments(arguments)['control'];
    if (control is SimpleIdentifier && control.name == 'control') {
      allowed.add((control.offset, control.end));
    }
  }));
  return problems;
}

/// C1e: the registry entry (`adaptive_*.dart`), the only place outside the
/// kernel that holds the Control, has the canonical shape: `CoreHost(create:)`
/// is a plain constructor tear-off, each `PlatformControlRenderer` closure
/// builds its skin with only `core:` (the builder's core) and `key:`
/// (choosing between skins only on the core), and `control` appears only as
/// `CoreHost(control:)`, inside the host's `key:` and inside `debugPrint`.
///
/// A sized entry (a control a scaffold sizes before building it, the AppBar)
/// builds no CoreHost itself: see [sizedEntryProblems].
List<String> entryShapeProblems(PlatformDependencyGraph graph, String entry) {
  final unit = graph.units[entry];
  if (unit == null) return ['$entry: no such library'];
  final problems = <String>[];
  final allowed = <(int, int)>[];
  final hosts = <ArgumentList>[];
  final debugPrints = <ArgumentList>[];
  unit.accept(_Calls((name, arguments) {
    if (name == 'CoreHost') hosts.add(arguments);
    if (name == 'debugPrint') debugPrints.add(arguments);
  }));
  for (final arguments in debugPrints) {
    allowed.add((arguments.offset, arguments.end));
  }
  if (hosts.isEmpty) {
    problems.addAll(sizedEntryProblems(unit, entry, allowed) ??
        ['$entry: builds no CoreHost']);
  }

  for (final arguments in hosts) {
    final named = _namedArguments(arguments);
    final create = named['create'];
    final isTearOff = create is PrefixedIdentifier &&
        create.prefix.name.startsWith(RegExp('[A-Z]'));
    if (!isTearOff) {
      problems.add('$entry: CoreHost(create:) must be a constructor '
          'tear-off like XCore.new, not "$create"');
    }
    final control = named['control'];
    if (control is SimpleIdentifier && control.name == 'control') {
      allowed.add((control.offset, control.end));
    } else {
      problems.add('$entry: CoreHost(control:) must be the entry\'s control');
    }
    final key = named['key'];
    if (key != null) {
      if (_isIdKey(key)) {
        allowed.add((key.offset, key.end));
      } else {
        problems.add('$entry: CoreHost(key:) may only be a ValueKey of a '
            'string built from control.id and control.canonicalType');
      }
    }
    final builder = named['builder'];
    final parameters = builder is FunctionExpression
        ? builder.parameters?.parameters ?? const <FormalParameter>[]
        : const <FormalParameter>[];
    final renderer = builder == null ? null : _closureResult(builder);
    final construction = renderer == null ? null : _construction(renderer);
    if (parameters.length != 2 ||
        construction == null ||
        construction.$1 != 'PlatformControlRenderer') {
      problems.add('$entry: CoreHost(builder:) must be '
          '(context, core) => PlatformControlRenderer(...)');
      continue;
    }
    final core = parameters[1].name!.lexeme;
    final closures = _namedArguments(construction.$2);
    for (final design in ['material', 'cupertino']) {
      final result =
          closures[design] == null ? null : _closureResult(closures[design]!);
      if (result == null || !_isSkinChoice(result, core)) {
        problems.add('$entry: the $design closure must build its skin with '
            'only core: $core and key:, choosing between skins only on the '
            'core');
      }
    }
  }

  final controlRefs = _ControlRefs();
  unit.accept(controlRefs);
  for (final offset in controlRefs.offsets) {
    if (!allowed.any((range) => offset >= range.$1 && offset < range.$2)) {
      final line = unit.lineInfo.getLocation(offset).lineNumber;
      problems.add('$entry:$line uses control outside CoreHost(control:), '
          'the host key and debugPrint');
    }
  }
  return problems;
}

class _Calls extends RecursiveAstVisitor<void> {
  _Calls(this.onCall);
  final void Function(String name, ArgumentList arguments) onCall;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) onCall(node.methodName.name, node.argumentList);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    onCall(node.constructorName.type.name.lexeme, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }
}

/// References to `control` (not declarations or named-argument labels).
class _ControlRefs extends RecursiveAstVisitor<void> {
  final List<int> offsets = [];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'control' && node.parent is! Label) {
      offsets.add(node.offset);
    }
    super.visitSimpleIdentifier(node);
  }
}

// ------------------------------------------------------------------ C4

/// Referenced identifiers (not declarations, not named-argument labels).
class _References extends RecursiveAstVisitor<void> {
  _References({this.skipClass});
  final String? skipClass;
  final Set<String> names = {};

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (node.name.lexeme == skipClass) return;
    super.visitClassDeclaration(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.parent is! Label) names.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

Set<String> referencedNames(CompilationUnit unit, {String? skipClass}) {
  final visitor = _References(skipClass: skipClass);
  unit.accept(visitor);
  return visitor.names;
}

Set<String> declaredMemberNames(CompilationUnit unit) => {
      for (final declaration in unit.declarations)
        if (declaration is ClassDeclaration || declaration is MixinDeclaration)
          for (final member in switch (declaration) {
            ClassDeclaration c => c.members,
            MixinDeclaration m => m.members,
            _ => const <ClassMember>[],
          })
            ...switch (member) {
              MethodDeclaration m => [m.name.lexeme],
              FieldDeclaration f => [
                  for (final v in f.fields.variables) v.name.lexeme
                ],
              _ => const <String>[],
            },
    };

Set<String> implementedInterfaces(CompilationUnit unit) => {
      for (final declaration in unit.declarations.whereType<ClassDeclaration>())
        for (final type
            in declaration.implementsClause?.interfaces ?? const <NamedType>[])
          type.name.lexeme,
    };

/// C4: a skin-consumed [PropSpec] field is referenced by every skin it lists
/// (or that skin's helpers) and by no other skin, whatever the core does; a
/// core-consumed one ([PropConsumer.core]) applies to both skins, is
/// referenced by the core outside its props class and by no skin.
/// Skin-sourced event callbacks exist in the core and are wired by every
/// listed skin; port methods are implemented by every skin.
List<String> skinConsumptionProblems({
  required PlatformDependencyGraph graph,
  required ControlSpec spec,
  required String core,
  required String propsClass,
  required Map<Skin, String> skins,
  Map<Skin, List<String>> helpers = const {},
  String? portInterface,
}) {
  final problems = <String>[];
  final coreUnit = graph.units[core];
  if (coreUnit == null) return ['$core: no such library'];
  final coreRefs = referencedNames(coreUnit, skipClass: propsClass);
  final coreMembers = declaredMemberNames(coreUnit);
  final skinRefs = <Skin, Set<String>>{};
  for (final skin in Skin.values) {
    if (skins[skin] == null) {
      problems.add('${spec.wireType}: no ${skin.name} skin in the manifest');
    }
    final refs = skinRefs[skin] = <String>{};
    for (final lib in [
      if (skins[skin] case final String path) path,
      ...?helpers[skin]
    ]) {
      final unit = graph.units[lib];
      if (unit == null) {
        problems.add('$lib: no such library');
      } else {
        refs.addAll(referencedNames(unit));
      }
    }
  }
  for (final prop in spec.props) {
    final both = prop.skins.length == Skin.values.length;
    final where = '${spec.wireType}.${prop.key}';
    if (prop.consumer == PropConsumer.core) {
      // Declared, then proven: the core uses it and no skin does.
      if (!both) {
        problems.add('$where: a core-consumed prop applies to both skins');
      }
      if (!coreRefs.contains(prop.field)) {
        problems.add('$where: declared core-consumed but the core never '
            'references "${prop.field}"');
      }
      for (final skin in Skin.values) {
        if (skinRefs[skin]!.contains(prop.field)) {
          problems.add('$where: core-consumed "${prop.field}" is also read '
              'by the ${skin.name} skin');
        }
      }
      continue;
    }
    // Skin-consumed: each listed skin must use it, whatever the core does.
    for (final skin in Skin.values) {
      final bySkin = skinRefs[skin]!.contains(prop.field);
      if (prop.skins.contains(skin) && !bySkin) {
        problems.add('$where: the ${skin.name} skin never consumes '
            '"${prop.field}"');
      }
      if (!prop.skins.contains(skin) && bySkin) {
        problems.add('$where: the ${skin.name} skin consumes "${prop.field}" '
            'but the spec says it does not apply (${prop.reason})');
      }
    }
  }
  for (final event in spec.events.where((e) => e.source == EventSource.skin)) {
    final field = event.field;
    if (field == null) continue;
    if (!coreMembers.contains(field)) {
      problems.add('${spec.wireType}.on_${event.name}: the core declares no '
          '"$field" callback');
    }
    for (final skin in event.skins) {
      if (!skinRefs[skin]!.contains(field)) {
        problems.add('${spec.wireType}.on_${event.name}: the ${skin.name} skin '
            'never wires "$field"');
      }
    }
  }
  if (spec.methods.any((m) => m.port)) {
    if (portInterface == null) {
      problems.add('${spec.wireType}: port methods without a port interface');
    } else {
      for (final entry in skins.entries) {
        final unit = graph.units[entry.value];
        if (unit == null ||
            !implementedInterfaces(unit).contains(portInterface)) {
          problems.add('${spec.wireType}: the ${entry.key.name} skin does not '
              'implement $portInterface');
        }
      }
    }
  }
  return problems;
}

// ------------------------------------------------------------------ C8

class LegacyReport {
  LegacyReport(this.unlisted, this.stale);

  /// Design files on the old pattern that are neither listed nor migrated.
  final List<String> unlisted;

  /// Listed files that no longer exist, no longer need the old pattern, or
  /// were migrated.
  final List<String> stale;

  bool get clean => unlisted.isEmpty && stale.isEmpty;
}

/// Whether a design library still renders a Control directly (imports the
/// Control model or fires events itself).
bool usesLegacyPattern(PlatformDependencyGraph graph, String path) {
  final unit = graph.units[path];
  if (unit == null) return false;
  if (_localNamespaceDirectives(graph, path)
      .any((d) => d.$2 == 'lib/src/models/control.dart')) {
    return true;
  }
  for (Token? token = unit.beginToken;
      token != null && !token.isEof;
      token = token.next) {
    if (token.type == TokenType.IDENTIFIER && token.lexeme == 'triggerEvent') {
      return true;
    }
  }
  return false;
}

/// C8: the legacy renderer list only shrinks.
LegacyReport legacyRatchet(PlatformDependencyGraph graph, Set<String> listed,
    Set<String> migratedSkins) {
  final designFiles = [
    for (final path in graph.units.keys)
      if (path.startsWith('lib/src/controls/') &&
          graph.directDesigns(path).isNotEmpty &&
          !graph.isIconDataLibrary(path))
        path
  ]..sort();
  return LegacyReport(
    [
      for (final path in designFiles)
        if (!listed.contains(path) &&
            !migratedSkins.contains(path) &&
            usesLegacyPattern(graph, path))
          path
    ],
    [
      for (final path in _sorted(listed))
        if (!graph.units.containsKey(path) ||
            migratedSkins.contains(path) ||
            !usesLegacyPattern(graph, path))
          path
    ],
  );
}

Set<String> readLegacyList(File file) => {
      for (final line in file.readAsLinesSync())
        if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#'))
          line.trim()
    };

// ------------------------------------------------------------------ samples

/// A wire value of [type] that the type's parser accepts.
Object? sampleValue(PropType type, int Function() nextId) => switch (type) {
      PropType.boolean => true,
      PropType.integer => 2,
      PropType.number => 24.0,
      PropType.string => 'sample',
      PropType.color => '#336699',
      PropType.stateColor => {'selected': '#993366', 'default': '#336699'},
      PropType.stateNumber => {'default': 2.0},
      PropType.stateIcon => {'default': 0x10000},
      PropType.stateBorderSide => {
          'default': {'width': 2.0, 'color': '#336699'}
        },
      PropType.textStyle => {'size': 13.0, 'color': '#336699'},
      PropType.edgeInsets => 4.0,
      PropType.borderRadius => 4.0,
      PropType.outlinedBorder => {'_type': 'roundedrectangle', 'radius': 4.0},
      PropType.alignment => {'x': 0.0, 'y': 0.0},
      PropType.duration => 100,
      PropType.animation => {'duration': 100, 'curve': 'linear'},
      PropType.enumName => 'sample',
      PropType.icon || PropType.iconOrWidget => 0x10000,
      PropType.image =>
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a6i8AAAAASUVORK5CYII=',
      PropType.mouseCursor => 'click',
      PropType.widget => {
          '_c': 'Text',
          '_i': nextId(),
          'value': 'Sample widget'
        },
      PropType.textOrWidget => 'Sample',
      PropType.widgets => [
          {'_c': 'Text', '_i': nextId(), 'value': 'Sample item'}
        ],
      PropType.raw => 'sample',
    };

// ------------------------------------------------------------------ C5–C7

Finder coreHostOf(int id) => find.byWidgetPredicate(
    (widget) => widget is CoreHost && widget.debugControlId == id);

int targetIdOf(MigratedControl entry, Map<String, dynamic> wire) {
  final node = findWireNode(wire, entry.wireType);
  if (node == null) {
    throw StateError('${entry.wireType} fixture has no ${entry.wireType} node');
  }
  return node['_i'] as int;
}

const _undeclaredMethod = '__ruflet_contract_undeclared__';

/// C5: exactly one invoke listener (all listeners counted, not only hosts),
/// declared methods answer, undeclared ones fail fast, an in-place
/// replacement moves the listener, unmount removes it. Returns the problems.
Future<List<String>> lifecycleProblems(
    WidgetTester tester, MigratedControl entry, HarnessDesign design) async {
  final problems = <String>[];
  final wire = entry.fixture();
  final id = targetIdOf(entry, wire);
  final mount =
      await mountWire(tester, design, wire, extensions: entry.extensions());
  final control = mount.control(id);
  final host = coreHostOf(id);
  if (host.evaluate().length != 1) {
    return ['${entry.wireType} is not rendered by exactly one CoreHost'];
  }
  final listeners = await invokeListenerCount(tester, control);
  if (listeners != 1) {
    problems.add('mounted control has $listeners invoke listeners, not 1');
  }

  for (final method in entry.spec.methods) {
    final outcome = await invokeOutcome(tester, control, method.name);
    if (outcome.timedOut) {
      problems.add('${method.name} timed out');
    } else if (outcome.error != null && !(method.port && outcome.unsupported)) {
      problems.add('${method.name} failed: ${outcome.error}');
    }
    await tester.pumpAndSettle();
  }
  if (!(await invokeOutcome(tester, control, _undeclaredMethod)).unsupported) {
    problems.add('an undeclared method does not fail fast');
  }

  final state = tester.state(host);
  final replacement = Control.fromMap(copyWire(wire), mount.backend);
  await tester.pumpWidget(
      harnessApp(mount.backend, design, ControlWidget(control: replacement)));
  await tester.pumpAndSettle();
  final replaced = mount.control(id);
  if (identical(replaced, control)) {
    problems.add('the fixture did not replace the control');
  }
  if (!identical(tester.state(host), state)) {
    problems.add('the replacement did not reuse the element');
  }
  final oldListeners = await invokeListenerCount(tester, control);
  if (oldListeners != 0) {
    problems.add('the replaced control keeps $oldListeners listeners');
  }
  final newListeners = await invokeListenerCount(tester, replaced);
  if (newListeners != 1) {
    problems.add('the replacement has $newListeners listeners, not 1');
  }
  if (!(await invokeOutcome(tester, replaced, _undeclaredMethod)).unsupported) {
    problems.add('invokes do not reach the replacement');
  }

  await tester.pumpWidget(harnessApp(mount.backend, design, const SizedBox()));
  final left = await invokeListenerCount(tester, replaced);
  if (left != 0) problems.add('unmount leaves $left listeners');
  return problems;
}

/// C6: rendering every declared key reads every declared key. Returns the
/// problems.
Future<List<String>> completenessProblems(
    WidgetTester tester, MigratedControl entry, HarnessDesign design) async {
  final wire = entry.fixture();
  final node = findWireNode(wire, entry.wireType)!;
  var nextId = 90000;
  for (final prop in entry.spec.props) {
    node[prop.key] = entry.samples.containsKey(prop.key)
        ? entry.samples[prop.key]
        : sampleValue(prop.type, () => ++nextId);
  }
  CoreReadLog.clear();
  await mountWire(tester, design, wire, extensions: entry.extensions());
  final exception = tester.takeException();
  final declared = {
    for (final prop in entry.spec.props) prop.key,
    ...entry.spec.children.keys,
  };
  final missing = declared.difference(CoreReadLog.keysRead(entry.wireType));
  return [
    if (exception != null) 'rendering every key threw: $exception',
    if (missing.isNotEmpty)
      'declared keys the core never parsed: ${_sorted(missing)}',
  ];
}

const parityFlags = {
  'hasCheckedState', 'isChecked', 'isCheckStateMixed', 'isSelected', //
  'hasToggledState', 'isToggled', 'hasEnabledState', 'isEnabled',
  'isInMutuallyExclusiveGroup', 'hasExpandedState', 'isExpanded',
};

const parityActions = {
  'tap', 'longPress', 'increase', 'decrease', 'dismiss', //
};

List<Map<String, Object?>> paritySemantics(
        WidgetTester tester, Finder finder) =>
    [
      for (final node in semanticsWithin(tester, finder))
        if ((node['flags'] as List).any(parityFlags.contains) ||
            (node['actions'] as List).any(parityActions.contains) ||
            (node['label'] as String).isNotEmpty)
          {
            'label': node['label'],
            'flags': [
              for (final f in node['flags'] as List)
                if (parityFlags.contains(f)) f
            ],
            'actions': [
              for (final a in node['actions'] as List)
                if (parityActions.contains(a)) a
            ],
          }
    ];

/// C7 record: semantics, then each script step's messages to Ruby (from any
/// control, except the target's single-skin events) and the semantics after
/// it. The script's `tap native` step taps [MigratedControl.nativeWidgets].
Future<Map<String, Object?>> parityRecord(
    WidgetTester tester, MigratedControl entry, HarnessDesign design) async {
  final semantics = tester.ensureSemantics();
  try {
    final wire = entry.fixture();
    final id = targetIdOf(entry, wire);
    final node = findWireNode(wire, entry.wireType)!;
    for (final event in entry.spec.events) {
      node['on_${event.name}'] = true;
    }
    final mount =
        await mountWire(tester, design, wire, extensions: entry.extensions());
    final context = SnapshotContext(tester, mount, mount.control(id));
    final nativeType = entry.nativeWidgets[
        design == HarnessDesign.ios ? Skin.cupertino : Skin.material];
    if (nativeType != null) {
      context.native = find.descendant(
          of: context.finder, matching: find.byType(nativeType));
    }
    final singleSkin = {
      for (final e in entry.spec.events)
        if (e.skins.length != Skin.values.length) e.name
    };
    final record = <String, Object?>{
      'semantics': paritySemantics(tester, context.finder),
    };
    final steps = <Map<String, Object?>>[];
    mount.backend.sent.clear();
    for (final step in entry.parityScript) {
      context
        ..outcome = null
        ..note = null;
      await step.run(context);
      steps.add({
        'step': step.name,
        if (context.note != null) 'note': context.note,
        if (context.outcome != null) 'outcome': context.outcome!.toJson(),
        'sent': [
          for (final m in mount.backend.sent)
            if (m.id != id || m.props != null || !singleSkin.contains(m.name))
              m.toJson()
        ],
        'semantics': paritySemantics(tester, context.finder),
      });
      mount.backend.sent.clear();
    }
    record['steps'] = steps;
    final exception = tester.takeException();
    if (exception != null) record['exception'] = '$exception';
    return record;
  } finally {
    semantics.dispose();
  }
}

/// C7: the script exercises the skins' native gesture path, every step
/// could run, every core-sourced event was fired by the control under test,
/// and iOS and Android sent the same messages with the same semantics.
List<String> parityProblems(MigratedControl entry, Map<String, Object?> android,
    Map<String, Object?> ios) {
  final problems = <String>[];
  if (!entry.parityScript.any((step) => step.name == 'tap native')) {
    problems.add('the parity script never taps the native widget');
  }
  for (final skin in Skin.values) {
    if (entry.nativeWidgets[skin] == null) {
      problems.add('no ${skin.name} native widget type in the manifest');
    }
  }
  final id = targetIdOf(entry, entry.fixture());
  for (final (design, record) in [('android', android), ('ios', ios)]) {
    if (record['exception'] != null) {
      problems.add('$design threw: ${record['exception']}');
    }
    final steps = (record['steps'] as List).cast<Map<String, Object?>>();
    for (final step in steps) {
      if (step['note'] != null) {
        problems.add('$design: step "${step['step']}": ${step['note']}');
      }
    }
    final fired = {
      for (final step in steps)
        for (final m in (step['sent'] as List).cast<Map<String, Object?>>())
          if (m['id'] == id && m['event'] != null) m['event'] as String
    };
    for (final event in entry.spec.events) {
      if (event.source != EventSource.core ||
          entry.unexercisedEvents.containsKey(event.name)) {
        continue;
      }
      if (!fired.contains(event.name)) {
        problems.add('$design: the script never made the core fire '
            '"${event.name}"');
      }
    }
  }
  final androidSteps = android['steps'] as List;
  final iosSteps = ios['steps'] as List;
  if (!const DeepCollectionEquality()
      .equals(android['semantics'], ios['semantics'])) {
    problems.add('initial semantics differ: android ${android['semantics']} '
        'vs ios ${ios['semantics']}');
  }
  for (var i = 0; i < androidSteps.length && i < iosSteps.length; i++) {
    if (!const DeepCollectionEquality().equals(androidSteps[i], iosSteps[i])) {
      problems.add('step ${i + 1} differs: android ${androidSteps[i]} vs '
          'ios ${iosSteps[i]}');
    }
  }
  if (androidSteps.length != iosSteps.length) {
    problems.add('android ran ${androidSteps.length} steps, ios '
        '${iosSteps.length}');
  }
  return problems;
}

List<String> _sorted(Iterable<String> values) => values.toList()..sort();
