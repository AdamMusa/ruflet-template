import RufletEngine
import RufletProtocol
import SwiftUI

struct BarChartControl: View {
  @ObservedObject var control: RufletControl

  private var groups: [BarChartGroup] {
    control.children("groups").enumerated().map { BarChartGroup.parse($0.element, paletteIndex: $0.offset) }
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
    let rods = groups.flatMap(\.rods)
    let values = rods.flatMap { [$0.fromY, $0.toY] }
    let minY = control.number("min_y") ?? values.min() ?? 0
    var maxY = control.number("max_y") ?? values.max() ?? 1
    if minY == maxY { maxY = minY + 1 }
    let baseline = control.number("baseline_y") ?? minY
    let usableWidth = max(1, size.width - 24)
    let groupWidth = usableWidth / CGFloat(max(1, groups.count))
    let usableHeight = max(1, size.height - 24)
    func y(_ value: Double) -> CGFloat {
      size.height - 12 - CGFloat((value - minY) / (maxY - minY)) * usableHeight
    }

    for (groupIndex, group) in groups.enumerated() {
      let totalWidth = group.rods.reduce(0) { $0 + $1.width }
        + Double(max(0, group.rods.count - 1)) * group.spacing
      var x = 12 + CGFloat(groupIndex) * groupWidth + (groupWidth - CGFloat(totalWidth)) / 2
      for rod in group.rods {
        let top = min(y(rod.fromY), y(rod.toY))
        let bottom = max(y(rod.fromY), y(rod.toY))
        let rect = CGRect(x: x, y: top, width: CGFloat(rod.width), height: max(1, bottom - top))
        context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(rod.color))
        if rod.selected {
          context.stroke(Path(roundedRect: rect.insetBy(dx: -2, dy: -2), cornerRadius: 3), with: .color(.primary), lineWidth: 2)
        }
        x += CGFloat(rod.width + group.spacing)
      }
    }

    var baselinePath = Path()
    baselinePath.move(to: CGPoint(x: 8, y: y(baseline)))
    baselinePath.addLine(to: CGPoint(x: size.width - 8, y: y(baseline)))
    context.stroke(baselinePath, with: .color(.secondary.opacity(0.35)), lineWidth: 1)
  }

  private func emitTap(at location: CGPoint, size: CGSize) {
    guard control.hasEventHandler("event"), control.boolean("interactive", default: true), !groups.isEmpty else { return }
    let groupWidth = max(1, size.width - 24) / CGFloat(groups.count)
    let groupIndex = min(groups.count - 1, max(0, Int((location.x - 12) / groupWidth)))
    let rods = groups[groupIndex].rods
    let rodIndex = rods.isEmpty ? nil : min(rods.count - 1, max(0, Int((location.x.truncatingRemainder(dividingBy: groupWidth)) / max(1, groupWidth / CGFloat(rods.count)))))
    let event = BarChartEventData(eventType: "tapUp", groupIndex: groupIndex, rodIndex: rodIndex)
    control.triggerEvent("event", data: .map(event.value))
  }
}
