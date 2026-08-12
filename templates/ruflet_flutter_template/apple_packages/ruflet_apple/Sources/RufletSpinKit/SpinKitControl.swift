import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

/// Values shared by Ruflet's generic spinner and the thirty native Flet wire
/// types. Keeping this resolution outside the drawing code makes the defaults
/// testable and prevents an individual `SpinKit*` control silently falling
/// back to the generic circle.
struct RufletSpinKitConfiguration: Equatable {
  static let fletWireTypes = [
    "SpinKitRotatingPlain", "SpinKitDoubleBounce", "SpinKitWave",
    "SpinKitWanderingCubes", "SpinKitFadingFour", "SpinKitFadingCube",
    "SpinKitPulse", "SpinKitChasingDots", "SpinKitThreeBounce", "SpinKitCircle",
    "SpinKitCubeGrid", "SpinKitFadingCircle", "SpinKitRotatingCircle",
    "SpinKitFoldingCube", "SpinKitPumpingHeart", "SpinKitHourGlass",
    "SpinKitPouringHourGlass", "SpinKitPouringHourGlassRefined", "SpinKitFadingGrid",
    "SpinKitRing", "SpinKitRipple", "SpinKitDualRing", "SpinKitSpinningCircle",
    "SpinKitSpinningLines", "SpinKitSquareCircle", "SpinKitThreeInOut",
    "SpinKitDancingSquare", "SpinKitPianoWave", "SpinKitPulsingGrid",
    "SpinKitWaveSpinner",
  ]

  let variant: String
  let size: CGFloat
  let duration: TimeInterval
  let lineWidth: CGFloat?
  let borderWidth: CGFloat?
  let itemCount: Int
  let waveType: String

  var frameWidth: CGFloat {
    switch variant {
    case "wave", "piano_wave": return size * 1.25
    case "three_bounce", "three_in_out": return size * 2
    default: return size
    }
  }
  var frameHeight: CGFloat { size }

  var effectiveLineWidth: CGFloat {
    lineWidth ?? (variant == "spinning_lines" ? 2 : 7)
  }
  var effectiveBorderWidth: CGFloat { borderWidth ?? 6 }

  init(node: ControlNode) {
    variant = Self.variant(node)
    size = CGFloat(node.double("size") ?? 50)
    // The generated global contract has a 1200ms fallback for this property,
    // but Flet applies duration defaults per SpinKit constructor. Inspect the
    // explicit wire property before selecting that constructor default.
    let fallback = node.type == "RufletSpinKit"
      ? 1200
      : Self.defaultDurationMilliseconds(for: variant)
    duration = Self.durationSeconds(node.props["duration"], defaultMilliseconds: fallback)
    lineWidth = node.double("line_width").map { CGFloat($0) }
    borderWidth = node.double("border_width").map { CGFloat($0) }
    // Flet forwards item_count only to Wave and PianoWave. Both Flutter
    // constructors require at least two items; clamp malformed wire input so
    // the native renderer remains deterministic instead of trapping.
    itemCount = max(node.int("item_count") ?? 5, 2)
    switch node.string("wave_type")?.lowercased() {
    case "end": waveType = "end"
    case "center": waveType = "center"
    default: waveType = "start"
    }
  }

  /// Mirrors Flet's `getInt` for the generic control and `getDuration` for
  /// individual controls. Scalar durations are milliseconds, extension type
  /// 3 carries microseconds, and component maps are summed as a Dart Duration.
  static func durationSeconds(
    _ value: RufletValue?,
    defaultMilliseconds: Double
  ) -> TimeInterval {
    guard let value, !value.isNull else { return defaultMilliseconds / 1_000 }
    if case .int(let milliseconds) = value { return Double(milliseconds) / 1_000 }
    if case .string(let raw) = value { return Double(Int64(raw) ?? 0) / 1_000 }
    if case .extended(type: 3, let microseconds) = value {
      return Double(Int64(microseconds) ?? 0) / 1_000_000
    }
    guard let map = value.mapValue else { return 0 }
    func integer(_ key: String) -> Int64 {
      switch map[key] {
      case .int(let value): return value
      case .string(let value): return Int64(value) ?? 0
      default: return 0
      }
    }
    let microseconds = integer("microseconds")
      + 1_000 * integer("milliseconds")
      + 1_000_000 * integer("seconds")
      + 60_000_000 * integer("minutes")
      + 3_600_000_000 * integer("hours")
      + 86_400_000_000 * integer("days")
    return Double(microseconds) / 1_000_000
  }

  private static func variant(_ node: ControlNode) -> String {
    if node.type == "RufletSpinKit" {
      let value = node.string("variant")?.trimmingCharacters(in: .whitespacesAndNewlines)
      return value?.isEmpty == false ? normalize(value!) : "rotating_circle"
    }
    guard node.type.hasPrefix("SpinKit") else { return "rotating_circle" }
    let suffix = node.type.dropFirst("SpinKit".count)
    var words: [String] = []
    var current = ""
    for character in suffix {
      if character.isUppercase, !current.isEmpty {
        words.append(current.lowercased())
        current = ""
      }
      current.append(character)
    }
    if !current.isEmpty { words.append(current.lowercased()) }
    return words.joined(separator: "_")
  }

  private static func normalize(_ value: String) -> String {
    let words = value.unicodeScalars.split {
      !CharacterSet.alphanumerics.contains($0)
    }
    let normalized = words.map { String(String.UnicodeScalarView($0)).lowercased() }
      .joined(separator: "_")
    return normalized.isEmpty ? "rotating_circle" : normalized
  }

  /// Defaults copied from the corresponding constructor in the pinned
  /// `flet_spinkit` switch. `RufletSpinKit` intentionally keeps its own 1200ms
  /// default; these values apply to Flet's thirty individual wire types.
  private static func defaultDurationMilliseconds(for variant: String) -> Double {
    switch variant {
    case "double_bounce", "chasing_dots":
      return 2000
    case "wandering_cubes", "ripple":
      return 1800
    case "pulse", "pumping_heart":
      return 1000
    case "three_bounce":
      return 1400
    case "folding_cube", "pouring_hour_glass", "pouring_hour_glass_refined":
      return 2400
    case "square_circle":
      return 500
    case "three_in_out":
      return 1500
    default:
      return 1200
    }
  }
}

/// Pure animation math shared by the native views and focused parity tests.
enum SpinKitAnimationSemantics {
  static func phase(elapsed: TimeInterval, duration: TimeInterval) -> Double {
    guard duration.isFinite, duration > 0 else { return 0 }
    let value = (elapsed / duration).truncatingRemainder(dividingBy: 1)
    return value < 0 ? value + 1 : value
  }

  static func waveDelays(count: Int, type: String) -> [Double] {
    let count = max(count, 2)
    let half = count / 2
    let odd = count.isMultiple(of: 2) == false
    switch type {
    case "end":
      let leading = (0..<half).map { -1 + Double($0) * 0.1 + 0.1 }.reversed()
      let trailing = (0..<half).map { -1 - Double($0) * 0.1 - (odd ? 0.1 : 0) }
      return Array(leading) + (odd ? [-1] : []) + trailing
    case "center":
      let halfDelays = (0..<half).map { -1 + Double($0) * 0.2 + 0.2 }
      return Array(halfDelays.reversed()) + (odd ? [-1] : []) + halfDelays
    default:
      let leading = (0..<half).map { -1 - Double($0) * 0.1 - 0.1 }.reversed()
      let trailing = (0..<half).map { -1 + Double($0) * 0.1 + (odd ? 0.1 : 0) }
      return Array(leading) + (odd ? [-1] : []) + trailing
    }
  }

  /// flutter_spinkit's DelayTween applies a half-cycle tween after wrapping
  /// its signed delay into the repeating controller interval.
  static func delayedPulse(_ phase: Double, delay: Double) -> CGFloat {
    let shifted = (phase - delay).truncatingRemainder(dividingBy: 1)
    let normalized = shifted < 0 ? shifted + 1 : shifted
    return CGFloat((sin(normalized * .pi * 2 - .pi / 2) + 1) / 2)
  }
}

/// Native SwiftUI implementations of the flet_spinkit variants Ruflet exposes.
struct SpinKitControlView: View {
  let node: ControlNode

  var body: some View {
    let configuration = RufletSpinKitConfiguration(node: node)
    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
      let seconds = timeline.date.timeIntervalSinceReferenceDate
      let phase = SpinKitAnimationSemantics.phase(
        elapsed: seconds, duration: configuration.duration)
      glyph(phase: phase, configuration: configuration)
    }
    .frame(width: configuration.frameWidth, height: configuration.frameHeight)
    .accessibilityHidden(true)
  }

  private var color: Color {
    MaterialPalette.color(for: node, property: "color", default: .primary)
  }
  private var size: CGFloat { RufletSpinKitConfiguration(node: node).size }

  /// The two halves of SpinKitRotatingCircle's cycle. The first axis eases in
  /// across 0...0.5 and then stays turned; the second eases out across
  /// 0.5...1 and is flat until it starts.
  private func rotatingCircleTurn(_ phase: Double, first: Bool) -> Double {
    if first {
      let progress = min(phase / 0.5, 1)
      // Curves.easeIn is a cubic ease.
      return 180 * progress * progress * progress
    }
    guard phase > 0.5 else { return 0 }
    let progress = (phase - 0.5) / 0.5
    let eased = 1 - pow(1 - progress, 3)
    return 180 * eased
  }

  @ViewBuilder
  private func glyph(phase: Double, configuration: RufletSpinKitConfiguration) -> some View {
    let size = configuration.size
    switch configuration.variant {
    case "rotating_circle":
      // SpinKitRotatingCircle tumbles a disc: 180 degrees about X over the
      // first half of the cycle, easing in, then 180 about Y over the second,
      // easing out. Both hold their turn rather than resetting between.
      Circle()
        .fill(color)
        .frame(width: size, height: size)
        .rotation3DEffect(.degrees(rotatingCircleTurn(phase, first: true)), axis: (x: 1, y: 0, z: 0))
        .rotation3DEffect(.degrees(rotatingCircleTurn(phase, first: false)), axis: (x: 0, y: 1, z: 0))
    case "rotating_plain":
      Rectangle()
        .fill(color)
        .frame(width: size, height: size)
        .rotation3DEffect(.degrees(rotatingCircleTurn(phase, first: true)), axis: (x: 1, y: 0, z: 0))
        .rotation3DEffect(.degrees(rotatingCircleTurn(phase, first: false)), axis: (x: 0, y: 1, z: 0))
    case "double_bounce":
      doubleBounce(phase: phase)
    case "wave":
      waveBars(phase: phase, configuration: configuration, horizontal: false)
    case "piano_wave":
      // Flet forwards item_count, but deliberately leaves the constructor's
      // PianoWave type at `start`; wave_type belongs only to SpinKitWave.
      waveBars(phase: phase, configuration: configuration, horizontal: true)
    case "spinning_lines":
      spinningLines(phase: phase, configuration: configuration)
    case "wandering_cubes":
      wanderingSquares(phase: phase)
    case "dancing_square":
      dancingSquares(phase: phase)
    case "fading_four":
      fadingFour(phase: phase)
    case "fading_cube":
      fadingCube(phase: phase)
    case "pulse":
      pulse(phase: phase)
    case "chasing_dots":
      chasingDots(phase: phase)
    case "three_bounce":
      threeBounce(phase: phase)
    case "three_in_out":
      threeInOut(phase: phase)
    case "circle":
      radialDots(phase: phase, mode: .scale)
    case "fading_circle":
      radialDots(phase: phase, mode: .fade)
    case "spinning_circle":
      radialDots(phase: phase, mode: .spin)
    case "cube_grid":
      grid(phase: phase, mode: .cube)
    case "fading_grid":
      grid(phase: phase, mode: .fade)
    case "pulsing_grid":
      grid(phase: phase, mode: .pulse)
    case "folding_cube":
      foldingTiles(phase: phase, fading: false)
    case "pumping_heart":
      SpinKitHeartShape()
        .fill(color)
        .padding(size * 0.04)
        .scaleEffect(0.8 + 0.2 * waveValue(phase))
    case "hour_glass":
      hourGlass(phase: phase, pouring: false, refined: false)
    case "pouring_hour_glass":
      hourGlass(phase: phase, pouring: true, refined: false)
    case "pouring_hour_glass_refined":
      hourGlass(phase: phase, pouring: true, refined: true)
    case "ripple":
      ripple(phase: phase, configuration: configuration)
    case "dual_ring":
      rings(phase: phase, dual: true, configuration: configuration)
    case "ring":
      rings(phase: phase, dual: false, configuration: configuration)
    case "wave_spinner":
      waveSpinner(phase: phase)
    case "square_circle":
      RoundedRectangle(cornerRadius: size * 0.5 * waveValue(phase))
        .fill(color)
        .frame(width: size * 0.75, height: size * 0.75)
        .rotationEffect(.degrees(phase * 90))
    default:
      // Unknown Ruflet variants become an unknown `SpinKit*` case in the
      // pinned Dart switch, whose fallback is SpinKitRotatingCircle.
      Circle()
        .fill(color)
        .frame(width: size, height: size)
        .rotation3DEffect(.degrees(rotatingCircleTurn(phase, first: true)), axis: (x: 1, y: 0, z: 0))
        .rotation3DEffect(.degrees(rotatingCircleTurn(phase, first: false)), axis: (x: 0, y: 1, z: 0))
    }
  }

  private func waveValue(_ value: Double) -> CGFloat {
    CGFloat((sin(value * .pi * 2) + 1) / 2)
  }

  private func delayedValue(_ phase: Double, index: Int, delay: Double = 0.1) -> CGFloat {
    SpinKitAnimationSemantics.delayedPulse(phase, delay: -Double(index) * delay)
  }

  private func doubleBounce(phase: Double) -> some View {
    ZStack {
      ForEach(0..<2, id: \.self) { index in
        let value = waveValue(phase + Double(index) * 0.5)
        Circle()
          .fill(color)
          .frame(width: size, height: size)
          .scaleEffect(value)
          .opacity(0.6)
      }
    }
  }

  private func pulse(phase: Double) -> some View {
    let value = waveValue(phase * 0.5)
    return Circle()
      .fill(color)
      .frame(width: size, height: size)
      .scaleEffect(value)
      .opacity(1 - Double(value))
  }

  private func waveBars(
    phase: Double,
    configuration: RufletSpinKitConfiguration,
    horizontal: Bool
  ) -> some View {
    let count = configuration.itemCount
    let delays = SpinKitAnimationSemantics.waveDelays(
      count: count, type: horizontal ? "start" : configuration.waveType)
    return HStack(spacing: 0) {
      ForEach(0..<count, id: \.self) { index in
        let base = 0.4 + 0.6 * SpinKitAnimationSemantics.delayedPulse(
          phase, delay: delays[index])
        let value = horizontal ? base * 0.8 : base
        Rectangle()
          .fill(color)
          .frame(width: configuration.size / CGFloat(count), height: configuration.size)
          .scaleEffect(x: horizontal ? value : 1, y: horizontal ? 1 : value)
      }
    }
    .frame(width: configuration.frameWidth, height: configuration.size)
  }

  private func spinningLines(
    phase: Double,
    configuration: RufletSpinKitConfiguration
  ) -> some View {
    ZStack {
      ForEach(0..<5, id: \.self) { index in
        Capsule()
          .fill(color.opacity(0.3 + 0.7 * Double(delayedValue(phase, index: index, delay: 0.2))))
          .frame(width: configuration.effectiveLineWidth, height: configuration.size * 0.32)
          .offset(y: -configuration.size * 0.28)
          .rotationEffect(.degrees(Double(index) * 72))
      }
    }
    .rotationEffect(.degrees(phase * 360))
  }

  private func chasingDots(phase: Double) -> some View {
    ZStack {
      ForEach(0..<2, id: \.self) { index in
        Circle()
          .fill(color)
          .frame(width: size * 0.6, height: size * 0.6)
          .scaleEffect(index == 0 ? waveValue(phase) : 1 - waveValue(phase))
          .offset(y: index == 0 ? -size * 0.2 : size * 0.2)
      }
    }
    .rotationEffect(.degrees(phase * 360))
  }

  private func threeBounce(phase: Double) -> some View {
    HStack(spacing: size * 0.08) {
      ForEach(0..<3, id: \.self) { index in
        Circle()
          .fill(color)
          .frame(width: size * 0.5, height: size * 0.5)
          .scaleEffect(delayedValue(phase, index: index, delay: 0.16))
      }
    }
    .frame(width: size * 2, height: size)
  }

  private func threeInOut(phase: Double) -> some View {
    HStack(spacing: 0) {
      ForEach(0..<4, id: \.self) { index in
        let value = delayedValue(phase, index: index, delay: 0.12)
        Circle()
          .fill(color)
          .frame(width: size * 0.5, height: size * 0.5)
          .scaleEffect(index == 0 || index == 3 ? value : 1)
          .opacity(index == 0 || index == 3 ? Double(value) : 1)
      }
    }
    .frame(width: size * 2, height: size)
  }

  private func fadingFour(phase: Double) -> some View {
    ZStack {
      ForEach(0..<4, id: \.self) { index in
        Circle()
          .fill(color)
          .frame(width: size * 0.25, height: size * 0.25)
          .offset(x: size * 0.25, y: size * 0.25)
          .rotationEffect(.degrees(Double(index) * 90))
          .opacity(Double(delayedValue(phase, index: index, delay: 0.3)))
      }
    }
  }

  private func fadingCube(phase: Double) -> some View {
    ZStack {
      ForEach(0..<4, id: \.self) { index in
        Rectangle()
          .fill(color)
          .frame(width: size * 0.5, height: size * 0.5)
          .offset(x: size * 0.25, y: size * 0.25)
          .rotationEffect(.degrees(Double(index) * 90))
          .opacity(Double(delayedValue(phase, index: index, delay: 0.3)))
      }
    }
    .rotationEffect(.degrees(-45))
    .scaleEffect(0.78)
  }

  private enum RadialDotMode { case scale, fade, spin }

  private func radialDots(phase: Double, mode: RadialDotMode) -> some View {
    ZStack {
      ForEach(0..<12, id: \.self) { index in
        let value = delayedValue(phase, index: index, delay: 1.0 / 12.0)
        Circle()
          .fill(color)
          .frame(width: size * 0.15, height: size * 0.15)
          .scaleEffect(mode == .scale ? value : (mode == .spin ? 0.45 + 0.55 * value : 1))
          .opacity(mode == .fade ? Double(value) : 1)
          .offset(y: -size * 0.4)
          .rotationEffect(.degrees(Double(index) * 30))
      }
    }
    .rotationEffect(.degrees(mode == .spin ? phase * 360 : 0))
  }

  private func dancingSquares(phase: Double) -> some View {
    ZStack {
      ForEach(0..<12, id: \.self) { index in
        Rectangle()
          .fill(color)
          .frame(width: size * 0.15, height: size * 0.15)
          .scaleEffect(delayedValue(phase, index: index, delay: 1.0 / 12.0))
          .offset(y: -size * 0.42)
          .rotationEffect(.degrees(Double(index) * 30))
      }
    }
  }

  private func wanderingSquares(phase: Double) -> some View {
    return ZStack {
      ForEach(0..<2, id: \.self) { index in
        let angle = (phase + Double(index) * 0.5) * .pi * 2
        RoundedRectangle(cornerRadius: size * 0.04)
          .fill(color)
          .frame(width: size * 0.25, height: size * 0.25)
          .offset(x: cos(angle) * size * 0.27, y: sin(angle) * size * 0.27)
          .rotationEffect(.degrees(phase * 360))
      }
    }
  }

  private enum GridMode { case cube, fade, pulse }

  private func grid(phase: Double, mode: GridMode) -> some View {
    ZStack {
      ForEach(0..<9, id: \.self) { index in
        let row = index / 3
        let column = index % 3
        let delay: Double = index == 4 ? 0.25 : (index.isMultiple(of: 2) ? 0.75 : 0.5)
        let value = SpinKitAnimationSemantics.delayedPulse(phase, delay: delay)
        RoundedRectangle(cornerRadius: mode == .pulse ? size * 0.125 : 0)
          .fill(color)
          .frame(width: size * 0.25, height: size * 0.25)
          .offset(x: CGFloat(column - 1) * size * 0.35, y: CGFloat(row - 1) * size * 0.35)
          .scaleEffect(mode == .fade ? 1 : value)
          .opacity(mode == .fade ? Double(value) : 1)
      }
    }
  }

  private func hourGlass(phase: Double, pouring: Bool, refined: Bool) -> some View {
    ZStack {
      SpinKitHourGlassShape()
        .stroke(color, style: StrokeStyle(lineWidth: refined ? 2 : 3, lineJoin: .round))
      SpinKitHourGlassSandShape(progress: CGFloat(phase), pouring: pouring)
        .fill(color)
    }
    .padding(size * 0.12)
    .rotationEffect(.degrees(phase * 180))
  }

  private func waveSpinner(phase: Double) -> some View {
    ZStack {
      Circle()
        .stroke(color.opacity(0.41), lineWidth: max(1, size * 0.06))
      SpinKitWaveShape(phase: CGFloat(phase))
        .fill(color.opacity(0.41))
        .clipShape(Circle().inset(by: size * 0.08))
      Circle()
        .trim(from: 0, to: 0.28)
        .stroke(color, style: StrokeStyle(lineWidth: max(1, size * 0.08), lineCap: .round))
        .rotationEffect(.degrees(phase * 360))
    }
    .padding(size * 0.08)
  }

  private func foldingTiles(phase: Double, fading: Bool) -> some View {
    ZStack {
      ForEach(0..<4, id: \.self) { index in
        let x: CGFloat = index % 2 == 0 ? -0.18 : 0.18
        let y: CGFloat = index < 2 ? -0.18 : 0.18
        Rectangle()
          .fill(color)
          .frame(width: size * 0.42, height: size * 0.42)
          .offset(x: x * size, y: y * size)
          .opacity(fading ? 0.25 + 0.75 * Double(waveValue(phase - Double(index) * 0.14)) : 1)
          .rotation3DEffect(.degrees(phase * 180 + Double(index) * 45), axis: (x: 1, y: 1, z: 0))
      }
    }
    .rotationEffect(.degrees(45))
    .scaleEffect(0.72)
  }

  private func rings(
    phase: Double,
    dual: Bool,
    configuration: RufletSpinKitConfiguration
  ) -> some View {
    let size = configuration.size
    let width = configuration.effectiveLineWidth
    return ZStack {
      Circle()
        .trim(from: 0.08, to: dual ? 0.46 : 0.78)
        .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
      if dual {
        Circle()
          .trim(from: 0.58, to: 0.9)
          .stroke(color.opacity(0.45), style: StrokeStyle(lineWidth: width, lineCap: .round))
      }
    }
    .padding(size * 0.08)
    .rotationEffect(.degrees(phase * 360))
  }

  private func ripple(phase: Double, configuration: RufletSpinKitConfiguration) -> some View {
    let width = configuration.effectiveBorderWidth
    return ZStack {
      ForEach(0..<2, id: \.self) { index in
        let progress = (phase + Double(index) * 0.5).truncatingRemainder(dividingBy: 1)
        Circle()
          .stroke(color.opacity(1 - progress), lineWidth: width)
          .scaleEffect(0.15 + progress * 0.85)
      }
    }
  }
}

private struct SpinKitHeartShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.maxY * 0.92))
    path.addCurve(
      to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.height * 0.36),
      control1: CGPoint(x: rect.width * 0.36, y: rect.height * 0.72),
      control2: CGPoint(x: rect.width * 0.08, y: rect.height * 0.58))
    path.addCurve(
      to: CGPoint(x: rect.midX, y: rect.height * 0.22),
      control1: CGPoint(x: rect.width * 0.08, y: rect.height * 0.08),
      control2: CGPoint(x: rect.width * 0.36, y: rect.height * 0.04))
    path.addCurve(
      to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.height * 0.36),
      control1: CGPoint(x: rect.width * 0.64, y: rect.height * 0.04),
      control2: CGPoint(x: rect.width * 0.92, y: rect.height * 0.08))
    path.addCurve(
      to: CGPoint(x: rect.midX, y: rect.maxY * 0.92),
      control1: CGPoint(x: rect.width * 0.92, y: rect.height * 0.58),
      control2: CGPoint(x: rect.width * 0.64, y: rect.height * 0.72))
    path.closeSubpath()
    return path
  }
}

private struct SpinKitHourGlassShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.addCurve(
      to: CGPoint(x: rect.midX, y: rect.midY),
      control1: CGPoint(x: rect.maxX, y: rect.height * 0.25),
      control2: CGPoint(x: rect.width * 0.62, y: rect.height * 0.42))
    path.addCurve(
      to: CGPoint(x: rect.maxX, y: rect.maxY),
      control1: CGPoint(x: rect.width * 0.62, y: rect.height * 0.58),
      control2: CGPoint(x: rect.maxX, y: rect.height * 0.75))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.addCurve(
      to: CGPoint(x: rect.midX, y: rect.midY),
      control1: CGPoint(x: rect.minX, y: rect.height * 0.75),
      control2: CGPoint(x: rect.width * 0.38, y: rect.height * 0.58))
    path.addCurve(
      to: CGPoint(x: rect.minX, y: rect.minY),
      control1: CGPoint(x: rect.width * 0.38, y: rect.height * 0.42),
      control2: CGPoint(x: rect.minX, y: rect.height * 0.25))
    path.closeSubpath()
    return path
  }
}

private struct SpinKitHourGlassSandShape: Shape {
  let progress: CGFloat
  let pouring: Bool

  func path(in rect: CGRect) -> Path {
    let progress = min(max(progress, 0), 1)
    var path = Path()
    let upperY = rect.minY + rect.height * (0.12 + progress * 0.3)
    path.move(to: CGPoint(x: rect.width * 0.16, y: upperY))
    path.addLine(to: CGPoint(x: rect.width * 0.84, y: upperY))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
    path.closeSubpath()
    let lowerY = rect.maxY - rect.height * (0.08 + progress * 0.35)
    path.move(to: CGPoint(x: rect.midX, y: lowerY))
    path.addLine(to: CGPoint(x: rect.width * 0.86, y: rect.maxY - rect.height * 0.08))
    path.addLine(to: CGPoint(x: rect.width * 0.14, y: rect.maxY - rect.height * 0.08))
    path.closeSubpath()
    if pouring {
      path.addRect(CGRect(
        x: rect.midX - max(0.5, rect.width * 0.015), y: rect.midY,
        width: max(1, rect.width * 0.03), height: max(0, lowerY - rect.midY)))
    }
    return path
  }
}

private struct SpinKitWaveShape: Shape {
  let phase: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let steps = 40
    path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
    for step in 0...steps {
      let fraction = CGFloat(step) / CGFloat(steps)
      let x = rect.minX + rect.width * fraction
      let angle = Double(fraction * 2 + phase) * .pi * 2
      let y = rect.midY + CGFloat(sin(angle)) * rect.height * 0.12
        + (phase - 0.5) * rect.height * 0.25
      path.addLine(to: CGPoint(x: x, y: y))
    }
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}
