import RufletEngine
import RufletProtocol
import SwiftUI

struct PieChartControl: View {
  @ObservedObject var control: RufletControl

  private var sections: [PieChartSection] {
    control.children("sections").enumerated().map { PieChartSection.parse($0.element, index: $0.offset) }
  }

  var body: some View {
    ChartFrame(control: control) {
      GeometryReader { proxy in
        let layout = chartLayout(size: proxy.size)
        ZStack {
          Canvas { context, _ in draw(context: &context, layout: layout) }
          badges(layout: layout)
        }
        .animation(
          chartAnimation(control.dynamicValue("animation")),
          value: control.revision)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onEnded { value in
          emitTap(at: value.location, layout: layout)
        })
      }
    }
  }

  private func chartLayout(size: CGSize) -> PieChartLayout {
    PieChartLayout(
      size: size,
      sections: sections,
      requestedCenterRadius: control.number("center_space_radius"),
      sectionsSpace: control.number("sections_space", default: 2) ?? 2,
      startDegreeOffset: control.number("start_degree_offset", default: 0) ?? 0)
  }

  private func draw(context: inout GraphicsContext, layout: PieChartLayout) {
    for slice in layout.slices {
      guard sections.indices.contains(slice.index) else { continue }
      let section = sections[slice.index]
      context.drawLayer { layer in
        layer.fill(wedgePath(slice: slice, center: layout.center), with: .color(section.color))
        if slice.innerRadius > 0 {
          layer.blendMode = .destinationOut
          layer.fill(
            Path(ellipseIn: CGRect(
              x: layout.center.x - slice.innerRadius,
              y: layout.center.y - slice.innerRadius,
              width: slice.innerRadius * 2,
              height: slice.innerRadius * 2)),
            with: .color(.black))
        }
      }

      if let title = section.title {
        context.draw(
          styledTitle(title, style: section.titleStyle),
          at: layout.point(in: slice, percentage: section.titlePosition))
      }
    }

    if layout.centerRadius > 0,
       let centerColor = parseColor(control.string("center_space_color")) {
      context.fill(
        Path(ellipseIn: CGRect(
          x: layout.center.x - layout.centerRadius,
          y: layout.center.y - layout.centerRadius,
          width: layout.centerRadius * 2,
          height: layout.centerRadius * 2)),
        with: .color(centerColor))
    }
  }

  private func wedgePath(slice: PieChartLayout.Slice, center: CGPoint) -> Path {
    var path = Path()
    if slice.sweep >= 2 * .pi - 0.000_001 {
      path.addEllipse(in: CGRect(
        x: center.x - slice.outerRadius,
        y: center.y - slice.outerRadius,
        width: slice.outerRadius * 2,
        height: slice.outerRadius * 2))
      return path
    }
    path.move(to: center)
    path.addLine(to: CGPoint(
      x: center.x + cos(slice.start) * slice.outerRadius,
      y: center.y + sin(slice.start) * slice.outerRadius))
    path.addArc(
      center: center,
      radius: slice.outerRadius,
      startAngle: .radians(slice.start),
      endAngle: .radians(slice.end),
      clockwise: false)
    path.closeSubpath()
    return path
  }

  private func styledTitle(_ title: String, style: RufletTextStyle?) -> Text {
    var result = Text(title)
    if let family = style?.fontFamily, let size = style?.size {
      result = result.font(.custom(family, size: size))
    } else if let size = style?.size {
      result = result.font(.system(size: size))
    }
    if let weight = style?.weight { result = result.fontWeight(weight) }
    if style?.italic == true { result = result.italic() }
    if let color = style?.color { result = result.foregroundColor(color) }
    if let spacing = style?.letterSpacing { result = result.kerning(spacing) }
    if let style {
      result = result.underline(style.decoration & 0x1 > 0, color: style.decorationColor)
      result = result.strikethrough(style.decoration & 0x4 > 0, color: style.decorationColor)
    }
    return result
  }

  @ViewBuilder
  private func badges(layout: PieChartLayout) -> some View {
    ForEach(layout.slices, id: \.index) { slice in
      if sections.indices.contains(slice.index), let badge = sections[slice.index].badge {
        ControlWidget(control: badge)
          .position(layout.point(in: slice, percentage: sections[slice.index].badgePosition))
      }
    }
  }

  private func emitTap(at location: CGPoint, layout: PieChartLayout) {
    guard control.hasEventHandler("event"), !control.disabled else { return }
    control.triggerEvent("event", data: chartEvent(
      type: "tapUp",
      location: location,
      fields: [
        "section_index": layout.sectionIndex(at: location).map { .int(Int64($0)) } ?? .null,
      ]))
  }
}
