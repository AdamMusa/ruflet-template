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
        Canvas { context, size in draw(context: &context, size: size) }
          .contentShape(Rectangle())
          .gesture(DragGesture(minimumDistance: 0).onEnded { value in
            emitTap(at: value.location, size: proxy.size)
          })
      }
    }
  }

  private func draw(context: inout GraphicsContext, size: CGSize) {
    let total = sections.reduce(0) { $0 + $1.value }
    guard total > 0 else { return }
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let outerRadius = min(size.width, size.height) / 2 - 8
    let holeRadius = CGFloat(control.number("center_space_radius", default: 0) ?? 0)
    var angle = Angle.degrees(control.number("start_degree_offset", default: -90) ?? -90)

    for section in sections {
      let next = angle + .degrees(section.value / total * 360)
      var path = Path()
      path.move(to: center)
      path.addArc(center: center, radius: outerRadius, startAngle: angle, endAngle: next, clockwise: false)
      path.closeSubpath()
      context.fill(path, with: .color(section.color))

      if let title = section.title {
        let middle = (angle.radians + next.radians) / 2
        let titleRadius = outerRadius * CGFloat(section.titlePosition)
        context.draw(
          Text(title).foregroundColor(.white),
          at: CGPoint(x: center.x + cos(middle) * titleRadius, y: center.y + sin(middle) * titleRadius))
      }
      angle = next
    }

    if holeRadius > 0 {
      context.fill(
        Path(ellipseIn: CGRect(
          x: center.x - holeRadius, y: center.y - holeRadius,
          width: holeRadius * 2, height: holeRadius * 2)),
        with: .color(control.chartColor("center_space_color", default: .clear)))
    }
  }

  private func emitTap(at location: CGPoint, size: CGSize) {
    guard control.hasEventHandler("event") else { return }
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    var degrees = atan2(location.y - center.y, location.x - center.x) * 180 / .pi
    let start = control.number("start_degree_offset", default: -90) ?? -90
    degrees = (degrees - start).truncatingRemainder(dividingBy: 360)
    if degrees < 0 { degrees += 360 }
    let total = sections.reduce(0) { $0 + $1.value }
    var cumulative = 0.0
    let index = total > 0 ? sections.firstIndex {
      cumulative += $0.value / total * 360
      return degrees <= cumulative
    } : nil
    control.triggerEvent("event", data: chartEvent(
      type: "tapUp",
      location: location,
      fields: ["section_index": index.map { .int(Int64($0)) } ?? .null]))
  }
}
