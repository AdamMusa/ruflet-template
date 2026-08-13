import RufletEngine
import RufletProtocol
import SwiftUI

struct BarChartControl: View {
  @ObservedObject var control: RufletControl

  private var groups: [BarChartGroup] {
    control.children("groups").enumerated().map { BarChartGroup.parse($0.element, paletteIndex: $0.offset) }
  }

  private var points: [ChartPoint] {
    groups.flatMap { group in
      group.rods.flatMap {
        [ChartPoint(x: Double(group.x), y: $0.fromY), ChartPoint(x: Double(group.x), y: $0.toY)]
      }
    }
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
            emitTap(at: value.location, layout: layout)
          })
      }
    }
  }

  private func draw(
    context: inout GraphicsContext,
    layout: ChartCartesianLayout,
    domain: ChartDomain
  ) {
    let rods = groups.flatMap(\.rods)
    let values = rods.flatMap { [$0.fromY, $0.toY] }
    let baseline = control.number("baseline_y") ?? values.min() ?? domain.minY
    let groupWidth = layout.plotRect.width / CGFloat(max(1, groups.count))

    for (groupIndex, group) in groups.enumerated() {
      let totalWidth = group.groupVertically
        ? (group.rods.map(\.width).max() ?? 0)
        : group.rods.reduce(0) { $0 + $1.width }
          + Double(max(0, group.rods.count - 1)) * group.spacing
      var x = layout.plotRect.minX + CGFloat(groupIndex) * groupWidth
        + (groupWidth - CGFloat(totalWidth)) / 2
      for rod in group.rods {
        let from = layout.location(ChartPoint(x: Double(group.x), y: rod.fromY), domain: domain).y
        let to = layout.location(ChartPoint(x: Double(group.x), y: rod.toY), domain: domain).y
        let top = min(from, to)
        let bottom = max(from, to)
        let rect = CGRect(x: x, y: top, width: CGFloat(rod.width), height: max(1, bottom - top))
        let path = Path(roundedRect: rect, cornerRadius: min(rod.borderRadius, rect.width / 2, rect.height / 2))
        let shading = rod.gradient?.shading(
          from: CGPoint(x: rect.midX, y: rect.maxY),
          to: CGPoint(x: rect.midX, y: rect.minY)) ?? .color(rod.color)
        context.fill(path, with: shading)
        for item in rod.stackItems {
          let itemFrom = layout.location(
            ChartPoint(x: Double(group.x), y: item.fromY), domain: domain).y
          let itemTo = layout.location(
            ChartPoint(x: Double(group.x), y: item.toY), domain: domain).y
          let itemRect = CGRect(
            x: rect.minX, y: min(itemFrom, itemTo),
            width: rect.width, height: max(1, abs(itemTo - itemFrom)))
          context.fill(Path(itemRect), with: .color(item.color))
          if let side = item.borderSide, side.width > 0 {
            context.stroke(Path(itemRect), with: .color(side.color), lineWidth: CGFloat(side.width))
          }
        }
        if let side = rod.borderSide, side.width > 0 {
          context.stroke(path, with: .color(side.color), lineWidth: CGFloat(side.width))
        }
        if rod.selected {
          context.stroke(Path(roundedRect: rect.insetBy(dx: -2, dy: -2), cornerRadius: 3), with: .color(.primary), lineWidth: 2)
        }
        if !group.groupVertically { x += CGFloat(rod.width + group.spacing) }
      }
    }

    var baselinePath = Path()
    let baselineY = layout.location(ChartPoint(x: domain.minX, y: baseline), domain: domain).y
    baselinePath.move(to: CGPoint(x: layout.plotRect.minX, y: baselineY))
    baselinePath.addLine(to: CGPoint(x: layout.plotRect.maxX, y: baselineY))
    context.stroke(baselinePath, with: .color(.secondary.opacity(0.35)), lineWidth: 1)
  }

  private func emitTap(at location: CGPoint, layout: ChartCartesianLayout) {
    guard control.hasEventHandler("event"), control.boolean("interactive", default: true), !groups.isEmpty else { return }
    let groupWidth = layout.plotRect.width / CGFloat(groups.count)
    let groupIndex = min(groups.count - 1, max(0, Int((location.x - layout.plotRect.minX) / groupWidth)))
    let rods = groups[groupIndex].rods
    let localX = location.x - layout.plotRect.minX
    let rodIndex = rods.isEmpty ? nil : min(rods.count - 1, max(0, Int(
      localX.truncatingRemainder(dividingBy: groupWidth)
        / max(1, groupWidth / CGFloat(rods.count)))))
    let event = BarChartEventData(eventType: "tapUp", groupIndex: groupIndex, rodIndex: rodIndex)
    control.triggerEvent("event", data: .map(event.value))
  }
}
