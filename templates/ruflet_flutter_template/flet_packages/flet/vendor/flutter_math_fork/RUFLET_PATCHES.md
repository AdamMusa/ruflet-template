# Ruflet patches to flutter_math_fork 0.7.4

Upstream: https://github.com/simpleclub-extended/flutter_math_fork.
The MIT license and bundled KaTeX fonts/licenses are retained.

The non-selectable Math widget uses widgets.dart and renders errors as Text.
This ensures malformed expressions remain design-neutral on Cupertino pages.
SelectableMath uses a neutral MathSelectionPlatform (platform override or the
framework target platform), with separate Material and Cupertino style, handle,
toolbar, and selectable-error renderers. Native selection reads CupertinoTheme
and DefaultSelectionStyle; Material Theme and TextSelectionTheme are confined to
the Material adapter. All shared AST, painting, layout and selection files use
widgets.dart. Existing caller-supplied selection controls remain supported.

The legacy selection delegate now implements select-all, copy, and scrolling to
selection endpoints. Toolbar hiding is idempotent, including the macOS
select-all action. Clipboard copying keeps the TeX encoding and omits the
internal select-all marker. Tests cover iOS, macOS and Android native controls,
select-all/copy toolbar callbacks, and valid/malformed equations.
