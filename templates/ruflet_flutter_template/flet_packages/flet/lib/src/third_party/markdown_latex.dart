// Adapted from flutter_markdown_plus_latex 1.0.5 under the repository's
// Apache-2.0 license. Modified to use Flutter's design-neutral widget layer.

import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

class LatexElementBuilder extends MarkdownElementBuilder {
  LatexElementBuilder({this.textStyle, this.textScaleFactor});

  final TextStyle? textStyle;
  final double? textScaleFactor;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = element.textContent;
    if (text.isEmpty) return const SizedBox();
    final mathStyle = element.attributes['MathStyle'] == 'display'
        ? MathStyle.display
        : MathStyle.text;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.antiAlias,
      child: Math.tex(
        text,
        textStyle: textStyle,
        mathStyle: mathStyle,
        textScaleFactor: textScaleFactor,
      ),
    );
  }
}

class LatexBlockSyntax extends md.BlockSyntax {
  LatexBlockSyntax() : super();

  @override
  RegExp get pattern => RegExp(
        r'^(?:(\${1,2})(?:\n|$))|(?:(?:\\\[(.+)\\\])(?:\n|$))',
        multiLine: true,
      );

  @override
  List<md.Line> parseChildLines(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content);
    if (match?[2] != null) {
      parser.advance();
      return [md.Line(match?[2] ?? '')];
    }
    final childLines = <md.Line>[];
    parser.advance();
    while (!parser.isDone) {
      if (!pattern.hasMatch(parser.current.content)) {
        childLines.add(parser.current);
        parser.advance();
      } else {
        parser.advance();
        break;
      }
    }
    return childLines;
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final content =
        parseChildLines(parser).map((line) => line.content).join('\n').trim();
    final textElement = md.Element.text('latex', content)
      ..attributes['MathStyle'] = 'display';
    return md.Element('p', [textElement]);
  }
}

const _delimiterList = <({String left, String right, bool display})>[
  (left: r'$$', right: r'$$', display: true),
  (left: r'$', right: r'$', display: false),
  (left: r'\pu{', right: '}', display: false),
  (left: r'\ce{', right: '}', display: false),
  (left: r'\(', right: r'\)', display: false),
  (left: '( ', right: ' )', display: false),
  (left: r'\[', right: r'\]', display: true),
  (left: '[ ', right: ' ]', display: true),
];

String _escapeRegex(String value) => value.replaceAllMapped(
      RegExp(r'[-\/\\^$*+?.()|[\]{}]'),
      (match) => '\\${match.group(0)}',
    );

String _generateRegexRules() {
  final patterns = <String>[];
  for (final delimiter in _delimiterList) {
    final left = _escapeRegex(delimiter.left);
    final right = _escapeRegex(delimiter.right);
    patterns.add(
      '$left((?:\\\\.|[^\\\\\n])*?(?:\\\\.|[^\\\\\n]|(?!$right)))$right',
    );
  }
  return '(${patterns.join("|")})(?=[\\s?!.,:？！。，：]|\$)';
}

final _latexPattern = _generateRegexRules();

class LatexInlineSyntax extends md.InlineSyntax {
  LatexInlineSyntax() : super(_latexPattern);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final raw = match.group(0) ?? '';
    var delimiterLength = 1;
    var mathStyle = 'text';
    for (final delimiter in _delimiterList) {
      if (raw.startsWith(delimiter.left) && raw.endsWith(delimiter.right)) {
        mathStyle = delimiter.display ? 'display' : 'text';
        delimiterLength = delimiter.left.length;
        break;
      }
    }
    final equation =
        raw.substring(delimiterLength, raw.length - delimiterLength);
    parser.addNode(md.Element.text('latex', equation)
      ..attributes['MathStyle'] = mathStyle);
    return true;
  }
}
