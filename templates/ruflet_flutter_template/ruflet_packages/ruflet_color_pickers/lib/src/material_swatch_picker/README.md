# Material swatch picker renderer

This is a local renderer fork of flutter_colorpicker 1.1.0's `MaterialPicker`
(`lib/src/material_picker.dart`), under the MIT license included in LICENSE.
It keeps the upstream Material layout, palettes, animations and callbacks, and
still uses the upstream package's `colorToHex` and `useWhiteForeground`.

It exists for one fix: upstream builds the shade label's hex text from
`Color.toString()`, whose format changed in Flutter 3.27, so the label read
`#COLOR(ALPHA: …`. Here the label goes through `colorToHex`, giving `#RRGGBB`.
The class is renamed `MaterialSwatchPicker` (like the Cupertino fork's
`CupertinoSwatchPicker`), and the library `material_swatch_picker`, so neither
clashes with upstream or the Cupertino fork.
Remaining edits only clear analyzer issues: `Color.value` → `toARGB32()`,
super parameters, braces and local names.
