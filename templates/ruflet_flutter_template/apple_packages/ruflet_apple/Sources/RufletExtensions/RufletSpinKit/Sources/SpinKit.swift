import RufletEngine
import RufletProtocol
import SwiftUI

private enum SpinKitVariant: String {
  case rotatingPlain = "SpinKitRotatingPlain"
  case doubleBounce = "SpinKitDoubleBounce"
  case wave = "SpinKitWave"
  case wanderingCubes = "SpinKitWanderingCubes"
  case fadingFour = "SpinKitFadingFour"
  case fadingCube = "SpinKitFadingCube"
  case pulse = "SpinKitPulse"
  case chasingDots = "SpinKitChasingDots"
  case threeBounce = "SpinKitThreeBounce"
  case circle = "SpinKitCircle"
  case cubeGrid = "SpinKitCubeGrid"
  case fadingCircle = "SpinKitFadingCircle"
  case rotatingCircle = "SpinKitRotatingCircle"
  case foldingCube = "SpinKitFoldingCube"
  case pumpingHeart = "SpinKitPumpingHeart"
  case hourGlass = "SpinKitHourGlass"
  case pouringHourGlass = "SpinKitPouringHourGlass"
  case pouringHourGlassRefined = "SpinKitPouringHourGlassRefined"
  case fadingGrid = "SpinKitFadingGrid"
  case ring = "SpinKitRing"
  case ripple = "SpinKitRipple"
  case dualRing = "SpinKitDualRing"
  case spinningCircle = "SpinKitSpinningCircle"
  case spinningLines = "SpinKitSpinningLines"
  case squareCircle = "SpinKitSquareCircle"
  case threeInOut = "SpinKitThreeInOut"
  case dancingSquare = "SpinKitDancingSquare"
  case pianoWave = "SpinKitPianoWave"
  case pulsingGrid = "SpinKitPulsingGrid"
  case waveSpinner = "SpinKitWaveSpinner"
}

struct SpinKitControl: View {
  @ObservedObject var control: RufletControl

  private var color: Color { parseColor(control.string("color")) ?? .accentColor }
  private var size: CGFloat { CGFloat(control.number("size", default: 50) ?? 50) }
  private var variant: SpinKitVariant {
    let variant = control.string("variant")
    guard
      let type = RufletSpinKit.resolvedControlType(
        controlType: control.type,
        variant: variant),
      let result = SpinKitVariant(rawValue: type)
    else {
      preconditionFailure("Unsupported RufletSpinKit variant: \(variant ?? "nil")")
    }
    return result
  }
  private var duration: TimeInterval {
    max(Self.duration(control.value("duration")) ?? defaultDuration, 0.001)
  }

  var body: some View {
    LayoutControl(control: control) {
      TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
        Canvas { graphics, canvasSize in
          let phase =
            context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration)
            / duration
          draw(context: &graphics, size: canvasSize, phase: phase)
        }
      }
      .frame(width: size, height: size)
      .accessibilityLabel("Loading")
    }
  }

  private func draw(context: inout GraphicsContext, size: CGSize, phase: Double) {
    switch variant {
    case .rotatingPlain:
      rotatingShape(context: &context, size: size, phase: phase, circle: false)
    case .doubleBounce:
      doubleBounce(context: &context, size: size, phase: phase)
    case .wave:
      wave(context: &context, size: size, phase: phase, horizontalScale: false)
    case .wanderingCubes:
      wanderingCubes(context: &context, size: size, phase: phase)
    case .fadingFour:
      fadingFour(context: &context, size: size, phase: phase)
    case .fadingCube:
      fadingCube(context: &context, size: size, phase: phase)
    case .pulse:
      pulse(context: &context, size: size, phase: phase, heart: false)
    case .chasingDots:
      dots(context: &context, size: size, phase: phase, chasing: true, fading: false)
    case .threeBounce:
      dots(context: &context, size: size, phase: phase, chasing: false, fading: false)
    case .circle:
      orbitItems(context: &context, size: size, phase: phase, square: false, fades: false)
    case .cubeGrid:
      grid(context: &context, size: size, phase: phase, circles: false, fades: false)
    case .fadingCircle:
      orbitItems(context: &context, size: size, phase: phase, square: false, fades: true)
    case .rotatingCircle:
      rotatingShape(context: &context, size: size, phase: phase, circle: true)
    case .foldingCube:
      foldingCube(context: &context, size: size, phase: phase)
    case .pumpingHeart:
      pulse(context: &context, size: size, phase: phase, heart: true)
    case .hourGlass:
      hourglass(context: &context, size: size, phase: phase, pouring: false, refined: false)
    case .pouringHourGlass:
      hourglass(context: &context, size: size, phase: phase, pouring: true, refined: false)
    case .pouringHourGlassRefined:
      hourglass(context: &context, size: size, phase: phase, pouring: true, refined: true)
    case .fadingGrid:
      grid(context: &context, size: size, phase: phase, circles: true, fades: true)
    case .ring:
      ring(context: &context, size: size, phase: phase, dual: false)
    case .ripple:
      ripple(context: &context, size: size, phase: phase)
    case .dualRing:
      ring(context: &context, size: size, phase: phase, dual: true)
    case .spinningCircle:
      spinningCircle(context: &context, size: size, phase: phase)
    case .spinningLines:
      spinningLines(context: &context, size: size, phase: phase)
    case .squareCircle:
      squareCircle(context: &context, size: size, phase: phase)
    case .threeInOut:
      dots(context: &context, size: size, phase: phase, chasing: false, fading: true)
    case .dancingSquare:
      orbitItems(context: &context, size: size, phase: phase, square: true, fades: false)
    case .pianoWave:
      wave(context: &context, size: size, phase: phase, horizontalScale: true)
    case .pulsingGrid:
      grid(context: &context, size: size, phase: phase, circles: true, fades: false)
    case .waveSpinner:
      waveSpinner(context: &context, size: size, phase: phase)
    }
  }

  private func ring(context: inout GraphicsContext, size: CGSize, phase: Double, dual: Bool) {
    let lineWidth = CGFloat(control.number("line_width", default: 7) ?? 7)
    let inset = lineWidth / 2 + 1
    let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
    let start = Angle.degrees(phase * 360 - 90)
    var path = Path()
    path.addArc(
      center: CGPoint(x: size.width / 2, y: size.height / 2), radius: rect.width / 2,
      startAngle: start, endAngle: start + .degrees(dual ? 125 : 260), clockwise: false)
    context.stroke(
      path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    if dual {
      var second = Path()
      second.addArc(
        center: CGPoint(x: size.width / 2, y: size.height / 2), radius: rect.width / 2,
        startAngle: start + .degrees(180), endAngle: start + .degrees(305), clockwise: false)
      context.stroke(
        second, with: .color(color.opacity(0.55)),
        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
  }

  private func rotatingShape(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double,
    circle: Bool
  ) {
    let side = min(size.width, size.height) * 0.72
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    var transformed = context
    transformed.translateBy(x: center.x, y: center.y)
    transformed.rotate(by: .degrees(phase * 360))
    transformed.translateBy(x: -center.x, y: -center.y)
    let rect = CGRect(
      x: center.x - side / 2,
      y: center.y - side / 2,
      width: side,
      height: side)
    transformed.fill(circle ? Path(ellipseIn: rect) : Path(rect), with: .color(color))
  }

  private func doubleBounce(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double
  ) {
    for offset in [0.0, 0.5] {
      let scale = abs(sin((phase + offset) * .pi))
      let diameter = min(size.width, size.height) * CGFloat(scale)
      let rect = CGRect(
        x: (size.width - diameter) / 2,
        y: (size.height - diameter) / 2,
        width: diameter,
        height: diameter)
      context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.6)))
    }
  }

  private func ripple(context: inout GraphicsContext, size: CGSize, phase: Double) {
    let border = CGFloat(control.number("border_width", default: 6) ?? 6)
    for offset in [0.0, 0.5] {
      let p = (phase + offset).truncatingRemainder(dividingBy: 1)
      let radius = CGFloat(p) * min(size.width, size.height) / 2
      let rect = CGRect(
        x: size.width / 2 - radius, y: size.height / 2 - radius, width: radius * 2,
        height: radius * 2)
      context.opacity = 1 - p
      context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: border)
    }
    context.opacity = 1
  }

  private func wave(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double,
    horizontalScale: Bool
  ) {
    let count = max(2, control.integer("item_count", default: 5) ?? 5)
    let waveType = control.string("wave_type") ?? "start"
    let gap: CGFloat = 2
    let width = (size.width - CGFloat(count - 1) * gap) / CGFloat(count)
    for index in 0..<count {
      let waveIndex: Int
      switch waveType {
      case "end":
        waveIndex = count - index - 1
      case "center":
        waveIndex = abs(index * 2 - (count - 1))
      default:
        waveIndex = index
      }
      let value =
        0.25 + 0.75 * abs(sin((phase + Double(waveIndex) / Double(count)) * .pi))
      let height = horizontalScale ? size.height : size.height * CGFloat(value)
      let barWidth = horizontalScale ? width * CGFloat(value) : width
      let rect = CGRect(
        x: CGFloat(index) * (width + gap) + (width - barWidth) / 2,
        y: (size.height - height) / 2,
        width: barWidth,
        height: height)
      context.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(color))
    }
  }

  private func wanderingCubes(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double
  ) {
    let unit = min(size.width, size.height) * 0.28
    let travel = min(size.width, size.height) - unit
    for offset in [0.0, 0.5] {
      let progress = (phase + offset).truncatingRemainder(dividingBy: 1)
      let segment = progress * 4
      let point: CGPoint
      switch segment {
      case 0..<1: point = CGPoint(x: CGFloat(segment) * travel, y: 0)
      case 1..<2: point = CGPoint(x: travel, y: CGFloat(segment - 1) * travel)
      case 2..<3: point = CGPoint(x: CGFloat(3 - segment) * travel, y: travel)
      default: point = CGPoint(x: 0, y: CGFloat(4 - segment) * travel)
      }
      let scale = 0.55 + 0.45 * abs(sin(progress * .pi * 2))
      let side = unit * CGFloat(scale)
      var transformed = context
      transformed.translateBy(x: point.x + unit / 2, y: point.y + unit / 2)
      transformed.rotate(by: .degrees(progress * 360))
      transformed.translateBy(x: -(point.x + unit / 2), y: -(point.y + unit / 2))
      transformed.fill(
        Path(
          CGRect(
            x: point.x + (unit - side) / 2,
            y: point.y + (unit - side) / 2,
            width: side,
            height: side)),
        with: .color(color))
    }
  }

  private func fadingFour(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double
  ) {
    let radius = min(size.width, size.height) * 0.26
    let dot = min(size.width, size.height) * 0.16
    for index in 0..<4 {
      let angle = Double(index) / 4 * 2 * .pi + phase * 2 * .pi
      let opacity = 0.15 + 0.85 * positiveRemainder(phase + Double(index) / 4)
      let center = polarPoint(in: size, radius: radius, angle: angle)
      context.fill(
        Path(
          ellipseIn: CGRect(
            x: center.x - dot / 2,
            y: center.y - dot / 2,
            width: dot,
            height: dot)),
        with: .color(color.opacity(opacity)))
    }
  }

  private func fadingCube(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double
  ) {
    let side = min(size.width, size.height) * 0.28
    let inset = side * 0.2
    let centers = [
      CGPoint(x: side / 2 + inset, y: side / 2 + inset),
      CGPoint(x: size.width - side / 2 - inset, y: side / 2 + inset),
      CGPoint(x: size.width - side / 2 - inset, y: size.height - side / 2 - inset),
      CGPoint(x: side / 2 + inset, y: size.height - side / 2 - inset),
    ]
    var transformed = context
    transformed.translateBy(x: size.width / 2, y: size.height / 2)
    transformed.rotate(by: .degrees(phase * 90))
    transformed.translateBy(x: -size.width / 2, y: -size.height / 2)
    for (index, center) in centers.enumerated() {
      let opacity = 0.15 + 0.85 * positiveRemainder(phase + Double(index) / 4)
      transformed.fill(
        Path(
          CGRect(
            x: center.x - side / 2,
            y: center.y - side / 2,
            width: side,
            height: side)),
        with: .color(color.opacity(opacity)))
    }
  }

  private func grid(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double,
    circles: Bool,
    fades: Bool
  ) {
    let gap: CGFloat = 2
    let unit = (min(size.width, size.height) - gap * 2) / 3
    for row in 0..<3 {
      for column in 0..<3 {
        let index = row * 3 + column
        let progress = positiveRemainder(phase + Double(index) / 9)
        let scale = fades ? 1 : 0.35 + 0.65 * abs(sin(progress * .pi))
        let side = unit * CGFloat(scale)
        let center = CGPoint(
          x: CGFloat(column) * (unit + gap) + unit / 2,
          y: CGFloat(row) * (unit + gap) + unit / 2)
        let rect = CGRect(
          x: center.x - side / 2,
          y: center.y - side / 2,
          width: side,
          height: side)
        context.fill(
          circles ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 2),
          with: .color(color.opacity(fades ? 0.15 + 0.85 * progress : 1)))
      }
    }
  }

  private func orbitItems(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double,
    square: Bool,
    fades: Bool
  ) {
    let count = 12
    let radius = min(size.width, size.height) * 0.38
    let dot = min(size.width, size.height) * 0.065
    for index in 0..<count {
      let angle = Double(index) / Double(count) * 2 * .pi
      let progress = positiveRemainder(phase + Double(index) / Double(count))
      let center = polarPoint(in: size, radius: radius, angle: angle)
      let scale = fades ? 1 : 0.25 + 0.75 * abs(sin(progress * .pi))
      let diameter = dot * 2 * CGFloat(scale)
      let rect = CGRect(
        x: center.x - diameter / 2,
        y: center.y - diameter / 2,
        width: diameter,
        height: diameter)
      context.fill(
        square ? Path(rect) : Path(ellipseIn: rect),
        with: .color(color.opacity(fades ? 0.15 + 0.85 * progress : 1)))
    }
  }

  private func pulse(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double,
    heart: Bool
  ) {
    let scale = heart ? 0.78 + 0.22 * abs(sin(phase * 2 * .pi)) : 0.3 + 0.7 * phase
    let diameter = min(size.width, size.height) * CGFloat(scale)
    let rect = CGRect(
      x: (size.width - diameter) / 2,
      y: (size.height - diameter) / 2,
      width: diameter,
      height: diameter)
    context.fill(
      heart ? heartPath(in: rect) : Path(ellipseIn: rect),
      with: .color(color.opacity(heart ? 1 : 1 - phase * 0.7)))
  }

  private func dots(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double,
    chasing: Bool,
    fading: Bool
  ) {
    let count = chasing ? 2 : 3
    let dot = min(size.width, size.height) / CGFloat(count * 2)
    for index in 0..<count {
      let angle = (phase + Double(index) / Double(count)) * 2 * .pi
      let radius = min(size.width, size.height) * 0.28
      let center =
        chasing
        ? CGPoint(x: size.width / 2 + cos(angle) * radius, y: size.height / 2 + sin(angle) * radius)
        : CGPoint(x: CGFloat(index + 1) * size.width / CGFloat(count + 1), y: size.height / 2)
      let progress = positiveRemainder(phase + Double(index) / Double(count))
      let scale =
        chasing ? 0.35 + 0.65 * abs(sin(progress * .pi)) : 0.45 + 0.55 * abs(sin(progress * .pi))
      let radiusDot = dot * CGFloat(scale)
      context.fill(
        Path(
          ellipseIn: CGRect(
            x: center.x - radiusDot,
            y: center.y - radiusDot,
            width: radiusDot * 2,
            height: radiusDot * 2)),
        with: .color(color.opacity(fading ? 0.15 + 0.85 * progress : 1)))
    }
  }

  private func foldingCube(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double
  ) {
    let unit = min(size.width, size.height) * 0.42
    let origin = CGPoint(x: (size.width - unit * 2) / 2, y: (size.height - unit * 2) / 2)
    var transformed = context
    transformed.translateBy(x: size.width / 2, y: size.height / 2)
    transformed.rotate(by: .degrees(45))
    transformed.translateBy(x: -size.width / 2, y: -size.height / 2)
    for index in 0..<4 {
      let row = index / 2
      let column = index % 2
      let progress = positiveRemainder(phase + Double(index) / 4)
      let scale = abs(cos(progress * .pi))
      let rect = CGRect(
        x: origin.x + CGFloat(column) * unit,
        y: origin.y + CGFloat(row) * unit + unit * CGFloat(1 - scale) / 2,
        width: unit,
        height: unit * CGFloat(scale))
      transformed.fill(Path(rect), with: .color(color.opacity(0.25 + 0.75 * scale)))
    }
  }

  private func hourglass(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double,
    pouring: Bool,
    refined: Bool
  ) {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    var path = Path()
    path.move(to: CGPoint(x: size.width * 0.2, y: size.height * 0.1))
    path.addLine(to: CGPoint(x: size.width * 0.8, y: size.height * 0.1))
    path.addLine(to: center)
    path.addLine(to: CGPoint(x: size.width * 0.8, y: size.height * 0.9))
    path.addLine(to: CGPoint(x: size.width * 0.2, y: size.height * 0.9))
    path.addLine(to: center)
    path.closeSubpath()
    if pouring {
      context.stroke(
        path,
        with: .color(color),
        style: StrokeStyle(lineWidth: refined ? 2 : 3, lineJoin: .round))
      let topSand = max(0, 1 - phase / 0.9)
      let bottomSand = min(1, phase / 0.9)
      var sand = Path()
      sand.move(to: CGPoint(x: size.width * 0.3, y: size.height * (0.18 + 0.22 * topSand)))
      sand.addLine(to: CGPoint(x: size.width * 0.7, y: size.height * (0.18 + 0.22 * topSand)))
      sand.addLine(to: center)
      sand.closeSubpath()
      context.fill(sand, with: .color(color.opacity(0.75)))
      let bottom = CGRect(
        x: size.width * 0.3,
        y: size.height * (0.82 - 0.25 * bottomSand),
        width: size.width * 0.4,
        height: size.height * 0.25 * bottomSand)
      context.fill(Path(bottom), with: .color(color.opacity(0.75)))
      if phase < 0.9 {
        var stream = Path()
        stream.move(to: center)
        stream.addLine(to: CGPoint(x: center.x, y: bottom.minY))
        context.stroke(stream, with: .color(color), lineWidth: refined ? 1 : 2)
      }
    } else {
      var transformed = context
      transformed.translateBy(x: center.x, y: center.y)
      transformed.rotate(by: .degrees(floor(phase * 8) * 180))
      transformed.translateBy(x: -center.x, y: -center.y)
      transformed.fill(path, with: .color(color))
    }
  }

  private func spinningCircle(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double
  ) {
    let count = 8
    let radius = min(size.width, size.height) * 0.34
    let side = min(size.width, size.height) * 0.12
    for index in 0..<count {
      let progress = positiveRemainder(phase + Double(index) / Double(count))
      let angle = (Double(index) / Double(count) + phase) * 2 * .pi
      let center = polarPoint(in: size, radius: radius, angle: angle)
      let rect = CGRect(
        x: center.x - side / 2,
        y: center.y - side / 2,
        width: side,
        height: side)
      context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.2 + 0.8 * progress)))
    }
  }

  private func spinningLines(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double
  ) {
    let count = max(1, control.integer("item_count", default: 5) ?? 5)
    let lineWidth = CGFloat(control.number("line_width", default: 2) ?? 2)
    let radius = min(size.width, size.height) * 0.42
    for index in 0..<count {
      let angle = (phase + Double(index) / Double(count)) * 2 * .pi
      let inner = polarPoint(in: size, radius: radius * 0.35, angle: angle)
      let outer = polarPoint(in: size, radius: radius, angle: angle)
      var path = Path()
      path.move(to: inner)
      path.addLine(to: outer)
      context.stroke(
        path,
        with: .color(color.opacity(0.25 + 0.75 * Double(index + 1) / Double(count))),
        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
  }

  private func squareCircle(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double
  ) {
    let progress = abs(sin(phase * .pi))
    let side = min(size.width, size.height) * CGFloat(0.55 + 0.35 * progress)
    let rect = CGRect(
      x: (size.width - side) / 2,
      y: (size.height - side) / 2,
      width: side,
      height: side)
    var transformed = context
    transformed.translateBy(x: size.width / 2, y: size.height / 2)
    transformed.rotate(by: .degrees(phase * 180))
    transformed.translateBy(x: -size.width / 2, y: -size.height / 2)
    transformed.fill(
      Path(roundedRect: rect, cornerRadius: side * CGFloat(progress) / 2),
      with: .color(color))
  }

  private func waveSpinner(
    context: inout GraphicsContext,
    size: CGSize,
    phase: Double
  ) {
    let radius = min(size.width, size.height) * 0.36
    for ringIndex in 0..<2 {
      var path = Path()
      let samples = 48
      for sample in 0...samples {
        let angle = Double(sample) / Double(samples) * 2 * .pi
        let wave = sin(angle * 3 + phase * 2 * .pi + Double(ringIndex) * .pi) * 3
        let point = polarPoint(
          in: size,
          radius: radius + CGFloat(wave) + CGFloat(ringIndex) * 4,
          angle: angle)
        if sample == 0 { path.move(to: point) } else { path.addLine(to: point) }
      }
      context.stroke(
        path,
        with: .color(color.opacity(ringIndex == 0 ? 1 : 0.45)),
        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }
    let dot = polarPoint(in: size, radius: radius, angle: phase * 2 * .pi)
    context.fill(
      Path(ellipseIn: CGRect(x: dot.x - 3, y: dot.y - 3, width: 6, height: 6)),
      with: .color(color))
  }

  private func polarPoint(in size: CGSize, radius: CGFloat, angle: Double) -> CGPoint {
    CGPoint(
      x: size.width / 2 + CGFloat(cos(angle)) * radius,
      y: size.height / 2 + CGFloat(sin(angle)) * radius)
  }

  private func positiveRemainder(_ value: Double) -> Double {
    let remainder = value.truncatingRemainder(dividingBy: 1)
    return remainder < 0 ? remainder + 1 : remainder
  }

  private func heartPath(in rect: CGRect) -> Path {
    let left = rect.minX
    let right = rect.maxX
    let top = rect.minY
    let bottom = rect.maxY
    let centerX = rect.midX
    let upper = top + rect.height * 0.28
    let middle = top + rect.height * 0.48
    var path = Path()
    path.move(to: CGPoint(x: centerX, y: bottom))
    path.addCurve(
      to: CGPoint(x: left, y: middle),
      control1: CGPoint(x: left + rect.width * 0.2, y: bottom - rect.height * 0.02),
      control2: CGPoint(x: left, y: top + rect.height * 0.68))
    path.addCurve(
      to: CGPoint(x: centerX, y: upper),
      control1: CGPoint(x: left, y: top),
      control2: CGPoint(x: left + rect.width * 0.38, y: top))
    path.addCurve(
      to: CGPoint(x: right, y: middle),
      control1: CGPoint(x: right - rect.width * 0.38, y: top),
      control2: CGPoint(x: right, y: top))
    path.addCurve(
      to: CGPoint(x: centerX, y: bottom),
      control1: CGPoint(x: right, y: top + rect.height * 0.68),
      control2: CGPoint(x: right - rect.width * 0.2, y: bottom - rect.height * 0.02))
    path.closeSubpath()
    return path
  }

  private var defaultDuration: TimeInterval {
    switch variant {
    case .doubleBounce, .chasingDots: 2
    case .wanderingCubes, .ripple: 1.8
    case .pulse, .pumpingHeart: 1
    case .threeBounce: 1.4
    case .foldingCube, .pouringHourGlass, .pouringHourGlassRefined: 2.4
    case .squareCircle: 0.5
    case .threeInOut: 1.5
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
