import RufletEngine
import RufletProtocol
import SwiftUI

struct CandlestickChartControl: View {
  @ObservedObject var control: RufletControl

  private var spots: [CandlestickSpot] { control.children("spots").map(CandlestickSpot.parse) }
  private var points: [ChartPoint] {
    spots.flatMap { [ChartPoint(x: $0.x, y: $0.low), ChartPoint(x: $0.x, y: $0.high)] }
  }

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
            draw(context: &context, layout: layout, domain: domain)
          }
          ChartAxesOverlay(axes: configuration.axes, domain: domain, layout: layout)
        }
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
    let bodyWidth = max(3, layout.plotRect.width / CGFloat(max(1, spots.count)) * 0.55)
    for spot in spots {
      let high = layout.location(ChartPoint(x: spot.x, y: spot.high), domain: domain)
      let low = layout.location(ChartPoint(x: spot.x, y: spot.low), domain: domain)
      let open = layout.location(ChartPoint(x: spot.x, y: spot.open), domain: domain)
      let close = layout.location(ChartPoint(x: spot.x, y: spot.close), domain: domain)
      let color: Color = spot.close >= spot.open ? .green : .red
      var wick = Path()
      wick.move(to: high)
      wick.addLine(to: low)
      context.stroke(wick, with: .color(color), lineWidth: spot.selected ? 3 : 1.5)
      let rect = CGRect(x: open.x - bodyWidth / 2, y: min(open.y, close.y), width: bodyWidth, height: max(1, abs(close.y - open.y)))
      context.fill(Path(rect), with: .color(color))
    }
  }

  private func emitTap(
    at location: CGPoint,
    layout: ChartCartesianLayout,
    domain: ChartDomain
  ) {
    guard control.hasEventHandler("event"), control.boolean("interactive", default: true), !spots.isEmpty else { return }
    let index = spots.indices.min {
      abs(layout.location(ChartPoint(x: spots[$0].x, y: spots[$0].close), domain: domain).x - location.x)
        < abs(layout.location(ChartPoint(x: spots[$1].x, y: spots[$1].close), domain: domain).x - location.x)
    }
    guard let index else { return }
    let spot = spots[index]
    control.triggerEvent("event", data: chartEvent(type: "tapUp", location: location, fields: [
      "spot_index": .int(Int64(index)), "spot_x": .double(spot.x),
      "spot_open": .double(spot.open), "spot_high": .double(spot.high),
      "spot_low": .double(spot.low), "spot_close": .double(spot.close),
    ]))
  }
}
