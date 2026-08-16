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
          ChartAxesOverlay(
            axes: configuration.axes, domain: domain, layout: layout,
            baselineX: configuration.baselineX, baselineY: configuration.baselineY,
            horizontalPositions: barAxisPositions(in: layout.plotRect))
        }
          .animation(
            chartAnimation(control.dynamicValue("animation")),
            value: control.revision)
          .contentShape(Rectangle())
          .chartTapGesture { location in
            emitTap(at: location, layout: layout, domain: domain)
          }
      }
    }
  }

  private func draw(
    context: inout GraphicsContext,
    layout: ChartCartesianLayout,
    domain: ChartDomain
  ) {
    let groupCenters = barGroupCenters(in: layout.plotRect)

    for (groupIndex, group) in groups.enumerated() {
      let totalWidth = group.groupVertically
        ? (group.rods.map(\.width).max() ?? 0)
        : group.rods.reduce(0) { $0 + $1.width }
          + Double(max(0, group.rods.count - 1)) * group.spacing
      var x = groupCenters[groupIndex] - CGFloat(totalWidth) / 2
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

  }

  private func barGroupCenters(in rect: CGRect) -> [CGFloat] {
    chartBarGroupCenters(
      in: rect,
      widths: groups.map(groupWidth),
      alignment: control.string("group_alignment"),
      spacing: CGFloat(control.number("spacing", default: 16) ?? 16))
  }

  private func barAxisPositions(in rect: CGRect) -> [Double: CGFloat] {
    zip(groups, barGroupCenters(in: rect)).reduce(into: [:]) { result, item in
      result[Double(item.0.x)] = item.1
    }
  }

  private func groupWidth(_ group: BarChartGroup) -> CGFloat {
    CGFloat(group.groupVertically
      ? (group.rods.map(\.width).max() ?? 0)
      : group.rods.reduce(0) { $0 + $1.width }
        + Double(max(0, group.rods.count - 1)) * group.spacing)
  }

  private func emitTap(
    at location: CGPoint,
    layout: ChartCartesianLayout,
    domain: ChartDomain
  ) {
    guard control.hasEventHandler("event"), control.boolean("interactive", default: true),
      !control.disabled, !groups.isEmpty else { return }
    let centers = barGroupCenters(in: layout.plotRect)
    guard let groupIndex = centers.indices.min(by: {
      abs(centers[$0] - location.x) < abs(centers[$1] - location.x)
    }) else { return }
    let group = groups[groupIndex]
    var cursor = centers[groupIndex] - groupWidth(group) / 2
    let rodRects = group.rods.map { rod -> CGRect in
      let centerX = group.groupVertically ? centers[groupIndex] : cursor + CGFloat(rod.width) / 2
      if !group.groupVertically { cursor += CGFloat(rod.width + group.spacing) }
      let from = layout.location(ChartPoint(x: Double(group.x), y: rod.fromY), domain: domain).y
      let to = layout.location(ChartPoint(x: Double(group.x), y: rod.toY), domain: domain).y
      return CGRect(
        x: centerX - CGFloat(rod.width) / 2,
        y: min(from, to),
        width: CGFloat(rod.width),
        height: max(1, abs(to - from)))
    }
    let rodIndex = rodRects.indices.min(by: {
      distance(from: location, to: rodRects[$0]) < distance(from: location, to: rodRects[$1])
    })
    let stackItemIndex = rodIndex.flatMap { rodIndex in
      group.rods[rodIndex].stackItems.indices.first { itemIndex in
        let item = group.rods[rodIndex].stackItems[itemIndex]
        let from = layout.location(ChartPoint(x: Double(group.x), y: item.fromY), domain: domain).y
        let to = layout.location(ChartPoint(x: Double(group.x), y: item.toY), domain: domain).y
        return location.y >= min(from, to) && location.y <= max(from, to)
      }
    }
    let event = BarChartEventData(
      eventType: "tapUp", groupIndex: groupIndex,
      rodIndex: rodIndex, stackItemIndex: stackItemIndex)
    control.triggerEvent("event", data: .map(event.value))
  }

  private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
    hypot(
      max(rect.minX - point.x, 0, point.x - rect.maxX),
      max(rect.minY - point.y, 0, point.y - rect.maxY))
  }
}
