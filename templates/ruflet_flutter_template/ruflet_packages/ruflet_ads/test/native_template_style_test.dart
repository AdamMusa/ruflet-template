import 'package:ruflet/ruflet.dart';
import 'package:ruflet_ads/utils/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native ad action styles receive values and native color roles in order',
      () {
    const theme = RufletStyleTheme(colors: {'primary': Color(0xFF123456)});
    final style = parseNativeTemplateStyle({
      'call_to_action_text_style': {
        'size': 18,
        'color': 'primary',
        'bgcolor': '#ffffff'
      },
    }, theme)!;
    expect(style.callToActionTextStyle?.size, 18);
    expect(style.callToActionTextStyle?.textColor, const Color(0xFF123456));
    expect(
        style.callToActionTextStyle?.backgroundColor, const Color(0xFFFFFFFF));
  });
}
