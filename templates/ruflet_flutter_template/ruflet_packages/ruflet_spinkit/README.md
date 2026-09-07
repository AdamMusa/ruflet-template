# ruflet_spinkit

Bundled Ruflet extension for Ruflet loading indicators. The package owns the
`flutter_spinkit` dependency and exports the standard `RufletExtension`
entrypoint:

```dart
import "package:ruflet_spinkit/ruflet_spinkit.dart" as ruflet_spinkit;

final extensions = <RufletExtension>[
  ruflet_spinkit.Extension(),
];
```

It accepts both the individual Ruflet SpinKit wire types and Ruflet's generic
`RufletSpinKit` wire type with a snake-case `variant` property. The reusable
client depends on this package; it does not import `flutter_spinkit` directly.
