import SwiftUI

@MainActor
public struct SafeAreaControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.rufletSafeAreaInsets) private var safeAreaInsets
  @State private var keyboardOverlap = CGFloat.zero
  @State private var persistentBottomInset = CGFloat.zero

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    guard let content = control.buildWidget("content") else {
      return AnyView(ErrorControl("SafeArea.content must be provided and visible"))
    }
    let configuration = RufletSafeAreaConfiguration(control: control)
    return AnyView(
      LayoutControl(control: control) {
        content
          .padding(configuration.resolvedPadding(safeAreaInsets: safeAreaInsets))
          .padding(
            .bottom,
            RufletSafeAreaKeyboardInsetPolicy.additionalBottomInset(
              maintainBottomViewPadding: configuration.maintainBottomViewPadding,
              avoidsBottomIntrusion: configuration.avoidsBottomIntrusion,
              keyboardOverlap: keyboardOverlap,
              persistentBottomInset: persistentBottomInset
            )
          )
          .overlay {
            RufletSafeAreaKeyboardBridge(
              keyboardOverlap: $keyboardOverlap,
              persistentBottomInset: $persistentBottomInset
            )
            .allowsHitTesting(false)
          }
      })
  }
}

@MainActor
struct RufletSafeAreaConfiguration {
  let avoidsLeftIntrusion: Bool
  let avoidsTopIntrusion: Bool
  let avoidsRightIntrusion: Bool
  let avoidsBottomIntrusion: Bool
  let maintainBottomViewPadding: Bool
  let minimumPadding: EdgeInsets

  init(control: RufletControl) {
    avoidsLeftIntrusion = control.boolean("avoid_intrusions_left", default: true)
    avoidsTopIntrusion = control.boolean("avoid_intrusions_top", default: true)
    avoidsRightIntrusion = control.boolean("avoid_intrusions_right", default: true)
    avoidsBottomIntrusion = control.boolean("avoid_intrusions_bottom", default: true)
    maintainBottomViewPadding = control.boolean("maintain_bottom_view_padding", default: false)
    minimumPadding = parseEdgeInsets(control.dynamicValue("minimum_padding")) ?? EdgeInsets()
  }

  func resolvedPadding(safeAreaInsets: RufletSafeAreaInsets) -> EdgeInsets {
    EdgeInsets(
      top: max(minimumPadding.top, avoidsTopIntrusion ? safeAreaInsets.top : 0),
      leading: max(minimumPadding.leading, avoidsLeftIntrusion ? safeAreaInsets.leading : 0),
      bottom: max(minimumPadding.bottom, avoidsBottomIntrusion ? safeAreaInsets.bottom : 0),
      trailing: max(minimumPadding.trailing, avoidsRightIntrusion ? safeAreaInsets.trailing : 0))
  }
}

enum RufletSafeAreaKeyboardInsetPolicy {
  static func additionalBottomInset(
    maintainBottomViewPadding: Bool,
    avoidsBottomIntrusion: Bool,
    keyboardOverlap: CGFloat,
    persistentBottomInset: CGFloat
  ) -> CGFloat {
    guard maintainBottomViewPadding, avoidsBottomIntrusion, keyboardOverlap > 0 else { return 0 }
    return max(persistentBottomInset, 0)
  }
}
