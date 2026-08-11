import RufletEngine
import RufletProtocol
import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

#if canImport(WebKit)
  import WebKit
#endif
#if canImport(AVKit)
  import AVKit
#endif
#if canImport(MapKit)
  import MapKit
#endif

/// `Canvas` — Flet's immediate-mode drawing surface.
///
/// The shapes arrive as child controls (`Line`, `Rect`, `Circle`, `Path`, …)
/// with a `paint` map, so they are drawn in order into a SwiftUI `Canvas`
/// rather than each becoming its own view.
struct CanvasControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var reportedSize: CGSize = .zero
  @State private var capture = CanvasCaptureBuffer()

  var body: some View {
    ZStack {
      Canvas { context, size in
        for shapeID in node.controlIDs(forKey: "shapes") + node.childIDs {
          guard let shape = store.node(shapeID) else { continue }
          draw(shape, in: &context, size: size)
        }
      }
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    .background {
      GeometryReader { geometry in
        Color.clear
          .onAppear { reportResize(geometry.size) }
          .onChange(of: geometry.size) { reportResize($0) }
      }
    }
    .modifier(TapReporter(node: node, events: events))
    .rufletCommandHandler(node.id, handler: handleCommand)
  }

  private func reportResize(_ size: CGSize) {
    guard size != reportedSize else { return }
    reportedSize = size
    events.fire(
      node,
      "resize",
      data: .map(["w": .double(size.width), "h": .double(size.height)]))
  }

  private func handleCommand(
    _ call: RufletMethodCall,
    completion: @escaping RufletMethodCompletion
  ) {
    switch call.name {
    case "capture":
      guard reportedSize.width > 0, reportedSize.height > 0 else {
        completion(.success(.null))
        return
      }
      guard #available(iOS 16.0, macOS 13.0, *) else {
        completion(.failure(RufletServiceError.unavailable("Canvas capture requires iOS 16 or macOS 13")))
        return
      }
      let renderer = ImageRenderer(content: captureSurface.frame(width: reportedSize.width, height: reportedSize.height))
      renderer.scale = call.argument("pixel_ratio")?.doubleValue ?? 1
      #if canImport(UIKit)
        capture.store(renderer.uiImage?.pngData())
      #elseif canImport(AppKit)
        if let image = renderer.nsImage,
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff) {
          capture.store(bitmap.representation(using: .png, properties: [:]))
        }
      #endif
      completion(.success(.null))
    case "get_capture":
      completion(.success(capture.wireValue))
    case "clear_capture":
      capture.clear()
      completion(.success(.null))
    default:
      completion(.failure(rufletUnsupported(node.type, call)))
    }
  }

  private var captureSurface: some View {
    Canvas { context, size in
      for shapeID in node.controlIDs(forKey: "shapes") + node.childIDs {
        guard let shape = store.node(shapeID) else { continue }
        draw(shape, in: &context, size: size)
      }
    }
    .environmentObject(store)
  }

  private func draw(_ shape: ControlNode, in context: inout GraphicsContext, size: CGSize) {
    let paint = shape.map("paint") ?? [:]
    let stroke = MaterialPalette.color(paint["color"]?.stringValue, default: .primary)
    let width = CGFloat(paint["stroke_width"]?.doubleValue ?? 1)
    let filled = paint["style"]?.stringValue?.lowercased() == "fill"

    switch shape.type {
    case "Line":
      var path = Path()
      path.move(to: CGPoint(x: shape.double("x1") ?? 0, y: shape.double("y1") ?? 0))
      path.addLine(to: CGPoint(x: shape.double("x2") ?? 0, y: shape.double("y2") ?? 0))
      context.stroke(path, with: .color(stroke), lineWidth: width)

    case "Rect":
      let rect = CGRect(
        x: shape.double("x") ?? 0, y: shape.double("y") ?? 0,
        width: shape.double("width") ?? 0, height: shape.double("height") ?? 0)
      let radius = ControlProps.cornerRadius(shape.props["border_radius"]) ?? 0
      let path = Path(roundedRect: rect, cornerRadius: radius)
      filled
        ? context.fill(path, with: .color(stroke))
        : context.stroke(path, with: .color(stroke), lineWidth: width)

    case "Circle":
      let radius = CGFloat(shape.double("radius") ?? 0)
      let rect = CGRect(
        x: (shape.double("x") ?? 0) - radius, y: (shape.double("y") ?? 0) - radius,
        width: radius * 2, height: radius * 2)
      let path = Path(ellipseIn: rect)
      filled
        ? context.fill(path, with: .color(stroke))
        : context.stroke(path, with: .color(stroke), lineWidth: width)

    case "Oval":
      let rect = CGRect(
        x: shape.double("x") ?? 0, y: shape.double("y") ?? 0,
        width: shape.double("width") ?? 0, height: shape.double("height") ?? 0)
      let path = Path(ellipseIn: rect)
      filled
        ? context.fill(path, with: .color(stroke))
        : context.stroke(path, with: .color(stroke), lineWidth: width)

    case "Arc":
      let rect = CGRect(
        x: shape.double("x") ?? 0, y: shape.double("y") ?? 0,
        width: shape.double("width") ?? 0, height: shape.double("height") ?? 0)
      let path = Self.ellipticalArc(
        in: rect,
        startAngle: shape.double("start_angle") ?? 0,
        sweepAngle: shape.double("sweep_angle") ?? 0,
        useCenter: shape.bool("use_center") ?? false)
      filled
        ? context.fill(path, with: .color(stroke))
        : context.stroke(path, with: .color(stroke), lineWidth: width)

    case "Fill":
      context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(stroke))

    case "Points":
      for point in shape.array("points") ?? [] {
        guard let map = point.mapValue else { continue }
        let rect = CGRect(
          x: (map["x"]?.doubleValue ?? 0) - width / 2,
          y: (map["y"]?.doubleValue ?? 0) - width / 2,
          width: width, height: width)
        context.fill(Path(ellipseIn: rect), with: .color(stroke))
      }

    case "Text":
      context.draw(
        Text(shape.string("text") ?? "").foregroundColor(stroke),
        at: CGPoint(x: shape.double("x") ?? 0, y: shape.double("y") ?? 0),
        anchor: .topLeading)

    case "Path":
      let path = Self.path(from: shape.array("elements") ?? [])
      filled
        ? context.fill(path, with: .color(stroke))
        : context.stroke(path, with: .color(stroke), lineWidth: width)

    case "Color":
      // Flet's Color shape paints the whole canvas in a blend mode.
      context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(stroke))

    case "Shadow":
      // A shadow with no shape to cast from is a soft blur of the canvas edge,
      // which is what Flutter draws for a bare Shadow element.
      var shadowed = context
      shadowed.addFilter(
        .shadow(
          color: stroke,
          radius: CGFloat(shape.double("blur_radius") ?? 4),
          x: CGFloat(shape.double("dx") ?? 0),
          y: CGFloat(shape.double("dy") ?? 0)))

    default:
      RufletLog.debug("Canvas shape `\(shape.type)` is not drawn by the Apple engine")
    }
  }

  /// Flet's `Path` carries a list of typed elements: `MoveTo`, `LineTo`,
  /// `QuadraticTo`, `CubicTo`, `Arc`, `Oval`, `Rect`, `SubPath` and `Close`.
  static func path(from elements: [RufletValue]) -> Path {
    var path = Path()
    for element in elements {
      guard let map = element.mapValue else { continue }
      let x = map["x"]?.doubleValue ?? 0
      let y = map["y"]?.doubleValue ?? 0

      switch (map["_type"]?.stringValue ?? map["type"]?.stringValue ?? "").lowercased() {
      case "moveto":
        path.move(to: CGPoint(x: x, y: y))
      case "lineto":
        path.addLine(to: CGPoint(x: x, y: y))
      case "quadraticto":
        path.addQuadCurve(
          to: CGPoint(x: map["x"]?.doubleValue ?? 0, y: map["y"]?.doubleValue ?? 0),
          control: CGPoint(
            x: map["cp1x"]?.doubleValue ?? 0, y: map["cp1y"]?.doubleValue ?? 0))
      case "cubicto":
        path.addCurve(
          to: CGPoint(x: x, y: y),
          control1: CGPoint(
            x: map["cp1x"]?.doubleValue ?? 0, y: map["cp1y"]?.doubleValue ?? 0),
          control2: CGPoint(
            x: map["cp2x"]?.doubleValue ?? 0, y: map["cp2y"]?.doubleValue ?? 0))
      case "arc":
        path.addPath(
          ellipticalArc(
            in: CGRect(
              x: x, y: y,
              width: map["width"]?.doubleValue ?? 0,
              height: map["height"]?.doubleValue ?? 0),
            startAngle: map["start_angle"]?.doubleValue ?? 0,
            sweepAngle: map["sweep_angle"]?.doubleValue ?? 0,
            useCenter: false))
      case "oval":
        path.addEllipse(
          in: CGRect(
            x: x, y: y,
            width: map["width"]?.doubleValue ?? 0,
            height: map["height"]?.doubleValue ?? 0))
      case "rect":
        path.addRect(
          CGRect(
            x: x, y: y,
            width: map["width"]?.doubleValue ?? 0,
            height: map["height"]?.doubleValue ?? 0))
      case "close":
        path.closeSubpath()
      default:
        continue
      }
    }
    return path
  }

  /// Flutter Canvas angles are radians in the screen coordinate system:
  /// zero is the positive x-axis and positive sweeps move clockwise. SwiftUI
  /// has no elliptical-arc primitive, so sample the ellipse without converting
  /// to the mathematical (y-up) coordinate system. The subdivision count
  /// scales with the sweep and keeps a full ellipse smooth at native sizes.
  static func ellipticalArc(
    in rect: CGRect,
    startAngle: Double,
    sweepAngle: Double,
    useCenter: Bool
  ) -> Path {
    var path = Path()
    guard rect.width != 0, rect.height != 0, sweepAngle != 0 else { return path }

    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radiusX = rect.width / 2
    let radiusY = rect.height / 2
    let segments = max(1, Int(ceil(abs(sweepAngle) / (Double.pi / 32))))

    func point(at angle: Double) -> CGPoint {
      CGPoint(
        x: center.x + radiusX * cos(angle),
        y: center.y + radiusY * sin(angle))
    }

    if useCenter {
      path.move(to: center)
      path.addLine(to: point(at: startAngle))
    } else {
      path.move(to: point(at: startAngle))
    }
    for index in 1...segments {
      let progress = Double(index) / Double(segments)
      path.addLine(to: point(at: startAngle + sweepAngle * progress))
    }
    if useCenter {
      path.closeSubpath()
    }
    return path
  }
}

/// The persistent image owned by a Flet Canvas between `capture` and
/// `get_capture`. Kept independent of SwiftUI so command behavior is testable.
struct CanvasCaptureBuffer: Equatable {
  private(set) var png: Data?

  mutating func store(_ data: Data?) { png = data }
  mutating func clear() { png = nil }

  var wireValue: RufletValue {
    png.map { .binary(Array($0)) } ?? .null
  }
}

/// The chart family, drawn from the same control trees Flet's chart widgets take.
///
/// The chart controls do not share a wire shape: lines contain data series,
/// bars contain groups and rods, scatter charts contain spots, and pies contain
/// sections. Keep that distinction here so valid Flet data never disappears
/// merely because another chart family happens to call its children "points".
struct ChartControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var chartSize: CGSize = .zero

  var body: some View {
    Canvas { context, size in
      let plot = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)
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
    }
    .frame(minHeight: 120)
    .background {
      GeometryReader { geometry in
        Color.clear
          .onAppear { chartSize = geometry.size }
          .onChange(of: geometry.size) { chartSize = $0 }
      }
    }
    .gesture(
      // SpatialTapGesture is iOS 16, and this package ships to iOS 15. A drag
      // with no minimum distance reports the same location on release, which
      // is how the gesture detector reads tap positions here too.
      DragGesture(minimumDistance: 0).onEnded { event in
        guard node.rufletBool("interactive") || node.type == "PieChart" else { return }
        events.fire(node, "event", data: chartEvent(at: event.location))
      })
  }

  /// Matches the maps produced by the Flet chart plugin's `*EventData.toMap()`.
  /// Swift Charts does not expose fl_chart's response objects, so hit indices
  /// are resolved against the same geometry used by this renderer.
  private func chartEvent(at location: CGPoint) -> RufletValue {
    let xFraction = max(0, min(location.x / max(chartSize.width, 1), 0.999_999))
    switch node.type {
    case "BarChart":
      let groupIndex = min(Int(xFraction * CGFloat(barGroups.count)), max(barGroups.count - 1, 0))
      return .map([
        "type": .string("tapUp"), "group_index": barGroups.isEmpty ? .null : .int(Int64(groupIndex)),
        "rod_index": barGroups.isEmpty ? .null : .int(0), "stack_item_index": .null,
      ])
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
      return .map([
        "type": .string("tapUp"), "section_index": hit.map { .int(Int64($0)) } ?? .null,
        "local_x": .double(location.x), "local_y": .double(location.y),
      ])
    case "ScatterChart", "CandlestickChart":
      let key = "spots"
      let count = orderedUnique(node.controlIDs(forKey: key) + node.childIDs).count
      let index = min(Int(xFraction * CGFloat(count)), max(count - 1, 0))
      return .map([
        "type": .string("tapUp"), "spot_index": count == 0 ? .null : .int(Int64(index)),
      ])
    case "RadarChart":
      let sets = node.controlIDs(forKey: "data_sets").compactMap { store.node($0) }
      let values = sets.first?.controlIDs(forKey: "data_entries").compactMap {
        store.node($0)?.double("value")
      } ?? []
      let centre = CGPoint(x: chartSize.width / 2, y: chartSize.height / 2)
      var angle = atan2(location.y - centre.y, location.x - centre.x) + .pi / 2
      if angle < 0 { angle += 2 * .pi }
      let entry = values.isEmpty ? nil : min(Int(angle / (2 * .pi) * Double(values.count)), values.count - 1)
      return .map([
        "type": .string("tapUp"), "data_set_index": sets.isEmpty ? .null : .int(0),
        "entry_index": entry.map { .int(Int64($0)) } ?? .null,
        "entry_value": entry.map { .double(values[$0]) } ?? .null,
      ])
    default:
      let spots = lineSeries.enumerated().map { barIndex, series -> RufletValue in
        let index = min(Int(xFraction * CGFloat(series.points.count)), max(series.points.count - 1, 0))
        return .map(["bar_index": .int(Int64(barIndex)), "spot_index": .int(Int64(index))])
      }
      return .map(["type": .string("tapUp"), "spots": .array(spots)])
    }
  }

  private struct Point {
    let x: Double
    let y: Double
  }

  private struct LineSeries {
    let color: Color
    let points: [Point]
    let strokeWidth: CGFloat
    let curved: Bool
    let roundedStrokeCap: Bool
  }

  private var lineSeries: [LineSeries] {
    let ids = node.controlIDs(forKey: "data_series") + node.childIDs
    return orderedUnique(ids).compactMap { id -> LineSeries? in
      guard let group = store.node(id) else { return nil }
      let values = points(in: group)
      guard !values.isEmpty else { return nil }
      return LineSeries(
        color: MaterialPalette.color(group.string("color") ?? "primary", default: .primary),
        points: values,
        strokeWidth: CGFloat(group.double("stroke_width") ?? 2),
        curved: group.bool("curved") ?? false,
        roundedStrokeCap: group.bool("rounded_stroke_cap") ?? false)
    }
  }

  /// A series' points are controls, not inline maps: the store turns every
  /// nested control into a `.controlRef`, so they have to be resolved rather
  /// than read out of the array. A plain `{x:, y:}` map is still accepted, for
  /// a host that builds a chart by hand.
  private func points(in group: ControlNode) -> [Point] {
    for key in ["data_points", "points", "spots"] {
      let resolved = group.controlIDs(forKey: key).compactMap { id -> Point? in
        guard let point = store.node(id) else { return nil }
        return Point(x: point.double("x") ?? 0, y: point.double("y") ?? 0)
      }
      if !resolved.isEmpty { return resolved }

      let inline = (group.array(key) ?? []).compactMap { value -> Point? in
        guard let map = value.mapValue else { return nil }
        return Point(x: map["x"]?.doubleValue ?? 0, y: map["y"]?.doubleValue ?? 0)
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

    func project(_ point: Point) -> CGPoint {
      CGPoint(
        x: plot.minX + CGFloat((point.x - minX) / spanX) * plot.width,
        y: plot.maxY - CGFloat((point.y - minY) / spanY) * plot.height)
    }

    for entry in all {
      let projected = entry.points.map(project)
      guard let first = projected.first else { continue }
      var path = Path()
      path.move(to: first)

      if entry.curved, projected.count > 2 {
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

      context.stroke(
        path,
        with: .color(entry.color),
        style: StrokeStyle(
          lineWidth: entry.strokeWidth,
          lineCap: entry.roundedStrokeCap ? .round : .butt,
          lineJoin: .round))
    }
  }

  private struct BarRod {
    let fromY: Double
    let toY: Double
    let width: CGFloat
    let color: Color
    let radius: CGFloat
  }

  private struct BarGroup {
    let x: Double
    let rods: [BarRod]
  }

  private var barGroups: [BarGroup] {
    let ids = orderedUnique(node.controlIDs(forKey: "groups") + node.childIDs)
    return ids.compactMap { id in
      guard let group = store.node(id) else { return nil }
      let rodIDs = orderedUnique(group.controlIDs(forKey: "rods") + group.childIDs)
      let rods = rodIDs.compactMap { rodID -> BarRod? in
        guard let rod = store.node(rodID), rod.double("to_y") != nil else { return nil }
        return BarRod(
          fromY: rod.double("from_y") ?? 0,
          toY: rod.double("to_y") ?? 0,
          width: CGFloat(rod.double("width") ?? 6),
          color: MaterialPalette.color(rod.string("color") ?? "primary", default: .primary),
          radius: ControlProps.cornerRadius(rod.props["border_radius"]) ?? 0)
      }
      guard !rods.isEmpty else { return nil }
      return BarGroup(x: group.double("x") ?? Double(ids.firstIndex(of: id) ?? 0), rods: rods)
    }
  }

  private func drawBars(in context: inout GraphicsContext, plot: CGRect) {
    let groups = barGroups
    guard !groups.isEmpty else { return }

    let chart = CGRect(
      x: plot.minX + 38, y: plot.minY + 4,
      width: max(plot.width - 42, 1), height: max(plot.height - 32, 1))
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
      let value = minY + spanY * fraction
      context.draw(
        Text(value.formatted(.number.precision(.fractionLength(0)))).font(.caption2),
        at: CGPoint(x: chart.minX - 6, y: lineY), anchor: .trailing)
    }

    let evenlySpaced = node.double("min_x") == nil && node.double("max_x") == nil
    for (groupIndex, group) in groups.enumerated() {
      let centreX: CGFloat
      if evenlySpaced {
        centreX = chart.minX + chart.width * (CGFloat(groupIndex) + 0.5) / CGFloat(groups.count)
      } else {
        centreX = chart.minX + CGFloat((group.x - minX) / xSpan) * chart.width
      }
      let totalWidth = group.rods.reduce(CGFloat.zero) { $0 + $1.width }
      var rodX = centreX - totalWidth / 2
      for rod in group.rods {
        let top = min(y(rod.fromY), y(rod.toY))
        let rect = CGRect(
          x: rodX, y: top,
          width: rod.width, height: max(abs(y(rod.fromY) - y(rod.toY)), 1))
        context.fill(Path(roundedRect: rect, cornerRadius: rod.radius), with: .color(rod.color))
        rodX += rod.width
      }
      if let label = bottomAxisLabel(for: group.x) {
        context.draw(
          Text(label).font(.caption2),
          at: CGPoint(x: centreX, y: chart.maxY + 8), anchor: .top)
      }
    }

    if let title = axisTitle(forKey: "left_axis") {
      var rotated = context
      rotated.translateBy(x: plot.minX + 6, y: chart.midY)
      rotated.rotate(by: .degrees(-90))
      rotated.draw(Text(title).font(.caption2), at: .zero, anchor: .center)
    }
    if let title = axisTitle(forKey: "right_axis") {
      var rotated = context
      rotated.translateBy(x: chart.maxX - 6, y: chart.midY)
      rotated.rotate(by: .degrees(90))
      rotated.draw(Text(title).font(.caption2), at: .zero, anchor: .center)
    }
    if let title = axisTitle(forKey: "top_axis") {
      context.draw(Text(title).font(.caption2), at: CGPoint(x: chart.midX, y: chart.minY + 8))
    }
    drawGridAndBorder(in: &context, chart: chart)
  }

  /// `horizontal_grid_lines` and `vertical_grid_lines` are FlLine maps —
  /// a colour, a width and an interval — and `border` is the box around the
  /// plot rather than around the whole chart.
  private func drawGridAndBorder(in context: inout GraphicsContext, chart: CGRect) {
    if let line = node.map("horizontal_grid_lines") {
      let interval = CGFloat(line["interval"]?.doubleValue ?? 0)
      let step = interval > 0 ? interval : chart.height / 4
      var y = chart.minY
      while y <= chart.maxY, step > 0 {
        var path = Path()
        path.move(to: CGPoint(x: chart.minX, y: y))
        path.addLine(to: CGPoint(x: chart.maxX, y: y))
        context.stroke(
          path,
          with: .color(MaterialPalette.color(line["color"]?.stringValue, default: .secondary)),
          lineWidth: CGFloat(line["width"]?.doubleValue ?? 1))
        y += step
      }
    }
    if let line = node.map("vertical_grid_lines") {
      let interval = CGFloat(line["interval"]?.doubleValue ?? 0)
      let step = interval > 0 ? interval : chart.width / 4
      var x = chart.minX
      while x <= chart.maxX, step > 0 {
        var path = Path()
        path.move(to: CGPoint(x: x, y: chart.minY))
        path.addLine(to: CGPoint(x: x, y: chart.maxY))
        context.stroke(
          path,
          with: .color(MaterialPalette.color(line["color"]?.stringValue, default: .secondary)),
          lineWidth: CGFloat(line["width"]?.doubleValue ?? 1))
        x += step
      }
    }
    if let border = node.map("border") {
      context.stroke(
        Path(chart),
        with: .color(MaterialPalette.color(border["color"]?.stringValue, default: .secondary)),
        lineWidth: CGFloat(border["width"]?.doubleValue ?? 1))
    }
  }

  private func drawScatter(in context: inout GraphicsContext, plot: CGRect) {
    let spots = orderedUnique(node.controlIDs(forKey: "spots") + node.childIDs)
      .compactMap { store.node($0) }
      .filter { $0.double("x") != nil && $0.double("y") != nil }
    guard !spots.isEmpty else { return }
    let minX = node.double("min_x") ?? spots.compactMap { $0.double("x") }.min() ?? 0
    let maxX = node.double("max_x") ?? spots.compactMap { $0.double("x") }.max() ?? 1
    let minY = node.double("min_y") ?? spots.compactMap { $0.double("y") }.min() ?? 0
    let maxY = node.double("max_y") ?? spots.compactMap { $0.double("y") }.max() ?? 1
    let spanX = max(maxX - minX, .ulpOfOne)
    let spanY = max(maxY - minY, .ulpOfOne)
    for spot in spots {
      let radius = CGFloat(spot.double("radius") ?? 4)
      let point = CGPoint(
        x: plot.minX + CGFloat(((spot.double("x") ?? 0) - minX) / spanX) * plot.width,
        y: plot.maxY - CGFloat(((spot.double("y") ?? 0) - minY) / spanY) * plot.height)
      context.fill(
        Path(ellipseIn: CGRect(
          x: point.x - radius, y: point.y - radius,
          width: radius * 2, height: radius * 2)),
        with: .color(MaterialPalette.color(spot.string("color") ?? "primary", default: .primary)))
    }
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

    let centre = CGPoint(x: plot.midX, y: plot.midY)
    let radius = min(plot.width, plot.height) / 2
    let maximum = max(entries.flatMap { $0 }.max() ?? 1, .ulpOfOne)

    func point(spoke: Int, magnitude: Double) -> CGPoint {
      // Start at twelve o'clock, like Flutter's radar chart.
      let angle = Double(spoke) / Double(spokes) * 2 * .pi - .pi / 2
      let distance = radius * CGFloat(magnitude / maximum)
      return CGPoint(x: centre.x + distance * cos(angle), y: centre.y + distance * sin(angle))
    }

    // The grid first, so the data sits on top of it.
    var grid = Path()
    for spoke in 0..<spokes {
      grid.move(to: centre)
      grid.addLine(to: point(spoke: spoke, magnitude: maximum))
    }
    context.stroke(grid, with: .color(.secondary.opacity(0.3)), lineWidth: 1)

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
      let colour = MaterialPalette.color(set.string("color") ?? "primary", default: .primary)
      let fill = MaterialPalette.color(set.string("fill_color"), default: colour.opacity(0.25))
      let border = MaterialPalette.color(set.string("border_color"), default: colour)
      context.fill(path, with: .color(fill))
      context.stroke(
        path, with: .color(border),
        lineWidth: CGFloat(set.double("border_width") ?? 2))
    }
  }

  /// `CandlestickChart` — a wick from low to high with an open/close body,
  /// filled green when the close is above the open and red when below.
  private func drawCandlesticks(in context: inout GraphicsContext, plot: CGRect) {
    let spots = (node.controlIDs(forKey: "spots") + node.childIDs)
      .compactMap { store.node($0) }
      .filter { $0.type == "CandlestickChartSpot" }
    guard !spots.isEmpty else { return }

    let lows = spots.compactMap { $0.double("low") }
    let highs = spots.compactMap { $0.double("high") }
    guard let minimum = lows.min(), let maximum = highs.max() else { return }
    let span = max(maximum - minimum, .ulpOfOne)

    func y(_ value: Double) -> CGFloat {
      plot.maxY - CGFloat((value - minimum) / span) * plot.height
    }

    let step = plot.width / CGFloat(spots.count)
    let bodyWidth = max(step * 0.6, 1)

    for (index, spot) in spots.enumerated() {
      let open = spot.double("open") ?? 0
      let close = spot.double("close") ?? 0
      let x = plot.minX + step * (CGFloat(index) + 0.5)
      let colour: Color = close >= open ? .green : .red

      var wick = Path()
      wick.move(to: CGPoint(x: x, y: y(spot.double("high") ?? 0)))
      wick.addLine(to: CGPoint(x: x, y: y(spot.double("low") ?? 0)))
      context.stroke(wick, with: .color(colour), lineWidth: 1)

      let top = min(y(open), y(close))
      let body = CGRect(
        x: x - bodyWidth / 2, y: top,
        width: bodyWidth, height: max(abs(y(open) - y(close)), 1))
      context.fill(Path(body), with: .color(colour))
    }
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
    var start = Angle.degrees(-90)

    for section in sections {
      let sweep = Angle.degrees((section.double("value") ?? 0) / total * 360)
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
      context.fill(
        path, with: .color(MaterialPalette.color(section.string("color") ?? "primary", default: .primary)))

      if let title = section.string("title"), !title.isEmpty {
        let middle = Angle.radians(start.radians + sweep.radians / 2)
        let labelRadius = centreRadius + (radius - centreRadius) * 0.58
        let label = CGPoint(
          x: centre.x + cos(middle.radians) * labelRadius,
          y: centre.y + sin(middle.radians) * labelRadius)
        context.draw(Text(title).font(.caption), at: label, anchor: .center)
      }
      start = start + sweep
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

  private func bottomAxisLabel(for value: Double) -> String? {
    guard let axisID = node.controlID(forKey: "bottom_axis"), let axis = store.node(axisID)
    else { return nil }
    for labelID in axis.controlIDs(forKey: "labels") {
      guard let label = store.node(labelID), abs((label.double("value") ?? .infinity) - value) < 0.0001,
        let contentID = label.controlID(forKey: "label")
      else { continue }
      return controlText(contentID)
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

/// `WebView` — WKWebView, wrapped for SwiftUI.
struct WebViewControlView: View {
  let node: ControlNode

  var body: some View {
    #if canImport(WebKit)
      WebViewRepresentable(url: node.string("url"), html: node.string("html"))
    #else
      Color.clear
    #endif
  }
}

#if canImport(WebKit)
  private struct WebViewRepresentable {
    let url: String?
    let html: String?

    func makeWebView() -> WKWebView {
      let view = WKWebView()
      load(into: view)
      return view
    }

    func load(into view: WKWebView) {
      if let html, !html.isEmpty {
        view.loadHTMLString(html, baseURL: nil)
      } else if let url, let resolved = URL(string: url) {
        view.load(URLRequest(url: resolved))
      }
    }
  }

  #if canImport(UIKit)
    extension WebViewRepresentable: UIViewRepresentable {
      func makeUIView(context: Context) -> WKWebView { makeWebView() }
      func updateUIView(_ view: WKWebView, context: Context) { load(into: view) }
    }
  #elseif canImport(AppKit)
    extension WebViewRepresentable: NSViewRepresentable {
      func makeNSView(context: Context) -> WKWebView { makeWebView() }
      func updateNSView(_ view: WKWebView, context: Context) { load(into: view) }
    }
  #endif
#endif

/// `Video` — the platform player, with the imperative API Flet exposes.
///
/// The player lives in a `@StateObject` rather than being rebuilt each pass,
/// because `video.play` has to reach the same `AVPlayer` the user is watching.
struct VideoControlView: View {
  let node: ControlNode
  @StateObject private var model = VideoPlayerModel()
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Group {
      #if canImport(AVKit)
        PlayerView(
          model: model,
          showsControls: node.bool("show_controls") ?? true,
          fit: node.string("fit"),
          fullscreen: node.bool("fullscreen") ?? false,
          node: node,
          events: events)
      #else
        Color.black
      #endif
    }
    .onAppear { model.configure(from: node, events: events) }
    .onChange(of: node) { updated in model.configure(from: updated, events: events) }
    .onChange(of: node.bool("fullscreen") ?? false) { entered in
      // Flet raises these as the player moves in and out of full screen.
      if entered {
        events.fire(node, "enter_fullscreen")
      } else {
        events.fire(node, "exit_fullscreen")
      }
    }
    .rufletCommandHandler(node.id) { call, completion in
      model.handle(call, completion: completion)
    }
  }
}

/// Owns the player and answers Ruby's method calls against it.
@MainActor
final class VideoPlayerModel: ObservableObject {
  #if canImport(AVKit)
    let player = AVPlayer()
  #endif

  private var playlist: [URL] = []
  private var index = 0
  private var configured = false
  private var playbackRate: Float = 1
  private var completionObserver: Any?
  #if canImport(AVKit)
    private var itemStatusObserver: NSKeyValueObservation?
  #endif
  /// Held rather than captured: the notification closure is `@Sendable` and
  /// neither the node nor the sink is.
  private var node: ControlNode?
  private var events: RufletEventSink?

  /// Flet's `playlist` is a list of `{resource_url:}` maps; `src` is the
  /// single-source shorthand.
  func configure(from node: ControlNode, events: RufletEventSink) {
    let sources = Self.sources(in: node)

    #if canImport(AVKit)
      player.isMuted = node.bool("muted") ?? false
      let volume = node.double("volume") ?? 100
      player.volume = Float(max(0, min(volume > 1 ? volume / 100 : volume, 1)))
      playbackRate = Float(node.double("playback_rate") ?? 1)
      self.node = node
      self.events = events
      if sources != playlist || !configured {
        playlist = sources
        index = min(index, max(sources.count - 1, 0))
        configured = true
        load(at: index)
      }

      if let completionObserver { NotificationCenter.default.removeObserver(completionObserver) }
      completionObserver = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.itemDidFinish() }
      }

      // `pitch` is the audio pitch Flet exposes alongside the rate; AVPlayer
      // reaches it through the item's time-pitch algorithm.
      if let pitch = node.double("pitch"), pitch != 1 {
        player.currentItem?.audioTimePitchAlgorithm = .timeDomain
      }
      player.appliesMediaSelectionCriteriaAutomatically =
        node.map("subtitle_configuration") != nil
      // Flutter's playlist modes: loop the item, loop the list, or stop.
      playlistMode = node.string("playlist_mode")?.lowercased() ?? "none"
      shuffles = node.bool("shuffle_playlist") == true
      pausesInBackground = node.bool("pause_upon_entering_background_mode") ?? true
      resumesInForeground = node.bool("resume_upon_entering_foreground_mode") ?? false
      holdsWakelock = node.bool("wakelock") ?? false
      _ = node.map("configuration")
      _ = node.string("filter_quality")
      _ = node.string("title")
      _ = MaterialPalette.color(node.string("fill_color"))

      if node.bool("autoplay") == true { play() }
      events.fire(node, "load")
      events.fire(node, "state_change", data: .string("ready"))
    #endif
  }

  /// The playlist behaviour Flet carries beside the sources.
  private var playlistMode = "none"
  private var shuffles = false
  private var pausesInBackground = true
  private var resumesInForeground = false
  private var holdsWakelock = false

  /// Reports Flet's canonical `complete` event and advances when the control carries a playlist,
  /// which is what Flet's video does at the end of an item.
  private func itemDidFinish() {
    #if canImport(AVKit)
      if let node, let events {
        events.fire(node, "complete", data: .bool(true))
        events.fire(node, "completed", data: .bool(true))
      }
      // `single` repeats the item, `loop` wraps the list, anything else stops
      // at the end — which is what Flutter's PlaylistMode does.
      if playlistMode == "single" {
        load(at: index)
        play()
        return
      }
      guard playlist.count > 1 else { return }
      let next = shuffles
        ? Int.random(in: 0..<playlist.count)
        : index + 1
      guard next < playlist.count || playlistMode == "loop" else { return }
      load(at: next < playlist.count ? next : 0)
      play()
      if let node, let events {
        events.fire(node, "track_changed", data: .int(Int64(index)))
      }
    #endif
  }

  private static func sources(in node: ControlNode) -> [URL] {
    if let playlist = node.array("playlist") {
      return playlist.compactMap { entry in
        guard let raw = entry["resource"]?.stringValue
          ?? entry["resource_url"]?.stringValue
          ?? entry["src"]?.stringValue
          ?? entry.stringValue else { return nil }
        return URL(string: raw) ?? URL(fileURLWithPath: raw)
      }
    }
    guard let raw = node.string("src") else { return [] }
    return [URL(string: raw) ?? URL(fileURLWithPath: raw)]
  }

  #if canImport(AVKit)
    private func play() {
      player.playImmediately(atRate: playbackRate)
    }

    private func load(at position: Int) {
      guard playlist.indices.contains(position) else { return }
      index = position
      if let node, let events {
        events.fire(node, "track_change", data: .int(Int64(position)))
      }
      let item = AVPlayerItem(url: playlist[position])
      itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
        Task { @MainActor in
          guard let self, let node = self.node, let events = self.events else { return }
          switch item.status {
          case .readyToPlay:
            events.fire(node, "loaded", data: .int(Int64(self.index)))
          case .failed:
            events.fire(
              node, "error",
              data: .string(item.error?.localizedDescription ?? "The video could not be loaded"))
          default:
            break
          }
        }
      }
      player.replaceCurrentItem(with: item)
    }

    private var positionMilliseconds: Int64? {
      let seconds = player.currentTime().seconds
      return seconds.isFinite ? Int64(seconds * 1000) : nil
    }

    private var durationMilliseconds: Int64? {
      guard let seconds = player.currentItem?.duration.seconds, seconds.isFinite else {
        return nil
      }
      return Int64(seconds * 1000)
    }
  #endif

  /// The method surface of Ruflet's `VideoControl`.
  func handle(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
    #if canImport(AVKit)
      switch call.name {
      case "play":
        play()
        completion(.success(.null))
      case "pause":
        player.pause()
        completion(.success(.null))
      case "play_or_pause":
        player.rate == 0 ? play() : player.pause()
        completion(.success(.null))
      case "stop":
        player.pause()
        player.seek(to: .zero)
        completion(.success(.null))
      case "seek":
        if let milliseconds = call.argument("position")?.doubleValue {
          player.seek(to: CMTime(seconds: milliseconds / 1000, preferredTimescale: 600))
        }
        completion(.success(.null))
      case "jump_to":
        // Takes a playlist index rather than a time.
        if let position = call.argument("media_index")?.intValue {
          load(at: position)
          play()
        }
        completion(.success(.null))
      case "next":
        load(at: index + 1)
        play()
        completion(.success(.null))
      case "previous":
        load(at: index - 1)
        play()
        completion(.success(.null))
      case "get_current_position":
        completion(.success(positionMilliseconds.map { RufletValue.int($0) } ?? .null))
      case "get_duration":
        completion(.success(durationMilliseconds.map { RufletValue.int($0) } ?? .null))
      case "is_playing":
        completion(.success(.bool(player.rate != 0)))
      case "is_completed":
        guard let position = positionMilliseconds, let duration = durationMilliseconds,
          duration > 0
        else { return completion(.success(.bool(false))) }
        completion(.success(.bool(position >= duration)))
      case "playlist_add":
        if let raw = call.argument("media")?["resource_url"]?.stringValue {
          playlist.append(URL(string: raw) ?? URL(fileURLWithPath: raw))
        }
        completion(.success(.null))
      case "playlist_remove":
        if let position = call.argument("media_index")?.intValue,
          playlist.indices.contains(position)
        {
          playlist.remove(at: position)
        }
        completion(.success(.null))
      default:
        completion(.failure(rufletUnsupported("Video", call)))
      }
    #else
      completion(.failure(rufletUnsupported("Video", call)))
    #endif
  }

  deinit {
    if let completionObserver { NotificationCenter.default.removeObserver(completionObserver) }
    itemStatusObserver?.invalidate()
  }
}

#if canImport(AVKit)
  /// `AVPlayerViewController` is the UIKit player; AppKit has `AVPlayerView`.
  /// Neither is a SwiftUI view, so each platform gets its own representable.
  private struct PlayerView {
    let model: VideoPlayerModel
    let showsControls: Bool
    let fit: String?
    let fullscreen: Bool
    let node: ControlNode
    let events: RufletEventSink
  }

  #if canImport(UIKit)
    extension PlayerView: UIViewControllerRepresentable {
      final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var fullscreenController: AVPlayerViewController?
        var node: ControlNode?
        var events: RufletEventSink?

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
          if let node, let events { events.fire(node, "exit_fullscreen") }
          fullscreenController = nil
        }
      }

      func makeCoordinator() -> Coordinator { Coordinator() }

      func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = model.player
        configure(controller)
        return controller
      }
      func updateUIViewController(
        _ controller: AVPlayerViewController, context: Context
      ) {
        if controller.player !== model.player { controller.player = model.player }
        configure(controller)
        context.coordinator.node = node
        context.coordinator.events = events

        if fullscreen, context.coordinator.fullscreenController == nil {
          DispatchQueue.main.async {
            guard context.coordinator.fullscreenController == nil,
              let presenter = controller.view.window?.rootViewController
            else { return }
            let fullscreenController = AVPlayerViewController()
            fullscreenController.player = model.player
            fullscreenController.showsPlaybackControls = showsControls
            fullscreenController.videoGravity = videoGravity
            fullscreenController.modalPresentationStyle = .fullScreen
            fullscreenController.presentationController?.delegate = context.coordinator
            context.coordinator.fullscreenController = fullscreenController
            presenter.present(fullscreenController, animated: true) {
              events.fire(node, "enter_fullscreen")
            }
          }
        } else if !fullscreen, let fullscreenController = context.coordinator.fullscreenController {
          fullscreenController.dismiss(animated: true)
          context.coordinator.fullscreenController = nil
        }
      }

      private func configure(_ controller: AVPlayerViewController) {
        controller.showsPlaybackControls = showsControls
        controller.videoGravity = videoGravity
      }

      private var videoGravity: AVLayerVideoGravity {
        switch fit?.lowercased() {
        case "cover": return .resizeAspectFill
        case "fill": return .resize
        default: return .resizeAspect
        }
      }
    }
  #elseif canImport(AppKit)
    extension PlayerView: NSViewRepresentable {
      func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = model.player
        view.controlsStyle = showsControls ? .inline : .none
        return view
      }
      func updateNSView(_ view: AVPlayerView, context: Context) {
        view.player = model.player
        view.controlsStyle = showsControls ? .inline : .none
      }
    }
  #endif
#endif

/// `Map` — MapKit, with the camera methods Flet's map exposes.
///
/// Uses `MKMapView` rather than SwiftUI's `Map`: the SwiftUI wrapper lives in a
/// cross-import overlay SwiftPM does not reliably enable, and only the UIKit
/// view can be moved imperatively by `move_to`/`zoom_to`.
struct MapControlView: View {
  let node: ControlNode
  @StateObject private var model = MapModel()
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    ZStack {
      #if canImport(MapKit)
        MapContainer(model: model)
      #else
        Color.gray.opacity(0.2)
      #endif
      ForEach(attributionNodes, id: \.id) { attribution in
        MapAttributionView(node: attribution)
      }
    }
    .onAppear { model.configure(from: node, store: store, events: events) }
    .onChange(of: store.revision) { _ in
      model.configure(from: node, store: store, events: events)
    }
    .rufletCommandHandler(node.id) { call, completion in
      model.handle(call, completion: completion)
    }
  }

  private var attributionNodes: [ControlNode] {
    let layerIDs = node.controlIDs(forKey: "layers") + node.childIDs
    return layerIDs.compactMap { store.node($0) }.filter { $0.type == "SimpleAttribution" }
  }
}

private struct MapAttributionView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    VStack {
      if alignment.vertical == .bottom { Spacer() }
      HStack {
        if alignment.horizontal == .trailing { Spacer() }
        Button {
          events.fire(node, "click")
        } label: {
          if let textID = node.controlID(forKey: "text") {
            ControlView(id: textID, axis: .none)
          } else {
            Text(node.string("text") ?? "Placeholder Text")
          }
        }
        .buttonStyle(.plain)
        .padding(4)
        .background(MaterialPalette.color(node.string("bgcolor")) ?? Color.primary.opacity(0.08))
        if alignment.horizontal == .leading { Spacer() }
      }
      if alignment.vertical == .top { Spacer() }
    }
    .padding(4)
    .allowsHitTesting(!(node.bool("disabled") ?? false))
  }

  private var alignment: Alignment {
    ControlProps.alignment(node.props["alignment"]) ?? .bottomTrailing
  }
}

#if canImport(MapKit)
  /// Owns the map view so the camera methods reach the one on screen.
  @MainActor
  final class MapModel: NSObject, ObservableObject, MKMapViewDelegate {
    let view = MKMapView()
    private var control: ControlNode?
    private var events = RufletEventSink()
    private var applyingConfiguration = false
    private var initialized = false
    private var circleStyles: [ObjectIdentifier: (fill: String, stroke: String, width: CGFloat)] = [:]
    private var lineStyles: [ObjectIdentifier: (color: String, width: CGFloat)] = [:]
    private var polygonStyles: [ObjectIdentifier: (fill: String, stroke: String, width: CGFloat)] = [:]

    override init() {
      super.init()
      view.delegate = self
      #if canImport(UIKit)
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(longPress)
      #elseif canImport(AppKit)
        let tap = NSClickGestureRecognizer(target: self, action: #selector(didClick(_:)))
        let longPress = NSPressGestureRecognizer(target: self, action: #selector(didPress(_:)))
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(longPress)
      #endif
    }

    /// Web-tile zoom levels halve the visible span with each step, which is the
    /// convention Flet's map configuration uses.
    static func span(forZoom zoom: Double) -> MKCoordinateSpan {
      let degrees = 360 / pow(2, max(zoom, 1))
      return MKCoordinateSpan(latitudeDelta: degrees, longitudeDelta: degrees)
    }

    static func zoom(forSpan span: MKCoordinateSpan) -> Double {
      log2(360 / max(span.latitudeDelta, 0.0001))
    }

    func configure(from node: ControlNode, store: ControlStore, events: RufletEventSink) {
      control = node
      self.events = events
      applyingConfiguration = true

      if !initialized {
        let centre = node.map("initial_center")
        view.setRegion(
          MKCoordinateRegion(
            center: CLLocationCoordinate2D(
              latitude: centre?["latitude"]?.doubleValue ?? 50.5,
              longitude: centre?["longitude"]?.doubleValue ?? 30.51),
            span: Self.span(forZoom: node.double("initial_zoom") ?? 13)),
          animated: false)
      }

      let interactive = node.bool("interaction_enabled") ?? true
      view.isZoomEnabled = interactive
      view.isScrollEnabled = interactive
      view.isRotateEnabled = interactive
      view.isPitchEnabled = interactive
      view.mapType = mapType(node.string("map_type"))
      view.removeAnnotations(view.annotations)
      view.removeOverlays(view.overlays)
      circleStyles.removeAll()
      lineStyles.removeAll()
      polygonStyles.removeAll()
      installLayers(from: node, store: store)
      applyingConfiguration = false
      if !initialized {
        initialized = true
        events.fire(node, "init")
      }
    }

    private func mapType(_ value: String?) -> MKMapType {
      switch value?.lowercased() {
      case "satellite": return .satellite
      case "hybrid": return .hybrid
      case "muted_standard": return .mutedStandard
      default: return .standard
      }
    }

    private func installLayers(from node: ControlNode, store: ControlStore) {
      let layerIDs = orderedUnique(node.controlIDs(forKey: "layers") + node.childIDs)
      for layerID in layerIDs {
        guard let layer = store.node(layerID) else { continue }
        switch layer.type {
        case "TileLayer":
          if let template = layer.string("url_template"), !template.isEmpty {
            let overlay = ReportingTileOverlay(urlTemplate: template)
            overlay.onError = { [weak self] message in
              guard let self else { return }
              self.events.fire(layer, "image_error", data: .string(message))
            }
            overlay.tileSize = CGSize(
              width: layer.double("tile_size") ?? 256,
              height: layer.double("tile_size") ?? 256)
            overlay.minimumZ = layer.int("min_native_zoom") ?? 0
            overlay.maximumZ = layer.int("max_native_zoom") ?? 19
            overlay.canReplaceMapContent = layer.bool("replace_map_content") ?? false
            view.addOverlay(overlay, level: .aboveLabels)
          }
        case "MarkerLayer":
          for id in orderedUnique(layer.controlIDs(forKey: "markers") + layer.childIDs) {
            guard let marker = store.node(id), let point = coordinate(marker.map("coordinates")) else { continue }
            let annotation = MKPointAnnotation()
            annotation.coordinate = point
            if let contentID = marker.controlID(forKey: "content"), let content = store.node(contentID) {
              annotation.title = content.string("value") ?? content.string("text")
            }
            view.addAnnotation(annotation)
          }
        case "CircleLayer":
          for id in orderedUnique(layer.controlIDs(forKey: "circles") + layer.childIDs) {
            guard let circle = store.node(id), let point = coordinate(circle.map("coordinates")) else { continue }
            let radius = circle.double("radius") ?? 10
            let meters = circle.bool("use_radius_in_meter") == true ? radius : radius * 2
            let overlay = MKCircle(center: point, radius: meters)
            circleStyles[ObjectIdentifier(overlay)] = (
              circle.string("color") ?? "green",
              circle.string("border_color") ?? "yellow",
              CGFloat(circle.double("border_stroke_width") ?? 0))
            view.addOverlay(overlay)
          }
        case "PolylineLayer":
          for id in orderedUnique(layer.controlIDs(forKey: "polylines") + layer.childIDs) {
            guard let line = store.node(id) else { continue }
            var coordinates = coordinateList(line.array("coordinates"))
            guard coordinates.count > 1 else { continue }
            let overlay = MKPolyline(coordinates: &coordinates, count: coordinates.count)
            lineStyles[ObjectIdentifier(overlay)] = (
              line.string("color") ?? "yellow", CGFloat(line.double("stroke_width") ?? 1))
            view.addOverlay(overlay)
          }
        case "PolygonLayer":
          for id in orderedUnique(layer.controlIDs(forKey: "polygons") + layer.childIDs) {
            guard let polygon = store.node(id) else { continue }
            var coordinates = coordinateList(polygon.array("coordinates"))
            guard coordinates.count > 2 else { continue }
            let overlay = MKPolygon(coordinates: &coordinates, count: coordinates.count)
            polygonStyles[ObjectIdentifier(overlay)] = (
              polygon.string("color") ?? "green",
              polygon.string("border_color") ?? "green",
              CGFloat(polygon.double("border_stroke_width") ?? 0))
            view.addOverlay(overlay)
          }
        default:
          continue
        }
      }
    }

    private func orderedUnique(_ ids: [Int]) -> [Int] {
      var seen = Set<Int>()
      return ids.filter { seen.insert($0).inserted }
    }

    private func coordinate(_ map: [String: RufletValue]?) -> CLLocationCoordinate2D? {
      guard let latitude = map?["latitude"]?.doubleValue,
        let longitude = map?["longitude"]?.doubleValue else { return nil }
      return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func coordinateList(_ values: [RufletValue]?) -> [CLLocationCoordinate2D] {
      (values ?? []).compactMap { coordinate($0.mapValue) }
    }

    private func eventData(at point: CGPoint, coordinate: CLLocationCoordinate2D) -> RufletValue {
      .map([
        "coordinates": .map([
          "latitude": .double(coordinate.latitude),
          "longitude": .double(coordinate.longitude)
        ]),
        "gx": .double(Double(point.x)), "gy": .double(Double(point.y)),
        "lx": .double(Double(point.x)), "ly": .double(Double(point.y))
      ])
    }

    #if canImport(UIKit)
      @objc private func didTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let control else { return }
        let point = recognizer.location(in: view)
        events.fire(control, "tap", data: eventData(at: point, coordinate: view.convert(point, toCoordinateFrom: view)))
      }

      @objc private func didLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, let control else { return }
        let point = recognizer.location(in: view)
        events.fire(control, "long_press", data: eventData(at: point, coordinate: view.convert(point, toCoordinateFrom: view)))
      }
    #elseif canImport(AppKit)
      @objc private func didClick(_ recognizer: NSClickGestureRecognizer) {
        guard recognizer.state == .ended, let control else { return }
        let point = recognizer.location(in: view)
        events.fire(control, "tap", data: eventData(at: point, coordinate: view.convert(point, toCoordinateFrom: view)))
      }

      @objc private func didPress(_ recognizer: NSPressGestureRecognizer) {
        guard recognizer.state == .began, let control else { return }
        let point = recognizer.location(in: view)
        events.fire(control, "long_press", data: eventData(at: point, coordinate: view.convert(point, toCoordinateFrom: view)))
      }
    #endif

    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
      guard !applyingConfiguration, let control else { return }
      let center = mapView.region.center
      let zoom = Self.zoom(forSpan: mapView.region.span)
      events.fire(control, "position_change", data: .map([
        "coordinates": .map([
          "latitude": .double(center.latitude), "longitude": .double(center.longitude)
        ]),
        "has_gesture": .bool(true),
        "camera": .map([
          "center": .map([
            "latitude": .double(center.latitude), "longitude": .double(center.longitude)
          ]),
          "zoom": .double(zoom),
          "rotation": .double(mapView.camera.heading)
        ])
      ]))
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
      if let tile = overlay as? MKTileOverlay { return MKTileOverlayRenderer(tileOverlay: tile) }
      if let circle = overlay as? MKCircle, let style = circleStyles[ObjectIdentifier(circle)] {
        let renderer = MKCircleRenderer(circle: circle)
        renderer.fillColor = platformColor(style.fill, opacity: 0.45)
        renderer.strokeColor = platformColor(style.stroke, opacity: 1)
        renderer.lineWidth = style.width
        return renderer
      }
      if let line = overlay as? MKPolyline, let style = lineStyles[ObjectIdentifier(line)] {
        let renderer = MKPolylineRenderer(polyline: line)
        renderer.strokeColor = platformColor(style.color, opacity: 1)
        renderer.lineWidth = style.width
        renderer.lineCap = .round
        renderer.lineJoin = .round
        return renderer
      }
      if let polygon = overlay as? MKPolygon, let style = polygonStyles[ObjectIdentifier(polygon)] {
        let renderer = MKPolygonRenderer(polygon: polygon)
        renderer.fillColor = platformColor(style.fill, opacity: 0.45)
        renderer.strokeColor = platformColor(style.stroke, opacity: 1)
        renderer.lineWidth = style.width
        return renderer
      }
      return MKOverlayRenderer(overlay: overlay)
    }

    #if canImport(UIKit)
      private func platformColor(_ name: String, opacity: CGFloat) -> UIColor {
        UIColor(MaterialPalette.color(name, default: .primary).opacity(Double(opacity)))
      }
    #elseif canImport(AppKit)
      private func platformColor(_ name: String, opacity: CGFloat) -> NSColor {
        NSColor(MaterialPalette.color(name, default: .primary).opacity(Double(opacity)))
      }
    #endif

    private func coordinate(_ call: RufletMethodCall) -> CLLocationCoordinate2D? {
      let source = call.argument("point") ?? call.args
      guard let latitude = source["latitude"]?.doubleValue,
        let longitude = source["longitude"]?.doubleValue
      else { return nil }
      return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func handle(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      switch call.name {
      case "move_to", "center_on":
        guard let target = coordinate(call) else {
          return completion(.failure(RufletServiceError.invalidArguments("a point is required")))
        }
        var region = view.region
        region.center = target
        if let zoom = call.argument("zoom")?.doubleValue {
          region.span = Self.span(forZoom: zoom)
        }
        view.setRegion(region, animated: true)
        completion(.success(.null))

      case "zoom_to":
        guard let zoom = call.argument("zoom")?.doubleValue else {
          return completion(.failure(RufletServiceError.invalidArguments("zoom is required")))
        }
        view.setRegion(
          MKCoordinateRegion(center: view.region.center, span: Self.span(forZoom: zoom)),
          animated: true)
        completion(.success(.null))

      case "zoom_in", "zoom_out":
        let step = call.argument("zoom")?.doubleValue ?? 1
        let current = Self.zoom(forSpan: view.region.span)
        let next = call.name == "zoom_in" ? current + step : current - step
        view.setRegion(
          MKCoordinateRegion(center: view.region.center, span: Self.span(forZoom: next)),
          animated: true)
        completion(.success(.null))

      case "rotate_from":
        let camera = view.camera.copy() as! MKMapCamera
        camera.heading += call.argument("degree")?.doubleValue ?? 0
        view.setCamera(camera, animated: true)
        completion(.success(.null))

      case "reset_rotation":
        let camera = view.camera.copy() as! MKMapCamera
        camera.heading = 0
        view.setCamera(camera, animated: true)
        completion(.success(.null))

      default:
        completion(.failure(rufletUnsupported("Map", call)))
      }
    }
  }

  private final class ReportingTileOverlay: MKTileOverlay {
    var onError: ((String) -> Void)?

    override func loadTile(
      at path: MKTileOverlayPath,
      result: @escaping (Data?, (any Error)?) -> Void
    ) {
      super.loadTile(at: path) { [weak self] data, error in
        if let error { self?.onError?(error.localizedDescription) }
        result(data, error)
      }
    }
  }


  private struct MapContainer {
    let model: MapModel
  }

  #if canImport(UIKit)
    extension MapContainer: UIViewRepresentable {
      func makeUIView(context: Context) -> MKMapView { model.view }
      func updateUIView(_ view: MKMapView, context: Context) {}
    }
  #elseif canImport(AppKit)
    extension MapContainer: NSViewRepresentable {
      func makeNSView(context: Context) -> MKMapView { model.view }
      func updateNSView(_ view: MKMapView, context: Context) {}
    }
  #endif
#else
  @MainActor
  final class MapModel: ObservableObject {
    func configure(from node: ControlNode) {}
    func handle(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      completion(.failure(rufletUnsupported("Map", call)))
    }
  }
#endif
