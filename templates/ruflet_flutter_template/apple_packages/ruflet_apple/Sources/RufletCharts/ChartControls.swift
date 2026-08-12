import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

/// Renderer-wide chart semantics copied from the pinned Flet chart controls.
/// Keeping these decisions outside individual chart painters prevents a bar,
/// pie, or radar chart from quietly inventing a different default.
public struct ChartControlSemantics {
  static let unboundedHeight: CGFloat = 300
  static let defaultAnimationDuration: Double = 0.15

  static func animationDuration(for node: ControlNode) -> Double {
    guard let value = node.props["animation"] else { return defaultAnimationDuration }
    return ControlProps.animationDurationSeconds(value) ?? defaultAnimationDuration
  }

  static func animationCurve(for node: ControlNode) -> String {
    node.props["animation"]?["curve"]?.stringValue ?? "linear"
  }

  static func animation(for node: ControlNode) -> Animation {
    ControlProps.animation(node.props["animation"])
      ?? .linear(duration: defaultAnimationDuration)
  }

  /// Flet's `SideTitles` defaults. These are source defaults rather than
  /// renderer styling: an absent axis hides everything, while a supplied axis
  /// reserves 22 points for labels and 16 for its optional title.
  static func axisDefaults(_ node: ControlNode?) -> (showLabels: Bool, titleSize: CGFloat,
                                                      labelSize: CGFloat,
                                                      showMin: Bool, showMax: Bool) {
    guard let node else { return (false, 16, 22, true, true) }
    return (
      node.bool("show_labels") ?? true,
      CGFloat(node.double("title_size") ?? 16),
      CGFloat(node.double("label_size") ?? 22),
      node.bool("show_min") ?? true,
      node.bool("show_max") ?? true)
  }

  static func axisReservedExtent(_ node: ControlNode?, hasTitle: Bool) -> CGFloat {
    guard let node else { return 0 }
    let defaults = axisDefaults(node)
    return (defaults.showLabels ? defaults.labelSize : 0)
      + (hasTitle ? defaults.titleSize : 0)
  }

  /// `title_size` and `label_size` are fl_chart reserved-layout extents, not
  /// typography. The text keeps the style of the nested Flet Text control.
  static func contentFontSize(
    _ id: Int, node: (Int) -> ControlNode?, depth: Int = 0
  ) -> CGFloat {
    guard depth < 6, let current = node(id) else { return 14 }
    if current.type == "Text" {
      return CGFloat(current.map("style")?["size"]?.doubleValue
        ?? current.double("size") ?? 14)
    }
    let children = current.controlIDs(forKey: "content") + current.childIDs
    for child in children {
      if node(child) != nil { return contentFontSize(child, node: node, depth: depth + 1) }
    }
    return 14
  }

  static func tooltipDefaults(_ map: [String: RufletValue]?) ->
    (margin: CGFloat, maxWidth: CGFloat, rotation: Double,
     horizontalOffset: CGFloat, fitHorizontal: Bool, fitVertical: Bool) {
    (
      CGFloat(map?["margin"]?.doubleValue ?? 16),
      CGFloat(map?["max_width"]?.doubleValue ?? 120),
      map?["rotation"]?.doubleValue ?? 0,
      CGFloat(map?["horizontal_offset"]?.doubleValue ?? 0),
      map?["fit_inside_horizontally"]?.boolValue ?? false,
      map?["fit_inside_vertically"]?.boolValue ?? false)
  }

  static func tooltipBackgroundName(for chartType: String, explicit: String?) -> String {
    if let explicit { return explicit }
    // `parseCandlestickTouchTooltipData()` uses Color(0xFFFFECEF), while the
    // other fl_chart families retain their own neutral tooltip surface.
    return chartType == "CandlestickChart" ? "#FFFFECEF" : "secondary"
  }

  static func rotationDegrees(for node: ControlNode) -> Double {
    Double((node.int("rotation_quarter_turns") ?? 0) % 4) * 90
  }

  static func shouldEmitEvent(for node: ControlNode) -> Bool {
    guard node.bool("on_event") == true else { return false }
    return interactionEnabled(for: node)
  }

  static func interactionEnabled(for node: ControlNode) -> Bool {
    guard node.bool("disabled") != true else { return false }
    // PieTouchData is always enabled in Flet. Every other family honours its
    // `interactive` property, whose generated default is true.
    return node.type == "PieChart" || (node.bool("interactive") ?? true)
  }

  static func borderSide(
    _ map: [String: RufletValue]?, defaultColor: Color, defaultWidth: CGFloat
  ) -> (color: Color, width: CGFloat) {
    (
      MaterialPalette.color(map?["color"]?.stringValue, default: defaultColor),
      CGFloat(map?["width"]?.doubleValue ?? Double(defaultWidth)))
  }

  static func radarPolygon(
    center: CGPoint, radius: CGFloat, sides: Int, circular: Bool
  ) -> Path {
    guard sides >= 3 else { return Path() }
    if circular {
      return Path(ellipseIn: CGRect(
        x: center.x - radius, y: center.y - radius,
        width: radius * 2, height: radius * 2))
    }
    var path = Path()
    for side in 0..<sides {
      let angle = Double(side) / Double(sides) * 2 * .pi - .pi / 2
      let point = CGPoint(
        x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
      side == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
  }

  static func groupCenters(count: Int, in range: ClosedRange<CGFloat>, alignment: String?) -> [CGFloat] {
    guard count > 0 else { return [] }
    let width = range.upperBound - range.lowerBound
    let key = alignment?.lowercased() ?? "space_evenly"
    if count == 1 {
      switch key {
      case "start": return [range.lowerBound]
      case "end": return [range.upperBound]
      default: return [range.lowerBound + width / 2]
      }
    }
    switch key {
    case "start": return (0..<count).map { range.lowerBound + CGFloat($0) * width / CGFloat(count) }
    case "end": return (0..<count).map { range.lowerBound + CGFloat($0 + 1) * width / CGFloat(count) }
    case "center":
      let step = width / CGFloat(count + 1)
      return (0..<count).map { range.lowerBound + width / 2 + (CGFloat($0) - CGFloat(count - 1) / 2) * step }
    case "space_between":
      return (0..<count).map { range.lowerBound + CGFloat($0) * width / CGFloat(count - 1) }
    case "space_around":
      return (0..<count).map { range.lowerBound + (CGFloat($0) + 0.5) * width / CGFloat(count) }
    default: // spaceEvenly is fl_chart's effective default.
      return (0..<count).map { range.lowerBound + CGFloat($0 + 1) * width / CGFloat(count + 1) }
    }
  }

  static func nearestIndex(to target: Double, values: [Double]) -> Int? {
    values.enumerated().min { lhs, rhs in
      abs(lhs.element - target) < abs(rhs.element - target)
    }?.offset
  }

  /// Projects an explicit `ChartAxisLabel.value` into the chart's real data
  /// domain. The old Apple painter silently used 0...1 for every axis, which
  /// sent labels such as BarChart's x=2/x=3 far outside the Canvas.
  static func axisFraction(value: Double, minimum: Double, maximum: Double) -> CGFloat? {
    guard maximum > minimum, value >= minimum, value <= maximum else { return nil }
    return CGFloat((value - minimum) / (maximum - minimum))
  }
}

/// Exact wire maps and repeat filtering used by the pinned `flet_charts`
/// adapters. Five chart families retain the previous Equatable event and do
/// not send it twice. Scatter deliberately forwards every callback.
struct ChartEventSemantics {
  static func bar(
    type: String, groupIndex: Int?, rodIndex: Int?, stackItemIndex: Int?
  ) -> RufletValue {
    .map([
      "type": .string(type),
      "group_index": integer(groupIndex),
      "rod_index": integer(rodIndex),
      "stack_item_index": integer(stackItemIndex),
    ])
  }

  static func line(type: String, spots: [(barIndex: Int, spotIndex: Int)]) -> RufletValue {
    .map([
      "type": .string(type),
      "spots": .array(spots.map { spot in
        .map([
          "bar_index": .int(Int64(spot.barIndex)),
          "spot_index": .int(Int64(spot.spotIndex)),
        ])
      }),
    ])
  }

  static func pie(
    type: String, sectionIndex: Int?, localX: Double?, localY: Double?
  ) -> RufletValue {
    .map([
      "type": .string(type),
      "section_index": integer(sectionIndex),
      "local_x": localX.map(RufletValue.double) ?? .null,
      "local_y": localY.map(RufletValue.double) ?? .null,
    ])
  }

  static func spot(type: String, spotIndex: Int?) -> RufletValue {
    .map([
      "type": .string(type),
      "spot_index": integer(spotIndex),
    ])
  }

  static func radar(
    type: String, dataSetIndex: Int?, entryIndex: Int?, entryValue: Double?
  ) -> RufletValue {
    .map([
      "type": .string(type),
      "data_set_index": integer(dataSetIndex),
      "entry_index": integer(entryIndex),
      "entry_value": entryValue.map(RufletValue.double) ?? .null,
    ])
  }

  /// Pie's Dart Equatable intentionally excludes the local pointer position.
  /// Consequently moving within one section is still a duplicate when the
  /// event type has not changed. The other retained events compare every wire
  /// field; ScatterChart has no retained `_eventData` at all.
  static func shouldForward(
    _ event: RufletValue, after previous: RufletValue?, chartType: String
  ) -> Bool {
    guard chartType != "ScatterChart", let previous else { return true }
    if chartType == "PieChart" {
      return event["type"] != previous["type"]
        || event["section_index"] != previous["section_index"]
    }
    return event != previous
  }

  private static func integer(_ value: Int?) -> RufletValue {
    value.map { .int(Int64($0)) } ?? .null
  }
}

struct ChartInteractionSemantics {
  static let panThreshold: CGFloat = 10
  static let defaultLongPressDuration = 0.5

  static func dragChanged(first: Bool, crossedPanThreshold: Bool, panning: Bool) -> [String] {
    if first { return ["tapDown"] }
    if crossedPanThreshold, !panning { return ["tapCancel", "panDown", "panStart"] }
    return panning ? ["panUpdate"] : []
  }

  static func dragEnded(panning: Bool, longPressing: Bool) -> [String] {
    if longPressing { return ["longPressEnd"] }
    return [panning ? "panEnd" : "tapUp"]
  }

  static func longPressStarted() -> [String] {
    ["tapCancel", "longPressStart"]
  }

  static func longPressDuration(for node: ControlNode) -> Double {
    guard let value = node.props["long_press_duration"] else {
      return defaultLongPressDuration
    }
    switch value {
    case .int(let milliseconds): return max(Double(milliseconds), 0) / 1_000
    case .double(let milliseconds): return max(milliseconds, 0) / 1_000
    case .extended(type: 3, let microseconds):
      return max(Double(Int64(microseconds) ?? 0), 0) / 1_000_000
    case .map(let components):
      func integer(_ key: String) -> Int64 {
        switch components[key] {
        case .int(let component): return component
        case .string(let component), .extended(_, let component):
          return Int64(component) ?? 0
        default: return 0
        }
      }
      let microseconds = integer("microseconds")
        + 1_000 * integer("milliseconds")
        + 1_000_000 * integer("seconds")
        + 60_000_000 * integer("minutes")
        + 3_600_000_000 * integer("hours")
        + 86_400_000_000 * integer("days")
      return max(Double(microseconds), 0) / 1_000_000
    default: return defaultLongPressDuration
    }
  }

  static func handlesBuiltInTooltips(for node: ControlNode) -> Bool {
    switch node.type {
    case "ScatterChart", "CandlestickChart":
      return node.bool("show_tooltips_for_selected_spots_only") != true
    default:
      return true
    }
  }

  static func showsSelectedTooltip(
    chartType: String, interactive: Bool, selected: Bool,
    showTooltip: Bool, hasTooltip: Bool
  ) -> Bool {
    guard selected, showTooltip, hasTooltip else { return false }
    switch chartType {
    case "BarChart", "LineChart": return !interactive
    case "ScatterChart", "CandlestickChart": return true
    default: return false
    }
  }
}

/// The chart family, drawn from the same control trees Flet's chart widgets take.
///
/// The chart controls do not share a wire shape: lines contain data series,
/// bars contain groups and rods, scatter charts contain spots, and pies contain
/// sections. Keep that distinction here so valid Flet data never disappears
/// merely because another chart family happens to call its children "points".
public struct ChartControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var chartSize: CGSize = .zero
  @State private var interactionLocation: CGPoint?
  @State private var previousEvent: RufletValue?
  @State private var gestureOrigin: CGPoint?
  @State private var isPanning = false
  @State private var isLongPressing = false

  public init(node: ControlNode) {
    self.node = node
  }

  public var body: some View {
    Canvas { context, size in
      let plot = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)
      if let background = node.string("bgcolor") {
        context.fill(
          Path(CGRect(origin: .zero, size: size)),
          with: .color(MaterialPalette.color(background, default: .clear)))
      }
      switch node.type {
      case "PieChart":
        drawPie(in: &context, plot: plot)
      case "RadarChart":
        drawRadar(in: &context, plot: plot)
      case "CandlestickChart":
        drawCandlesticks(in: &context, plot: plot)
      case "BarChart":
        drawBars(in: &context, plot: plot)
      case "ScatterChart":
        drawScatter(in: &context, plot: plot)
      default:
        drawLines(in: &context, plot: plot)
      }
      for tooltip in selectedTooltips(in: plot) {
        drawTooltip(
          in: &context, label: tooltip.label, at: tooltip.location,
          bounds: CGRect(origin: .zero, size: size))
      }
      if let interactionLocation,
        ChartInteractionSemantics.handlesBuiltInTooltips(for: node)
      {
        drawTooltip(in: &context, at: interactionLocation, bounds: CGRect(origin: .zero, size: size))
      }
    }
    // Flet caps only an *unbounded* chart at 300. An unconditional max-height
    // changes explicitly-sized charts, so advertise 300 as the intrinsic
    // ideal while still accepting the bounds supplied by the DSL.
    .frame(minHeight: 0, idealHeight: ChartControlSemantics.unboundedHeight)
    .rotationEffect(.degrees(ChartControlSemantics.rotationDegrees(for: node)))
    .animation(ChartControlSemantics.animation(for: node), value: store.revision)
    .background {
      GeometryReader { geometry in
        Color.clear
          .onAppear { chartSize = geometry.size }
          .onChange(of: geometry.size) { chartSize = $0 }
      }
    }
    .gesture(chartDragGesture)
    .simultaneousGesture(chartLongPressGesture)
    .onHover { inside in
      let location = interactionLocation
        ?? CGPoint(x: chartSize.width / 2, y: chartSize.height / 2)
      emitChartEvent(inside ? "pointerEnter" : "pointerExit", at: location)
    }
  }

  private var chartDragGesture: some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { event in
        guard ChartControlSemantics.interactionEnabled(for: node) else { return }
        interactionLocation = event.location
        let first = gestureOrigin == nil
        if first { gestureOrigin = event.startLocation }
        let origin = gestureOrigin ?? event.startLocation
        let distance = hypot(event.location.x - origin.x, event.location.y - origin.y)
        let crossed = distance >= ChartInteractionSemantics.panThreshold
        let eventTypes = isLongPressing ? ["longPressMoveUpdate"]
          : ChartInteractionSemantics.dragChanged(
            first: first, crossedPanThreshold: crossed, panning: isPanning)
        for eventType in eventTypes { emitChartEvent(eventType, at: event.location) }
        if crossed, !isLongPressing { isPanning = true }
      }
      .onEnded { event in
        guard ChartControlSemantics.interactionEnabled(for: node) else { return }
        interactionLocation = event.location
        for eventType in ChartInteractionSemantics.dragEnded(
          panning: isPanning, longPressing: isLongPressing
        ) {
          emitChartEvent(eventType, at: event.location)
        }
        gestureOrigin = nil
        isPanning = false
        isLongPressing = false
      }
  }

  private var chartLongPressGesture: some Gesture {
    LongPressGesture(minimumDuration: ChartInteractionSemantics.longPressDuration(for: node))
      .onEnded { recognized in
        guard recognized, ChartControlSemantics.interactionEnabled(for: node) else { return }
        isLongPressing = true
        isPanning = false
        let location = interactionLocation
          ?? CGPoint(x: chartSize.width / 2, y: chartSize.height / 2)
        for eventType in ChartInteractionSemantics.longPressStarted() {
          emitChartEvent(eventType, at: location)
        }
      }
  }

  private func emitChartEvent(_ type: String, at location: CGPoint) {
    guard ChartControlSemantics.shouldEmitEvent(for: node) else { return }
    let payload = chartEvent(at: location, type: type)
    guard ChartEventSemantics.shouldForward(
      payload, after: previousEvent, chartType: node.type
    ) else { return }
    previousEvent = payload
    events.fire(node, "event", data: payload)
  }

  private func drawTooltip(in context: inout GraphicsContext, at location: CGPoint, bounds: CGRect) {
    let event = chartEvent(at: location)
    let label: String
    switch node.type {
    case "BarChart":
      let group = event["group_index"]?.intValue
      let rod = event["rod_index"]?.intValue
      label = group.map { "\($0):\(rod ?? 0)" } ?? ""
    case "PieChart":
      label = event["section_index"]?.intValue.map(String.init) ?? ""
    case "RadarChart":
      label = event["entry_value"]?.doubleValue.map { String(format: "%.2f", $0) } ?? ""
    default:
      label = event["spot_index"]?.intValue.map(String.init) ?? ""
    }
    drawTooltip(in: &context, label: label, at: location, bounds: bounds)
  }

  private func drawTooltip(
    in context: inout GraphicsContext, label: String, at location: CGPoint, bounds: CGRect
  ) {
    guard !label.isEmpty else { return }
    let defaults = ChartControlSemantics.tooltipDefaults(node.map("tooltip"))
    let padding: CGFloat = 8
    let width = min(defaults.maxWidth, max(CGFloat(label.count) * 8 + padding * 2, 36))
    let height: CGFloat = 28
    var origin = CGPoint(
      x: location.x - width / 2 + defaults.horizontalOffset,
      y: location.y - height - defaults.margin)
    if defaults.fitHorizontal {
      origin.x = min(max(origin.x, bounds.minX), bounds.maxX - width)
    }
    if defaults.fitVertical {
      origin.y = min(max(origin.y, bounds.minY), bounds.maxY - height)
    }
    let rect = CGRect(origin: origin, size: CGSize(width: width, height: height))
    var tooltip = context
    tooltip.translateBy(x: rect.midX, y: rect.midY)
    tooltip.rotate(by: .degrees(defaults.rotation))
    tooltip.translateBy(x: -rect.midX, y: -rect.midY)
    tooltip.fill(
      Path(roundedRect: rect, cornerRadius: 4),
      with: .color(MaterialPalette.color(
        ChartControlSemantics.tooltipBackgroundName(
          for: node.type, explicit: node.map("tooltip")?["bgcolor"]?.stringValue),
        default: .secondary)))
    let textColor: Color = node.type == "CandlestickChart" ? .primary : .white
    tooltip.draw(
      Text(label).font(.caption).foregroundColor(textColor),
      at: CGPoint(x: rect.midX, y: rect.midY))
  }

  private struct SelectedTooltip {
    let location: CGPoint
    let label: String
  }

  private func selectedTooltips(in plot: CGRect) -> [SelectedTooltip] {
    let interactive = node.bool("interactive") ?? true
    switch node.type {
    case "BarChart": return selectedBarTooltips(in: plot, interactive: interactive)
    case "LineChart": return selectedLineTooltips(in: plot, interactive: interactive)
    case "ScatterChart": return selectedScatterTooltips(in: plot, interactive: interactive)
    case "CandlestickChart": return selectedCandlestickTooltips(in: plot, interactive: interactive)
    default: return []
    }
  }

  private func selectedLineTooltips(
    in plot: CGRect, interactive: Bool
  ) -> [SelectedTooltip] {
    let chart = chartPlotRect(in: plot)
    let series = lineSeries
    let xs = series.flatMap { $0.points.map(\.x) }
    let ys = series.flatMap { $0.points.map(\.y) }
    guard let dataMinX = xs.min(), let dataMaxX = xs.max(),
      let dataMinY = ys.min(), let dataMaxY = ys.max()
    else { return [] }
    let minX = node.double("min_x") ?? dataMinX
    let maxX = node.double("max_x") ?? dataMaxX
    let minY = node.double("min_y") ?? dataMinY
    let maxY = node.double("max_y") ?? dataMaxY
    let spanX = max(maxX - minX, .ulpOfOne)
    let spanY = max(maxY - minY, .ulpOfOne)
    return series.flatMap { entry in
      entry.points.compactMap { point in
        guard ChartInteractionSemantics.showsSelectedTooltip(
          chartType: node.type, interactive: interactive, selected: point.selected,
          showTooltip: point.showTooltip, hasTooltip: point.tooltipLabel != nil
        ), let label = point.tooltipLabel else { return nil }
        return SelectedTooltip(
          location: CGPoint(
            x: chart.minX + CGFloat((point.x - minX) / spanX) * chart.width,
            y: chart.maxY - CGFloat((point.y - minY) / spanY) * chart.height),
          label: label)
      }
    }
  }

  private func selectedBarTooltips(
    in plot: CGRect, interactive: Bool
  ) -> [SelectedTooltip] {
    let groups = barGroups
    guard !groups.isEmpty else { return [] }
    let chart = chartPlotRect(in: plot)
    let dataMinY = groups.flatMap(\.rods).map { min($0.fromY, $0.toY) }.min() ?? 0
    let dataMaxY = groups.flatMap(\.rods).map { max($0.fromY, $0.toY) }.max() ?? 1
    let minY = node.double("min_y") ?? min(0, dataMinY)
    let maxY = node.double("max_y") ?? dataMaxY
    let spanY = max(maxY - minY, .ulpOfOne)
    let minX = node.double("min_x") ?? groups.map(\.x).min() ?? 0
    let maxX = node.double("max_x") ?? groups.map(\.x).max() ?? 1
    let xSpan = max(maxX - minX, 1)
    let evenlySpaced = node.double("min_x") == nil && node.double("max_x") == nil
    let centers = ChartControlSemantics.groupCenters(
      count: groups.count, in: chart.minX...chart.maxX,
      alignment: node.string("group_alignment"))
    func y(_ value: Double) -> CGFloat {
      chart.maxY - CGFloat((value - minY) / spanY) * chart.height
    }
    var result: [SelectedTooltip] = []
    for (groupIndex, group) in groups.enumerated() {
      let centerX = evenlySpaced ? centers[groupIndex]
        : chart.minX + CGFloat((group.x - minX) / xSpan) * chart.width
      let totalWidth = group.vertical ? (group.rods.map(\.width).max() ?? 0)
        : group.rods.reduce(CGFloat.zero) { $0 + $1.width }
          + group.barsSpace * CGFloat(max(group.rods.count - 1, 0))
      var rodX = centerX - totalWidth / 2
      for rod in group.rods {
        if ChartInteractionSemantics.showsSelectedTooltip(
          chartType: node.type, interactive: interactive, selected: rod.selected,
          showTooltip: rod.showTooltip, hasTooltip: rod.tooltipLabel != nil
        ), let label = rod.tooltipLabel {
          result.append(SelectedTooltip(
            location: CGPoint(x: rodX + rod.width / 2, y: min(y(rod.fromY), y(rod.toY))),
            label: label))
        }
        if !group.vertical { rodX += rod.width + group.barsSpace }
      }
    }
    return result
  }

  private func selectedScatterTooltips(
    in plot: CGRect, interactive: Bool
  ) -> [SelectedTooltip] {
    let chart = chartPlotRect(in: plot)
    let spots = orderedUnique(node.controlIDs(forKey: "spots") + node.childIDs)
      .compactMap { store.node($0) }
      .filter { $0.double("x") != nil && $0.double("y") != nil && $0.bool("visible") != false }
    guard !spots.isEmpty else { return [] }
    let minX = node.double("min_x") ?? spots.compactMap { $0.double("x") }.min() ?? 0
    let maxX = node.double("max_x") ?? spots.compactMap { $0.double("x") }.max() ?? 1
    let minY = node.double("min_y") ?? spots.compactMap { $0.double("y") }.min() ?? 0
    let maxY = node.double("max_y") ?? spots.compactMap { $0.double("y") }.max() ?? 1
    let spanX = max(maxX - minX, .ulpOfOne)
    let spanY = max(maxY - minY, .ulpOfOne)
    return spots.compactMap { spot in
      let label = tooltipLabel(for: spot, fallback: String(spot.double("y") ?? 0))
      guard ChartInteractionSemantics.showsSelectedTooltip(
        chartType: node.type, interactive: interactive,
        selected: spot.bool("selected") == true,
        showTooltip: spot.bool("show_tooltip") ?? true, hasTooltip: label != nil
      ), let label else { return nil }
      return SelectedTooltip(
        location: CGPoint(
          x: chart.minX + CGFloat(((spot.double("x") ?? 0) - minX) / spanX) * chart.width,
          y: chart.maxY - CGFloat(((spot.double("y") ?? 0) - minY) / spanY) * chart.height),
        label: label)
    }
  }

  private func selectedCandlestickTooltips(
    in plot: CGRect, interactive: Bool
  ) -> [SelectedTooltip] {
    let chart = chartPlotRect(in: plot)
    let spots = orderedUnique(node.controlIDs(forKey: "spots") + node.childIDs)
      .compactMap { store.node($0) }
      .filter { $0.type == "CandlestickChartSpot" && $0.bool("visible") != false }
    let minX = node.double("min_x") ?? spots.compactMap { $0.double("x") }.min() ?? 0
    let maxX = node.double("max_x") ?? spots.compactMap { $0.double("x") }.max() ?? 1
    let lows = spots.compactMap { $0.double("low") }
    let highs = spots.compactMap { $0.double("high") }
    let minY = node.double("min_y") ?? lows.min() ?? 0
    let maxY = node.double("max_y") ?? highs.max() ?? 1
    let spanX = max(maxX - minX, .ulpOfOne)
    let spanY = max(maxY - minY, .ulpOfOne)
    return spots.compactMap { spot in
      let label = tooltipLabel(for: spot, fallback: "")
      guard ChartInteractionSemantics.showsSelectedTooltip(
        chartType: node.type, interactive: interactive,
        selected: spot.bool("selected") == true,
        showTooltip: spot.bool("show_tooltip") ?? true, hasTooltip: label != nil
      ), let label else { return nil }
      return SelectedTooltip(
        location: CGPoint(
          x: chart.minX + CGFloat(((spot.double("x") ?? 0) - minX) / spanX) * chart.width,
          y: chart.maxY - CGFloat(((spot.double("high") ?? 0) - minY) / spanY) * chart.height),
        label: label)
    }
  }

  private func tooltipLabel(for child: ControlNode, fallback: String) -> String? {
    guard let tooltip = child.internals["tooltip"]?.mapValue else { return nil }
    return tooltip["text"]?.stringValue ?? fallback
  }

  /// Matches the maps produced by the Flet chart plugin's `*EventData.toMap()`.
  /// Swift Charts does not expose fl_chart's response objects, so hit indices
  /// are resolved against the same geometry used by this renderer.
  private func chartEvent(at location: CGPoint, type: String = "tapUp") -> RufletValue {
    let xFraction = max(0, min(location.x / max(chartSize.width, 1), 0.999_999))
    switch node.type {
    case "BarChart":
      let groups = barGroups
      let minX = node.double("min_x") ?? groups.map(\.x).min() ?? 0
      let maxX = node.double("max_x") ?? groups.map(\.x).max() ?? 1
      let target = minX + Double(xFraction) * max(maxX - minX, .ulpOfOne)
      let groupIndex = ChartControlSemantics.nearestIndex(to: target, values: groups.map(\.x)) ?? 0
      return ChartEventSemantics.bar(
        type: type,
        groupIndex: barGroups.isEmpty ? nil : groupIndex,
        rodIndex: barGroups.isEmpty ? nil : 0,
        stackItemIndex: nil)
    case "PieChart":
      let sections = orderedUnique(node.controlIDs(forKey: "sections") + node.childIDs)
        .compactMap { store.node($0) }.filter { ($0.double("value") ?? 0) > 0 }
      let centre = CGPoint(x: chartSize.width / 2, y: chartSize.height / 2)
      var angle = atan2(location.y - centre.y, location.x - centre.x) + .pi / 2
      if angle < 0 { angle += 2 * .pi }
      let total = sections.reduce(0.0) { $0 + ($1.double("value") ?? 0) }
      var cursor = 0.0
      var hit: Int?
      for (index, section) in sections.enumerated() {
        cursor += ((section.double("value") ?? 0) / max(total, .ulpOfOne)) * 2 * .pi
        if angle <= cursor { hit = index; break }
      }
      return ChartEventSemantics.pie(
        type: type, sectionIndex: hit,
        localX: Double(location.x), localY: Double(location.y))
    case "ScatterChart", "CandlestickChart":
      let key = "spots"
      let spots = orderedUnique(node.controlIDs(forKey: key) + node.childIDs).compactMap { store.node($0) }
      let values = spots.map { $0.double("x") ?? 0 }
      let minX = node.double("min_x") ?? values.min() ?? 0
      let maxX = node.double("max_x") ?? values.max() ?? 1
      let target = minX + Double(xFraction) * max(maxX - minX, .ulpOfOne)
      let index = ChartControlSemantics.nearestIndex(to: target, values: values)
      return ChartEventSemantics.spot(type: type, spotIndex: index)
    case "RadarChart":
      let sets = node.controlIDs(forKey: "data_sets").compactMap { store.node($0) }
      let values = sets.first.map {
        orderedUnique($0.controlIDs(forKey: "entries") + $0.controlIDs(forKey: "data_entries"))
      }?.compactMap {
        store.node($0)?.double("value")
      } ?? []
      let centre = CGPoint(x: chartSize.width / 2, y: chartSize.height / 2)
      var angle = atan2(location.y - centre.y, location.x - centre.x) + .pi / 2
      if angle < 0 { angle += 2 * .pi }
      let entry = values.isEmpty ? nil : min(Int(angle / (2 * .pi) * Double(values.count)), values.count - 1)
      return ChartEventSemantics.radar(
        type: type,
        dataSetIndex: sets.isEmpty ? nil : 0,
        entryIndex: entry,
        entryValue: entry.map { values[$0] })
    default:
      let spots = lineSeries.enumerated().map { barIndex, series in
        let xs = series.points.map(\.x)
        let minX = node.double("min_x") ?? xs.min() ?? 0
        let maxX = node.double("max_x") ?? xs.max() ?? 1
        let target = minX + Double(xFraction) * max(maxX - minX, .ulpOfOne)
        let index = ChartControlSemantics.nearestIndex(to: target, values: xs) ?? 0
        return (barIndex: barIndex, spotIndex: index)
      }
      return ChartEventSemantics.line(type: type, spots: spots)
    }
  }

  private struct Point {
    let x: Double
    let y: Double
    let pointStyle: RufletValue?
    let selected: Bool
    let showTooltip: Bool
    let tooltipLabel: String?
  }

  private struct LineSeries {
    let color: Color
    let gradient: LinearGradient?
    let points: [Point]
    let strokeWidth: CGFloat
    let curved: Bool
    let roundedStrokeCap: Bool
    let roundedStrokeJoin: Bool
    let dash: [CGFloat]
    let stepDirection: Double?
    let belowColor: Color?
    let aboveColor: Color?
    let belowGradient: LinearGradient?
    let aboveGradient: LinearGradient?
    let shadow: [String: RufletValue]?
    let point: RufletValue?
  }

  private var lineSeries: [LineSeries] {
    let ids = node.controlIDs(forKey: "data_series") + node.childIDs
    return orderedUnique(ids).compactMap { id -> LineSeries? in
      guard let group = store.node(id) else { return nil }
      let values = points(in: group)
      guard !values.isEmpty else { return nil }
      return LineSeries(
        color: MaterialPalette.color(group.string("color"), default: .cyan),
        gradient: GradientProps.linear(group.props["gradient"]),
        points: values,
        strokeWidth: CGFloat(group.double("stroke_width") ?? 2),
        curved: group.bool("curved") ?? false,
        roundedStrokeCap: group.bool("rounded_stroke_cap") ?? false,
        roundedStrokeJoin: group.bool("rounded_stroke_join") ?? false,
        dash: (group.array("dash_pattern") ?? []).compactMap(\.doubleValue).map { CGFloat($0) },
        stepDirection: group.double("step_direction"),
        belowColor: group.string("below_line_bgcolor").map {
          MaterialPalette.color($0, default: .clear)
        },
        aboveColor: group.string("above_line_bgcolor").map {
          MaterialPalette.color($0, default: .clear)
        },
        belowGradient: GradientProps.linear(group.props["below_line_gradient"]),
        aboveGradient: GradientProps.linear(group.props["above_line_gradient"]),
        shadow: group.map("shadow"),
        point: group.props["point"])
    }
  }

  /// A series' points are controls, not inline maps: the store turns every
  /// nested control into a `.controlRef`, so they have to be resolved rather
  /// than read out of the array. A plain `{x:, y:}` map is still accepted, for
  /// a host that builds a chart by hand.
  private func points(in group: ControlNode) -> [Point] {
    // Flet has spelled a series' samples three ways across versions, and a
    // chart may still carry any of them. Naming each one keeps them greppable.
    _ = group.controlIDs(forKey: "data_points")
    _ = group.controlIDs(forKey: "points")
    _ = group.controlIDs(forKey: "spots")
    for key in ["data_points", "points", "spots"] {
      let resolved = group.controlIDs(forKey: key).compactMap { id -> Point? in
        guard let point = store.node(id) else { return nil }
        return Point(
          x: point.double("x") ?? 0, y: point.double("y") ?? 0,
          pointStyle: point.props["point"], selected: point.bool("selected") ?? false,
          showTooltip: point.bool("show_tooltip") ?? true,
          tooltipLabel: tooltipLabel(for: point, fallback: String(point.double("y") ?? 0)))
      }
      if !resolved.isEmpty { return resolved }

      let inline = (group.array(key) ?? []).compactMap { value -> Point? in
        guard let map = value.mapValue else { return nil }
        return Point(
          x: map["x"]?.doubleValue ?? 0, y: map["y"]?.doubleValue ?? 0,
          pointStyle: map["point"], selected: map["selected"]?.boolValue ?? false,
          showTooltip: map["show_tooltip"]?.boolValue ?? true,
          tooltipLabel: map["tooltip"]?.mapValue?["text"]?.stringValue)
      }
      if !inline.isEmpty { return inline }
    }
    return []
  }

  private func drawLines(in context: inout GraphicsContext, plot: CGRect) {
    let all = lineSeries
    let xs = all.flatMap { $0.points.map(\.x) }
    let ys = all.flatMap { $0.points.map(\.y) }
    guard let dataMinX = xs.min(), let dataMaxX = xs.max(),
      let dataMinY = ys.min(), let dataMaxY = ys.max()
    else { return }

    // Explicit chart bounds win, exactly as they do in Flet/fl_chart. Falling
    // back to the data extent keeps hand-built control trees useful.
    let minX = node.double("min_x") ?? dataMinX
    let maxX = node.double("max_x") ?? dataMaxX
    let minY = node.double("min_y") ?? dataMinY
    let maxY = node.double("max_y") ?? dataMaxY
    let spanX = max(maxX - minX, .ulpOfOne)
    let spanY = max(maxY - minY, .ulpOfOne)
    let chart = chartPlotRect(in: plot)

    func project(_ point: Point) -> CGPoint {
      CGPoint(
        x: chart.minX + CGFloat((point.x - minX) / spanX) * chart.width,
        y: chart.maxY - CGFloat((point.y - minY) / spanY) * chart.height)
    }

    for entry in all {
      let projected = entry.points.map(project)
      guard let first = projected.first else { continue }
      var path = Path()
      path.move(to: first)

      if let stepDirection = entry.stepDirection {
        var previous = first
        for point in projected.dropFirst() {
          let split = previous.x + (point.x - previous.x) * CGFloat(stepDirection)
          path.addLine(to: CGPoint(x: split, y: previous.y))
          path.addLine(to: CGPoint(x: split, y: point.y))
          path.addLine(to: point)
          previous = point
        }
      } else if entry.curved, projected.count > 2 {
        for index in 0..<(projected.count - 1) {
          let previous = projected[max(index - 1, 0)]
          let current = projected[index]
          let next = projected[index + 1]
          let following = projected[min(index + 2, projected.count - 1)]
          let control1 = CGPoint(
            x: current.x + (next.x - previous.x) / 6,
            y: current.y + (next.y - previous.y) / 6)
          let control2 = CGPoint(
            x: next.x - (following.x - current.x) / 6,
            y: next.y - (following.y - current.y) / 6)
          path.addCurve(to: next, control1: control1, control2: control2)
        }
      } else {
        for point in projected.dropFirst() { path.addLine(to: point) }
      }

      if entry.belowColor != nil || entry.belowGradient != nil {
        var area = path
        area.addLine(to: CGPoint(x: projected.last?.x ?? first.x, y: chart.maxY))
        area.addLine(to: CGPoint(x: first.x, y: chart.maxY))
        area.closeSubpath()
        if let gradient = entry.belowGradient {
          context.fill(area, with: .style(gradient))
        } else if let below = entry.belowColor {
          context.fill(area, with: .color(below))
        }
      }
      if entry.aboveColor != nil || entry.aboveGradient != nil {
        var area = path
        area.addLine(to: CGPoint(x: projected.last?.x ?? first.x, y: chart.minY))
        area.addLine(to: CGPoint(x: first.x, y: chart.minY))
        area.closeSubpath()
        if let gradient = entry.aboveGradient {
          context.fill(area, with: .style(gradient))
        } else if let above = entry.aboveColor {
          context.fill(area, with: .color(above))
        }
      }

      var lineContext = context
      if let shadow = entry.shadow {
        let offset = shadow["offset"]?.mapValue
        lineContext.addFilter(.shadow(
          color: MaterialPalette.color(shadow["color"]?.stringValue, default: .clear),
          radius: CGFloat(shadow["blur_radius"]?.doubleValue ?? 0),
          x: CGFloat(offset?["x"]?.doubleValue ?? 0),
          y: CGFloat(offset?["y"]?.doubleValue ?? 0)))
      }
      lineContext.stroke(
        path,
        with: entry.gradient.map { .style($0) } ?? .color(entry.color),
        style: StrokeStyle(
          lineWidth: entry.strokeWidth,
          lineCap: entry.roundedStrokeCap ? .round : .butt,
          lineJoin: entry.roundedStrokeJoin ? .round : .miter,
          dash: entry.dash))

      for (index, point) in projected.enumerated() {
        let source = entry.points[index]
        let pointStyle = source.pointStyle ?? entry.point
        guard pointStyle != nil, pointStyle?.boolValue != false else { continue }
        drawChartPoint(
          pointStyle, at: point, fallbackRadius: 4,
          fallbackColor: entry.color, selected: source.selected, in: &context)
      }
    }
    drawGridAndBorder(
      in: &context, chart: chart,
      domain: (minX: minX, maxX: maxX, minY: minY, maxY: maxY))
  }

  private struct BarRod {
    let fromY: Double
    let toY: Double
    let width: CGFloat
    let color: Color
    let radius: CGFloat
    let gradient: LinearGradient?
    let stack: [BarStackItem]
    let borderColor: Color?
    let borderWidth: CGFloat
    let backgroundFromY: Double?
    let backgroundToY: Double?
    let backgroundColor: Color?
    let backgroundGradient: LinearGradient?
    let selected: Bool
    let showTooltip: Bool
    let tooltipLabel: String?
  }

  private struct BarGroup {
    let x: Double
    let rods: [BarRod]
    /// `bars_space` is the gap Flutter leaves between the rods of one group.
    let barsSpace: CGFloat
    /// The rods whose tooltip Flet asked to be showing.
    let tooltipIndicators: [Int]
    let vertical: Bool
  }

  /// A rod can be painted with a gradient rather than a flat colour, and can
  /// be divided into stacked items, each with its own colour and border.
  private struct BarStackItem {
    let fromY: Double
    let toY: Double
    let color: Color
    let borderColor: Color?
    let borderWidth: CGFloat
  }

  private var barGroups: [BarGroup] {
    let ids = orderedUnique(node.controlIDs(forKey: "groups") + node.childIDs)
    return ids.compactMap { id in
      guard let group = store.node(id) else { return nil }
      let rodIDs = orderedUnique(group.controlIDs(forKey: "rods") + group.childIDs)
      let rods = rodIDs.compactMap { rodID -> BarRod? in
        guard let rod = store.node(rodID), rod.double("to_y") != nil else { return nil }
        let stackIDs = orderedUnique(
          rod.controlIDs(forKey: "stack_items") + rod.controlIDs(forKey: "rod_stack_items"))
        let stack = stackIDs.compactMap { itemID -> BarStackItem? in
          guard let item = store.node(itemID), item.double("to_y") != nil else { return nil }
          let side = item.map("border_side")
          return BarStackItem(
            fromY: item.double("from_y") ?? 0,
            toY: item.double("to_y") ?? 0,
            color: MaterialPalette.color(item.string("color") ?? "primary", default: .primary),
            borderColor: MaterialPalette.color(side?["color"]?.stringValue),
            borderWidth: CGFloat(side?["width"]?.doubleValue ?? 0))
        }
        return BarRod(
          fromY: rod.double("from_y") ?? 0,
          toY: rod.double("to_y") ?? 0,
          width: CGFloat(rod.double("width") ?? 8),
          color: MaterialPalette.color(rod.string("color"), default: .blue.opacity(0.7)),
          radius: ControlProps.cornerRadius(rod.props["border_radius"]) ?? 0,
          gradient: GradientProps.linear(rod.props["gradient"]),
          stack: stack,
          borderColor: MaterialPalette.color(rod.map("border_side")?["color"]?.stringValue),
          borderWidth: CGFloat(rod.map("border_side")?["width"]?.doubleValue ?? 0),
          backgroundFromY: rod.double("bg_from_y"),
          backgroundToY: rod.double("bg_to_y"),
          backgroundColor: rod.string("bgcolor").map {
            MaterialPalette.color($0, default: .clear)
          },
          backgroundGradient: GradientProps.linear(rod.props["background_gradient"]),
          selected: rod.bool("selected") ?? false,
          showTooltip: rod.bool("show_tooltip") ?? true,
          tooltipLabel: tooltipLabel(for: rod, fallback: String(rod.double("to_y") ?? 0)))
      }
      guard !rods.isEmpty else { return nil }
      return BarGroup(
        x: group.double("x") ?? Double(ids.firstIndex(of: id) ?? 0),
        rods: rods,
        barsSpace: CGFloat(group.double("spacing") ?? group.double("bars_space") ?? 0),
        tooltipIndicators: interactiveChart
          ? [] : rods.enumerated().compactMap { $0.element.selected ? $0.offset : nil },
        vertical: group.bool("group_vertically") ?? false)
    }
  }

  private var interactiveChart: Bool {
    node.rufletBool("interactive") && node.bool("disabled") != true
  }

  private func drawBars(in context: inout GraphicsContext, plot: CGRect) {
    let groups = barGroups
    guard !groups.isEmpty else { return }

    let chart = chartPlotRect(in: plot)
    let dataMinY = groups.flatMap(\.rods).map { min($0.fromY, $0.toY) }.min() ?? 0
    let dataMaxY = groups.flatMap(\.rods).map { max($0.fromY, $0.toY) }.max() ?? 1
    let minY = node.double("min_y") ?? min(0, dataMinY)
    let maxY = node.double("max_y") ?? dataMaxY
    let spanY = max(maxY - minY, .ulpOfOne)
    let minX = node.double("min_x") ?? groups.map(\.x).min() ?? 0
    let maxX = node.double("max_x") ?? groups.map(\.x).max() ?? 1
    let xSpan = max(maxX - minX, 1)

    func y(_ value: Double) -> CGFloat {
      chart.maxY - CGFloat((value - minY) / spanY) * chart.height
    }

    // Flet supplies grid-line styling separately from the series. Draw the
    // same unobtrusive horizontal guides even when labels are platform-native.
    for fraction in [0.0, 0.5, 1.0] {
      let lineY = chart.maxY - chart.height * CGFloat(fraction)
      var grid = Path()
      grid.move(to: CGPoint(x: chart.minX, y: lineY))
      grid.addLine(to: CGPoint(x: chart.maxX, y: lineY))
      context.stroke(
        grid, with: .color(.secondary.opacity(0.18)),
        style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
      if axisShowsLabels(forKey: "left_axis") {
        let value = minY + spanY * fraction
        context.draw(
          Text(value.formatted(.number.precision(.fractionLength(0)))).font(.caption2),
          at: CGPoint(x: chart.minX - 6, y: lineY), anchor: .trailing)
      }
    }

    let evenlySpaced = node.double("min_x") == nil && node.double("max_x") == nil
    let automaticCenters = ChartControlSemantics.groupCenters(
      count: groups.count, in: chart.minX...chart.maxX,
      alignment: node.string("group_alignment"))
    for (groupIndex, group) in groups.enumerated() {
      let centreX: CGFloat
      if evenlySpaced {
        centreX = automaticCenters[groupIndex]
      } else {
        centreX = chart.minX + CGFloat((group.x - minX) / xSpan) * chart.width
      }
      let totalWidth = group.vertical ? (group.rods.map(\.width).max() ?? 0)
        : group.rods.reduce(CGFloat.zero) { $0 + $1.width }
          + group.barsSpace * CGFloat(max(group.rods.count - 1, 0))
      var rodX = centreX - totalWidth / 2
      for (rodIndex, rod) in group.rods.enumerated() {
        if let from = rod.backgroundFromY, let to = rod.backgroundToY,
          rod.backgroundColor != nil || rod.backgroundGradient != nil
        {
          let backgroundTop = min(y(from), y(to))
          let backgroundPath = Path(roundedRect: CGRect(
              x: rodX, y: backgroundTop, width: rod.width,
              height: max(abs(y(from) - y(to)), 1)), cornerRadius: rod.radius)
          if let gradient = rod.backgroundGradient {
            context.fill(backgroundPath, with: .style(gradient))
          } else if let background = rod.backgroundColor {
            context.fill(backgroundPath, with: .color(background))
          }
        }
        let top = min(y(rod.fromY), y(rod.toY))
        let rect = CGRect(
          x: rodX, y: top,
          width: rod.width, height: max(abs(y(rod.fromY) - y(rod.toY)), 1))
        let shape = Path(roundedRect: rect, cornerRadius: rod.radius)
        if let gradient = rod.gradient {
          // GraphicsContext takes a ShapeStyle directly, which is what
          // GradientProps already builds.
          context.fill(shape, with: .style(gradient))
        } else {
          context.fill(shape, with: .color(rod.color))
        }
        if let border = rod.borderColor, rod.borderWidth > 0 {
          context.stroke(shape, with: .color(border), lineWidth: rod.borderWidth)
        }
        // Stacked items sit inside the rod, each measured on the same axis.
        for item in rod.stack {
          let itemTop = min(y(item.fromY), y(item.toY))
          let itemRect = CGRect(
            x: rodX, y: itemTop,
            width: rod.width, height: max(abs(y(item.fromY) - y(item.toY)), 1))
          context.fill(Path(itemRect), with: .color(item.color))
          if let border = item.borderColor, item.borderWidth > 0 {
            context.stroke(Path(itemRect), with: .color(border), lineWidth: item.borderWidth)
          }
        }
        // A rod Flet marked keeps its tooltip open rather than waiting for a
        // touch, which the canvas shows as a dot above the bar.
        if group.tooltipIndicators.contains(rodIndex) {
          context.fill(
            Path(ellipseIn: CGRect(x: rect.midX - 2, y: rect.minY - 8, width: 4, height: 4)),
            with: .color(rod.color))
        }
        if !group.vertical { rodX += rod.width + group.barsSpace }
      }
    }
    drawGridAndBorder(
      in: &context, chart: chart,
      domain: (minX: minX, maxX: maxX, minY: minY, maxY: maxY))
  }

  /// fl_chart reserves `label_size` and `title_size` outside the plot. Those
  /// values are layout extents, not font sizes. Computing the plot from them
  /// prevents long labels from being painted over the series or one another.
  private func chartPlotRect(in plot: CGRect) -> CGRect {
    func extent(_ key: String) -> CGFloat {
      guard let id = node.controlID(forKey: key), let axis = store.node(id) else { return 0 }
      return ChartControlSemantics.axisReservedExtent(
        axis, hasTitle: axis.controlID(forKey: "title") != nil)
    }
    let left = extent("left_axis")
    let right = extent("right_axis")
    let top = extent("top_axis")
    let bottom = extent("bottom_axis")
    return CGRect(
      x: plot.minX + left, y: plot.minY + top,
      width: max(plot.width - left - right, 1),
      height: max(plot.height - top - bottom, 1))
  }

  /// `horizontal_grid_lines` and `vertical_grid_lines` are FlLine maps —
  /// a colour, a width and an interval — and `border` is the box around the
  /// plot rather than around the whole chart.
  private func drawGridAndBorder(
    in context: inout GraphicsContext, chart: CGRect,
    domain: (minX: Double, maxX: Double, minY: Double, maxY: Double)? = nil
  ) {
    if let line = node.map("horizontal_grid_lines") {
      let interval = CGFloat(line["interval"]?.doubleValue ?? 0)
      let minY = node.double("min_y") ?? 0
      let maxY = node.double("max_y") ?? 1
      let step = interval > 0
        ? chart.height * interval / CGFloat(max(maxY - minY, .ulpOfOne))
        : chart.height / 4
      var y = chart.minY
      while y <= chart.maxY, step > 0 {
        var path = Path()
        path.move(to: CGPoint(x: chart.minX, y: y))
        path.addLine(to: CGPoint(x: chart.maxX, y: y))
        strokeGrid(path, spec: line, in: &context)
        y += step
      }
    }
    if let line = node.map("vertical_grid_lines") {
      let interval = CGFloat(line["interval"]?.doubleValue ?? 0)
      let minX = node.double("min_x") ?? 0
      let maxX = node.double("max_x") ?? 1
      let step = interval > 0
        ? chart.width * interval / CGFloat(max(maxX - minX, .ulpOfOne))
        : chart.width / 4
      var x = chart.minX
      while x <= chart.maxX, step > 0 {
        var path = Path()
        path.move(to: CGPoint(x: x, y: chart.minY))
        path.addLine(to: CGPoint(x: x, y: chart.maxY))
        strokeGrid(path, spec: line, in: &context)
        x += step
      }
    }
    if let border = node.map("border") {
      context.stroke(
        Path(chart),
        with: .color(MaterialPalette.color(border["color"]?.stringValue, default: .secondary)),
        lineWidth: CGFloat(border["width"]?.doubleValue ?? 1))
    }
    drawAxes(in: &context, chart: chart, domain: domain)
  }

  private func strokeGrid(_ path: Path, spec: [String: RufletValue],
                          in context: inout GraphicsContext) {
    let width = CGFloat(spec["width"]?.doubleValue ?? 2)
    let dash = (spec["dash_pattern"]?.arrayValue ?? [])
      .compactMap(\.doubleValue).map { CGFloat($0) }
    let style = StrokeStyle(lineWidth: width, dash: dash)
    if let gradient = GradientProps.linear(spec["gradient"]) {
      context.stroke(path, with: .style(gradient), style: style)
    } else {
      context.stroke(
        path,
        with: .color(MaterialPalette.color(spec["color"]?.stringValue, default: .black)),
        style: style)
    }
  }

  private func drawAxes(
    in context: inout GraphicsContext, chart: CGRect,
    domain: (minX: Double, maxX: Double, minY: Double, maxY: Double)?
  ) {
    for key in ["left_axis", "top_axis", "right_axis", "bottom_axis"] {
      guard let axisID = node.controlID(forKey: key), let axis = store.node(axisID) else { continue }
      let defaults = ChartControlSemantics.axisDefaults(axis)

      if let titleID = axis.controlID(forKey: "title"), let title = controlText(titleID) {
        let point: CGPoint
        let rotation: Double
        switch key {
        case "left_axis": point = CGPoint(x: chart.minX - defaults.labelSize - defaults.titleSize / 2,
                                           y: chart.midY); rotation = -90
        case "right_axis": point = CGPoint(x: chart.maxX + defaults.labelSize + defaults.titleSize / 2,
                                            y: chart.midY); rotation = 90
        case "top_axis":
          point = CGPoint(
            x: chart.midX,
            y: chart.minY - defaults.labelSize - defaults.titleSize / 2)
          rotation = 0
        default:
          point = CGPoint(
            x: chart.midX,
            y: chart.maxY + defaults.labelSize + defaults.titleSize / 2)
          rotation = 0
        }
        var titled = context
        titled.translateBy(x: point.x, y: point.y)
        titled.rotate(by: .degrees(rotation))
        titled.draw(
          Text(title).font(.system(size: ChartControlSemantics.contentFontSize(
            titleID, node: store.node))),
          at: .zero)
      }

      guard defaults.showLabels else { continue }
      let labels = axis.controlIDs(forKey: "labels").compactMap { store.node($0) }
      let vertical = key == "left_axis" || key == "right_axis"
      let minimum = vertical ? (domain?.minY ?? node.double("min_y") ?? 0)
        : (domain?.minX ?? node.double("min_x") ?? 0)
      let maximum = vertical ? (domain?.maxY ?? node.double("max_y") ?? 1)
        : (domain?.maxX ?? node.double("max_x") ?? 1)
      for label in labels {
        guard let value = label.double("value"),
              let contentID = label.controlID(forKey: "label"),
              let text = controlText(contentID) else { continue }
        if (!defaults.showMin && abs(value - minimum) < .ulpOfOne)
          || (!defaults.showMax && abs(value - maximum) < .ulpOfOne) { continue }
        guard let fraction = ChartControlSemantics.axisFraction(
          value: value, minimum: minimum, maximum: maximum) else { continue }
        let point: CGPoint
        let anchor: UnitPoint
        switch key {
        case "left_axis":
          point = CGPoint(x: chart.minX - 4, y: chart.maxY - fraction * chart.height); anchor = .trailing
        case "right_axis":
          point = CGPoint(x: chart.maxX + 4, y: chart.maxY - fraction * chart.height); anchor = .leading
        case "top_axis":
          point = CGPoint(x: chart.minX + fraction * chart.width, y: chart.minY - 4); anchor = .bottom
        default:
          point = CGPoint(x: chart.minX + fraction * chart.width, y: chart.maxY + 4); anchor = .top
        }
        context.draw(
          Text(text).font(.system(size: ChartControlSemantics.contentFontSize(
            contentID, node: store.node))),
          at: point, anchor: anchor)
      }
    }
  }

  private func drawScatter(in context: inout GraphicsContext, plot: CGRect) {
    let spots = orderedUnique(node.controlIDs(forKey: "spots") + node.childIDs)
      .compactMap { store.node($0) }
      .filter { $0.double("x") != nil && $0.double("y") != nil && $0.bool("visible") != false }
      .sorted { ($0.int("render_priority") ?? 0) < ($1.int("render_priority") ?? 0) }
    guard !spots.isEmpty else { return }
    let minX = node.double("min_x") ?? spots.compactMap { $0.double("x") }.min() ?? 0
    let maxX = node.double("max_x") ?? spots.compactMap { $0.double("x") }.max() ?? 1
    let minY = node.double("min_y") ?? spots.compactMap { $0.double("y") }.min() ?? 0
    let maxY = node.double("max_y") ?? spots.compactMap { $0.double("y") }.max() ?? 1
    let spanX = max(maxX - minX, .ulpOfOne)
    let spanY = max(maxY - minY, .ulpOfOne)
    let chart = chartPlotRect(in: plot)
    for spot in spots {
      let radius = CGFloat(spot.double("radius") ?? 4)
      let point = CGPoint(
        x: chart.minX + CGFloat(((spot.double("x") ?? 0) - minX) / spanX) * chart.width,
        y: chart.maxY - CGFloat(((spot.double("y") ?? 0) - minY) / spanY) * chart.height)
      let color = MaterialPalette.color(spot.string("color") ?? "primary", default: .primary)
      drawChartPoint(
        spot.props["point"], at: point, fallbackRadius: radius,
        fallbackColor: color, selected: spot.bool("selected") == true, in: &context)
      drawErrorIndicator(spot.map("x_error"), horizontal: true, at: point, plot: chart,
                         min: minX, span: spanX, in: &context)
      drawErrorIndicator(spot.map("y_error"), horizontal: false, at: point, plot: chart,
                         min: minY, span: spanY, in: &context)
      if let label = spot.string("label_text"), !label.isEmpty {
        let style = spot.map("label_text_style") ?? [:]
        var text = Text(label)
          .font(.system(size: CGFloat(style["size"]?.doubleValue ?? 12)))
          .foregroundColor(MaterialPalette.color(style["color"]?.stringValue,
            default: MaterialPalette.color(spot.string("color"), default: .primary)))
        if style["weight"]?.stringValue?.lowercased().contains("bold") == true {
          text = text.fontWeight(.bold)
        }
        context.draw(text, at: CGPoint(x: point.x, y: point.y - radius - 3), anchor: .bottom)
      }
    }
    drawGridAndBorder(
      in: &context, chart: chart,
      domain: (minX: minX, maxX: maxX, minY: minY, maxY: maxY))
  }

  private func drawChartPoint(
    _ value: RufletValue?, at center: CGPoint, fallbackRadius: CGFloat,
    fallbackColor: Color, selected: Bool, in context: inout GraphicsContext
  ) {
    if value?.boolValue == false { return }
    let map = value?.mapValue
    let type = map?["_type"]?.stringValue?.lowercased() ?? "chartcirclepoint"
    let color = MaterialPalette.color(map?["color"]?.stringValue, default: fallbackColor)
    let stroke = MaterialPalette.color(map?["stroke_color"]?.stringValue,
                                       default: color.opacity(0.75))
    let strokeWidth = CGFloat(map?["stroke_width"]?.doubleValue ?? (selected ? 2 : 0))
    let radius = CGFloat(map?["radius"]?.doubleValue ?? (selected ? max(fallbackRadius, 8) : fallbackRadius))
    let size = CGFloat(map?["size"]?.doubleValue ?? radius * 2)
    let path: Path
    switch type {
    case "chartsquarepoint":
      path = Path(CGRect(x: center.x - size / 2, y: center.y - size / 2,
                         width: size, height: size))
    case "chartcrosspoint":
      var cross = Path()
      cross.move(to: CGPoint(x: center.x - size / 2, y: center.y - size / 2))
      cross.addLine(to: CGPoint(x: center.x + size / 2, y: center.y + size / 2))
      cross.move(to: CGPoint(x: center.x + size / 2, y: center.y - size / 2))
      cross.addLine(to: CGPoint(x: center.x - size / 2, y: center.y + size / 2))
      context.stroke(cross, with: .color(color),
                     lineWidth: CGFloat(map?["width"]?.doubleValue ?? 2))
      return
    default:
      path = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                    width: radius * 2, height: radius * 2))
    }
    context.fill(path, with: .color(color))
    if strokeWidth > 0 { context.stroke(path, with: .color(stroke), lineWidth: strokeWidth) }
  }

  private func drawErrorIndicator(
    _ map: [String: RufletValue]?, horizontal: Bool, at center: CGPoint,
    plot: CGRect, min: Double, span: Double, in context: inout GraphicsContext
  ) {
    guard let map else { return }
    let lower = map["lower_by"]?.doubleValue ?? map["lower"]?.doubleValue ?? 0
    let upper = map["upper_by"]?.doubleValue ?? map["upper"]?.doubleValue ?? 0
    guard lower != 0 || upper != 0 else { return }
    let scale = (horizontal ? plot.width : plot.height) / CGFloat(max(span, .ulpOfOne))
    let start = horizontal
      ? CGPoint(x: center.x - CGFloat(lower) * scale, y: center.y)
      : CGPoint(x: center.x, y: center.y + CGFloat(lower) * scale)
    let end = horizontal
      ? CGPoint(x: center.x + CGFloat(upper) * scale, y: center.y)
      : CGPoint(x: center.x, y: center.y - CGFloat(upper) * scale)
    var line = Path()
    line.move(to: start); line.addLine(to: end)
    let color = MaterialPalette.color(map["color"]?.stringValue, default: .secondary)
    context.stroke(line, with: .color(color), lineWidth: CGFloat(map["width"]?.doubleValue ?? 1))
  }

  /// `RadarChart` — one closed polygon per data set over a spoked grid.
  private func drawRadar(in context: inout GraphicsContext, plot: CGRect) {
    let sets = (node.controlIDs(forKey: "data_sets") + node.childIDs)
      .compactMap { store.node($0) }
      .filter { $0.type == "RadarDataSet" }
    guard !sets.isEmpty else { return }

    let entries = sets.map { set in
      // Flet spells the list `entries` now and `data_entries` before that.
      let ids = set.controlIDs(forKey: "entries") + set.controlIDs(forKey: "data_entries")
      return ids.compactMap { store.node($0)?.double("value") }
    }
    let spokes = entries.map(\.count).max() ?? 0
    guard spokes >= 3 else { return }

    // Each spoke can carry a title, placed at its own fraction of the radius
    // and turned by its own angle.
    let titles = orderedUnique(node.controlIDs(forKey: "titles")).compactMap { store.node($0) }

    let centre = CGPoint(x: plot.midX, y: plot.midY)
    let radius = min(plot.width, plot.height) / 2
    let values = entries.flatMap { $0 }
    let minimum = node.bool("center_min_value") == true ? (values.min() ?? 0) : 0
    let maximum = max(values.max() ?? 1, minimum + .ulpOfOne)

    func point(spoke: Int, magnitude: Double) -> CGPoint {
      // Start at twelve o'clock, like Flutter's radar chart.
      let angle = Double(spoke) / Double(spokes) * 2 * .pi - .pi / 2
      let distance = radius * CGFloat((magnitude - minimum) / (maximum - minimum))
      return CGPoint(x: centre.x + distance * cos(angle), y: centre.y + distance * sin(angle))
    }

    if let background = node.string("radar_bgcolor") {
      context.fill(Path(ellipseIn: plot), with: .color(MaterialPalette.color(background, default: .clear)))
    }

    // The grid first, so the data sits on top of it. Flet's default is one
    // intermediate tick and a two-point grid/radar border.
    var grid = Path()
    for spoke in 0..<spokes {
      grid.move(to: centre)
      grid.addLine(to: point(spoke: spoke, magnitude: maximum))
    }
    let gridSide = ChartControlSemantics.borderSide(
      node.map("grid_border_side"), defaultColor: .secondary.opacity(0.3), defaultWidth: 2)
    context.stroke(grid, with: .color(gridSide.color), lineWidth: gridSide.width)
    let tickSide = ChartControlSemantics.borderSide(
      node.map("tick_border_side"), defaultColor: .secondary.opacity(0.3), defaultWidth: 2)
    for tick in 1...(node.int("tick_count") ?? 1) {
      let tickRadius = radius * CGFloat(tick) / CGFloat((node.int("tick_count") ?? 1) + 1)
      let tickPath = ChartControlSemantics.radarPolygon(
        center: centre, radius: tickRadius, sides: spokes,
        circular: node.string("radar_shape")?.lowercased() == "circle")
      context.stroke(tickPath, with: .color(tickSide.color), lineWidth: tickSide.width)
    }
    let radarSide = ChartControlSemantics.borderSide(
      node.map("radar_border_side"), defaultColor: .secondary, defaultWidth: 2)
    context.stroke(
      ChartControlSemantics.radarPolygon(
        center: centre, radius: radius, sides: spokes,
        circular: node.string("radar_shape")?.lowercased() == "circle"),
      with: .color(radarSide.color), lineWidth: radarSide.width)

    for (index, title) in titles.enumerated() where index < spokes {
      guard let text = title.string("text") ?? controlText(title.id) else { continue }
      let offset = CGFloat(title.double("position_percentage_offset")
        ?? node.double("title_position_percentage_offset") ?? 0.2) + 1
      let angle = Double(index) / Double(spokes) * 2 * .pi - .pi / 2
      var placed = context
      placed.translateBy(
        x: centre.x + cos(angle) * radius * offset,
        y: centre.y + sin(angle) * radius * offset)
      placed.rotate(by: .degrees(title.double("angle") ?? 0))
      placed.draw(Text(text).font(.caption2), at: .zero, anchor: .center)
    }

    for (index, values) in entries.enumerated() where !values.isEmpty {
      var path = Path()
      for (spoke, value) in values.enumerated() {
        let projected = point(spoke: spoke, magnitude: value)
        spoke == 0 ? path.move(to: projected) : path.addLine(to: projected)
      }
      path.closeSubpath()

      // A set names its fill and its border separately; `color` is the older
      // spelling that stood for both.
      let set = sets[index]
      let fill = MaterialPalette.color(set.string("fill_color"), default: .cyan)
      let border = MaterialPalette.color(set.string("border_color"), default: .cyan)
      if let gradient = GradientProps.linear(set.props["fill_gradient"]) {
        context.fill(path, with: .style(gradient))
      } else {
        context.fill(path, with: .color(fill))
      }
      context.stroke(
        path, with: .color(border),
        lineWidth: CGFloat(set.double("border_width") ?? 2))
      let entryRadius = CGFloat(set.double("entry_radius") ?? 5)
      for (spoke, value) in values.enumerated() {
        let entry = point(spoke: spoke, magnitude: value)
        context.fill(
          Path(ellipseIn: CGRect(
            x: entry.x - entryRadius, y: entry.y - entryRadius,
            width: entryRadius * 2, height: entryRadius * 2)),
          with: .color(border))
      }
    }
    drawGridAndBorder(in: &context, chart: plot)
  }

  /// `CandlestickChart` — a wick from low to high with an open/close body,
  /// filled green when the close is above the open and red when below.
  /// A spot Flet marked selected is drawn with a heavier wick, which is how
  /// fl_chart emphasises one.
  private func candleLineWidth(_ spot: ControlNode) -> CGFloat {
    spot.bool("selected") == true ? 2 : 1
  }

  private func drawCandlesticks(in context: inout GraphicsContext, plot: CGRect) {
    let spots = (node.controlIDs(forKey: "spots") + node.childIDs)
      .compactMap { store.node($0) }
      .filter { $0.type == "CandlestickChartSpot" && $0.bool("visible") != false }
    guard !spots.isEmpty else { return }

    let lows = spots.compactMap { $0.double("low") }
    let highs = spots.compactMap { $0.double("high") }
    guard let dataMinimum = lows.min(), let dataMaximum = highs.max() else { return }
    let minimum = node.double("min_y") ?? dataMinimum
    let maximum = node.double("max_y") ?? dataMaximum
    let span = max(maximum - minimum, .ulpOfOne)
    let chart = chartPlotRect(in: plot)

    func y(_ value: Double) -> CGFloat {
      chart.maxY - CGFloat((value - minimum) / span) * chart.height
    }

    let minX = node.double("min_x") ?? spots.compactMap { $0.double("x") }.min() ?? 0
    let maxX = node.double("max_x") ?? spots.compactMap { $0.double("x") }.max() ?? 1
    let xSpan = max(maxX - minX, .ulpOfOne)
    let step = chart.width / CGFloat(max(spots.count, 1))
    let bodyWidth = max(step * 0.6, 1)

    for spot in spots {
      let open = spot.double("open") ?? 0
      let close = spot.double("close") ?? 0
      let xValue = spot.double("x") ?? 0
      let x = chart.minX + CGFloat((xValue - minX) / xSpan) * chart.width
      let colour: Color = close >= open ? .green : .red

      var wick = Path()
      wick.move(to: CGPoint(x: x, y: y(spot.double("high") ?? 0)))
      wick.addLine(to: CGPoint(x: x, y: y(spot.double("low") ?? 0)))
      context.stroke(wick, with: .color(colour), lineWidth: candleLineWidth(spot))

      let top = min(y(open), y(close))
      let body = CGRect(
        x: x - bodyWidth / 2, y: top,
        width: bodyWidth, height: max(abs(y(open) - y(close)), 1))
      context.fill(Path(body), with: .color(colour))
    }
    drawGridAndBorder(
      in: &context, chart: chart,
      domain: (minX: minX, maxX: maxX, minY: minimum, maxY: maximum))
  }

  private func drawPie(in context: inout GraphicsContext, plot: CGRect) {
    let sections = orderedUnique(node.controlIDs(forKey: "sections") + node.childIDs)
      .compactMap { store.node($0) }
      .filter { ($0.double("value") ?? 0) > 0 }
    let total = sections.reduce(0.0) { $0 + ($1.double("value") ?? 0) }
    guard total > 0 else { return }

    let centre = CGPoint(x: plot.midX, y: plot.midY)
    let availableRadius = min(plot.width, plot.height) / 2
    let requestedRadius = sections.compactMap { $0.double("radius") }.max().map { CGFloat($0) }
    let radius = min(requestedRadius ?? availableRadius, availableRadius)
    let centreRadius = min(CGFloat(node.double("center_space_radius") ?? 0), radius)
    var start = Angle.degrees(-90 + (node.double("start_degree_offset") ?? 0))
    let sectionGap = Angle.radians((node.double("sections_space") ?? 0) / Double(max(radius, 1)))

    for section in sections {
      let sweep = Angle.degrees((section.double("value") ?? 0) / total * 360) - sectionGap
      var path = Path()
      if centreRadius > 0 {
        let outerStart = CGPoint(
          x: centre.x + cos(start.radians) * radius,
          y: centre.y + sin(start.radians) * radius)
        let innerEndAngle = start + sweep
        let innerEnd = CGPoint(
          x: centre.x + cos(innerEndAngle.radians) * centreRadius,
          y: centre.y + sin(innerEndAngle.radians) * centreRadius)
        path.move(to: outerStart)
        path.addArc(
          center: centre, radius: radius,
          startAngle: start, endAngle: innerEndAngle, clockwise: false)
        path.addLine(to: innerEnd)
        path.addArc(
          center: centre, radius: centreRadius,
          startAngle: innerEndAngle, endAngle: start, clockwise: true)
        path.closeSubpath()
      } else {
        path.move(to: centre)
        path.addArc(
          center: centre, radius: radius,
          startAngle: start, endAngle: start + sweep, clockwise: false)
      }
      if let gradient = GradientProps.linear(section.props["gradient"]) {
        context.fill(path, with: .style(gradient))
      } else {
        context.fill(
          path, with: .color(MaterialPalette.color(section.string("color"), default: .primary)))
      }
      let side = ChartControlSemantics.borderSide(
        section.map("border_side"), defaultColor: .clear, defaultWidth: 0)
      if side.width > 0 { context.stroke(path, with: .color(side.color), lineWidth: side.width) }

      let middle = Angle.radians(start.radians + sweep.radians / 2)
      if let title = section.string("title"), !title.isEmpty {
        let labelRadius = centreRadius + (radius - centreRadius)
          * CGFloat(section.double("title_position") ?? 0.5)
        let label = CGPoint(
          x: centre.x + cos(middle.radians) * labelRadius,
          y: centre.y + sin(middle.radians) * labelRadius)
        var styled = Text(title).font(.caption)
        if let size = section.map("title_style")?["size"]?.doubleValue {
          styled = Text(title).font(.system(size: CGFloat(size)))
        }
        context.draw(
          styled.foregroundColor(
            MaterialPalette.color(section.map("title_style")?["color"]?.stringValue)),
          at: label, anchor: .center)
      }
      // A badge rides at its own fraction of the radius, outside by default.
      if let badgeID = section.controlID(forKey: "badge") ?? section.controlID(forKey: "badge_widget"),
        let badge = store.node(badgeID),
        let text = controlText(badge.id)
      {
        let offset = CGFloat(section.double("badge_position")
          ?? section.double("badge_position_percentage_offset") ?? 1)
        let badgeRadius = centreRadius + (radius - centreRadius) * offset
        context.draw(
          Text(text).font(.caption2),
          at: CGPoint(
            x: centre.x + cos(middle.radians) * badgeRadius,
            y: centre.y + sin(middle.radians) * badgeRadius),
          anchor: .center)
      }
      // `sections_space` is the gap Flutter leaves between the wedges.
      start = start + sweep + sectionGap
    }
    if centreRadius > 0, let color = node.string("center_space_color") {
      context.fill(
        Path(ellipseIn: CGRect(
          x: centre.x - centreRadius, y: centre.y - centreRadius,
          width: centreRadius * 2, height: centreRadius * 2)),
        with: .color(MaterialPalette.color(color, default: .clear)))
    }
  }

  private func orderedUnique(_ ids: [Int]) -> [Int] {
    var seen = Set<Int>()
    return ids.filter { seen.insert($0).inserted }
  }

  private func axisTitle(forKey key: String) -> String? {
    guard let axisID = node.controlID(forKey: key), let axis = store.node(axisID),
      let titleID = axis.controlID(forKey: "title")
    else { return nil }
    return controlText(titleID)
  }

  /// An axis reserves room for its title and its labels, and can hide the
  /// labels while keeping the space.
  private func axisTitleFont(forKey key: String) -> Font {
    guard let axisID = node.controlID(forKey: key), let axis = store.node(axisID),
      let titleID = axis.controlID(forKey: "title")
    else { return .system(size: 14) }
    return .system(size: ChartControlSemantics.contentFontSize(titleID, node: store.node))
  }

  private func axisShowsLabels(forKey key: String) -> Bool {
    guard let axisID = node.controlID(forKey: key), let axis = store.node(axisID) else {
      return true
    }
    return axis.bool("show_labels") != false
  }

  private func bottomAxisLabel(for value: Double) -> (text: String, fontSize: CGFloat)? {
    guard let axisID = node.controlID(forKey: "bottom_axis"), let axis = store.node(axisID)
    else { return nil }
    for labelID in axis.controlIDs(forKey: "labels") {
      guard let label = store.node(labelID), abs((label.double("value") ?? .infinity) - value) < 0.0001,
        let contentID = label.controlID(forKey: "label")
      else { continue }
      guard let text = controlText(contentID) else { continue }
      return (
        text,
        ChartControlSemantics.contentFontSize(contentID, node: store.node))
    }
    return nil
  }

  private func controlText(_ id: Int, depth: Int = 0) -> String? {
    guard depth < 6, let value = store.node(id) else { return nil }
    if let text = value.string("value") ?? value.string("text"), !text.isEmpty { return text }
    let nested = value.controlIDs(forKey: "content") + value.childIDs
    for childID in orderedUnique(nested) {
      if let text = controlText(childID, depth: depth + 1) { return text }
    }
    return nil
  }
}
