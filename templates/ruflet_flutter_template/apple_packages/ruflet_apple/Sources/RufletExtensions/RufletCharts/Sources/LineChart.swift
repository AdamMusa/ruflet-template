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
        let domain = ChartDomain(points: allPoints, control: control)
        let configuration = ChartCartesianConfiguration(control: control)
        let layout = ChartCartesianLayout(size: proxy.size, axes: configuration.axes)
        ZStack {
          Canvas { context, _ in
            drawCartesianDecoration(
              context: &context, layout: layout, domain: domain,
              configuration: configuration)
            draw(context: &context, layout: layout, domain: domain)
          }
          ChartAxesOverlay(
            axes: configuration.axes, domain: domain, layout: layout,
            baselineX: configuration.baselineX, baselineY: configuration.baselineY)
        }
          .animation(
            chartAnimation(control.dynamicValue("animation")),
            value: control.revision)
          .contentShape(Rectangle())
          .gesture(DragGesture(minimumDistance: 0).onEnded { value in
            emitTap(at: value.location, layout: layout, domain: domain)
          })
      }
    }
  }

  private func draw(
    context: inout GraphicsContext,
    layout: ChartCartesianLayout,
    domain: ChartDomain
  ) {
    for line in series {
      let locations = line.points.map {
        layout.location(ChartPoint(x: $0.x, y: $0.y), domain: domain)
      }
      guard let first = locations.first else { continue }
      var path = Path()
      path.move(to: first)
      if line.curved {
        for (previous, location) in zip(locations, locations.dropFirst()) {
          let midpoint = CGPoint(x: (previous.x + location.x) / 2, y: (previous.y + location.y) / 2)
          path.addQuadCurve(to: midpoint, control: previous)
          path.addQuadCurve(to: location, control: location)
        }
      } else {
        for location in locations.dropFirst() { path.addLine(to: location) }
      }
      let shading = line.gradient?.shading(
        from: CGPoint(x: layout.plotRect.minX, y: layout.plotRect.midY),
        to: CGPoint(x: layout.plotRect.maxX, y: layout.plotRect.midY)) ?? .color(line.color)
      context.stroke(
        path,
        with: shading,
        style: StrokeStyle(
          lineWidth: CGFloat(line.strokeWidth),
          lineCap: line.roundedStrokeCap ? .round : .butt,
          dash: line.dashPattern.map { CGFloat($0) }))
      for (index, point) in line.points.enumerated() {
        let radius: CGFloat = point.selected ? 6 : 3
        let circle = CGRect(
          x: locations[index].x - radius,
          y: locations[index].y - radius,
          width: radius * 2,
          height: radius * 2)
        context.fill(Path(ellipseIn: circle), with: shading)
        if point.selected && !control.boolean("interactive", default: true) {
          let range = chartIndicatorRange(
            start: control.number("point_line_start"),
            end: control.number("point_line_end"),
            pointY: point.y,
            domain: domain)
          var indicator = Path()
          indicator.move(to: CGPoint(
            x: locations[index].x,
            y: layout.location(ChartPoint(x: point.x, y: range.lowerBound), domain: domain).y))
          indicator.addLine(to: CGPoint(
            x: locations[index].x,
            y: layout.location(ChartPoint(x: point.x, y: range.upperBound), domain: domain).y))
          context.stroke(indicator, with: .color(line.color.opacity(0.7)), lineWidth: 1)
        }
      }
    }
  }

  private func emitTap(
    at location: CGPoint,
    layout: ChartCartesianLayout,
    domain: ChartDomain
  ) {
    guard control.hasEventHandler("event"), control.boolean("interactive", default: true),
      !control.disabled else { return }
    let candidates = series.enumerated().flatMap { seriesIndex, line in
      line.points.enumerated().map { pointIndex, point in
        (seriesIndex, pointIndex, point, layout.location(
          ChartPoint(x: point.x, y: point.y), domain: domain))
      }
    }
    guard let nearest = candidates.min(by: {
      hypot($0.3.x - location.x, $0.3.y - location.y) < hypot($1.3.x - location.x, $1.3.y - location.y)
    }) else { return }
    control.triggerEvent("event", data: .map([
      "type": .string("tapUp"),
      "spots": .array([.map([
        "bar_index": .int(Int64(nearest.0)),
        "spot_index": .int(Int64(nearest.1)),
      ])]),
    ]))
  }
}
