import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_ads/utils/native.dart';

void main() {
  test('template_type uses the Ruby value name, not the Dart toString', () {
    // Ruby sends "small"; the old comparison expected "TemplateType.small"
    // and always fell back to medium.
    expect(parseTemplateType('small', TemplateType.medium), TemplateType.small);
    expect(parseTemplateType('SMALL'), TemplateType.small);
    expect(
        parseTemplateType('large', TemplateType.medium), TemplateType.medium);
    const theme = RufletStyleTheme();
    expect(
        parseNativeTemplateStyle({'template_type': 'small'}, theme)!
            .templateType,
        TemplateType.small);
  });

  test('text style font style names match by value name', () {
    expect(parseNativeTemplateFontStyle('bold'), NativeTemplateFontStyle.bold);
    expect(parseNativeTemplateFontStyle('Monospace'),
        NativeTemplateFontStyle.monospace);
    expect(parseNativeTemplateFontStyle('heavy'), isNull);
    const theme = RufletStyleTheme();
    expect(parseNativeTemplateTextStyle({'style': 'italic'}, theme)!.style,
        NativeTemplateFontStyle.italic);
  });
}
