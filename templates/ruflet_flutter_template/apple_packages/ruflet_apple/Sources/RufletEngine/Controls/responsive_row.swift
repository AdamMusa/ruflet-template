import SwiftUI

/// Apple-native port of Flet's `ResponsiveRowControl`.
@MainActor
public struct ResponsiveRowControl: View, RufletStoreMixin {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    withPageSize { page in
      LayoutControl(control: control) {
        GeometryReader { proxy in
          responsiveContent(
            width: proxy.size.width,
            pageWidth: page.size.width,
            pageBreakpoints: page.breakpoints)
        }
      }
    }
  }

  private func responsiveContent(
    width: CGFloat,
    pageWidth: CGFloat,
    pageBreakpoints: [String: Double]
  ) -> some View {
    let activeBreakpoints = breakpoints(defaults: pageBreakpoints)
    let columns = active(
      control.dynamicValue("columns"), default: 12, width: pageWidth,
      breakpoints: activeBreakpoints)
    let spacing = active(
      control.dynamicValue("spacing"), default: 10, width: pageWidth,
      breakpoints: activeBreakpoints)
    // Pinned Flet resolves run spacing against the View breakpoint contract,
    // while columns, spacing and child spans honor ResponsiveRow.breakpoints.
    let runSpacing = active(
      control.dynamicValue("run_spacing"), default: 10, width: pageWidth,
      breakpoints: pageBreakpoints)
    let columnWidth =
      columns > 0
      ? (width - spacing * max(columns - 1, 0)) / columns
      : 0
    let children = control.children("controls")
    let spans = children.map {
      max(
        active(
          $0.dynamicValue("col"), default: 12, width: pageWidth,
          breakpoints: activeBreakpoints),
        0)
    }
    let views = zip(children, spans).map { child, span in
      AnyView(
        ControlWidget(control: child)
          .frame(width: max(columnWidth * span + spacing * max(span - 1, 0), 0)))
    }
    let childWidths = Dictionary(
      zip(children, spans).map { child, span in
        (
          child.id,
          max(columnWidth * span + spacing * max(span - 1, 0), 0)
        )
      },
      uniquingKeysWith: { _, latest in latest })

    if spans.reduce(0, +) > columns {
      return AnyView(
        RufletFlowLayout(
          axis: .horizontal,
          spacing: Double(max(spacing - 0.1, 0)),
          runSpacing: Double(runSpacing),
          alignment: rufletMainAxisAlignment(control.string("alignment")),
          runAlignment: .start,
          crossAlignment: rufletWrapCrossAlignment(
            control.string("vertical_alignment"), default: .start),
          crossExtent: nil,
          children: views
        ))
    }

    return AnyView(
      RufletFlexibleAxisStack(
        axis: .horizontal,
        children: children,
        spacing: max(spacing - 0.1, 0),
        horizontalAlignment: .leading,
        verticalAlignment: verticalAlignment,
        frameAlignment: .leading,
        mainAxisAlignment: rufletMainAxisAlignment(control.string("alignment")),
        crossAxisStretch: control.string("vertical_alignment")?.lowercased() == "stretch",
        tight: false,
        fixedMainExtents: childWidths
      ))
  }

  private func active(
    _ value: Any?,
    default defaultValue: Double,
    width: CGFloat,
    breakpoints: [String: Double]
  ) -> CGFloat {
    CGFloat(
      getBreakpointNumber(
        parseResponsiveNumber(value, defaultValue),
        width: Double(width),
        breakpoints: breakpoints
      ))
  }

  private func breakpoints(defaults: [String: Double]) -> [String: Double] {
    guard let raw = rufletDictionary(control.dynamicValue("breakpoints")) else { return defaults }
    var result: [String: Double] = [:]
    for (key, value) in raw {
      if let number = parseDouble(value) { result[key] = number }
    }
    return result
  }

  private var verticalAlignment: VerticalAlignment {
    switch control.string("vertical_alignment")?.lowercased() {
    case "end": .bottom
    case "center", "stretch": .center
    case "baseline": .firstTextBaseline
    default: .top
    }
  }

}
