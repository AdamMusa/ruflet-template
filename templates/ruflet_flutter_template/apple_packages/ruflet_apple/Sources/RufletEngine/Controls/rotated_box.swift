import SwiftUI

/// Native Apple implementation of Ruflet's Flet-compatible `RotatedBox` wire
/// control. Unlike a visual rotation transform, quarter turns participate in
/// layout: odd turns exchange the child's width and height.
@MainActor
public struct RotatedBoxControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      if let content = control.buildWidget("content") {
        RufletQuarterTurnLayout(
          quarterTurns: presentation.quarterTurns,
          content: content)
      }
    }
  }

  private var presentation: RufletRotatedBoxPresentation {
    RufletRotatedBoxPresentation(control: control)
  }
}

@MainActor
struct RufletRotatedBoxPresentation {
  let quarterTurns: Int

  init(control: RufletControl) {
    quarterTurns = Self.normalized(control.integer("quarter_turns", default: 0) ?? 0)
  }

  static func normalized(_ value: Int) -> Int {
    let remainder = value % 4
    return remainder >= 0 ? remainder : remainder + 4
  }

  var swapsDimensions: Bool { quarterTurns.isMultiple(of: 2) == false }
  var angle: Angle { .degrees(Double(quarterTurns * 90)) }
}

private struct RufletQuarterTurnLayout: View {
  let quarterTurns: Int
  let content: AnyView
  @State private var contentSize = CGSize.zero

  var body: some View {
    let presentation = RufletRotatedBoxPresentationValue(quarterTurns: quarterTurns)
    content
      .fixedSize()
      .background {
        GeometryReader { proxy in
          Color.clear.preference(key: RufletRotatedContentSizeKey.self, value: proxy.size)
        }
      }
      .rotationEffect(presentation.angle)
      .frame(
        width: contentSize == .zero
          ? nil : (presentation.swapsDimensions ? contentSize.height : contentSize.width),
        height: contentSize == .zero
          ? nil : (presentation.swapsDimensions ? contentSize.width : contentSize.height)
      )
      .onPreferenceChange(RufletRotatedContentSizeKey.self) { next in
        if next != contentSize { contentSize = next }
      }
  }
}

private struct RufletRotatedBoxPresentationValue {
  let quarterTurns: Int
  var swapsDimensions: Bool { quarterTurns.isMultiple(of: 2) == false }
  var angle: Angle { .degrees(Double(quarterTurns * 90)) }
}

private struct RufletRotatedContentSizeKey: PreferenceKey {
  static let defaultValue = CGSize.zero

  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    let next = nextValue()
    if next != .zero { value = next }
  }
}
