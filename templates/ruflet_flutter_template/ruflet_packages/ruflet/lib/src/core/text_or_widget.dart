import 'package:flutter/widgets.dart';

/// A label-like value Ruby sends either as plain text (`label: "On"`) or as a
/// child control (`label: text("On", weight: "bold")`).
///
/// The core parses it; the skin builds it, styling plain text with its native
/// label style while a child control keeps its own style.
@immutable
class TextOrWidget {
  const TextOrWidget.text(String this.text) : widget = null;
  const TextOrWidget.widget(Widget this.widget) : text = null;

  final String? text;
  final Widget? widget;

  /// Plain text that is the empty string.
  bool get isEmptyText => text != null && text!.isEmpty;

  Widget build({TextStyle? style}) => widget ?? Text(text!, style: style);
}
