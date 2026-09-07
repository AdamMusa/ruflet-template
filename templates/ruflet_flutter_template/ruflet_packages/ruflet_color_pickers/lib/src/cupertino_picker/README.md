# Cupertino color picker renderer

This is a local renderer fork of flutter_colorpicker 1.1.0, under the MIT
license included in LICENSE. It preserves the upstream palettes, painters,
HSV/HSL/RGB conversion, alpha handling, history and picker callbacks. Cupertino
buttons, action sheets and text fields replace Material input, dropdowns and ink.

`palette_colors.dart` retains the numeric swatches needed by the existing
MaterialPicker wire control. It contains only painting data, adapted from
Flutter's colors.dart under the BSD license in FLUTTER_LICENSE. Selecting that
wire control still offers the same named swatch values in a Cupertino renderer.

The extension's Material renderers continue to use the pinned upstream package.
