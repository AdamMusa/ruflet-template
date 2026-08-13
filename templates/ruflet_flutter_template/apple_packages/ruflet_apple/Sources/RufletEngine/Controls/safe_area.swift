import SwiftUI

@MainActor
public struct SafeAreaControl: View {
  @ObservedObject public var control: RufletControl
  @State private var keyboardOverlap = CGFloat.zero
  @State private var persistentBottomInset = CGFloat.zero

  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    guard let content = control.buildWidget("content") else {
      preconditionFailure("SafeArea.content must be provided and visible")
    }
    let configuration = RufletSafeAreaConfiguration(control: control)
    return AnyView(
      LayoutControl(control: control) {
        content
          .padding(configuration.minimumPadding)
          .padding(
            .bottom,
            RufletSafeAreaKeyboardInsetPolicy.additionalBottomInset(
              maintainBottomViewPadding: configuration.maintainBottomViewPadding,
              avoidsBottomIntrusion: configuration.avoidsBottomIntrusion,
              keyboardOverlap: keyboardOverlap,
              persistentBottomInset: persistentBottomInset
            )
          )
          .ignoresSafeArea(edges: configuration.ignoredEdges)
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
  let avoidsBottomIntrusion: Bool
  let ignoredEdges: Edge.Set
  let maintainBottomViewPadding: Bool
  let minimumPadding: EdgeInsets

  init(control: RufletControl) {
    var ignoredEdges: Edge.Set = []
    if !control.boolean("avoid_intrusions_left", default: true) { ignoredEdges.insert(.leading) }
    if !control.boolean("avoid_intrusions_top", default: true) { ignoredEdges.insert(.top) }
    if !control.boolean("avoid_intrusions_right", default: true) { ignoredEdges.insert(.trailing) }
    avoidsBottomIntrusion = control.boolean("avoid_intrusions_bottom", default: true)
    if !avoidsBottomIntrusion { ignoredEdges.insert(.bottom) }
    self.ignoredEdges = ignoredEdges
    maintainBottomViewPadding = control.boolean("maintain_bottom_view_padding", default: false)
    minimumPadding = parseEdgeInsets(control.dynamicValue("minimum_padding")) ?? EdgeInsets()
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
