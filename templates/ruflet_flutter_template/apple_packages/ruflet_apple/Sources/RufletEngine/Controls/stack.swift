import SwiftUI

@MainActor
public struct StackControl: View {
  @ObservedObject public var control: RufletControl
  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    LayoutControl(control: control) {
      ZStack(
        alignment: parseAlignment(control.dynamicValue("alignment"), RufletAlignment(x: -1, y: -1))!
          .swiftUI
      ) {
        ForEach(control.children("controls"), id: \.id) { child in
          ControlWidget(control: child)
        }
      }
      .modifier(RufletStackFitModifier(fit: control.string("fit")))
      .clipped(antialiased: control.string("clip_behavior")?.lowercased() == "antialias")
    }
  }
}

private struct RufletStackFitModifier: ViewModifier {
  let fit: String?

  func body(content: Content) -> some View {
    switch fit?.lowercased() {
    case "expand": content.frame(maxWidth: .infinity, maxHeight: .infinity)
    case "passthrough": content.fixedSize()
    default: content
    }
  }
}
