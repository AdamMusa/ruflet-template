import RufletEngine
import RufletProtocol
import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
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
      capturedImage
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
    // Flet's Canvas defaults this to 10 ms, not zero. The first size is still
    // reported immediately; subsequent changes are throttled.
    let interval = TimeInterval(node.int("resize_interval") ?? 10) / 1_000
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
      capture.store(renderer.uiImage?.pngData(), logicalSize: reportedSize)
      #elseif canImport(AppKit)
        if let image = renderer.nsImage,
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff) {
          capture.store(bitmap.representation(using: .png, properties: [:]), logicalSize: reportedSize)
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
    ZStack {
      capturedImage
      Canvas { context, size in
        for shapeID in shapeIDs {
          guard let shape = store.node(shapeID) else { continue }
          draw(shape, in: &context, size: size)
        }
      } symbols: {
        canvasImageSymbols
      }
    }
    .environmentObject(store)
  }

  @ViewBuilder
  private var capturedImage: some View {
    if let png = capture.png, let logicalSize = capture.logicalSize {
      PlatformImageView(data: png)
        .frame(width: logicalSize.width, height: logicalSize.height)
        .clipped()
    }
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
      let elevation = CGFloat(max(shape.double("elevation") ?? 0, 0))
      var shadowed = context
      shadowed.addFilter(
        .shadow(
          color: MaterialPalette.color(shape.string("color"), default: .black),
          radius: elevation, x: 0, y: elevation / 2))
      shadowed.fill(path, with: .color(.black.opacity(shape.bool("transparent_occluder") == true ? 0.001 : 1)))

    case "Image":
      guard let symbol = context.resolveSymbol(id: shape.id) else { break }
      let width = CGFloat(shape.double("width") ?? symbol.size.width)
      let height = CGFloat(shape.double("height") ?? symbol.size.height)
      paint.draw(
        symbol, in: CGRect(
          x: CGFloat(shape.double("x") ?? 0), y: CGFloat(shape.double("y") ?? 0),
          width: width, height: height), context: &context)

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
  private(set) var logicalSize: CGSize?

  mutating func store(_ data: Data?, logicalSize: CGSize? = nil) {
    png = data
    self.logicalSize = data == nil ? nil : logicalSize
  }
  mutating func clear() {
    png = nil
    logicalSize = nil
  }

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
  let blurSigmaX: CGFloat
  let blurSigmaY: CGFloat
  let gradient: RufletValue?

  init(_ map: [String: RufletValue]?) {
    colorName = map?["color"]?.stringValue
    style = map?["style"]?.stringValue?.lowercased() ?? "fill"
    // A zero-width Flutter stroke is a one-device-pixel hairline. SwiftUI
    // drops a literal zero, so use one logical pixel rather than disappearing.
    // Keep Flutter's actual Paint value. CoreGraphics also interprets a zero
    // line width as a device-space hairline, so replacing it with one logical
    // point makes Retina strokes twice as thick.
    strokeWidth = CGFloat(map?["stroke_width"]?.doubleValue ?? 0)
    strokeCap = Self.lineCap(map?["stroke_cap"]?.stringValue)
    strokeJoin = Self.lineJoin(map?["stroke_join"]?.stringValue)
    strokeMiterLimit = CGFloat(map?["stroke_miter_limit"]?.doubleValue ?? 4)
    dash = (map?["stroke_dash_pattern"]?.arrayValue ?? [])
      .compactMap(\.doubleValue).map { CGFloat($0) }
    antiAlias = map?["anti_alias"]?.boolValue ?? true
    blendModeName = map?["blend_mode"]?.stringValue
    let blur = map?["blur_image"]?.mapValue
    blurSigmaX = CGFloat(blur?["sigma_x"]?.doubleValue ?? 0)
    blurSigmaY = CGFloat(blur?["sigma_y"]?.doubleValue ?? 0)
    gradient = map?["gradient"]
  }

  var color: Color { MaterialPalette.color(colorName, default: .black) }

  func draw(_ path: Path, in context: inout GraphicsContext) {
    style == "stroke" ? stroke(path, in: &context) : fill(path, in: &context)
  }

  func fill(_ path: Path, in context: inout GraphicsContext) {
    var copy = context
    copy.blendMode = Self.blendMode(blendModeName)
    addFilters(to: &copy)
    copy.fill(path, with: shading(in: path.boundingRect), style: FillStyle(antialiased: antiAlias))
  }

  func stroke(_ path: Path, in context: inout GraphicsContext) {
    var copy = context
    copy.blendMode = Self.blendMode(blendModeName)
    addFilters(to: &copy)
    copy.stroke(
      path, with: shading(in: path.boundingRect),
      style: StrokeStyle(
        lineWidth: strokeWidth, lineCap: strokeCap, lineJoin: strokeJoin,
        miterLimit: strokeMiterLimit, dash: dash))
  }

  func draw(_ symbol: GraphicsContext.ResolvedSymbol, in rect: CGRect,
            context: inout GraphicsContext) {
    var copy = context
    copy.blendMode = Self.blendMode(blendModeName)
    addFilters(to: &copy)
    copy.draw(symbol, in: rect)
  }

  private func addFilters(to context: inout GraphicsContext) {
    // GraphicsContext exposes an isotropic blur. Using the larger sigma keeps
    // the same visual extent as Flutter when its image filter is anisotropic;
    // the X/Y distinction is retained above for conformance and tests.
    let sigma = max(blurSigmaX, blurSigmaY)
    if sigma > 0 { context.addFilter(.blur(radius: sigma)) }
  }

  private func shading(in bounds: CGRect) -> GraphicsContext.Shading {
    guard let map = gradient?.mapValue else { return .color(color) }
    let colors = (map["colors"]?.arrayValue ?? []).map {
      MaterialPalette.color($0.stringValue, default: .clear)
    }
    guard !colors.isEmpty else { return .color(color) }
    let stops = map["color_stops"]?.arrayValue?.compactMap(\.doubleValue)
    let gradient = Gradient(stops: colors.enumerated().map { index, value in
      let location = stops.flatMap { index < $0.count ? $0[index] : nil }
        ?? (colors.count == 1 ? 0 : Double(index) / Double(colors.count - 1))
      return Gradient.Stop(color: value, location: location)
    })
    func point(_ value: RufletValue?, fallback: CGPoint) -> CGPoint {
      guard let map = value?.mapValue else { return fallback }
      return CGPoint(x: map["x"]?.doubleValue ?? fallback.x,
                     y: map["y"]?.doubleValue ?? fallback.y)
    }
    switch map["_type"]?.stringValue?.lowercased() {
    case "radial":
      let center = point(map["center"], fallback: CGPoint(x: bounds.midX, y: bounds.midY))
      return .radialGradient(
        gradient, center: center, startRadius: 0,
        endRadius: CGFloat(map["radius"]?.doubleValue ?? 0))
    case "sweep":
      let center = point(map["center"], fallback: CGPoint(x: bounds.midX, y: bounds.midY))
      return .conicGradient(
        gradient, center: center,
        angle: .radians(map["start_angle"]?.doubleValue ?? 0))
    default:
      return .linearGradient(
        gradient,
        startPoint: point(map["begin"], fallback: CGPoint(x: bounds.minX, y: bounds.minY)),
        endPoint: point(map["end"], fallback: CGPoint(x: bounds.maxX, y: bounds.maxY)))
    }
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
    case "clear": return .clear
    case "src": return .copy
    case "dst": return .destinationOver
    case "src_over": return .normal
    case "dst_over": return .destinationOver
    case "src_in": return .sourceAtop
    case "dst_in": return .destinationIn
    case "src_out": return .sourceOut
    case "dst_out": return .destinationOut
    case "src_atop": return .sourceAtop
    case "dst_atop": return .destinationAtop
    case "xor": return .xor
    case "plus": return .plusLighter
    case "modulate": return .multiply
    case "multiply": return .multiply
    case "screen": return .screen
    case "overlay": return .overlay
    case "darken": return .darken
    case "lighten": return .lighten
    case "difference": return .difference
    case "exclusion": return .exclusion
    case "color_dodge": return .colorDodge
    case "color_burn": return .colorBurn
    case "hard_light": return .hardLight
    case "soft_light": return .softLight
    case "hue": return .hue
    case "saturation": return .saturation
    case "color": return .color
    case "luminosity": return .luminosity
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
    case .empty, .invalid, .missing:
      Color.clear
    }
  }
}
