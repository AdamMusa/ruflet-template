import RufletEngine
import RufletProtocol
import SwiftUI

struct RadarChartControl: View {
  @ObservedObject var control: RufletControl

  private var dataSets: [RadarDataSet] {
    control.children("data_sets").enumerated().map { RadarDataSet.parse($0.element, index: $0.offset) }
  }

  var body: some View {
    ChartFrame(control: control) {
      GeometryReader { proxy in
        Canvas { context, size in draw(context: &context, size: size) }
          .contentShape(Rectangle())
          .gesture(DragGesture(minimumDistance: 0).onEnded { value in emitTap(at: value.location, size: proxy.size) })
      }
    }
  }

  private func draw(context: inout GraphicsContext, size: CGSize) {
    let count = dataSets.map(\.entries.count).max() ?? 0
    guard count >= 3 else { return }
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let radius = min(size.width, size.height) / 2 - 20
    let maximum = max(1, dataSets.flatMap(\.entries).max() ?? 1)
    let tickCount = max(1, control.integer("tick_count", default: 1) ?? 1)
    for tick in 1 ... tickCount {
      let tickRadius = radius * CGFloat(tick) / CGFloat(tickCount)
      var grid = Path()
      for index in 0 ..< count {
        let point = vertex(index: index, count: count, radius: tickRadius, center: center)
        index == 0 ? grid.move(to: point) : grid.addLine(to: point)
      }
      grid.closeSubpath()
      context.stroke(grid, with: .color(.secondary.opacity(0.35)), lineWidth: 1)
    }
    for dataSet in dataSets {
      var path = Path()
      for index in 0 ..< count {
        let value = index < dataSet.entries.count ? dataSet.entries[index] : 0
        let point = vertex(index: index, count: count, radius: radius * CGFloat(value / maximum), center: center)
        index == 0 ? path.move(to: point) : path.addLine(to: point)
      }
      path.closeSubpath()
      context.fill(path, with: .color(dataSet.fillColor))
      context.stroke(path, with: .color(dataSet.borderColor), lineWidth: CGFloat(dataSet.borderWidth))
    }
  }

  private func emitTap(at location: CGPoint, size: CGSize) {
    guard control.boolean("interactive", default: true), control.hasEventHandler("event") else { return }
    let count = dataSets.map(\.entries.count).max() ?? 0
    guard count > 0 else { return }
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    var angle = atan2(location.y - center.y, location.x - center.x) + .pi / 2
    if angle < 0 { angle += 2 * .pi }
    let entryIndex = min(count - 1, Int((angle / (2 * .pi) * CGFloat(count)).rounded()) % count)
    let setIndex = dataSets.indices.min { lhs, rhs in
      let left = entryIndex < dataSets[lhs].entries.count ? dataSets[lhs].entries[entryIndex] : 0
      let right = entryIndex < dataSets[rhs].entries.count ? dataSets[rhs].entries[entryIndex] : 0
      return left < right
    }
    let value = setIndex.flatMap { entryIndex < dataSets[$0].entries.count ? dataSets[$0].entries[entryIndex] : nil }
    control.triggerEvent("event", data: .map([
      "type": .string("tapUp"),
      "data_set_index": setIndex.map { .int(Int64($0)) } ?? .null,
      "entry_index": .int(Int64(entryIndex)),
      "entry_value": value.map(RufletValue.double) ?? .null,
    ]))
  }

  private func vertex(index: Int, count: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
    let angle = CGFloat(index) / CGFloat(count) * 2 * .pi - .pi / 2
    return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
  }
}
