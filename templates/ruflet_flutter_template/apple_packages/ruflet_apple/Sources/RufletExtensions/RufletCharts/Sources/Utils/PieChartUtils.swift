import RufletEngine
import SwiftUI

struct PieChartSection: Identifiable {
  let id: Int
  let value: Double
  let color: Color
  let radius: CGFloat
  let title: String?
  let titleStyle: RufletTextStyle?
  let titlePosition: Double
  let badge: RufletControl?
  let badgePosition: Double

  @MainActor static func parse(_ control: RufletControl, index: Int) -> Self {
    control.notifyParent = true
    let badge = control.child("badge_widget", visibleOnly: false)
    badge?.notifyParent = true
    return Self(
      id: control.id,
      value: max(0, control.number("value", default: 10) ?? 10),
      color: control.chartColor("color", default: .cyan),
      radius: CGFloat(max(0, control.number("radius", default: 40) ?? 40)),
      title: control.string("title"),
      titleStyle: parseTextStyle(control.value("title_style")),
      titlePosition: control.number("title_position", default: 0.5) ?? 0.5,
      badge: badge,
      badgePosition: control.number("badge_position_percentage_offset", default: 0.5) ?? 0.5)
  }
}

/// Geometry shared by drawing, overlays, and hit testing. Flet's pinned
/// `fl_chart` source interprets `sections_space` as pixels, section radius as
/// radial thickness, and a nil center radius as an automatically fitted hole.
struct PieChartLayout {
  struct Slice {
    let index: Int
    let start: Double
    let end: Double
    let middle: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    var sweep: Double { end - start }
  }

  let center: CGPoint
  let centerRadius: CGFloat
  let slices: [Slice]

  init(
    size: CGSize,
    sections: [PieChartSection],
    requestedCenterRadius: Double?,
    sectionsSpace: Double,
    startDegreeOffset: Double
  ) {
    center = CGPoint(x: size.width / 2, y: size.height / 2)
    let shortestSide = max(0, min(size.width, size.height))
    let resolvedCenterRadius: CGFloat
    if let requestedCenterRadius {
      resolvedCenterRadius = min(CGFloat(max(0, requestedCenterRadius)), shortestSide / 2)
    } else {
      let maximumSectionRadius = sections.map(\.radius).max() ?? 0
      resolvedCenterRadius = max(0, (shortestSide - maximumSectionRadius * 2) / 2)
    }
    centerRadius = resolvedCenterRadius

    let total = sections.reduce(0) { $0 + $1.value }
    guard total > 0 else {
      slices = []
      return
    }

    var angle = startDegreeOffset * .pi / 180
    slices = sections.enumerated().compactMap { index, section in
      guard section.value > 0 else { return nil }
      let rawSweep = section.value / total * 2 * .pi
      let middle = angle + rawSweep / 2
      let outerRadius = min(resolvedCenterRadius + section.radius, shortestSide / 2)
      let middleRadius = max((resolvedCenterRadius + outerRadius) / 2, 1)
      // A single full-circle section is the special case used by fl_chart:
      // no separator is cut from it. Otherwise convert the requested pixel
      // gap to the corresponding angular opening at the section midpoint.
      let gap = rawSweep >= 2 * .pi - 0.000_001
        ? 0
        : min(max(0, sectionsSpace) / Double(middleRadius), rawSweep)
      let slice = Slice(
        index: index,
        start: angle + gap / 2,
        end: angle + rawSweep - gap / 2,
        middle: middle,
        innerRadius: resolvedCenterRadius,
        outerRadius: outerRadius)
      angle += rawSweep
      return slice
    }
  }

  func point(in slice: Slice, percentage: Double) -> CGPoint {
    let clamped = min(max(percentage, 0), 1)
    let radius = slice.innerRadius + (slice.outerRadius - slice.innerRadius) * CGFloat(clamped)
    return CGPoint(
      x: center.x + cos(slice.middle) * radius,
      y: center.y + sin(slice.middle) * radius)
  }

  func sectionIndex(at point: CGPoint) -> Int? {
    let dx = point.x - center.x
    let dy = point.y - center.y
    let radius = hypot(dx, dy)
    var angle = atan2(dy, dx)
    if angle < 0 { angle += 2 * .pi }

    return slices.first { slice in
      guard radius >= slice.innerRadius, radius <= slice.outerRadius else { return false }
      let start = normalized(slice.start)
      let end = normalized(slice.end)
      if slice.sweep >= 2 * .pi - 0.000_001 { return true }
      return start <= end ? (angle >= start && angle <= end) : (angle >= start || angle <= end)
    }?.index
  }

  private func normalized(_ angle: Double) -> Double {
    let result = angle.truncatingRemainder(dividingBy: 2 * .pi)
    return result >= 0 ? result : result + 2 * .pi
  }
}

struct PieChartEventData: Equatable {
  let eventType: String
  let sectionIndex: Int?
}
