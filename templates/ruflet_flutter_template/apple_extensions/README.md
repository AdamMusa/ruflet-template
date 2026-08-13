# Ruflet Apple application extensions

This is the application-owned native counterpart of Flet's `FletExtension`.
It is used by both `ruflet build ios` and `ruflet build ios --self` (and by
the equivalent macOS builds).

Add Swift files under `Sources/RufletAppExtensions`, conform your extension to
`RufletExtension`, then add its type to `RufletAppExtensionRegistry.extensions`.
The first extension returning a non-nil view, service, or icon wins.

```swift
import RufletApple
import SwiftUI

enum RatingExtension: RufletExtension {
  static func createView(for control: ControlNode) -> AnyView? {
    guard control.type == "rating" else { return nil }
    return AnyView(RatingView(control: control))
  }
}
```

The renderer applies the ordinary Ruflet layout/modifier pipeline around the
returned view. Do not edit the generated files under `build/client`; the CLI
copies this package from the Ruby project into that client during every build.
