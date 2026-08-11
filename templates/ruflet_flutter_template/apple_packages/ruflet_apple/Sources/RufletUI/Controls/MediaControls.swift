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
  @State private var lastResizeReport = Date.distantPast
  @State private var capture = CanvasCaptureBuffer()
  @Environment(\.displayScale) private var displayScale

  private var shapeIDs: [Int] {
    orderedUnique(node.controlIDs(forKey: "shapes") + node.childIDs)
  }

  var body: some View {
    ZStack {
      Canvas { context, size in
        for shapeID in shapeIDs {
          guard let shape = store.node(shapeID) else { continue }
          draw(shape, in: &context, size: size)
        }
      } symbols: {
        canvasImageSymbols
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
    // `resize_interval` throttles the stream the way Flet throttles its own;
    // zero reports every change.
    let interval = TimeInterval(node.int("resize_interval") ?? 0) / 1_000
    guard Date().timeIntervalSince(lastResizeReport) >= interval else { return }
    lastResizeReport = Date()
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
      renderer.scale = call.argument("pixel_ratio")?.doubleValue ?? displayScale
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
      for shapeID in shapeIDs {
        guard let shape = store.node(shapeID) else { continue }
        draw(shape, in: &context, size: size)
      }
    } symbols: {
      canvasImageSymbols
    }
    .environmentObject(store)
  }

  @ViewBuilder
  private var canvasImageSymbols: some View {
    ForEach(shapeIDs, id: \.self) { shapeID in
      if let shape = store.node(shapeID), shape.type == "Image" {
        CanvasShapeImageView(node: shape)
          .tag(shapeID)
      }
    }
  }

  private func draw(_ shape: ControlNode, in context: inout GraphicsContext, size: CGSize) {
    let paint = CanvasPaint(shape.map("paint"))

    switch shape.type {
    case "Line":
      var path = Path()
      path.move(to: CGPoint(x: shape.double("x1") ?? 0, y: shape.double("y1") ?? 0))
      path.addLine(to: CGPoint(x: shape.double("x2") ?? 0, y: shape.double("y2") ?? 0))
      paint.stroke(path, in: &context)

    case "Rect":
      let rect = CGRect(
        x: shape.double("x") ?? 0, y: shape.double("y") ?? 0,
        width: shape.double("width") ?? 0, height: shape.double("height") ?? 0)
      let radii = ControlProps.cornerRadii(shape.props["border_radius"])
        ?? RufletCornerRadii(uniform: 0)
      let path = RufletRoundedRectangle(radii: radii).path(in: rect)
      paint.draw(path, in: &context)

    case "Circle":
      let radius = CGFloat(shape.double("radius") ?? 0)
      let rect = CGRect(
        x: (shape.double("x") ?? 0) - radius, y: (shape.double("y") ?? 0) - radius,
        width: radius * 2, height: radius * 2)
      let path = Path(ellipseIn: rect)
      paint.draw(path, in: &context)

    case "Oval":
      let rect = CGRect(
        x: shape.double("x") ?? 0, y: shape.double("y") ?? 0,
        width: shape.double("width") ?? 0, height: shape.double("height") ?? 0)
      let path = Path(ellipseIn: rect)
      paint.draw(path, in: &context)

    case "Arc":
      let rect = CGRect(
        x: shape.double("x") ?? 0, y: shape.double("y") ?? 0,
        width: shape.double("width") ?? 0, height: shape.double("height") ?? 0)
      let path = Self.ellipticalArc(
        in: rect,
        startAngle: shape.double("start_angle") ?? 0,
        sweepAngle: shape.double("sweep_angle") ?? 0,
        useCenter: shape.bool("use_center") ?? false)
      paint.draw(path, in: &context)

    case "Fill":
      paint.fill(Path(CGRect(origin: .zero, size: size)), in: &context)

    case "Points":
      // Flutter's PointMode: points draws a dot each, lines joins them in
      // pairs, and polygon runs one path through all of them.
      let mode = shape.string("point_mode")?.lowercased() ?? "points"
      let centres = (shape.array("points") ?? []).compactMap { point -> CGPoint? in
        guard let map = point.mapValue else { return nil }
        return CGPoint(x: map["x"]?.doubleValue ?? 0, y: map["y"]?.doubleValue ?? 0)
      }
      if mode == "lines" || mode == "polygon" {
        var path = Path()
        if mode == "polygon" {
          for (index, centre) in centres.enumerated() {
            index == 0 ? path.move(to: centre) : path.addLine(to: centre)
          }
        } else {
          for pair in stride(from: 0, to: centres.count - 1, by: 2) {
            path.move(to: centres[pair])
            path.addLine(to: centres[pair + 1])
          }
        }
        paint.stroke(path, in: &context)
        break
      }
      for centre in centres {
        let rect = CGRect(
          x: centre.x - paint.strokeWidth / 2, y: centre.y - paint.strokeWidth / 2,
          width: paint.strokeWidth, height: paint.strokeWidth)
        paint.fill(Path(ellipseIn: rect), in: &context)
      }

    case "Text":
      drawText(shape, in: &context)

    case "Path":
      let path = Self.path(from: shape.array("elements") ?? [])
      paint.draw(path, in: &context)

    case "Color":
      var colored = context
      colored.blendMode = CanvasPaint.blendMode(shape.string("blend_mode"))
      colored.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .color(MaterialPalette.color(shape.string("color"), default: .black)))

    case "Shadow":
      let path = Self.path(from: shape.array("path") ?? [])
      var shadowed = context
      shadowed.addFilter(
        .shadow(
          color: MaterialPalette.color(shape.string("color"), default: .black),
          radius: CGFloat(shape.double("elevation") ?? 0), x: 0, y: 0))
      shadowed.fill(path, with: .color(.black.opacity(shape.bool("transparent_occluder") == true ? 0.001 : 1)))

    case "Image":
      guard let symbol = context.resolveSymbol(id: shape.id) else { break }
      let width = CGFloat(shape.double("width") ?? symbol.size.width)
      let height = CGFloat(shape.double("height") ?? symbol.size.height)
      context.draw(
        symbol, in: CGRect(
          x: CGFloat(shape.double("x") ?? 0), y: CGFloat(shape.double("y") ?? 0),
          width: width, height: height))

    default:
      RufletLog.debug("Canvas shape `\(shape.type)` is not drawn by the Apple engine")
    }
  }

  private func drawText(_ shape: ControlNode, in context: inout GraphicsContext) {
    let style = shape.map("style") ?? [:]
    var text = Text(shape.string("value") ?? "")
      .foregroundColor(MaterialPalette.color(style["color"]?.stringValue, default: .primary))
    if let size = style["size"]?.doubleValue { text = text.font(.system(size: CGFloat(size))) }
    if style["weight"]?.stringValue?.lowercased().contains("bold") == true {
      text = text.fontWeight(.bold)
    }
    let alignment = ControlProps.continuousAlignment(shape.props["alignment"]) ?? .topLeft
    let anchor = UnitPoint(
      x: (alignment.x + 1) / 2,
      y: (alignment.y + 1) / 2)
    var transformed = context
    let point = CGPoint(x: shape.double("x") ?? 0, y: shape.double("y") ?? 0)
    transformed.translateBy(x: point.x, y: point.y)
    transformed.rotate(by: .radians(shape.double("rotate") ?? 0))
    transformed.draw(text, at: .zero, anchor: anchor)
  }

  private func orderedUnique(_ ids: [Int]) -> [Int] {
    var seen = Set<Int>()
    return ids.filter { seen.insert($0).inserted }
  }

  /// Flet's `Path` carries a list of typed elements: `MoveTo`, `LineTo`,
  /// `QuadraticTo`, `CubicTo`, `Arc`, `Oval`, `Rect`, `SubPath` and `Close`.
  static func path(from elements: [RufletValue]) -> Path {
    var path = Path()
    var current = CGPoint.zero
    var subpathStart = CGPoint.zero
    for element in elements {
      guard let map = element.mapValue else { continue }
      let x = map["x"]?.doubleValue ?? 0
      let y = map["y"]?.doubleValue ?? 0

      switch (map["_type"]?.stringValue ?? map["type"]?.stringValue ?? "").lowercased() {
      case "moveto":
        current = CGPoint(x: x, y: y)
        subpathStart = current
        path.move(to: current)
      case "lineto":
        current = CGPoint(x: x, y: y)
        path.addLine(to: current)
      case "quadraticto":
        let end = CGPoint(x: x, y: y)
        let control = CGPoint(
          x: map["cp1x"]?.doubleValue ?? 0, y: map["cp1y"]?.doubleValue ?? 0)
        let weight = map["w"]?.doubleValue ?? 1
        if abs(weight - 1) < .ulpOfOne {
          path.addQuadCurve(to: end, control: control)
        } else {
          // Flutter uses Path.conicTo. Sample the rational quadratic when the
          // conic weight differs from one; SwiftUI has no conic primitive.
          for step in 1...24 {
            let t = Double(step) / 24
            let mt = 1 - t
            let denominator = mt * mt + 2 * weight * mt * t + t * t
            path.addLine(to: CGPoint(
              x: (mt * mt * current.x + 2 * weight * mt * t * control.x + t * t * end.x)
                / denominator,
              y: (mt * mt * current.y + 2 * weight * mt * t * control.y + t * t * end.y)
                / denominator))
          }
        }
        current = end
      case "arcto":
        let end = CGPoint(x: x, y: y)
        addEndpointArc(
          to: &path, from: current, to: end,
          radius: CGFloat(map["radius"]?.doubleValue ?? 0),
          largeArc: map["large_arc"]?.boolValue ?? false,
          clockwise: map["clockwise"]?.boolValue ?? true)
        current = end
      case "cubicto":
        path.addCurve(
          to: CGPoint(x: x, y: y),
          control1: CGPoint(
            x: map["cp1x"]?.doubleValue ?? 0, y: map["cp1y"]?.doubleValue ?? 0),
          control2: CGPoint(
            x: map["cp2x"]?.doubleValue ?? 0, y: map["cp2y"]?.doubleValue ?? 0))
        current = CGPoint(x: x, y: y)
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
        let rect = CGRect(
          x: x, y: y,
          width: map["width"]?.doubleValue ?? 0,
          height: map["height"]?.doubleValue ?? 0)
        let radii = ControlProps.cornerRadii(map["border_radius"])
          ?? RufletCornerRadii(uniform: 0)
        path.addPath(RufletRoundedRectangle(radii: radii).path(in: rect))
      case "subpath":
        let nested = Self.path(from: map["elements"]?.arrayValue ?? [])
        path.addPath(
          nested,
          transform: CGAffineTransform(
            translationX: CGFloat(map["x"]?.doubleValue ?? 0),
            y: CGFloat(map["y"]?.doubleValue ?? 0)))
      case "close":
        path.closeSubpath()
        current = subpathStart
      default:
        continue
      }
    }
    return path
  }

  /// Circular endpoint arc used by Flutter's `Path.arcToPoint`. Rotation is
  /// intentionally absent because Ruflet's `ArcTo.radius` is circular; a
  /// rotated circle is unchanged. Positive sweeps are clockwise in the
  /// screen's y-down coordinate system.
  static func addEndpointArc(
    to path: inout Path, from start: CGPoint, to end: CGPoint,
    radius requestedRadius: CGFloat, largeArc: Bool, clockwise: Bool
  ) {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let distance = hypot(dx, dy)
    guard requestedRadius > 0, distance > .ulpOfOne else {
      path.addLine(to: end)
      return
    }
    let radius = max(requestedRadius, distance / 2)
    let midpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    let height = sqrt(max(radius * radius - distance * distance / 4, 0))
    let perpendicular = CGPoint(x: -dy / distance, y: dx / distance)
    let candidates = [
      CGPoint(x: midpoint.x + perpendicular.x * height, y: midpoint.y + perpendicular.y * height),
      CGPoint(x: midpoint.x - perpendicular.x * height, y: midpoint.y - perpendicular.y * height),
    ]

    func sweep(around center: CGPoint) -> Double {
      let startAngle = atan2(start.y - center.y, start.x - center.x)
      let endAngle = atan2(end.y - center.y, end.x - center.x)
      var value = endAngle - startAngle
      if clockwise {
        while value < 0 { value += 2 * .pi }
      } else {
        while value > 0 { value -= 2 * .pi }
      }
      return value
    }
    let center = candidates.first {
      let magnitude = abs(sweep(around: $0))
      return largeArc ? magnitude >= .pi : magnitude <= .pi
    } ?? candidates[0]
    let startAngle = atan2(start.y - center.y, start.x - center.x)
    let arcSweep = sweep(around: center)
    let segments = max(1, Int(ceil(abs(arcSweep) / (.pi / 32))))
    for step in 1...segments {
      let angle = startAngle + arcSweep * Double(step) / Double(segments)
      path.addLine(to: CGPoint(
        x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
    }
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

/// Flutter's `dart:ui.Paint` defaults and the subset which SwiftUI's
/// immediate-mode canvas can express directly. Keeping this translation in
/// one value prevents every shape from inventing its own colour, width, and
/// stroke defaults.
struct CanvasPaint: Equatable {
  let colorName: String?
  let style: String
  let strokeWidth: CGFloat
  let strokeCap: CGLineCap
  let strokeJoin: CGLineJoin
  let strokeMiterLimit: CGFloat
  let dash: [CGFloat]
  let antiAlias: Bool
  let blendModeName: String?

  init(_ map: [String: RufletValue]?) {
    colorName = map?["color"]?.stringValue
    style = map?["style"]?.stringValue?.lowercased() ?? "fill"
    // A zero-width Flutter stroke is a one-device-pixel hairline. SwiftUI
    // drops a literal zero, so use one logical pixel rather than disappearing.
    strokeWidth = CGFloat(max(map?["stroke_width"]?.doubleValue ?? 0, 1))
    strokeCap = Self.lineCap(map?["stroke_cap"]?.stringValue)
    strokeJoin = Self.lineJoin(map?["stroke_join"]?.stringValue)
    strokeMiterLimit = CGFloat(map?["stroke_miter_limit"]?.doubleValue ?? 4)
    dash = (map?["stroke_dash_pattern"]?.arrayValue ?? [])
      .compactMap(\.doubleValue).map { CGFloat($0) }
    antiAlias = map?["anti_alias"]?.boolValue ?? true
    blendModeName = map?["blend_mode"]?.stringValue
  }

  var color: Color { MaterialPalette.color(colorName, default: .black) }

  func draw(_ path: Path, in context: inout GraphicsContext) {
    style == "stroke" ? stroke(path, in: &context) : fill(path, in: &context)
  }

  func fill(_ path: Path, in context: inout GraphicsContext) {
    var copy = context
    copy.blendMode = Self.blendMode(blendModeName)
    copy.fill(path, with: .color(color), style: FillStyle(antialiased: antiAlias))
  }

  func stroke(_ path: Path, in context: inout GraphicsContext) {
    var copy = context
    copy.blendMode = Self.blendMode(blendModeName)
    copy.stroke(
      path, with: .color(color),
      style: StrokeStyle(
        lineWidth: strokeWidth, lineCap: strokeCap, lineJoin: strokeJoin,
        miterLimit: strokeMiterLimit, dash: dash))
  }

  static func lineCap(_ value: String?) -> CGLineCap {
    switch value?.lowercased() {
    case "round": return .round
    case "square": return .square
    default: return .butt
    }
  }

  static func lineJoin(_ value: String?) -> CGLineJoin {
    switch value?.lowercased() {
    case "round": return .round
    case "bevel": return .bevel
    default: return .miter
    }
  }

  static func blendMode(_ value: String?) -> GraphicsContext.BlendMode {
    switch value?.lowercased() {
    case "multiply": return .multiply
    case "screen": return .screen
    case "overlay": return .overlay
    case "darken": return .darken
    case "lighten": return .lighten
    case "difference": return .difference
    case "exclusion": return .exclusion
    default: return .normal // Flutter's default `srcOver`.
    }
  }
}

/// Image shapes are supplied as Canvas symbols so remote, file, asset, data
/// URI, and binary sources share the same loader as Flet's ordinary Image.
private struct CanvasShapeImageView: View {
  let node: ControlNode

  @ViewBuilder
  var body: some View {
    switch RufletImageSource(node: node) {
    case .binary(let data):
      PlatformImageView(data: data)
    case .remote(let url):
      if url.isFileURL, let data = try? Data(contentsOf: url) {
        PlatformImageView(data: data)
      } else {
        AsyncImage(url: url) { image in image.resizable() } placeholder: { Color.clear }
      }
    case .asset(let name):
      Image(name).resizable()
    case .missing:
      Color.clear
    }
  }
}

/// Renderer-wide chart semantics copied from the pinned Flet chart controls.
/// Keeping these decisions outside individual chart painters prevents a bar,
/// pie, or radar chart from quietly inventing a different default.
struct ChartControlSemantics {
  static let unboundedHeight: CGFloat = 300

  static func rotationDegrees(for node: ControlNode) -> Double {
    Double((node.int("rotation_quarter_turns") ?? 0) % 4) * 90
  }

  static func shouldEmitEvent(for node: ControlNode) -> Bool {
    guard node.bool("on_event") == true, node.bool("disabled") != true else { return false }
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
    }
    // Flet caps only an *unbounded* chart at 300. An unconditional max-height
    // changes explicitly-sized charts, so advertise 300 as the intrinsic
    // ideal while still accepting the bounds supplied by the DSL.
    .frame(minHeight: 0, idealHeight: ChartControlSemantics.unboundedHeight)
    .rotationEffect(.degrees(ChartControlSemantics.rotationDegrees(for: node)))
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
        guard ChartControlSemantics.shouldEmitEvent(for: node)
        else { return }
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
    let roundedStrokeJoin: Bool
    let dash: [CGFloat]
    let stepDirection: Double?
    let belowColor: Color?
    let aboveColor: Color?
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

      if let below = entry.belowColor {
        var area = path
        area.addLine(to: CGPoint(x: projected.last?.x ?? first.x, y: plot.maxY))
        area.addLine(to: CGPoint(x: first.x, y: plot.maxY))
        area.closeSubpath()
        context.fill(area, with: .color(below))
      }
      if let above = entry.aboveColor {
        var area = path
        area.addLine(to: CGPoint(x: projected.last?.x ?? first.x, y: plot.minY))
        area.addLine(to: CGPoint(x: first.x, y: plot.minY))
        area.closeSubpath()
        context.fill(area, with: .color(above))
      }

      context.stroke(
        path,
        with: .color(entry.color),
        style: StrokeStyle(
          lineWidth: entry.strokeWidth,
          lineCap: entry.roundedStrokeCap ? .round : .butt,
          lineJoin: entry.roundedStrokeJoin ? .round : .miter,
          dash: entry.dash))

      if entry.point != nil, entry.point?.boolValue != false {
        for point in projected {
          context.fill(
            Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)),
            with: .color(entry.color))
        }
      }
    }
    drawGridAndBorder(in: &context, chart: plot)
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
    let selected: Bool
  }

  private struct BarGroup {
    let x: Double
    let rods: [BarRod]
    /// `bars_space` is the gap Flutter leaves between the rods of one group.
    let barsSpace: CGFloat
    /// The rods whose tooltip Flet asked to be showing.
    let tooltipIndicators: [Int]
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
          selected: rod.bool("selected") ?? false)
      }
      guard !rods.isEmpty else { return nil }
      return BarGroup(
        x: group.double("x") ?? Double(ids.firstIndex(of: id) ?? 0),
        rods: rods,
        barsSpace: CGFloat(group.double("spacing") ?? group.double("bars_space") ?? 0),
        tooltipIndicators: interactiveChart
          ? [] : rods.enumerated().compactMap { $0.element.selected ? $0.offset : nil })
    }
  }

  private var interactiveChart: Bool {
    node.rufletBool("interactive") && node.bool("disabled") != true
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
        + group.barsSpace * CGFloat(max(group.rods.count - 1, 0))
      var rodX = centreX - totalWidth / 2
      for (rodIndex, rod) in group.rods.enumerated() {
        if let from = rod.backgroundFromY, let to = rod.backgroundToY,
          let background = rod.backgroundColor
        {
          let backgroundTop = min(y(from), y(to))
          context.fill(
            Path(roundedRect: CGRect(
              x: rodX, y: backgroundTop, width: rod.width,
              height: max(abs(y(from) - y(to)), 1)), cornerRadius: rod.radius),
            with: .color(background))
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
        rodX += rod.width + group.barsSpace
      }
      if axisShowsLabels(forKey: "bottom_axis"), let label = bottomAxisLabel(for: group.x) {
        context.draw(
          Text(label).font(axisLabelFont(forKey: "bottom_axis")),
          at: CGPoint(x: centreX, y: chart.maxY + 8), anchor: .top)
      }
    }

    if let title = axisTitle(forKey: "left_axis") {
      var rotated = context
      rotated.translateBy(x: plot.minX + 6, y: chart.midY)
      rotated.rotate(by: .degrees(-90))
      rotated.draw(
        Text(title).font(axisTitleFont(forKey: "left_axis")), at: .zero, anchor: .center)
    }
    if let title = axisTitle(forKey: "right_axis") {
      var rotated = context
      rotated.translateBy(x: chart.maxX - 6, y: chart.midY)
      rotated.rotate(by: .degrees(90))
      rotated.draw(
        Text(title).font(axisTitleFont(forKey: "right_axis")), at: .zero, anchor: .center)
    }
    if let title = axisTitle(forKey: "top_axis") {
      context.draw(
        Text(title).font(axisTitleFont(forKey: "top_axis")),
        at: CGPoint(x: chart.midX, y: chart.minY + 8))
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
      .filter { $0.double("x") != nil && $0.double("y") != nil && $0.bool("visible") != false }
      .sorted { ($0.int("render_priority") ?? 0) < ($1.int("render_priority") ?? 0) }
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
      if spot.bool("selected") == true {
        context.stroke(
          Path(ellipseIn: CGRect(
            x: point.x - radius - 3, y: point.y - radius - 3,
            width: radius * 2 + 6, height: radius * 2 + 6)),
          with: .color(.primary), lineWidth: 1)
      }
    }
    drawGridAndBorder(in: &context, chart: plot)
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

    func y(_ value: Double) -> CGFloat {
      plot.maxY - CGFloat((value - minimum) / span) * plot.height
    }

    let minX = node.double("min_x") ?? spots.compactMap { $0.double("x") }.min() ?? 0
    let maxX = node.double("max_x") ?? spots.compactMap { $0.double("x") }.max() ?? 1
    let xSpan = max(maxX - minX, .ulpOfOne)
    let step = plot.width / CGFloat(max(spots.count, 1))
    let bodyWidth = max(step * 0.6, 1)

    for spot in spots {
      let open = spot.double("open") ?? 0
      let close = spot.double("close") ?? 0
      let xValue = spot.double("x") ?? 0
      let x = plot.minX + CGFloat((xValue - minX) / xSpan) * plot.width
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
    drawGridAndBorder(in: &context, chart: plot)
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
      let size = axis.double("title_size")
    else { return .caption2 }
    return .system(size: CGFloat(size))
  }

  private func axisLabelFont(forKey key: String) -> Font {
    guard let axisID = node.controlID(forKey: key), let axis = store.node(axisID),
      let size = axis.double("label_size")
    else { return .caption2 }
    return .system(size: CGFloat(size))
  }

  private func axisShowsLabels(forKey key: String) -> Bool {
    guard let axisID = node.controlID(forKey: key), let axis = store.node(axisID) else {
      return true
    }
    return axis.bool("show_labels") != false
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
  @Environment(\.scenePhase) private var scenePhase

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
        .background(MaterialPalette.color(node.string("fill_color"), default: .black))
      #else
        Color.black
      #endif
    }
    .onAppear { model.configure(from: node, events: events) }
    .onDisappear { model.disappear() }
    .onChange(of: node) { updated in model.configure(from: updated, events: events) }
    .onChange(of: scenePhase) { model.scenePhaseChanged($0) }
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

  private var playlist: [VideoMediaSource] = []
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
      player.volume = Float(max(0, min(volume / 100, 1)))
      let newPlaybackRate = Float(node.double("playback_rate") ?? 1)
      let rateChangedWhilePlaying = playbackRate != newPlaybackRate && player.rate != 0
      playbackRate = newPlaybackRate
      self.node = node
      self.events = events
      let sourcesChanged = sources != playlist || !configured
      if sourcesChanged {
        playlist = sources
        index = min(index, max(sources.count - 1, 0))
        configured = true
        load(at: index)
      }

      // media_kit supports independent pitch. AVPlayer does not expose a pitch
      // control; changing its time-pitch preservation algorithm would not be an
      // equivalent implementation and is therefore deliberately avoided.
      player.appliesMediaSelectionCriteriaAutomatically = true
      // Flutter's playlist modes: loop the item, loop the list, or stop.
      playlistMode = node.string("playlist_mode")?.lowercased() ?? "none"
      shuffles = node.bool("shuffle_playlist") == true
      pausesInBackground = node.bool("pause_upon_entering_background_mode") ?? true
      resumesInForeground = node.bool("resume_upon_entering_foreground_mode") ?? false
      holdsWakelock = node.bool("wakelock") ?? true
      setWakelock(holdsWakelock)

      if sourcesChanged, node.bool("autoplay") == true { play() }
      else if rateChangedWhilePlaying { play() }
    #endif
  }

  /// The playlist behaviour Flet carries beside the sources.
  private var playlistMode = "none"
  private var shuffles = false
  private var pausesInBackground = true
  private var resumesInForeground = false
  private var holdsWakelock = true
  private var wasPlayingBeforeBackground = false

  /// Reports Flet's canonical `complete` event and advances when the control carries a playlist,
  /// which is what Flet's video does at the end of an item.
  private func itemDidFinish() {
    #if canImport(AVKit)
      if let node, let events {
        events.fire(node, "complete", data: .bool(true))
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
    #endif
  }

  static func sources(in node: ControlNode) -> [VideoMediaSource] {
    if let playlist = node.array("playlist") {
      return playlist.compactMap(VideoMediaSource.init)
    }
    guard let raw = node.string("src") else { return [] }
    return [VideoMediaSource(resource: raw)]
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
      let source = playlist[position]
      let asset: AVURLAsset
      if source.httpHeaders.isEmpty {
        asset = AVURLAsset(url: source.url)
      } else {
        asset = AVURLAsset(
          url: source.url,
          options: ["AVURLAssetHTTPHeaderFieldsKey": source.httpHeaders])
      }
      let item = AVPlayerItem(asset: asset)
      if let completionObserver { NotificationCenter.default.removeObserver(completionObserver) }
      completionObserver = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.itemDidFinish() }
      }
      itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
        Task { @MainActor in
          guard let self, let node = self.node, let events = self.events else { return }
          switch item.status {
          case .readyToPlay:
            events.fire(node, "loaded")
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
        if !playlist.isEmpty { load(at: 0) }
        completion(.success(.null))
      case "seek":
        if let milliseconds = call.argument("position")?.doubleValue {
          player.seek(to: CMTime(seconds: milliseconds / 1000, preferredTimescale: 600))
        }
        completion(.success(.null))
      case "jump_to":
        // Takes a playlist index rather than a time.
        if let position = call.argument("media_index")?.intValue {
          let wasPlaying = player.rate != 0
          load(at: position)
          if wasPlaying { play() }
        }
        completion(.success(.null))
      case "next":
        if index + 1 < playlist.count {
          let wasPlaying = player.rate != 0
          load(at: index + 1)
          if wasPlaying { play() }
        }
        completion(.success(.null))
      case "previous":
        if index > 0 {
          let wasPlaying = player.rate != 0
          load(at: index - 1)
          if wasPlaying { play() }
        }
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
        if let media = call.argument("media"), let source = VideoMediaSource(media) {
          playlist.append(source)
        }
        completion(.success(.null))
      case "playlist_remove":
        if let position = call.argument("media_index")?.intValue,
          playlist.indices.contains(position)
        {
          let wasPlaying = player.rate != 0
          playlist.remove(at: position)
          if playlist.isEmpty {
            index = 0
            player.replaceCurrentItem(with: nil)
          } else if position == index {
            index = min(position, playlist.count - 1)
            load(at: index)
            if wasPlaying { play() }
          } else if position < index {
            index -= 1
          }
        }
        completion(.success(.null))
      default:
        completion(.failure(rufletUnsupported("Video", call)))
      }
    #else
      completion(.failure(rufletUnsupported("Video", call)))
    #endif
  }

  func scenePhaseChanged(_ phase: ScenePhase) {
    #if canImport(AVKit)
      switch phase {
      case .background, .inactive:
        guard pausesInBackground else { return }
        wasPlayingBeforeBackground = player.rate != 0
        player.pause()
      case .active:
        if resumesInForeground && wasPlayingBeforeBackground { play() }
        wasPlayingBeforeBackground = false
      @unknown default:
        break
      }
    #endif
  }

  func disappear() {
    setWakelock(false)
  }

  private func setWakelock(_ enabled: Bool) {
    #if canImport(UIKit)
      UIApplication.shared.isIdleTimerDisabled = enabled
    #endif
  }

  deinit {
    if let completionObserver { NotificationCenter.default.removeObserver(completionObserver) }
    itemStatusObserver?.invalidate()
  }
}

/// The exact serializable subset of media_kit's `Media`: resource and HTTP
/// headers. `extras` are mpv-specific and intentionally do not alter Apple's
/// AVURLAsset behavior.
struct VideoMediaSource: Equatable {
  let resource: String
  let url: URL
  let httpHeaders: [String: String]

  init(resource: String, httpHeaders: [String: String] = [:]) {
    self.resource = resource
    self.url = URL(string: resource) ?? URL(fileURLWithPath: resource)
    self.httpHeaders = httpHeaders
  }

  init?(_ value: RufletValue) {
    if let raw = value.stringValue {
      self.init(resource: raw)
      return
    }
    guard let map = value.mapValue,
      let resource = map["resource"]?.stringValue
        ?? map["resource_url"]?.stringValue
        ?? map["src"]?.stringValue
    else { return nil }
    let headers = map["http_headers"]?.mapValue?.reduce(into: [String: String]()) {
      if let string = $1.value.stringValue { $0[$1.key] = string }
    } ?? [:]
    self.init(resource: resource, httpHeaders: headers)
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
          events.fire(node, "exit_fullscreen")
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
