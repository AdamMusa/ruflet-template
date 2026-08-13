import SwiftUI

/// Apple-native port of pinned Flet `navigation_bar_destination.dart`.
/// The parent navigation bar supplies selected state; when rendered directly,
/// this view preserves the destination's icon/label/tooltip contract.
@MainActor
public struct NavigationBarDestinationControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    BaseControl(control: control) {
      VStack(spacing: 2) {
        control.buildIconOrWidget("icon")
        if let label = control.string("label"), !label.isEmpty {
          Text(label).font(.caption2)
        }
      }
      .opacity(control.disabled ? 0.45 : 1)
      .modifier(
        RufletNavigationDestinationTooltip(
          text: control.string("tooltip"), enabled: !control.disabled))
    }
  }
}

private struct RufletNavigationDestinationTooltip: ViewModifier {
  let text: String?
  let enabled: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled, let text {
      #if os(macOS)
      content.help(text)
      #elseif os(iOS)
      content.accessibilityHint(Text(text))
      #endif
    } else {
      content
    }
  }
}
