import RufletEngine
import RufletProtocol
import SwiftUI

struct SpinKitControl: View {
  @ObservedObject var control: RufletControl

  private var color: Color { parseColor(control.string("color")) ?? .accentColor }
  private var size: CGFloat { CGFloat(control.number("size", default: 50) ?? 50) }
  private var duration: TimeInterval {
    Self.duration(control.value("duration")) ?? defaultDuration
  }

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
      Canvas { graphics, canvasSize in
        let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration) / duration
        draw(context: &graphics, size: canvasSize, phase: phase)
      }
    }
    .frame(width: size, height: size)
    .accessibilityLabel("Loading")
  }

  private func draw(context: inout GraphicsContext, size: CGSize, phase: Double) {
    switch control.type {
    case "SpinKitRing", "SpinKitDualRing", "SpinKitRotatingCircle", "SpinKitWaveSpinner":
      ring(context: &context, size: size, phase: phase, dual: control.type == "SpinKitDualRing")
    case "SpinKitRipple":
      ripple(context: &context, size: size, phase: phase)
    case "SpinKitWave", "SpinKitPianoWave", "SpinKitSpinningLines":
      wave(context: &context, size: size, phase: phase)
    case "SpinKitCubeGrid", "SpinKitFadingGrid", "SpinKitPulsingGrid":
      grid(context: &context, size: size, phase: phase)
    case "SpinKitCircle", "SpinKitFadingCircle", "SpinKitSpinningCircle":
      circle(context: &context, size: size, phase: phase)
    case "SpinKitDoubleBounce", "SpinKitPulse", "SpinKitPumpingHeart":
      pulse(context: &context, size: size, phase: phase)
    case "SpinKitChasingDots", "SpinKitThreeBounce", "SpinKitThreeInOut":
      dots(context: &context, size: size, phase: phase)
    case "SpinKitHourGlass", "SpinKitPouringHourGlass", "SpinKitPouringHourGlassRefined":
      hourglass(context: &context, size: size, phase: phase)
    default:
      rotatingSquares(context: &context, size: size, phase: phase)
    }
  }

  private func ring(context: inout GraphicsContext, size: CGSize, phase: Double, dual: Bool) {
    let lineWidth = CGFloat(control.number("line_width", default: 7) ?? 7)
    let inset = lineWidth / 2 + 1
    let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
    let start = Angle.degrees(phase * 360 - 90)
    var path = Path()
    path.addArc(center: CGPoint(x: size.width / 2, y: size.height / 2), radius: rect.width / 2,
      startAngle: start, endAngle: start + .degrees(dual ? 125 : 260), clockwise: false)
    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    if dual {
      var second = Path()
      second.addArc(center: CGPoint(x: size.width / 2, y: size.height / 2), radius: rect.width / 2,
        startAngle: start + .degrees(180), endAngle: start + .degrees(305), clockwise: false)
      context.stroke(second, with: .color(color.opacity(0.55)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
  }

  private func ripple(context: inout GraphicsContext, size: CGSize, phase: Double) {
    let border = CGFloat(control.number("border_width", default: 6) ?? 6)
    for offset in [0.0, 0.5] {
      let p = (phase + offset).truncatingRemainder(dividingBy: 1)
      let radius = CGFloat(p) * min(size.width, size.height) / 2
      let rect = CGRect(x: size.width / 2 - radius, y: size.height / 2 - radius, width: radius * 2, height: radius * 2)
      context.opacity = 1 - p
      context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: border)
    }
    context.opacity = 1
  }

  private func wave(context: inout GraphicsContext, size: CGSize, phase: Double) {
    let count = max(1, control.integer("item_count", default: 5) ?? 5)
    let gap: CGFloat = 2
    let width = (size.width - CGFloat(count - 1) * gap) / CGFloat(count)
    for index in 0 ..< count {
      let value = 0.25 + 0.75 * abs(sin((phase + Double(index) / Double(count)) * .pi))
      let height = size.height * CGFloat(value)
      let rect = CGRect(x: CGFloat(index) * (width + gap), y: (size.height - height) / 2, width: width, height: height)
      context.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(color))
    }
  }

  private func grid(context: inout GraphicsContext, size: CGSize, phase: Double) {
    let gap: CGFloat = 2
    let unit = (min(size.width, size.height) - gap * 2) / 3
    for row in 0 ..< 3 {
      for column in 0 ..< 3 {
        let index = row * 3 + column
        let scale = 0.35 + 0.65 * abs(sin((phase + Double(index) / 9) * .pi))
        let side = unit * CGFloat(scale)
        let center = CGPoint(x: CGFloat(column) * (unit + gap) + unit / 2, y: CGFloat(row) * (unit + gap) + unit / 2)
        context.fill(Path(roundedRect: CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side), cornerRadius: 2), with: .color(color))
      }
    }
  }

  private func circle(context: inout GraphicsContext, size: CGSize, phase: Double) {
    let count = 12
    let radius = min(size.width, size.height) * 0.38
    let dot = min(size.width, size.height) * 0.065
    for index in 0 ..< count {
      let angle = Double(index) / Double(count) * 2 * .pi
      let p = (phase + Double(index) / Double(count)).truncatingRemainder(dividingBy: 1)
      let center = CGPoint(x: size.width / 2 + cos(angle) * radius, y: size.height / 2 + sin(angle) * radius)
      context.fill(Path(ellipseIn: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2)), with: .color(color.opacity(0.2 + 0.8 * p)))
    }
  }

  private func pulse(context: inout GraphicsContext, size: CGSize, phase: Double) {
    let scale = 0.3 + 0.7 * abs(sin(phase * .pi))
    let diameter = min(size.width, size.height) * CGFloat(scale)
    let rect = CGRect(x: (size.width - diameter) / 2, y: (size.height - diameter) / 2, width: diameter, height: diameter)
    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(1 - phase * 0.35)))
  }

  private func dots(context: inout GraphicsContext, size: CGSize, phase: Double) {
    let count = control.type == "SpinKitChasingDots" ? 2 : 3
    let dot = min(size.width, size.height) / CGFloat(count * 2)
    for index in 0 ..< count {
      let angle = (phase + Double(index) / Double(count)) * 2 * .pi
      let radius = min(size.width, size.height) * 0.28
      let center = control.type == "SpinKitChasingDots"
        ? CGPoint(x: size.width / 2 + cos(angle) * radius, y: size.height / 2 + sin(angle) * radius)
        : CGPoint(x: CGFloat(index + 1) * size.width / CGFloat(count + 1), y: size.height / 2)
      let scale = control.type == "SpinKitChasingDots" ? 1 : 0.45 + 0.55 * abs(sin((phase + Double(index) / Double(count)) * .pi))
      let radiusDot = dot * CGFloat(scale)
      context.fill(Path(ellipseIn: CGRect(x: center.x - radiusDot, y: center.y - radiusDot, width: radiusDot * 2, height: radiusDot * 2)), with: .color(color))
    }
  }

  private func hourglass(context: inout GraphicsContext, size: CGSize, phase: Double) {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    var path = Path()
    path.move(to: CGPoint(x: size.width * 0.2, y: size.height * 0.1))
    path.addLine(to: CGPoint(x: size.width * 0.8, y: size.height * 0.1))
    path.addLine(to: center)
    path.addLine(to: CGPoint(x: size.width * 0.8, y: size.height * 0.9))
    path.addLine(to: CGPoint(x: size.width * 0.2, y: size.height * 0.9))
    path.addLine(to: center)
    path.closeSubpath()
    var transformed = context
    transformed.translateBy(x: center.x, y: center.y)
    transformed.rotate(by: .degrees(phase * 360))
    transformed.translateBy(x: -center.x, y: -center.y)
    transformed.fill(path, with: .color(color))
  }

  private func rotatingSquares(context: inout GraphicsContext, size: CGSize, phase: Double) {
    let side = min(size.width, size.height) * 0.48
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    var transformed = context
    transformed.translateBy(x: center.x, y: center.y)
    transformed.rotate(by: .degrees(phase * 360))
    transformed.translateBy(x: -center.x, y: -center.y)
    transformed.fill(Path(roundedRect: CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side), cornerRadius: side * 0.12), with: .color(color))
  }

  private var defaultDuration: TimeInterval {
    switch control.type {
    case "SpinKitDoubleBounce", "SpinKitChasingDots": 2
    case "SpinKitWanderingCubes": 1.8
    case "SpinKitPulse", "SpinKitPumpingHeart": 1
    case "SpinKitThreeBounce": 1.4
    case "SpinKitFoldingCube", "SpinKitPouringHourGlass", "SpinKitPouringHourGlassRefined": 2.4
    case "SpinKitRipple": 1.8
    case "SpinKitSquareCircle": 0.5
    case "SpinKitThreeInOut": 1.5
    default: 1.2
    }
  }

  private static func duration(_ value: RufletValue?) -> TimeInterval? {
    guard let value else { return nil }
    if let milliseconds = value.number { return milliseconds / 1_000 }
    guard let map = value.map else { return nil }
    return (map["seconds"]?.number ?? 0)
      + (map["milliseconds"]?.number ?? 0) / 1_000
      + (map["microseconds"]?.number ?? 0) / 1_000_000
  }
}
