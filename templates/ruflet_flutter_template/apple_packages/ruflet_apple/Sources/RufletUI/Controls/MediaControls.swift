import RufletEngine
import RufletProtocol
import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

#if canImport(WebKit)
  @preconcurrency import WebKit
#endif
#if canImport(AVKit)
  import AVKit
#endif
#if canImport(MediaPlayer)
  import MediaPlayer
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
    case .missing:
      Color.clear
    }
  }
}


/// `WebView` — WKWebView, wrapped for SwiftUI.
struct WebViewControlView: View {
  let node: ControlNode
  @StateObject private var model = WebViewModel()
  @Environment(\.rufletEvents) private var events

  var body: some View {
    #if canImport(WebKit)
      WebViewRepresentable(model: model)
        .onAppear { model.configure(node: node, events: events) }
        .onChange(of: node) { model.configure(node: $0, events: events) }
        .rufletCommandHandler(node.id) { call, completion in
          model.handle(call, completion: completion)
        }
    #else
      Color.clear
    #endif
  }
}

#if canImport(WebKit)
  struct WebViewRequestSpec: Equatable {
    static let defaultURL = "https://flet.dev"

    let url: URL
    let method: String

    init?(url: String?, method: String?) {
      guard let resolved = URL(string: url ?? Self.defaultURL) else { return nil }
      self.url = resolved
      self.method = method?.lowercased() == "post" ? "POST" : "GET"
    }

    var request: URLRequest {
      var request = URLRequest(url: url)
      request.httpMethod = method
      return request
    }
  }

  @MainActor
  final class WebViewModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate
  {
    private(set) var webView: WKWebView?
    private var node: ControlNode?
    private var events = RufletEventSink()
    private var progressObserver: NSKeyValueObservation?
    private var urlObserver: NSKeyValueObservation?
    private var loadedInitialRequest = false
    private var scriptProxy: WeakWebViewScriptHandler?

    func configure(node: ControlNode, events: RufletEventSink) {
      self.node = node
      self.events = events
      if let webView {
        applyBackground(to: webView)
        loadInitialRequestIfNeeded(in: webView)
      }
    }

    func makeWebView() -> WKWebView {
      if let webView { return webView }
      let configuration = WKWebViewConfiguration()
      let proxy = WeakWebViewScriptHandler(target: self)
      scriptProxy = proxy
      configuration.userContentController.add(proxy, name: "rufletConsole")
      configuration.userContentController.addUserScript(WKUserScript(
        source: Self.consoleBridge,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: false))
      let view = WKWebView(frame: .zero, configuration: configuration)
      view.navigationDelegate = self
      view.uiDelegate = self
      webView = view
      progressObserver = view.observe(\.estimatedProgress, options: [.new]) {
        [weak self] view, _ in
        Task { @MainActor in
          self?.fire("progress", .int(Int64((view.estimatedProgress * 100).rounded())))
        }
      }
      urlObserver = view.observe(\.url, options: [.new]) { [weak self] view, _ in
        Task { @MainActor in
          guard let url = view.url?.absoluteString else { return }
          self?.fire("url_change", .string(url))
        }
      }
      #if canImport(UIKit)
        view.scrollView.delegate = self
      #endif
      applyBackground(to: view)
      loadInitialRequestIfNeeded(in: view)
      return view
    }

    private func loadInitialRequestIfNeeded(in webView: WKWebView) {
      guard !loadedInitialRequest, let node,
        let request = WebViewRequestSpec(
          url: node.string("url"), method: node.string("method"))?.request
      else { return }
      loadedInitialRequest = true
      webView.load(request)
    }

    private func applyBackground(to webView: WKWebView) {
      guard let colorName = node?.string("bgcolor") else { return }
      guard let color = MaterialPalette.color(colorName) else { return }
      #if canImport(UIKit)
        let native = UIColor(color)
        webView.isOpaque = native.cgColor.alpha == 1
        webView.backgroundColor = native
        webView.scrollView.backgroundColor = native
      #elseif canImport(AppKit)
        webView.setValue(NSColor(color), forKey: "underPageBackgroundColor")
      #endif
    }

    func handle(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      guard let webView else {
        completion(.failure(RufletServiceError.unavailable("WebView is not mounted")))
        return
      }
      switch call.name {
      case "reload":
        webView.reload()
        completion(.success(.null))
      case "can_go_back":
        completion(.success(.bool(webView.canGoBack)))
      case "can_go_forward":
        completion(.success(.bool(webView.canGoForward)))
      case "go_back":
        if webView.canGoBack { webView.goBack() }
        completion(.success(.null))
      case "go_forward":
        if webView.canGoForward { webView.goForward() }
        completion(.success(.null))
      case "enable_zoom", "disable_zoom":
        setZoomEnabled(call.name == "enable_zoom", in: webView)
        completion(.success(.null))
      case "clear_cache":
        let types: Set<String> = [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
        WKWebsiteDataStore.default().removeData(
          ofTypes: types, modifiedSince: .distantPast
        ) { completion(.success(.null)) }
      case "clear_local_storage":
        evaluate("window.localStorage.clear();", in: webView, completion: completion)
      case "get_current_url":
        completion(.success(webView.url.map { .string($0.absoluteString) } ?? .null))
      case "get_title":
        completion(.success(webView.title.map(RufletValue.string) ?? .null))
      case "get_user_agent":
        evaluate("navigator.userAgent", in: webView, returnsValue: true, completion: completion)
      case "load_file":
        guard let path = call.argument("path")?.stringValue else {
          return completion(.success(.null))
        }
        let url = URL(fileURLWithPath: path)
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        completion(.success(.null))
      case "load_html":
        guard let value = call.argument("value")?.stringValue else {
          return completion(.success(.null))
        }
        let baseURL = call.argument("base_url")?.stringValue.flatMap(URL.init(string:))
        webView.loadHTMLString(value, baseURL: baseURL)
        completion(.success(.null))
      case "load_request":
        if let url = call.argument("url")?.stringValue,
          let spec = WebViewRequestSpec(
            url: url,
            method: call.argument("method")?.stringValue)
        {
          webView.load(spec.request)
        }
        completion(.success(.null))
      case "run_javascript":
        guard let value = call.argument("value")?.stringValue else {
          return completion(.success(.null))
        }
        evaluate(value, in: webView, completion: completion)
      case "scroll_to", "scroll_by":
        guard let x = call.argument("x")?.intValue, let y = call.argument("y")?.intValue else {
          return completion(.success(.null))
        }
        let function = call.name == "scroll_to" ? "scrollTo" : "scrollBy"
        evaluate("window.\(function)(\(x), \(y));", in: webView, completion: completion)
      case "set_javascript_mode":
        if let mode = call.argument("mode")?.stringValue?.lowercased(),
          ["disabled", "unrestricted"].contains(mode)
        {
          webView.configuration.defaultWebpagePreferences.allowsContentJavaScript =
            mode == "unrestricted"
        }
        completion(.success(.null))
      default:
        completion(.failure(rufletUnsupported("WebView", call)))
      }
    }

    private func evaluate(
      _ script: String,
      in webView: WKWebView,
      returnsValue: Bool = false,
      completion: @escaping RufletMethodCompletion
    ) {
      webView.evaluateJavaScript(script) { value, error in
        if let error {
          completion(.failure(RufletServiceError.failed(error.localizedDescription)))
        } else if returnsValue, let string = value as? String {
          completion(.success(.string(string)))
        } else {
          completion(.success(.null))
        }
      }
    }

    private func setZoomEnabled(_ enabled: Bool, in webView: WKWebView) {
      #if canImport(UIKit)
        webView.scrollView.pinchGestureRecognizer?.isEnabled = enabled
      #elseif canImport(AppKit)
        webView.enclosingScrollView?.allowsMagnification = enabled
      #endif
    }

    private func shouldPreventNavigation(_ url: String) -> Bool {
      Self.preventsNavigation(
        to: url,
        prefixes: node?.array("prevent_links")?.compactMap(\.stringValue) ?? [])
    }

    static func preventsNavigation(to url: String, prefixes: [String]) -> Bool {
      prefixes.contains(where: url.hasPrefix)
    }

    private func fire(_ name: String, _ data: RufletValue) {
      guard let node else { return }
      events.fire(node, name, data: data)
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
      guard let url = navigationAction.request.url?.absoluteString else {
        return decisionHandler(.allow)
      }
      decisionHandler(shouldPreventNavigation(url) ? .cancel : .allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      if let url = webView.url?.absoluteString { fire("page_started", .string(url)) }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      if let url = webView.url?.absoluteString { fire("page_ended", .string(url)) }
    }

    func webView(
      _ webView: WKWebView,
      didFailProvisionalNavigation navigation: WKNavigation!,
      withError error: Error
    ) {
      fire("web_resource_error", .string(error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      fire("web_resource_error", .string(error.localizedDescription))
    }

    func webView(
      _ webView: WKWebView,
      runJavaScriptAlertPanelWithMessage message: String,
      initiatedByFrame frame: WKFrameInfo,
      completionHandler: @escaping () -> Void
    ) {
      fire("javascript_alert_dialog", .map([
        "message": .string(message),
        "url": .string(frame.request.url?.absoluteString ?? "")
      ]))
      completionHandler()
    }

    fileprivate func receiveConsoleMessage(name: String, body value: Any) {
      guard name == "rufletConsole", let body = value as? [String: Any],
        let text = body["message"] as? String, let level = body["severity_level"] as? String
      else { return }
      fire("console_message", .map([
        "message": .string(text), "severity_level": .string(level)
      ]))
    }

    deinit {
      progressObserver?.invalidate()
      urlObserver?.invalidate()
    }

    private static let consoleBridge = """
      (() => {
        if (window.__rufletConsoleInstalled) return;
        window.__rufletConsoleInstalled = true;
        const bridge = window.webkit && window.webkit.messageHandlers &&
          window.webkit.messageHandlers.rufletConsole;
        if (!bridge) return;
        ['log', 'debug', 'warn', 'error'].forEach((name) => {
          const original = console[name];
          console[name] = function(...args) {
            bridge.postMessage({
              message: args.map((value) => String(value)).join(' '),
              severity_level: name === 'warn' ? 'warning' : name
            });
            return original.apply(console, args);
          };
        });
      })();
      """
  }

  private final class WeakWebViewScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WebViewModel?

    init(target: WebViewModel) { self.target = target }

    func userContentController(
      _ userContentController: WKUserContentController,
      didReceive message: WKScriptMessage
    ) {
      Task { @MainActor [weak target] in
        target?.receiveConsoleMessage(name: message.name, body: message.body)
      }
    }
  }

  private struct WebViewRepresentable {
    let model: WebViewModel
  }

  #if canImport(UIKit)
    extension WebViewRepresentable: UIViewRepresentable {
      func makeUIView(context: Context) -> WKWebView { model.makeWebView() }
      func updateUIView(_ view: WKWebView, context: Context) {}
    }
  #elseif canImport(AppKit)
    extension WebViewRepresentable: NSViewRepresentable {
      func makeNSView(context: Context) -> WKWebView { model.makeWebView() }
      func updateNSView(_ view: WKWebView, context: Context) {}
    }
  #endif

  #if canImport(UIKit)
    extension WebViewModel: UIScrollViewDelegate {
      nonisolated func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset
        Task { @MainActor in
          fire("scroll", .map(["x": .double(offset.x), "y": .double(offset.y)]))
        }
      }
    }
  #endif
#endif

/// `Video` — the platform player, with the imperative API Flet exposes.
///
/// The player lives in a `@StateObject` rather than being rebuilt each pass,
/// because `video.play` has to reach the same `AVPlayer` the user is watching.
struct VideoSubtitleConfiguration: Equatable {
  var visible = true
  var scale: CGFloat = 1
  var alignment = "center"
  var padding = EdgeInsets(top: 0, leading: 16, bottom: 24, trailing: 16)
  var style = RufletTextStyle(map: [
    "size": .double(32), "height": .double(1.4), "color": .string("#ffffffff"),
    "bgcolor": .string("#aa000000"), "weight": .string("normal"),
  ])

  init(_ value: RufletValue?) {
    guard let map = value?.mapValue else { return }
    visible = map["visible"]?.boolValue ?? true
    scale = CGFloat(map["text_scale_factor"]?.doubleValue ?? 1)
    alignment = map["text_align"]?.stringValue ?? "center"
    padding = ControlProps.edgeInsets(map["padding"])
      ?? EdgeInsets(top: 0, leading: 16, bottom: 24, trailing: 16)
    if let textStyle = map["text_style"]?.mapValue { style = RufletTextStyle(map: textStyle) }
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.visible == rhs.visible && lhs.scale == rhs.scale && lhs.alignment == rhs.alignment
      && lhs.padding == rhs.padding
  }
}

enum VideoSubtitleTrack: Equatable {
  case automatic
  case none
  case external(String)

  init?(_ value: RufletValue?) {
    guard let map = value?.mapValue, let source = map["src"]?.stringValue else { return nil }
    switch source.lowercased() {
    case "auto": self = .automatic
    case "none": self = .none
    default: self = .external(source)
    }
  }
}

struct VideoSubtitleCue: Equatable {
  let start: TimeInterval
  let end: TimeInterval
  let text: String

  static func parse(_ source: String) -> [Self] {
    source.replacingOccurrences(of: "\r\n", with: "\n")
      .components(separatedBy: "\n\n")
      .compactMap { block in
        let lines = block.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else { return nil }
        let endpoints = lines[timingIndex].components(separatedBy: "-->")
        guard endpoints.count == 2,
          let start = parseTime(endpoints[0]), let end = parseTime(endpoints[1]), end >= start
        else { return nil }
        let text = lines.dropFirst(timingIndex + 1)
          .joined(separator: "\n")
          .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        return text.isEmpty ? nil : Self(start: start, end: end, text: text)
      }
  }

  private static func parseTime(_ raw: String) -> TimeInterval? {
    let token = raw.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init)
      ?? ""
    let parts = token.replacingOccurrences(of: ",", with: ".").split(separator: ":")
    guard parts.count >= 2, let seconds = Double(parts.last ?? "") else { return nil }
    let minutes = Double(parts[parts.count - 2]) ?? 0
    let hours = parts.count > 2 ? (Double(parts[parts.count - 3]) ?? 0) : 0
    return hours * 3600 + minutes * 60 + seconds
  }
}

struct VideoControllerOptions: Equatable {
  let outputDriver: String?
  let hardwareDecodingAPI: String?
  let enablesHardwareAcceleration: Bool
  let width: Int?
  let height: Int?
  let scale: Double
  let mpvProperties: [String: String]

  init(_ value: RufletValue?) {
    let map = value?.mapValue ?? [:]
    outputDriver = map["output_driver"]?.stringValue
    hardwareDecodingAPI = map["hardware_decoding_api"]?.stringValue
    enablesHardwareAcceleration = map["enable_hardware_acceleration"]?.boolValue ?? true
    width = map["width"]?.intValue
    height = map["height"]?.intValue
    scale = map["scale"]?.doubleValue ?? 1
    mpvProperties = map["mpv_properties"]?.mapValue?.reduce(into: [:]) { result, entry in
      if let boolean = entry.value.boolValue { result[entry.key] = boolean ? "yes" : "no" }
      else if let string = entry.value.stringValue { result[entry.key] = string }
      else if let number = entry.value.doubleValue { result[entry.key] = String(number) }
    } ?? [:]
  }

  /// These settings configure media_kit's MPV backend. AVFoundation owns its
  /// decoder/output selection and exposes no equivalent knobs; retaining the
  /// parsed values makes that platform boundary explicit instead of silently
  /// pretending to apply them.
  var avFoundationUnsupportedKeys: Set<String> {
    var keys = Set(mpvProperties.keys.map { "mpv_properties.\($0)" })
    if outputDriver != nil { keys.insert("output_driver") }
    if hardwareDecodingAPI != nil { keys.insert("hardware_decoding_api") }
    if width != nil { keys.insert("width") }
    if height != nil { keys.insert("height") }
    if scale != 1 { keys.insert("scale") }
    if !enablesHardwareAcceleration { keys.insert("enable_hardware_acceleration") }
    return keys
  }
}

struct VideoPresentationOptions: Equatable {
  let title: String
  let muted: Bool
  let volume: Double?
  let pitch: Double?
  let playbackRate: Double?
  let shufflePlaylist: Bool?
  let showControls: Bool
  let playlistMode: String?
  let fullscreen: Bool
  let wakelock: Bool
  let pausesInBackground: Bool
  let resumesInForeground: Bool
  let alignment: String
  let fit: String
  let filterQuality: String
  let fillColor: String
  let autoplay: Bool

  init(_ node: ControlNode) {
    title = node.string("title") ?? "flet-video"
    muted = node.bool("muted") ?? false
    let requestedVolume = node.double("volume")
    volume = requestedVolume.flatMap { (0...100).contains($0) ? $0 : nil }
    pitch = node.double("pitch")
    playbackRate = node.double("playback_rate")
    shufflePlaylist = node.bool("shuffle_playlist")
    showControls = node.bool("show_controls") ?? true
    playlistMode = node.string("playlist_mode")
    fullscreen = node.bool("fullscreen") ?? false
    wakelock = node.bool("wakelock") ?? true
    pausesInBackground = node.bool("pause_upon_entering_background_mode") ?? true
    resumesInForeground = node.bool("resume_upon_entering_foreground_mode") ?? false
    alignment = node.string("alignment") ?? "center"
    fit = node.string("fit") ?? "contain"
    filterQuality = node.string("filter_quality") ?? "low"
    fillColor = node.string("fill_color") ?? "black"
    autoplay = node.bool("autoplay") ?? false
  }
}

struct VideoControlView: View {
  let node: ControlNode
  @StateObject private var model = VideoPlayerModel()
  @Environment(\.rufletEvents) private var events
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    Group {
      #if canImport(AVKit)
        ZStack(alignment: .bottom) {
          PlayerView(
          model: model,
          showsControls: node.bool("show_controls") ?? true,
          fit: node.string("fit"),
          filterQuality: node.string("filter_quality") ?? "low",
          fullscreen: node.bool("fullscreen") ?? false,
          node: node,
          events: events)
          if model.subtitleConfiguration.visible, !model.subtitleText.isEmpty {
            Text(model.subtitleText)
              .rufletTextStyle(model.subtitleConfiguration.style)
              .multilineTextAlignment(model.subtitleConfiguration.alignment == "start" ? .leading
                : model.subtitleConfiguration.alignment == "end" ? .trailing : .center)
              .scaleEffect(model.subtitleConfiguration.scale)
              .padding(model.subtitleConfiguration.padding)
          }
        }
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
  private var didEmitLoaded = false
  private var playbackRate: Float = 1
  private var completionObserver: Any?
  private var subtitleTimeObserver: Any?
  #if canImport(AVKit)
    private var itemStatusObserver: NSKeyValueObservation?
  #endif
  @Published private(set) var subtitleText = ""
  @Published private(set) var subtitleConfiguration = VideoSubtitleConfiguration(nil)
  private(set) var controllerOptions = VideoControllerOptions(nil)
  private(set) var avFoundationUnsupportedProperties: Set<String> = []
  private var subtitleTrack: VideoSubtitleTrack?
  private var subtitleCues: [VideoSubtitleCue] = []
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
      subtitleConfiguration = VideoSubtitleConfiguration(node.props["subtitle_configuration"])
      controllerOptions = VideoControllerOptions(node.props["configuration"])
      let presentation = VideoPresentationOptions(node)
      avFoundationUnsupportedProperties = controllerOptions.avFoundationUnsupportedKeys
      if node.double("pitch") != nil { avFoundationUnsupportedProperties.insert("pitch") }
      if presentation.alignment.lowercased() != "center" {
        avFoundationUnsupportedProperties.insert("alignment")
      }
      if !["contain", "cover", "fill"].contains(presentation.fit.lowercased()) {
        avFoundationUnsupportedProperties.insert("fit.\(presentation.fit)")
      }
      let newSubtitleTrack = VideoSubtitleTrack(node.props["subtitle_track"])
      let subtitleChanged = newSubtitleTrack != subtitleTrack
      subtitleTrack = newSubtitleTrack
      let sourcesChanged = sources != playlist || !configured
      if sourcesChanged {
        playlist = sources
        index = min(index, max(sources.count - 1, 0))
        configured = true
        load(at: index)
      } else if subtitleChanged {
        applySubtitleTrack()
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
      applyTitle(to: item)
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
            if !self.didEmitLoaded {
              self.didEmitLoaded = true
              events.fire(node, "loaded")
            }
            events.fire(node, "complete", data: .bool(false))
            self.applySubtitleTrack()
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
      installSubtitleTimeObserverIfNeeded()
    }

    private func applyTitle(to item: AVPlayerItem) {
      let title = node?.string("title") ?? "flet-video"
      #if canImport(MediaPlayer)
        var information = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        information[MPMediaItemPropertyTitle] = title
        MPNowPlayingInfoCenter.default().nowPlayingInfo = information
      #else
        avFoundationUnsupportedProperties.insert("title")
      #endif
    }

    private func installSubtitleTimeObserverIfNeeded() {
      guard subtitleTimeObserver == nil else { return }
      subtitleTimeObserver = player.addPeriodicTimeObserver(
        forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main
      ) { [weak self] time in
        Task { @MainActor in self?.updateSubtitle(at: time.seconds) }
      }
    }

    private func applySubtitleTrack() {
      subtitleText = ""
      subtitleCues = []
      guard let item = player.currentItem else { return }
      switch subtitleTrack {
      case .automatic, nil:
        player.appliesMediaSelectionCriteriaAutomatically = true
      case .some(.none):
        player.appliesMediaSelectionCriteriaAutomatically = false
        Task { @MainActor in
          if let group = try? await item.asset.loadMediaSelectionGroup(
            for: .legible)
          {
            item.select(nil, in: group)
          }
        }
      case .external(let source):
        player.appliesMediaSelectionCriteriaAutomatically = false
        loadExternalSubtitle(source)
      }
    }

    private func loadExternalSubtitle(_ source: String) {
      if let url = URL(string: source), let scheme = url.scheme,
        scheme == "http" || scheme == "https"
      {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
          guard let data, let contents = String(data: data, encoding: .utf8) else { return }
          Task { @MainActor in self?.subtitleCues = VideoSubtitleCue.parse(contents) }
        }.resume()
      } else if FileManager.default.fileExists(atPath: source),
        let contents = try? String(contentsOfFile: source, encoding: .utf8)
      {
        subtitleCues = VideoSubtitleCue.parse(contents)
      } else {
        // Flet treats a non-URL, non-file value as raw subtitle contents.
        subtitleCues = VideoSubtitleCue.parse(source)
      }
    }

    private func updateSubtitle(at seconds: TimeInterval) {
      guard seconds.isFinite else { return }
      subtitleText = subtitleCues.first(where: { $0.start <= seconds && seconds <= $0.end })?.text
        ?? ""
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
    if let subtitleTimeObserver {
      #if canImport(AVKit)
        player.removeTimeObserver(subtitleTimeObserver)
      #endif
    }
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
    let filterQuality: String
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
        controller.view.layer.magnificationFilter = layerFilter
        controller.view.layer.minificationFilter = layerFilter
      }

      private var layerFilter: CALayerContentsFilter {
        filterQuality.lowercased() == "none" ? .nearest
          : filterQuality.lowercased() == "high" ? .trilinear : .linear
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
        view.wantsLayer = true
        view.player = model.player
        view.controlsStyle = showsControls ? .inline : .none
        view.layer?.magnificationFilter = layerFilter
        view.layer?.minificationFilter = layerFilter
        return view
      }
      func updateNSView(_ view: AVPlayerView, context: Context) {
        view.player = model.player
        view.controlsStyle = showsControls ? .inline : .none
        view.layer?.magnificationFilter = layerFilter
        view.layer?.minificationFilter = layerFilter
      }

      private var layerFilter: CALayerContentsFilter {
        filterQuality.lowercased() == "none" ? .nearest
          : filterQuality.lowercased() == "high" ? .trilinear : .linear
      }
    }
  #endif
#endif
