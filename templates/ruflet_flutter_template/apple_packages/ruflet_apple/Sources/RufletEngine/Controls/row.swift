import SwiftUI

@MainActor
public struct RowControl: View {
  @ObservedObject public var control: RufletControl
  public init(control: RufletControl) { self.control = control }

  public var body: some View {
    LayoutControl(control: control) {
      scrollNotified(scrollable(content))
    }
  }

  private var content: AnyView {
    let spacing = control.number("spacing") ?? 10
    let children = control.children("controls")
    if control.boolean("wrap", default: false) {
      return AnyView(
        RufletFlowLayout(
          axis: .horizontal,
          spacing: spacing,
          runSpacing: control.number("run_spacing") ?? 10,
          alignment: rufletMainAxisAlignment(control.string("alignment")),
          runAlignment: rufletMainAxisAlignment(control.string("run_alignment")),
          crossAlignment: rufletWrapCrossAlignment(control.string("vertical_alignment")),
          crossExtent: control.number("height").map { CGFloat($0) },
          children: children.map { AnyView(ControlWidget(control: $0)) }
        ))
    }
    return AnyView(
      RufletFlexibleAxisStack(
        axis: .horizontal,
        children: children,
        spacing: spacing,
        horizontalAlignment: .leading,
        verticalAlignment: verticalAlignment,
        frameAlignment: horizontalAlignment,
        mainAxisAlignment: rufletMainAxisAlignment(control.string("alignment")),
        crossAxisStretch: control.string("vertical_alignment")?.lowercased() == "stretch",
        tight: control.boolean("tight", default: false)
      )
      .modifier(
        RufletIntrinsicAxisModifier(
          horizontal: false,
          vertical: control.boolean("intrinsic_height", default: false))))
  }

  private func scrollable(_ content: AnyView) -> AnyView {
    AnyView(
      ScrollableControl(
        control: control,
        scrollDirection: control.boolean("wrap", default: false) ? .vertical : .horizontal,
        wrapIntoScrollableView: true
      ) { content })
  }

  private func scrollNotified(_ content: AnyView) -> AnyView {
    guard control.boolean("on_scroll", default: false) else { return content }
    return AnyView(ScrollNotificationControl(control: control) { content })
  }

  private var verticalAlignment: VerticalAlignment {
    switch control.string("vertical_alignment")?.lowercased() {
    case "start": .top
    case "end": .bottom
    case "baseline": .firstTextBaseline
    default: .center
    }
  }

  private var horizontalAlignment: Alignment {
    switch control.string("alignment")?.lowercased() {
    case "end": .trailing
    case "center": .center
    default: .leading
    }
  }
}
