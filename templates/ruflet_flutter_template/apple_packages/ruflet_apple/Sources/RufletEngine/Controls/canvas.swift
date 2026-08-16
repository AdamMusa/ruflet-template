import CoreGraphics
import CoreText
import Foundation
import ImageIO
import RufletProtocol
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

/// Stateful dash-interval cursor used by the pinned Flet Canvas algorithm.
/// The actual Apple path dashing is performed by CoreGraphics below; keeping
/// the cursor here preserves the source contract without a second renderer.
public final class CircularIntervalList<Value> {
  private let values: [Value]
  private var index = 0

  public init(_ values: [Value]) { self.values = values }

  public var next: Value {
    if index >= values.count { index = 0 }
    defer { index += 1 }
    return values[index]
  }
}

@MainActor
enum RufletCanvasRenderer {
  static func makeImage(
    size: CGSize,
    pixelRatio: CGFloat,
    shapes: [RufletControl],
    images: [Int: RufletCanvasCoordinator.CachedImage],
    capturedImage: CGImage?,
    capturedSize: CGSize
  ) -> CGImage? {
    let width = max(Int((size.width * pixelRatio).rounded(.down)), 1)
    let height = max(Int((size.height * pixelRatio).rounded(.down)), 1)
    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: pixelRatio, y: -pixelRatio)
    draw(
      in: context,
      size: size,
      shapes: shapes,
      images: images,
      capturedImage: capturedImage,
      capturedSize: capturedSize)
    return context.makeImage()
  }

  static func draw(
    in context: CGContext,
    size: CGSize,
    shapes: [RufletControl],
    images: [Int: RufletCanvasCoordinator.CachedImage],
    capturedImage: CGImage?,
    capturedSize: CGSize
  ) {
    context.saveGState()
    context.clip(to: CGRect(origin: .zero, size: size))
    if let capturedImage, capturedSize.width > 0, capturedSize.height > 0 {
      drawImage(capturedImage, in: CGRect(origin: .zero, size: capturedSize), context: context)
    }
    for shape in shapes {
      shape.notifyParent = true
      draw(shape, in: context, canvasSize: size, images: images)
    }
    context.restoreGState()
  }

  static func path(elements: RufletValue?) -> CGPath {
    let path = CGMutablePath()
    append(elements?.array ?? [], to: path, offset: .zero)
    return path
  }

  private static func draw(
    _ shape: RufletControl,
    in context: CGContext,
    canvasSize: CGSize,
    images: [Int: RufletCanvasCoordinator.CachedImage]
  ) {
    switch shape.type {
    case "Line": drawLine(shape, context)
    case "Circle": drawCircle(shape, context)
    case "Arc": drawArc(shape, context)
    case "Color": drawColor(shape, context, canvasSize)
    case "Oval": drawOval(shape, context)
    case "Fill": drawFill(shape, context, canvasSize)
    case "Points": drawPoints(shape, context)
    case "Rect": drawRect(shape, context)
    case "Path": drawPath(shape, context)
    case "Shadow": drawShadow(shape, context)
    case "Text": drawText(shape, context)
    case "Image":
      if let image = images[shape.id]?.image { drawImageShape(shape, image, context) }
    default: break
    }
  }

  private static func drawLine(_ shape: RufletControl, _ context: CGContext) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: shape.number("x1") ?? 0, y: shape.number("y1") ?? 0))
    path.addLine(to: CGPoint(x: shape.number("x2") ?? 0, y: shape.number("y2") ?? 0))
    draw(
      path: path, paint: RufletCanvasPaint(shape.dynamicValue("paint")), forceStroke: true,
      in: context)
  }

  private static func drawCircle(_ shape: RufletControl, _ context: CGContext) {
    let radius = CGFloat(shape.number("radius", default: 0) ?? 0)
    let rect = CGRect(
      x: CGFloat(shape.number("x") ?? 0) - radius,
      y: CGFloat(shape.number("y") ?? 0) - radius,
      width: radius * 2,
      height: radius * 2)
    let path = CGPath(ellipseIn: rect, transform: nil)
    draw(path: path, paint: RufletCanvasPaint(shape.dynamicValue("paint")), in: context)
  }

  private static func drawOval(_ shape: RufletControl, _ context: CGContext) {
    let path = CGPath(ellipseIn: shapeRect(shape), transform: nil)
    draw(path: path, paint: RufletCanvasPaint(shape.dynamicValue("paint")), in: context)
  }

  private static func drawArc(_ shape: RufletControl, _ context: CGContext) {
    let rect = shapeRect(shape)
    let start = CGFloat(shape.number("start_angle", default: 0) ?? 0)
    let sweep = CGFloat(shape.number("sweep_angle", default: 0) ?? 0)
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let path = CGMutablePath()
    if shape.boolean("use_center", default: false) { path.move(to: center) }
    appendEllipticalArc(path, rect: rect, start: start, sweep: sweep)
    if shape.boolean("use_center", default: false) { path.closeSubpath() }
    draw(path: path, paint: RufletCanvasPaint(shape.dynamicValue("paint")), in: context)
  }

  private static func drawColor(
    _ shape: RufletControl,
    _ context: CGContext,
    _ canvasSize: CGSize
  ) {
    guard shape.string("blend_mode")?.lowercased() != "dst" else { return }
    context.saveGState()
    context.setBlendMode(rufletCanvasBlendMode(shape.string("blend_mode")))
    context.setFillColor(rufletCanvasCGColor(parseColor(shape.string("color"), .black)!))
    context.fill(CGRect(origin: .zero, size: canvasSize))
    context.restoreGState()
  }

  private static func drawFill(
    _ shape: RufletControl,
    _ context: CGContext,
    _ canvasSize: CGSize
  ) {
    let path = CGPath(rect: CGRect(origin: .zero, size: canvasSize), transform: nil)
    draw(path: path, paint: RufletCanvasPaint(shape.dynamicValue("paint")), in: context)
  }

  private static func drawPoints(_ shape: RufletControl, _ context: CGContext) {
    let points = (shape.value("points")?.array ?? []).compactMap(rufletCanvasPoint)
    guard !points.isEmpty else { return }
    let paint = RufletCanvasPaint(shape.dynamicValue("paint"))
    let mode = shape.string("point_mode", default: "points")?.lowercased()
    let path = CGMutablePath()
    if mode == "lines" {
      for pairStart in stride(from: 0, to: points.count - 1, by: 2) {
        path.move(to: points[pairStart])
        path.addLine(to: points[pairStart + 1])
      }
    } else if mode == "polygon" {
      path.move(to: points[0])
      for point in points.dropFirst() { path.addLine(to: point) }
    } else {
      let radius = max(paint.strokeWidth / 2, 0.5)
      for point in points {
        path.addEllipse(
          in: CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2))
      }
    }
    // Pinned Flet calls Canvas.drawPoints directly and never routes this
    // shape's paint dash array through dashPath. Preserve that distinction
    // for both `lines` and `polygon` point modes.
    draw(
      path: path,
      paint: paint,
      forceStroke: mode != "points",
      applyDashPattern: false,
      in: context)
  }

  private static func drawRect(_ shape: RufletControl, _ context: CGContext) {
    let radius = parseBorderRadius(shape.dynamicValue("border_radius"), .zero)!
    let path = roundedRectPath(shapeRect(shape), radius: radius)
    draw(path: path, paint: RufletCanvasPaint(shape.dynamicValue("paint")), in: context)
  }

  private static func drawPath(_ shape: RufletControl, _ context: CGContext) {
    draw(
      path: path(elements: shape.value("elements")),
      paint: RufletCanvasPaint(shape.dynamicValue("paint")),
      in: context)
  }

  private static func drawShadow(_ shape: RufletControl, _ context: CGContext) {
    let path = path(elements: shape.value("path"))
    let color = rufletCanvasCGColor(parseColor(shape.string("color"), .black)!)
    let elevation = CGFloat(shape.number("elevation", default: 0) ?? 0)
    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 0, height: elevation / 2),
      blur: max(elevation, 0),
      color: color)
    context.setFillColor(
      color.copy(alpha: shape.boolean("transparent_occluder", default: false) ? 0.01 : 1) ?? color)
    context.addPath(path)
    context.fillPath()
    context.restoreGState()
  }

  private static func shapeRect(_ shape: RufletControl) -> CGRect {
    CGRect(
      x: shape.number("x") ?? 0,
      y: shape.number("y") ?? 0,
      width: shape.number("width", default: 0) ?? 0,
      height: shape.number("height", default: 0) ?? 0)
  }

  private static func draw(
    path sourcePath: CGPath,
    paint: RufletCanvasPaint,
    forceStroke: Bool = false,
    applyDashPattern: Bool = true,
    in context: CGContext
  ) {
    guard paint.drawsSource else { return }
    context.saveGState()
    paint.prepare(context)
    if !applyDashPattern { context.setLineDash(phase: 0, lengths: []) }
    let stroke = forceStroke || paint.style == .stroke
    if let gradient = paint.gradient {
      let clipPath = gradientClipPath(
        sourcePath,
        paint: paint,
        stroke: stroke,
        applyDashPattern: applyDashPattern)
      context.addPath(clipPath)
      context.clip()
      draw(gradient: gradient, bounds: clipPath.boundingBoxOfPath, in: context)
    } else {
      context.addPath(sourcePath)
      stroke ? context.strokePath() : context.fillPath()
    }
    context.restoreGState()
  }

  private static func gradientClipPath(
    _ path: CGPath,
    paint: RufletCanvasPaint,
    stroke: Bool,
    applyDashPattern: Bool
  ) -> CGPath {
    guard stroke else { return path }
    let dashed =
      !applyDashPattern || paint.dashPattern.isEmpty
      ? path
      : path.copy(dashingWithPhase: 0, lengths: paint.dashPattern)
    return dashed.copy(
      strokingWithWidth: max(paint.strokeWidth, 1),
      lineCap: paint.strokeCap,
      lineJoin: paint.strokeJoin,
      miterLimit: paint.strokeMiterLimit)
  }

  private static func appendEllipticalArc(
    _ path: CGMutablePath,
    rect: CGRect,
    start: CGFloat,
    sweep: CGFloat
  ) {
    guard rect.width != 0, rect.height != 0, sweep != 0 else { return }
    let transform = CGAffineTransform(
      translationX: rect.midX,
      y: rect.midY
    ).scaledBy(x: rect.width / 2, y: rect.height / 2)
    let unit = CGMutablePath()
    unit.addArc(
      center: .zero,
      radius: 1,
      startAngle: start,
      endAngle: start + sweep,
      clockwise: sweep < 0)
    path.addPath(unit, transform: transform)
  }

  private static func roundedRectPath(
    _ rect: CGRect,
    radius: RufletBorderRadius
  ) -> CGPath {
    let tl = min(CGFloat(radius.topLeft), min(rect.width, rect.height) / 2)
    let tr = min(CGFloat(radius.topRight), min(rect.width, rect.height) / 2)
    let bl = min(CGFloat(radius.bottomLeft), min(rect.width, rect.height) / 2)
    let br = min(CGFloat(radius.bottomRight), min(rect.width, rect.height) / 2)
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
    path.addArc(
      center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
      radius: tr, startAngle: -.pi / 2, endAngle: 0, clockwise: false)
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
    path.addArc(
      center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
      radius: br, startAngle: 0, endAngle: .pi / 2, clockwise: false)
    path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
    path.addArc(
      center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
      radius: bl, startAngle: .pi / 2, endAngle: .pi, clockwise: false)
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
    path.addArc(
      center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
      radius: tl, startAngle: .pi, endAngle: .pi * 1.5, clockwise: false)
    path.closeSubpath()
    return path
  }

  private static func append(
    _ elements: [RufletValue],
    to path: CGMutablePath,
    offset: CGPoint
  ) {
    for element in elements {
      guard let value = element.map, let type = value["_type"]?.text else { continue }
      func number(_ key: String, _ defaultValue: Double = 0) -> CGFloat {
        CGFloat(value[key]?.number ?? defaultValue)
      }
      func point(_ x: String = "x", _ y: String = "y") -> CGPoint {
        CGPoint(x: number(x) + offset.x, y: number(y) + offset.y)
      }
      switch type {
      case "MoveTo": path.move(to: point())
      case "LineTo": path.addLine(to: point())
      case "Arc":
        appendEllipticalArc(
          path,
          rect: CGRect(
            x: number("x") + offset.x,
            y: number("y") + offset.y,
            width: number("width"),
            height: number("height")),
          start: number("start_angle"),
          sweep: number("sweep_angle"))
      case "ArcTo":
        appendEndpointArc(
          to: path,
          end: point(),
          radius: max(number("radius"), 0),
          rotation: number("rotation"),
          largeArc: value["large_arc"]?.bool ?? false,
          clockwise: value["clockwise"]?.bool ?? true)
      case "Oval":
        path.addEllipse(
          in: CGRect(
            x: number("x") + offset.x,
            y: number("y") + offset.y,
            width: number("width"),
            height: number("height")))
      case "Rect":
        let radius = parseBorderRadius(value["border_radius"].map(rufletAny), .zero)!
        path.addPath(
          roundedRectPath(
            CGRect(
              x: number("x") + offset.x,
              y: number("y") + offset.y,
              width: number("width"),
              height: number("height")),
            radius: radius))
      case "QuadraticTo":
        appendConic(
          to: path,
          control: point("cp1x", "cp1y"),
          end: point(),
          weight: number("w"))
      case "CubicTo":
        path.addCurve(
          to: point(),
          control1: point("cp1x", "cp1y"),
          control2: point("cp2x", "cp2y"))
      case "SubPath":
        append(
          value["elements"]?.array ?? [],
          to: path,
          offset: CGPoint(x: offset.x + number("x"), y: offset.y + number("y")))
      case "Close": path.closeSubpath()
      default: break
      }
    }
  }

  private static func appendConic(
    to path: CGMutablePath,
    control: CGPoint,
    end: CGPoint,
    weight: CGFloat
  ) {
    let start = path.currentPoint
    guard weight != 1 else {
      path.addQuadCurve(to: end, control: control)
      return
    }
    let segments = 32
    for index in 1...segments {
      let t = CGFloat(index) / CGFloat(segments)
      let mt = 1 - t
      let denominator = mt * mt + 2 * weight * mt * t + t * t
      guard denominator != 0 else { continue }
      path.addLine(
        to: CGPoint(
          x: (mt * mt * start.x + 2 * weight * mt * t * control.x + t * t * end.x)
            / denominator,
          y: (mt * mt * start.y + 2 * weight * mt * t * control.y + t * t * end.y)
            / denominator))
    }
  }

  private static func appendEndpointArc(
    to path: CGMutablePath,
    end: CGPoint,
    radius requestedRadius: CGFloat,
    rotation: CGFloat,
    largeArc: Bool,
    clockwise: Bool
  ) {
    let start = path.currentPoint
    let distance = hypot(end.x - start.x, end.y - start.y)
    guard requestedRadius > 0, distance > 0 else {
      path.addLine(to: end)
      return
    }
    let radius = max(requestedRadius, distance / 2)
    let midpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    let halfChord = distance / 2
    let centerDistance = sqrt(max(radius * radius - halfChord * halfChord, 0))
    let perpendicular = CGPoint(
      x: -(end.y - start.y) / distance,
      y: (end.x - start.x) / distance)
    let direction: CGFloat = (largeArc == clockwise) ? -1 : 1
    let center = CGPoint(
      x: midpoint.x + perpendicular.x * centerDistance * direction,
      y: midpoint.y + perpendicular.y * centerDistance * direction)
    let startAngle = atan2(start.y - center.y, start.x - center.x) + rotation * 0
    var endAngle = atan2(end.y - center.y, end.x - center.x)
    if clockwise, endAngle < startAngle { endAngle += .pi * 2 }
    if !clockwise, endAngle > startAngle { endAngle -= .pi * 2 }
    if largeArc, abs(endAngle - startAngle) < .pi {
      endAngle += clockwise ? .pi * 2 : -.pi * 2
    } else if !largeArc, abs(endAngle - startAngle) > .pi {
      endAngle += clockwise ? -.pi * 2 : .pi * 2
    }
    path.addArc(
      center: center,
      radius: radius,
      startAngle: startAngle,
      endAngle: endAngle,
      clockwise: !clockwise)
  }

  private static func draw(
    gradient: RufletCanvasGradient,
    bounds: CGRect,
    in context: CGContext
  ) {
    guard
      let cgGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: gradient.colors as CFArray,
        locations: gradient.stops)
    else { return }
    switch gradient.kind {
    case .linear(let begin, let end):
      drawLinearGradient(gradient, cgGradient, begin, end, bounds, context)
    case .radial(let center, let radius, let focal, let focalRadius):
      drawRadialGradient(
        gradient, cgGradient, center, radius, focal ?? center, focalRadius, bounds, context)
    case .sweep(let center, let startAngle, let endAngle, let rotation):
      drawSweepGradient(
        gradient, center, startAngle + rotation, endAngle + rotation, bounds, context)
    }
  }

  private static func drawLinearGradient(
    _ spec: RufletCanvasGradient,
    _ gradient: CGGradient,
    _ begin: CGPoint,
    _ end: CGPoint,
    _ bounds: CGRect,
    _ context: CGContext
  ) {
    guard begin != end else { return }
    if spec.tileMode == .clamp || spec.tileMode == .decal {
      context.drawLinearGradient(
        gradient,
        start: begin,
        end: end,
        options: spec.tileMode == .clamp ? [.drawsBeforeStartLocation, .drawsAfterEndLocation] : [])
      return
    }
    let vector = CGVector(dx: end.x - begin.x, dy: end.y - begin.y)
    let lengthSquared = vector.dx * vector.dx + vector.dy * vector.dy
    let corners = [
      CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.minY),
      CGPoint(x: bounds.minX, y: bounds.maxY), CGPoint(x: bounds.maxX, y: bounds.maxY),
    ]
    let projections = corners.map {
      (($0.x - begin.x) * vector.dx + ($0.y - begin.y) * vector.dy) / lengthSquared
    }
    let lower = Int(floor(projections.min() ?? 0)) - 1
    let upper = Int(ceil(projections.max() ?? 1)) + 1
    for index in lower...upper {
      let start = CGPoint(
        x: begin.x + CGFloat(index) * vector.dx,
        y: begin.y + CGFloat(index) * vector.dy)
      let finish = CGPoint(x: start.x + vector.dx, y: start.y + vector.dy)
      let mirrored = spec.tileMode == .mirror && abs(index % 2) == 1
      context.drawLinearGradient(
        gradient,
        start: mirrored ? finish : start,
        end: mirrored ? start : finish,
        options: [])
    }
  }

  private static func drawRadialGradient(
    _ spec: RufletCanvasGradient,
    _ gradient: CGGradient,
    _ center: CGPoint,
    _ radius: CGFloat,
    _ focal: CGPoint,
    _ focalRadius: CGFloat,
    _ bounds: CGRect,
    _ context: CGContext
  ) {
    guard radius > 0 else { return }
    if spec.tileMode == .clamp || spec.tileMode == .decal {
      context.drawRadialGradient(
        gradient,
        startCenter: focal,
        startRadius: max(focalRadius, 0),
        endCenter: center,
        endRadius: radius,
        options: spec.tileMode == .clamp ? [.drawsBeforeStartLocation, .drawsAfterEndLocation] : [])
      return
    }
    let corners = [
      CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.minY),
      CGPoint(x: bounds.minX, y: bounds.maxY), CGPoint(x: bounds.maxX, y: bounds.maxY),
    ]
    let repetitions = max(
      Int(ceil(corners.map { hypot($0.x - center.x, $0.y - center.y) }.max()! / radius)), 1)
    for index in stride(from: repetitions - 1, through: 0, by: -1) {
      let inner = CGFloat(index) * radius
      let outer = CGFloat(index + 1) * radius
      let mirrored = spec.tileMode == .mirror && index % 2 == 1
      context.drawRadialGradient(
        gradient,
        startCenter: index == 0 ? focal : center,
        startRadius: index == 0 ? focalRadius : (mirrored ? outer : inner),
        endCenter: center,
        endRadius: mirrored ? inner : outer,
        options: [])
    }
  }

  private static func drawSweepGradient(
    _ spec: RufletCanvasGradient,
    _ center: CGPoint,
    _ startAngle: CGFloat,
    _ endAngle: CGFloat,
    _ bounds: CGRect,
    _ context: CGContext
  ) {
    let span = endAngle - startAngle
    guard span != 0 else { return }
    let corners = [
      CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.minY),
      CGPoint(x: bounds.minX, y: bounds.maxY), CGPoint(x: bounds.maxX, y: bounds.maxY),
    ]
    let radius = max(corners.map { hypot($0.x - center.x, $0.y - center.y) }.max() ?? 0, 1)
    let fullCircle = CGFloat.pi * 2
    let segments = 720
    for index in 0..<segments {
      let a0 = fullCircle * CGFloat(index) / CGFloat(segments)
      let a1 = fullCircle * CGFloat(index + 1) / CGFloat(segments)
      let midpoint = (a0 + a1) / 2
      var normalizedAngle = midpoint
      while normalizedAngle < startAngle { normalizedAngle += fullCircle }
      let rawPosition = (normalizedAngle - startAngle) / span
      guard let color = sampledColor(spec, at: rawPosition) else { continue }
      context.beginPath()
      context.move(to: center)
      context.addLine(to: CGPoint(x: center.x + cos(a0) * radius, y: center.y + sin(a0) * radius))
      context.addLine(to: CGPoint(x: center.x + cos(a1) * radius, y: center.y + sin(a1) * radius))
      context.closePath()
      context.setFillColor(color)
      context.fillPath()
    }
  }

  private static func sampledColor(
    _ gradient: RufletCanvasGradient,
    at rawPosition: CGFloat
  ) -> CGColor? {
    var position = rawPosition
    switch gradient.tileMode {
    case .clamp: position = min(max(position, 0), 1)
    case .decal: guard 0...1 ~= position else { return nil }
    case .repeated: position -= floor(position)
    case .mirror:
      let whole = floor(position)
      let fraction = position - whole
      position = Int(abs(whole)) % 2 == 0 ? fraction : 1 - fraction
    }
    guard let right = gradient.stops.firstIndex(where: { $0 >= position }) else {
      return gradient.colors.last
    }
    guard right > 0 else { return gradient.colors[0] }
    let left = right - 1
    let distance = gradient.stops[right] - gradient.stops[left]
    let amount = distance == 0 ? 0 : (position - gradient.stops[left]) / distance
    return interpolate(gradient.colors[left], gradient.colors[right], amount)
  }

  private static func interpolate(_ left: CGColor, _ right: CGColor, _ amount: CGFloat) -> CGColor {
    let lhs = rgba(left)
    let rhs = rgba(right)
    return CGColor(
      red: lhs.0 + (rhs.0 - lhs.0) * amount,
      green: lhs.1 + (rhs.1 - lhs.1) * amount,
      blue: lhs.2 + (rhs.2 - lhs.2) * amount,
      alpha: lhs.3 + (rhs.3 - lhs.3) * amount)
  }

  private static func rgba(_ color: CGColor) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
    let components =
      color.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)?
      .components ?? color.components ?? [0, 0, 0, 1]
    if components.count >= 4 { return (components[0], components[1], components[2], components[3]) }
    return (components[0], components[0], components[0], components.count > 1 ? components[1] : 1)
  }

  private static func drawImageShape(
    _ shape: RufletControl,
    _ image: CGImage,
    _ context: CGContext
  ) {
    let width = shape.number("width")
    let height = shape.number("height")
    let rect = CGRect(
      x: shape.number("x") ?? 0,
      y: shape.number("y") ?? 0,
      width: width ?? Double(image.width),
      height: height ?? Double(image.height))
    let paint = RufletCanvasPaint(shape.dynamicValue("paint"))
    guard paint.drawsSource else { return }
    context.saveGState()
    paint.prepare(context)
    context.setAlpha(rgba(paint.color).3)
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    context.setBlendMode(.normal)
    context.interpolationQuality = paint.antiAlias ? .default : .none
    drawImage(image, in: rect, context: context)
    if let gradient = paint.gradient {
      context.setBlendMode(.sourceAtop)
      draw(gradient: gradient, bounds: rect, in: context)
    }
    context.endTransparencyLayer()
    context.restoreGState()
  }

  private static func drawImage(
    _ image: CGImage,
    in rect: CGRect,
    context: CGContext
  ) {
    context.saveGState()
    context.translateBy(x: 0, y: rect.minY * 2 + rect.height)
    context.scaleBy(x: 1, y: -1)
    context.draw(image, in: rect)
    context.restoreGState()
  }

  private static func drawText(_ shape: RufletControl, _ context: CGContext) {
    var attributed = rufletCanvasAttributedText(shape)
    guard attributed.length > 0 else { return }
    let maxWidth = CGFloat(shape.number("max_width") ?? 100_000)
    if let maxLines = shape.integer("max_lines"), maxLines > 0,
      let ellipsis = shape.string("ellipsis"), maxWidth < 100_000
    {
      attributed = rufletTruncatedCanvasText(
        attributed, maxWidth: maxWidth, maxLines: maxLines, ellipsis: ellipsis)
    }
    let framesetter = CTFramesetterCreateWithAttributedString(attributed)
    var fitRange = CFRange()
    var measured = CTFramesetterSuggestFrameSizeWithConstraints(
      framesetter,
      CFRange(location: 0, length: attributed.length),
      nil,
      CGSize(width: maxWidth, height: 100_000),
      &fitRange)
    measured.width = min(ceil(measured.width), maxWidth)
    measured.height = ceil(measured.height)
    if let maxLines = shape.integer("max_lines"), maxLines > 0 {
      let lineHeight = rufletCanvasLineHeight(shape.dynamicValue("style"))
      measured.height = min(measured.height, lineHeight * CGFloat(maxLines))
    }
    let offset = CGPoint(x: shape.number("x") ?? 0, y: shape.number("y") ?? 0)
    let alignment = parseAlignment(shape.dynamicValue("alignment"), RufletAlignment(x: -1, y: -1))!
    let origin = CGPoint(
      x: offset.x - measured.width / 2 * CGFloat(alignment.x + 1),
      y: offset.y - measured.height / 2 * CGFloat(alignment.y + 1))
    let textPath = CGPath(rect: CGRect(origin: .zero, size: measured), transform: nil)
    let frame = CTFramesetterCreateFrame(
      framesetter,
      CFRange(location: 0, length: attributed.length),
      textPath,
      nil)
    let style = rufletDictionary(shape.dynamicValue("style")) ?? [:]
    let foreground = style["foreground"].map(RufletCanvasPaint.init)
    guard foreground?.drawsSource != false else { return }
    context.saveGState()
    foreground?.prepare(context)
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    context.setBlendMode(.normal)
    context.saveGState()
    context.translateBy(x: offset.x, y: offset.y)
    context.rotate(by: CGFloat(shape.number("rotate", default: 0) ?? 0))
    context.translateBy(x: -offset.x, y: -offset.y)
    context.translateBy(x: origin.x, y: origin.y + measured.height)
    context.scaleBy(x: 1, y: -1)
    CTFrameDraw(frame, context)
    context.restoreGState()
    if let gradient = foreground?.gradient {
      context.setBlendMode(.sourceAtop)
      draw(gradient: gradient, bounds: CGRect(origin: origin, size: measured), in: context)
    }
    context.endTransparencyLayer()
    context.restoreGState()
  }
}

@MainActor
private func rufletCanvasAttributedText(_ shape: RufletControl) -> NSAttributedString {
  let result = NSMutableAttributedString()
  let rootStyle = rufletDictionary(shape.dynamicValue("style")) ?? [:]
  rufletAppendCanvasStyledString(
    shape.string("value", default: "") ?? "", style: rootStyle, to: result)
  for span in shape.children("spans") {
    rufletAppendCanvasTextSpan(span, inheritedStyle: rootStyle, to: result)
  }
  let paragraph = NSMutableParagraphStyle()
  switch shape.string("text_align", default: "start")?.lowercased() {
  case "center": paragraph.alignment = .center
  case "right", "end": paragraph.alignment = .right
  case "justify": paragraph.alignment = .justified
  default: paragraph.alignment = .left
  }
  if shape.string("ellipsis") != nil { paragraph.lineBreakMode = .byTruncatingTail }
  paragraph.lineHeightMultiple = CGFloat(parseDouble(rootStyle["height"], 1)!)
  result.addAttribute(
    .paragraphStyle, value: paragraph, range: NSRange(location: 0, length: result.length))
  return result
}

@MainActor
private func rufletAppendCanvasTextSpan(
  _ span: RufletControl,
  inheritedStyle: [String: Any],
  to result: NSMutableAttributedString
) {
  span.notifyParent = true
  let style = inheritedStyle.merging(
    rufletDictionary(span.dynamicValue("style")) ?? [:],
    uniquingKeysWith: { _, child in child })
  rufletAppendCanvasStyledString(
    span.string("text", default: "") ?? "", style: style, to: result)
  for child in span.children("spans") {
    rufletAppendCanvasTextSpan(child, inheritedStyle: style, to: result)
  }
}

private func rufletAppendCanvasStyledString(
  _ string: String,
  style: [String: Any],
  to result: NSMutableAttributedString
) {
  let start = result.length
  result.append(NSAttributedString(string: string, attributes: rufletCanvasTextAttributes(style)))
  guard let wordSpacing = parseDouble(style["word_spacing"]), wordSpacing != 0 else { return }
  let utf16 = Array(string.utf16)
  for (index, value) in utf16.enumerated() {
    guard let scalar = UnicodeScalar(value),
      CharacterSet.whitespacesAndNewlines.contains(scalar)
    else { continue }
    let letterSpacing = parseDouble(style["letter_spacing"], 0)!
    result.addAttribute(
      .kern, value: letterSpacing + wordSpacing, range: NSRange(location: start + index, length: 1))
  }
}

private func rufletCanvasTextAttributes(_ style: [String: Any]) -> [NSAttributedString.Key: Any] {
  let foregroundPaint = RufletCanvasPaint(style["foreground"])
  let color =
    style["foreground"] == nil
    ? rufletCanvasCGColor(parseColor(style["color"] as? String, .black)!)
    : foregroundPaint.color
  var attributes: [NSAttributedString.Key: Any] = [
    NSAttributedString.Key(kCTFontAttributeName as String): rufletCanvasFont(style),
    NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
  ]
  if let background = parseColor(style["bgcolor"] as? String) {
    attributes[.backgroundColor] = rufletCanvasPlatformColor(background)
  }
  if let spacing = parseDouble(style["letter_spacing"]) { attributes[.kern] = spacing }
  let decoration = parseInt(style["decoration"], 0)!
  if decoration & 0x1 > 0 {
    attributes[.underlineStyle] = rufletCanvasUnderlineStyle(style["decoration_style"] as? String)
  }
  if decoration & 0x4 > 0 {
    attributes[.strikethroughStyle] = rufletCanvasUnderlineStyle(
      style["decoration_style"] as? String)
  }
  if let decorationColor = parseColor(style["decoration_color"] as? String) {
    attributes[.underlineColor] = rufletCanvasPlatformColor(decorationColor)
    attributes[.strikethroughColor] = rufletCanvasPlatformColor(decorationColor)
  }
  if let thickness = parseDouble(style["decoration_thickness"]) {
    attributes[.strokeWidth] = -abs(thickness)
  }
  let shadowValue = rufletArray(style["shadow"])?.first ?? style["shadow"]
  if let shadowMap = rufletDictionary(shadowValue) {
    let shadow = NSShadow()
    let offset = rufletCanvasPoint(shadowMap["offset"]) ?? .zero
    shadow.shadowOffset = CGSize(width: offset.x, height: offset.y)
    shadow.shadowBlurRadius = CGFloat(parseDouble(shadowMap["blur_radius"], 0)!)
    if let color = parseColor(shadowMap["color"] as? String) {
      shadow.shadowColor = rufletCanvasPlatformColor(color)
    }
    attributes[.shadow] = shadow
  }
  return attributes
}

private func rufletCanvasLineHeight(_ value: Any?) -> CGFloat {
  let style = rufletDictionary(value) ?? [:]
  let size = CGFloat(parseDouble(style["size"], 14)!)
  return size * CGFloat(parseDouble(style["height"], 1.2)!)
}

private func rufletTruncatedCanvasText(
  _ source: NSAttributedString,
  maxWidth: CGFloat,
  maxLines: Int,
  ellipsis: String
) -> NSAttributedString {
  guard source.length > 0, maxWidth > 0, maxLines > 0 else { return source }
  let typesetter = CTTypesetterCreateWithAttributedString(source)
  var lineStart = 0
  var lastLineStart = 0
  for line in 0..<maxLines where lineStart < source.length {
    lastLineStart = lineStart
    let count = CTTypesetterSuggestLineBreak(typesetter, lineStart, Double(maxWidth))
    lineStart += max(count, 1)
    if line == maxLines - 1, lineStart >= source.length { return source }
  }
  guard lineStart < source.length || maxLines == 1 else { return source }
  let attributes = source.attributes(
    at: max(min(lineStart - 1, source.length - 1), 0),
    effectiveRange: nil)
  let suffix = NSAttributedString(string: ellipsis, attributes: attributes)
  var low = lastLineStart
  var high = min(lineStart, source.length)
  while low < high {
    let candidate = (low + high + 1) / 2
    let line = NSMutableAttributedString(
      attributedString: source.attributedSubstring(
        from: NSRange(location: lastLineStart, length: candidate - lastLineStart)))
    line.append(suffix)
    let width = CTLineGetTypographicBounds(CTLineCreateWithAttributedString(line), nil, nil, nil)
    if width <= Double(maxWidth) { low = candidate } else { high = candidate - 1 }
  }
  let result = NSMutableAttributedString(
    attributedString: source.attributedSubstring(from: NSRange(location: 0, length: low)))
  result.append(suffix)
  return result
}

private func rufletCanvasUnderlineStyle(_ value: String?) -> Int {
  switch value?.lowercased() {
  case "double": return NSUnderlineStyle.double.rawValue
  case "dotted": return NSUnderlineStyle.patternDot.rawValue
  case "dashed": return NSUnderlineStyle.patternDash.rawValue
  case "wavy": return NSUnderlineStyle.patternDashDot.rawValue
  default: return NSUnderlineStyle.single.rawValue
  }
}

#if os(iOS)
  private func rufletCanvasFont(_ style: [String: Any]) -> UIFont {
    let size = CGFloat(parseDouble(style["size"], 14)!)
    let weight: UIFont.Weight
    switch (style["weight"] as? String)?.lowercased() {
    case "bold", "w700": weight = .bold
    case "w100": weight = .ultraLight
    case "w200": weight = .thin
    case "w300": weight = .light
    case "w500": weight = .medium
    case "w600": weight = .semibold
    case "w800": weight = .heavy
    case "w900": weight = .black
    default: weight = .regular
    }
    var font =
      (style["font_family"] as? String).flatMap { UIFont(name: $0, size: size) }
      ?? UIFont.systemFont(ofSize: size, weight: weight)
    if parseBool(style["italic"], false) == true,
      let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic)
    {
      font = UIFont(descriptor: descriptor, size: size)
    }
    return font
  }

  private func rufletCanvasPlatformColor(_ color: Color) -> UIColor { UIColor(color) }
#elseif os(macOS)
  private func rufletCanvasFont(_ style: [String: Any]) -> NSFont {
    let size = CGFloat(parseDouble(style["size"], 14)!)
    let weight: NSFont.Weight
    switch (style["weight"] as? String)?.lowercased() {
    case "bold", "w700": weight = .bold
    case "w100": weight = .ultraLight
    case "w200": weight = .thin
    case "w300": weight = .light
    case "w500": weight = .medium
    case "w600": weight = .semibold
    case "w800": weight = .heavy
    case "w900": weight = .black
    default: weight = .regular
    }
    var font =
      (style["font_family"] as? String).flatMap { NSFont(name: $0, size: size) }
      ?? NSFont.systemFont(ofSize: size, weight: weight)
    if parseBool(style["italic"], false) == true {
      font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    }
    return font
  }

  private func rufletCanvasPlatformColor(_ color: Color) -> NSColor { NSColor(color) }
#endif

enum RufletCanvasTileMode: String {
  case clamp
  case repeated = "repeated"
  case mirror
  case decal
}

struct RufletCanvasGradient {
  enum Kind {
    case linear(begin: CGPoint, end: CGPoint)
    case radial(center: CGPoint, radius: CGFloat, focal: CGPoint?, focalRadius: CGFloat)
    case sweep(center: CGPoint, startAngle: CGFloat, endAngle: CGFloat, rotation: CGFloat)
  }

  let kind: Kind
  let colors: [CGColor]
  let stops: [CGFloat]
  let tileMode: RufletCanvasTileMode

  init?(_ value: Any?) {
    guard let value = rufletDictionary(value),
      let rawColors = rufletArray(value["colors"])
    else { return nil }
    colors = rawColors.compactMap { raw in
      parseColor(raw as? String).map(rufletCanvasCGColor)
    }
    guard colors.count > 1 else { return nil }
    let parsedStops = (rufletArray(value["color_stops"]) ?? []).compactMap {
      parseDouble($0).map { CGFloat($0) }
    }
    let colorCount = colors.count
    stops =
      parsedStops.count == colors.count
      ? parsedStops
      : (0..<colorCount).map { CGFloat($0) / CGFloat(colorCount - 1) }
    tileMode =
      RufletCanvasTileMode(
        rawValue: (value["tile_mode"] as? String)?.lowercased() ?? "clamp") ?? .clamp
    switch (value["_type"] as? String)?.lowercased() {
    case "linear":
      kind = .linear(
        begin: rufletCanvasPoint(value["begin"]) ?? .zero,
        end: rufletCanvasPoint(value["end"]) ?? .zero)
    case "radial":
      kind = .radial(
        center: rufletCanvasPoint(value["center"]) ?? .zero,
        radius: CGFloat(parseDouble(value["radius"], 0)!),
        focal: rufletCanvasPoint(value["focal"]),
        focalRadius: CGFloat(parseDouble(value["focal_radius"], 0)!))
    case "sweep":
      kind = .sweep(
        center: rufletCanvasPoint(value["center"]) ?? .zero,
        startAngle: CGFloat(parseDouble(value["start_angle"], 0)!),
        endAngle: CGFloat(parseDouble(value["end_angle"], 0)!),
        rotation: CGFloat(parseDouble(value["rotation"], 0)!))
    default:
      return nil
    }
  }
}

struct RufletCanvasPaint {
  let color: CGColor
  let blendMode: CGBlendMode
  let antiAlias: Bool
  let blurX: CGFloat
  let blurY: CGFloat
  let blurTileMode: RufletCanvasTileMode?
  let gradient: RufletCanvasGradient?
  let strokeMiterLimit: CGFloat
  let strokeWidth: CGFloat
  let strokeCap: CGLineCap
  let strokeJoin: CGLineJoin
  let style: RufletPaintingStyle
  let dashPattern: [CGFloat]
  let drawsSource: Bool

  init(_ value: Any?) {
    let value = rufletDictionary(value) ?? [:]
    color = rufletCanvasCGColor(parseColor(value["color"] as? String, .black)!)
    blendMode = rufletCanvasBlendMode(value["blend_mode"] as? String)
    drawsSource = (value["blend_mode"] as? String)?.lowercased() != "dst"
    antiAlias = parseBool(value["anti_alias"], true)!
    let blur = rufletCanvasBlur(value["blur_image"])
    blurX = blur.width
    blurY = blur.height
    blurTileMode = blur.tileMode
    gradient = RufletCanvasGradient(value["gradient"])
    strokeMiterLimit = CGFloat(parseDouble(value["stroke_miter_limit"], 4)!)
    strokeWidth = CGFloat(parseDouble(value["stroke_width"], 0)!)
    strokeCap = rufletCanvasLineCap(value["stroke_cap"] as? String)
    strokeJoin = rufletCanvasLineJoin(value["stroke_join"] as? String)
    style = parsePaintingStyle(value["style"] as? String, .fill)!
    dashPattern = (rufletArray(value["stroke_dash_pattern"]) ?? []).compactMap {
      parseDouble($0).map { CGFloat($0) }
    }
  }

  func prepare(_ context: CGContext) {
    context.setBlendMode(blendMode)
    context.setShouldAntialias(antiAlias)
    context.setAllowsAntialiasing(antiAlias)
    context.setLineWidth(strokeWidth)
    context.setMiterLimit(strokeMiterLimit)
    context.setLineCap(strokeCap)
    context.setLineJoin(strokeJoin)
    context.setLineDash(phase: 0, lengths: dashPattern)
    context.setFillColor(color)
    context.setStrokeColor(color)
    if max(blurX, blurY) > 0 {
      context.setShadow(offset: .zero, blur: max(blurX, blurY), color: color)
    }
  }
}

private struct RufletCanvasBlurSpec {
  let width: CGFloat
  let height: CGFloat
  let tileMode: RufletCanvasTileMode?
}

private func rufletCanvasBlur(_ value: Any?) -> RufletCanvasBlurSpec {
  if let number = parseDouble(value) {
    return RufletCanvasBlurSpec(width: number, height: number, tileMode: nil)
  }
  if let values = rufletArray(value) {
    let x = parseDouble(values.first, 0)!
    return RufletCanvasBlurSpec(
      width: x,
      height: parseDouble(values.count > 1 ? values[1] : x, x)!,
      tileMode: nil)
  }
  if let value = rufletDictionary(value) {
    return RufletCanvasBlurSpec(
      width: parseDouble(value["sigma_x"], 0)!,
      height: parseDouble(value["sigma_y"], 0)!,
      tileMode: (value["tile_mode"] as? String).flatMap(RufletCanvasTileMode.init(rawValue:)))
  }
  return RufletCanvasBlurSpec(width: 0, height: 0, tileMode: nil)
}

private func rufletCanvasBlendMode(_ value: String?) -> CGBlendMode {
  switch value?.lowercased() {
  case "clear": return .clear
  case "src": return .copy
  case "dst": return .destinationIn
  case "srcover": return .normal
  case "dstover": return .destinationOver
  case "srcin": return .sourceIn
  case "dstin": return .destinationIn
  case "srcout": return .sourceOut
  case "dstout": return .destinationOut
  case "srcatop": return .sourceAtop
  case "dstatop": return .destinationAtop
  case "xor": return .xor
  case "plus": return .plusLighter
  case "modulate", "multiply": return .multiply
  case "screen": return .screen
  case "overlay": return .overlay
  case "darken": return .darken
  case "lighten": return .lighten
  case "colordodge": return .colorDodge
  case "colorburn": return .colorBurn
  case "hardlight": return .hardLight
  case "softlight": return .softLight
  case "difference": return .difference
  case "exclusion": return .exclusion
  case "hue": return .hue
  case "saturation": return .saturation
  case "color": return .color
  case "luminosity": return .luminosity
  default: return .normal
  }
}

private func rufletCanvasLineCap(_ value: String?) -> CGLineCap {
  switch value?.lowercased() {
  case "round": return .round
  case "square": return .square
  default: return .butt
  }
}

private func rufletCanvasLineJoin(_ value: String?) -> CGLineJoin {
  switch value?.lowercased() {
  case "round": return .round
  case "bevel": return .bevel
  default: return .miter
  }
}

private func rufletCanvasPoint(_ value: Any?) -> CGPoint? {
  if let values = rufletArray(value), values.count > 1 {
    return CGPoint(x: parseDouble(values[0], 0)!, y: parseDouble(values[1], 0)!)
  }
  guard let value = rufletDictionary(value) else { return nil }
  return CGPoint(x: parseDouble(value["x"], 0)!, y: parseDouble(value["y"], 0)!)
}

private func rufletCanvasCGColor(_ color: Color) -> CGColor {
  #if os(iOS)
    UIColor(color).cgColor
  #elseif os(macOS)
    (NSColor(color).usingColorSpace(.deviceRGB) ?? .black).cgColor
  #endif
}

@MainActor
public struct CanvasControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var coordinator = RufletCanvasCoordinator()
  @State private var invokeToken: UUID?

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      GeometryReader { proxy in
        ZStack(alignment: .topLeading) {
          RufletCanvasNativeView(control: control, coordinator: coordinator)
          if let content = control.buildWidget("content") { content }
        }
        .onAppear { sizeChanged(proxy.size) }
        .onChange(of: proxy.size, perform: sizeChanged)
      }
    }
    .onAppear(perform: attach)
    .onDisappear(perform: detach)
  }

  private func attach() {
    coordinator.attach(control: control)
    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { name, arguments in
      try await coordinator.invoke(name, arguments: arguments)
    }
  }

  private func detach() {
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
    coordinator.detach()
  }

  private func sizeChanged(_ size: CGSize) {
    coordinator.updateSize(
      size,
      resizeIntervalMilliseconds: control.integer("resize_interval", default: 10) ?? 10)
  }
}

enum RufletCanvasError: Error, Equatable {
  case invalidPixelRatio
  case unknownMethod(String)
}

struct RufletCanvasResizeTracker {
  private(set) var lastSize = CGSize.zero
  private(set) var lastResizeMilliseconds = ProcessInfo.processInfo.systemUptime * 1_000

  mutating func update(
    size: CGSize,
    nowMilliseconds: TimeInterval,
    intervalMilliseconds: Int
  ) -> Bool {
    let shouldReport =
      lastSize == .zero
      || (lastSize != size
        && nowMilliseconds - lastResizeMilliseconds > Double(intervalMilliseconds))
    guard shouldReport else { return false }
    lastSize = size
    lastResizeMilliseconds = nowMilliseconds
    return true
  }
}

@MainActor
final class RufletCanvasCoordinator: ObservableObject {
  struct CachedImage {
    let hash: UInt32
    let image: CGImage
  }

  private weak var control: RufletControl?
  private var controlUpdateToken: UUID?
  private(set) var shapes: [RufletControl] = []
  private(set) var images: [Int: CachedImage] = [:]
  private var imageTasks: [Int: Task<Void, Never>] = [:]
  private var invalidationHandler: (() -> Void)?
  private var resizeTracker = RufletCanvasResizeTracker()
  private(set) var canvasSize = CGSize.zero
  private(set) var capturedImage: CGImage?
  private(set) var capturedSize = CGSize.zero

  func attach(control: RufletControl) {
    if self.control !== control {
      if let controlUpdateToken, let currentControl = self.control {
        currentControl.removeListener(controlUpdateToken)
      }
      self.control = control
      controlUpdateToken = control.addListener { [weak self] in
        guard let self, let control = self.control else { return }
        self.configure(control: control)
        self.invalidationHandler?()
      }
    }
    configure(control: control)
  }

  func configure(control: RufletControl) {
    self.control = control
    shapes = control.children("shapes")
    for shape in shapes { shape.notifyParent = true }
    synchronizeImages()
  }

  func installInvalidationHandler(_ handler: @escaping () -> Void) {
    invalidationHandler = handler
  }

  func detach() {
    if let controlUpdateToken, let control { control.removeListener(controlUpdateToken) }
    controlUpdateToken = nil
    invalidationHandler = nil
    for task in imageTasks.values { task.cancel() }
    imageTasks.removeAll()
  }

  func updateSize(_ size: CGSize, resizeIntervalMilliseconds: Int) {
    canvasSize = size
    guard size.width > 0, size.height > 0,
      resizeTracker.update(
        size: size,
        nowMilliseconds: ProcessInfo.processInfo.systemUptime * 1_000,
        intervalMilliseconds: resizeIntervalMilliseconds)
    else { return }
    control?.triggerEvent("resize", data: ["w": .double(size.width), "h": .double(size.height)])
  }

  func invoke(_ name: String, arguments: RufletValue) async throws -> RufletValue {
    switch name {
    case "capture":
      guard canvasSize.width > 0, canvasSize.height > 0, !shapes.isEmpty else { return .null }
      configureIfPossible()
      await awaitImageLoads()
      let ratio = arguments.map?["pixel_ratio"]?.number ?? defaultApplePixelRatio()
      guard ratio > 0 else { throw RufletCanvasError.invalidPixelRatio }
      guard
        let image = RufletCanvasRenderer.makeImage(
          size: canvasSize,
          pixelRatio: CGFloat(ratio),
          shapes: shapes,
          images: images,
          capturedImage: capturedImage,
          capturedSize: capturedSize)
      else { return .null }
      capturedImage = image
      capturedSize = canvasSize
      invalidationHandler?()
      return .null
    case "get_capture":
      return capturedImage.flatMap(rufletCanvasPNGData).map(RufletValue.binary) ?? .null
    case "clear_capture":
      capturedImage = nil
      capturedSize = .zero
      invalidationHandler?()
      return .null
    default:
      throw RufletCanvasError.unknownMethod(name)
    }
  }

  func render(in context: CGContext, size: CGSize) {
    configureIfPossible()
    canvasSize = size
    RufletCanvasRenderer.draw(
      in: context,
      size: size,
      shapes: shapes,
      images: images,
      capturedImage: capturedImage,
      capturedSize: capturedSize)
  }

  private func configureIfPossible() {
    if let control { configure(control: control) }
  }

  private func synchronizeImages() {
    let imageShapes = shapes.filter { $0.type == "Image" }
    let validIDs = Set(imageShapes.map(\.id))
    images = images.filter { validIDs.contains($0.key) }
    let obsoleteTaskIDs = imageTasks.keys.filter { !validIDs.contains($0) }
    for id in obsoleteTaskIDs {
      imageTasks.removeValue(forKey: id)?.cancel()
    }
    for shape in imageShapes {
      guard let sourceValue = shape.value("src") else {
        images.removeValue(forKey: shape.id)
        continue
      }
      let hash = rufletCanvasImageHash(sourceValue)
      guard images[shape.id]?.hash != hash, imageTasks[shape.id] == nil,
        let source = parseImageSource(rufletAny(sourceValue), backend: shape.backend)
      else { continue }
      let shapeID = shape.id
      imageTasks[shapeID] = Task { [weak self] in
        let image = await rufletLoadCanvasCGImage(source)
        guard !Task.isCancelled, let self else { return }
        if let image { self.images[shapeID] = CachedImage(hash: hash, image: image) }
        self.imageTasks.removeValue(forKey: shapeID)
        self.invalidationHandler?()
      }
    }
  }

  private func awaitImageLoads() async {
    let tasks = Array(imageTasks.values)
    for task in tasks { await task.value }
  }
}

@MainActor
private func rufletLoadCanvasCGImage(_ source: RufletImageSource) async -> CGImage? {
  do {
    let data: Data
    switch source {
    case .data(let value): data = value
    case .url(let url) where url.isFileURL: data = try Data(contentsOf: url)
    case .url(let url):
      let (value, response) = try await URLSession.shared.data(from: url)
      guard (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) != false else {
        return nil
      }
      data = value
    }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
  } catch {
    return nil
  }
}

func rufletCanvasImageHash(_ value: RufletValue) -> UInt32 {
  switch value {
  case .binary(let data): return fnv1aHash(Array(data))
  case .string(let value): return fnv1aHash(Array(value.utf8))
  default: return fnv1aHash(Array(rufletStableValueDescription(value).utf8))
  }
}

private func rufletCanvasPNGData(_ image: CGImage) -> Data? {
  let data = NSMutableData()
  guard
    let destination = CGImageDestinationCreateWithData(
      data,
      UTType.png.identifier as CFString,
      1,
      nil)
  else { return nil }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else { return nil }
  return data as Data
}

#if os(iOS)
  private struct RufletCanvasNativeView: UIViewRepresentable {
    let control: RufletControl
    let coordinator: RufletCanvasCoordinator

    func makeUIView(context: Context) -> RufletCanvasUIView {
      let view = RufletCanvasUIView()
      view.coordinator = coordinator
      coordinator.installInvalidationHandler { [weak view] in view?.setNeedsDisplay() }
      return view
    }

    func updateUIView(_ view: RufletCanvasUIView, context: Context) {
      coordinator.configure(control: control)
      view.setNeedsDisplay()
    }
  }

  private final class RufletCanvasUIView: UIView {
    weak var coordinator: RufletCanvasCoordinator?

    override init(frame: CGRect) {
      super.init(frame: frame)
      backgroundColor = .clear
      isOpaque = false
      isUserInteractionEnabled = false
      contentMode = .redraw
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ rect: CGRect) {
      guard let context = UIGraphicsGetCurrentContext() else { return }
      coordinator?.render(in: context, size: bounds.size)
    }
  }
#elseif os(macOS)
  private struct RufletCanvasNativeView: NSViewRepresentable {
    let control: RufletControl
    let coordinator: RufletCanvasCoordinator

    func makeNSView(context: Context) -> RufletCanvasNSView {
      let view = RufletCanvasNSView()
      view.coordinator = coordinator
      coordinator.installInvalidationHandler { [weak view] in view?.needsDisplay = true }
      return view
    }

    func updateNSView(_ view: RufletCanvasNSView, context: Context) {
      coordinator.configure(control: control)
      view.needsDisplay = true
    }
  }

  private final class RufletCanvasNSView: NSView {
    weak var coordinator: RufletCanvasCoordinator?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
      super.draw(dirtyRect)
      guard let context = NSGraphicsContext.current?.cgContext else { return }
      coordinator?.render(in: context, size: bounds.size)
    }
  }
#endif
