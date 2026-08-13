import RufletEngine
import RufletProtocol
import SwiftUI

struct LineChartControl: View {
  @ObservedObject var control: RufletControl

  private var series: [LineChartSeries] {
    control.children("data_series").enumerated().map { LineChartSeries.parse($0.element, index: $0.offset) }
  }

  private var allPoints: [ChartPoint] {
    series.flatMap { $0.points.map { ChartPoint(x: $0.x, y: $0.y) } }
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
    let domain = ChartDomain(points: allPoints, control: control)
    for line in series {
      let locations = line.points.map { domain.location(ChartPoint(x: $0.x, y: $0.y), in: size) }
      guard let first = locations.first else { continue }
      var path = Path()
      path.move(to: first)
      for location in locations.dropFirst() { path.addLine(to: location) }
      context.stroke(
        path,
        with: .color(line.color),
        style: StrokeStyle(lineWidth: CGFloat(line.strokeWidth), dash: line.dashPattern.map { CGFloat($0) }))
      for (index, point) in line.points.enumerated() {
        let radius: CGFloat = point.selected ? 6 : 3
        let circle = CGRect(
          x: locations[index].x - radius,
          y: locations[index].y - radius,
          width: radius * 2,
          height: radius * 2)
        context.fill(Path(ellipseIn: circle), with: .color(line.color))
      }
    }
  }

  private func emitTap(at location: CGPoint, size: CGSize) {
    guard control.hasEventHandler("event"), control.boolean("interactive", default: true) else { return }
    let domain = ChartDomain(points: allPoints, control: control)
    let candidates = series.enumerated().flatMap { seriesIndex, line in
      line.points.enumerated().map { pointIndex, point in
        (seriesIndex, pointIndex, point, domain.location(ChartPoint(x: point.x, y: point.y), in: size))
      }
    }
    guard let nearest = candidates.min(by: {
      hypot($0.3.x - location.x, $0.3.y - location.y) < hypot($1.3.x - location.x, $1.3.y - location.y)
    }) else { return }
    control.triggerEvent("event", data: .map([
      "type": .string("tapUp"),
      "bar_index": .int(Int64(nearest.0)),
      "spot_index": .int(Int64(nearest.1)),
      "spot_x": .double(nearest.2.x),
      "spot_y": .double(nearest.2.y),
    ]))
  }
}
