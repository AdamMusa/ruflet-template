import RufletEngine
import RufletProtocol
import SwiftUI

struct ScatterChartControl: View {
  @ObservedObject var control: RufletControl

  private var spots: [ScatterChartSpot] {
    control.children("spots").enumerated().map { ScatterChartSpot.parse($0.element, index: $0.offset) }
  }

  private var points: [ChartPoint] { spots.map { ChartPoint(x: $0.x, y: $0.y) } }

  var body: some View {
    ChartFrame(control: control) {
      GeometryReader { proxy in
        let domain = ChartDomain(points: points, control: control)
        let configuration = ChartCartesianConfiguration(control: control)
        let layout = ChartCartesianLayout(size: proxy.size, axes: configuration.axes)
        ZStack {
          Canvas { context, _ in
            drawCartesianDecoration(
              context: &context, layout: layout, domain: domain,
              configuration: configuration)
            for spot in spots {
              let location = layout.location(ChartPoint(x: spot.x, y: spot.y), domain: domain)
              let radius = CGFloat(spot.selected ? spot.radius * 1.5 : spot.radius)
              context.fill(
                Path(ellipseIn: CGRect(x: location.x - radius, y: location.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(spot.color))
              if let label = spot.label { context.draw(Text(label), at: CGPoint(x: location.x, y: location.y - radius - 8)) }
              if spot.selected {
                context.draw(Text("\(chartNumber(spot.x)), \(chartNumber(spot.y))"),
                  at: CGPoint(x: location.x, y: location.y - radius - 10))
              }
            }
          }
          ChartAxesOverlay(
            axes: configuration.axes, domain: domain, layout: layout,
            baselineX: configuration.baselineX, baselineY: configuration.baselineY)
        }
        .rotationEffect(.degrees(Double(
          control.integer("rotation_quarter_turns", default: 0) ?? 0) * 90))
        .animation(
          chartAnimation(control.dynamicValue("animation")),
          value: control.revision)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onEnded { value in
          emitTap(at: value.location, layout: layout, domain: domain)
        })
        .simultaneousGesture(
          LongPressGesture(minimumDuration: chartLongPressDuration(
            control.dynamicValue("long_press_duration")))
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onEnded { value in
              guard case .second(true, let drag?) = value else { return }
              emitTap(
                at: drag.location, layout: layout, domain: domain,
                type: "longPressEnd")
            })
      }
    }
  }

  private func emitTap(
    at location: CGPoint,
    layout: ChartCartesianLayout,
    domain: ChartDomain,
    type: String = "tapUp"
  ) {
    guard control.hasEventHandler("event"), control.boolean("interactive", default: true),
      !control.disabled else { return }
    let index = spots.indices.min { lhs, rhs in
      let a = layout.location(points[lhs], domain: domain)
      let b = layout.location(points[rhs], domain: domain)
      return hypot(a.x - location.x, a.y - location.y) < hypot(b.x - location.x, b.y - location.y)
    }
    control.triggerEvent("event", data: .map([
      "type": .string(type),
      "spot_index": index.map { .int(Int64($0)) } ?? .null,
    ]))
  }
}
