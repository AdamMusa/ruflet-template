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
        Canvas { context, size in
          let domain = ChartDomain(points: points, control: control)
          for spot in spots {
            let location = domain.location(ChartPoint(x: spot.x, y: spot.y), in: size)
            let radius = CGFloat(spot.selected ? spot.radius * 1.5 : spot.radius)
            context.fill(
              Path(ellipseIn: CGRect(x: location.x - radius, y: location.y - radius, width: radius * 2, height: radius * 2)),
              with: .color(spot.color))
            if let label = spot.label { context.draw(Text(label), at: CGPoint(x: location.x, y: location.y - radius - 8)) }
          }
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onEnded { value in emitTap(at: value.location, size: proxy.size) })
      }
    }
  }

  private func emitTap(at location: CGPoint, size: CGSize) {
    guard control.hasEventHandler("event"), control.boolean("interactive", default: true) else { return }
    let domain = ChartDomain(points: points, control: control)
    let index = spots.indices.min { lhs, rhs in
      let a = domain.location(points[lhs], in: size)
      let b = domain.location(points[rhs], in: size)
      return hypot(a.x - location.x, a.y - location.y) < hypot(b.x - location.x, b.y - location.y)
    }
    control.triggerEvent("event", data: .map([
      "type": .string("tapUp"),
      "spot_index": index.map { .int(Int64($0)) } ?? .null,
    ]))
  }
}
