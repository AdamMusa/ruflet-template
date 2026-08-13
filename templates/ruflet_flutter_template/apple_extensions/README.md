# Ruflet Apple application extensions

This is the application-owned native counterpart of Flet's `FletExtension`.
It is used by both `ruflet build ios` and `ruflet build ios --self` (and by
the equivalent macOS builds).

Add Swift files under `Sources/RufletAppExtensions`, conform your extension to
`RufletExtension`, then add an instance to
`RufletAppExtensionRegistry.extensions`. The first extension returning a
non-nil view, service, or icon wins. The same registry is copied into both
server-driven and self-contained Apple builds.

```swift
import RufletApple
import SwiftUI

@MainActor
struct RatingExtension: RufletExtension {
  let renderedControlTypes: Set<String> = ["Rating"]

  func createView(for control: RufletControl) -> AnyView? {
    guard control.type == "Rating" else { return nil }
    return AnyView(
      LayoutControl(control: control) {
        RatingView(control: control)
      })
  }
}

@MainActor
struct RatingView: View {
  @ObservedObject var control: RufletControl

  var body: some View {
    HStack {
      ForEach(1...5, id: \.self) { value in
        Button {
          control.updateProperties(["value": .int(value)], notify: false)
          control.triggerEvent("change", data: .int(value))
        } label: {
          Image(systemName: value <= (control.integer("value") ?? 0) ? "star.fill" : "star")
        }
        .buttonStyle(.plain)
      }
    }
  }
}
```

Register the instance in `RufletAppExtensionRegistry.swift`:

```swift
public static let extensions: [any RufletExtension] = [
  RatingExtension(),
]
```

Use `LayoutControl` for controls that participate in Ruflet layout properties
and `BaseControl` for non-layout controls. Do not reproduce those modifiers in
the extension itself.

The renderer applies the ordinary Ruflet layout/modifier pipeline around the
returned view. Do not edit the generated files under `build/client`; the CLI
copies this package from the Ruby project into that client during every build.
