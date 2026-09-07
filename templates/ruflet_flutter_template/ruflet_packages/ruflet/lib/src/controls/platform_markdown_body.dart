import '../utils/style_theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../extensions/control.dart';
import '../models/control.dart';
import '../third_party/markdown_latex.dart';
import '../utils/images.dart';
import '../utils/launch_url.dart';
import '../utils/markdown.dart';
import '../utils/numbers.dart';
import '../utils/text.dart';
import '../utils/uri.dart';
import 'highlight_view.dart';

class PlatformMarkdownBody extends StatelessWidget {
  final Control control;
  final RufletStyleTheme parserTheme;
  final MarkdownStyleSheet baseStyleSheet;
  final MarkdownStyleSheetBaseTheme baseTheme;

  const PlatformMarkdownBody({
    super.key,
    required this.control,
    required this.parserTheme,
    required this.baseStyleSheet,
    required this.baseTheme,
  });

  @override
  Widget build(BuildContext context) {
    final extensionSet =
        control.getMarkdownExtensionSet("extension_set", md.ExtensionSet.none)!;
    final autoFollowLinks = control.getBool("auto_follow_links", false)!;
    final autoFollowLinksTarget = control.getString("auto_follow_links_target");
    final codeStyleSheet = control.getMarkdownStyleSheet(
          "code_style_sheet",
          context,
          null,
          parserTheme,
          baseStyleSheet,
        ) ??
        baseStyleSheet.copyWith(
          code: baseStyleSheet.p?.copyWith(fontFamily: "monospace"),
        );
    final mdStyleSheet = control.getMarkdownStyleSheet(
      "md_style_sheet",
      context,
      null,
      parserTheme,
      baseStyleSheet,
    );
    final codeTheme = control.getMarkdownCodeTheme("code_theme", parserTheme);
    final latexStyle = control.getTextStyle("latex_style", parserTheme);

    return MarkdownBody(
      data: control.getString("value", "")!,
      selectable: false,
      styleSheetTheme: baseTheme,
      imageDirectory: control.backend.assetsDir != ""
          ? control.backend.assetsDir
          : getBaseUri(control.backend.pageUri).toString(),
      extensionSet: md.ExtensionSet(
        [...extensionSet.blockSyntaxes, LatexBlockSyntax()],
        [...extensionSet.inlineSyntaxes, LatexInlineSyntax()],
      ),
      builders: {
        'code': CodeElementBuilder(codeTheme, codeStyleSheet),
        'latex': LatexElementBuilder(
          textStyle: latexStyle,
          textScaleFactor: control.getDouble("latex_scale_factor"),
        ),
      },
      styleSheet: mdStyleSheet ?? baseStyleSheet,
      imageBuilder: (Uri uri, String? title, String? alt) => buildImage(
        context: context,
        src: uri.toString(),
        semanticsLabel: alt,
        disabled: control.disabled,
        errorCtrl: control.buildWidget("image_error_content"),
      ),
      shrinkWrap: control.getBool("shrink_wrap", true)!,
      fitContent: control.getBool("fit_content", true)!,
      softLineBreak: control.getBool("soft_line_break", false)!,
      onTapText: () => control.triggerEvent("tap_text"),
      onTapLink: (String text, String? href, String title) {
        if (autoFollowLinks && href != null) {
          openWebBrowser(Url(href, autoFollowLinksTarget));
        }
        control.triggerEvent("tap_link", href);
      },
    );
  }
}

void triggerMarkdownSelection(Control control, String selectedText) {
  final value = control.getString("value", "")!;
  final start = selectedText.isEmpty ? -1 : value.indexOf(selectedText);
  final end = start < 0 ? -1 : start + selectedText.length;
  control.triggerEvent("selection_change", {
    "text": selectedText,
    "cause": "user",
    "selection": {
      "start": start,
      "end": end,
      "selection": selectedText,
      "base_offset": start,
      "extent_offset": end,
      "affinity": "downstream",
      "directional": false,
      "collapsed": selectedText.isEmpty,
      "valid": start >= 0,
      "normalized": true,
    },
  });
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final Map<String, TextStyle> codeTheme;
  final MarkdownStyleSheet mdStyleSheet;

  CodeElementBuilder(this.codeTheme, this.mdStyleSheet);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (!element.textContent.endsWith('\n')) return null;
    var language = '';
    if (element.attributes['class'] != null) {
      language = (element.attributes['class'] as String).substring(9);
    }
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
        width:
            constraints.maxWidth == double.infinity ? 10000 : double.infinity,
        child: HighlightView(
          element.textContent.substring(0, element.textContent.length - 1),
          language: language,
          theme: codeTheme,
          padding: mdStyleSheet.codeblockPadding,
          decoration: mdStyleSheet.codeblockDecoration,
          textStyle: mdStyleSheet.code,
        ),
      );
    });
  }
}
