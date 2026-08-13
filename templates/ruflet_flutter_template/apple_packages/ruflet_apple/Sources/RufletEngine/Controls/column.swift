import SwiftUI

@MainActor
public struct ColumnControl: View {
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
          axis: .vertical,
          spacing: spacing,
          runSpacing: control.number("run_spacing") ?? 10,
          alignment: rufletMainAxisAlignment(control.string("alignment")),
          runAlignment: rufletMainAxisAlignment(control.string("run_alignment")),
          crossAlignment: rufletWrapCrossAlignment(
            control.string("horizontal_alignment"), default: .start),
          crossExtent: control.number("width").map { CGFloat($0) },
          children: children.map { AnyView(ControlWidget(control: $0)) }
        ))
    }
    return AnyView(
      RufletFlexibleAxisStack(
        axis: .vertical,
        children: children,
        spacing: spacing,
        horizontalAlignment: horizontalAlignment,
        verticalAlignment: .center,
        frameAlignment: verticalAlignment,
        mainAxisAlignment: rufletMainAxisAlignment(control.string("alignment")),
        crossAxisStretch: control.string("horizontal_alignment")?.lowercased() == "stretch",
        tight: control.boolean("tight", default: false)
      )
      .modifier(
        RufletIntrinsicAxisModifier(
          horizontal: control.boolean("intrinsic_width", default: false),
          vertical: false)))
  }

  private func scrollable(_ content: AnyView) -> AnyView {
    AnyView(
      ScrollableControl(
        control: control,
        scrollDirection: control.boolean("wrap", default: false) ? .horizontal : .vertical,
        wrapIntoScrollableView: true
      ) { content })
  }

  private func scrollNotified(_ content: AnyView) -> AnyView {
    guard control.boolean("on_scroll", default: false) else { return content }
    return AnyView(ScrollNotificationControl(control: control) { content })
  }

  private var horizontalAlignment: HorizontalAlignment {
    switch control.string("horizontal_alignment")?.lowercased() {
    case "end": .trailing
    case "center": .center
    default: .leading
    }
  }

  private var verticalAlignment: Alignment {
    switch control.string("alignment")?.lowercased() {
    case "end": .bottom
    case "center": .center
    default: .top
    }
  }
}
