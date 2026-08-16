# Material Color Utilities

This directory vendors the official Swift implementation from
[`material-foundation/material-color-utilities`](https://github.com/material-foundation/material-color-utilities),
commit `f05459ea2170f3be610f89a4ddeee8843c2deb61`.

Ruflet uses it to reproduce Flutter's `ThemeData(colorSchemeSeed:)` Material 3
tonal-spot scheme. The corresponding Flet 0.80.5 Flutter runtime resolves the
same roles through Dart `material_color_utilities` 0.13.0.

The vendored source is licensed under Apache License 2.0. See `LICENSE`.
