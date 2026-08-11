import RufletEngine
import SwiftUI

/// Native SwiftUI implementations of the flet_spinkit variants Ruflet exposes.
struct SpinKitControlView: View {
  let node: ControlNode

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
      let seconds = timeline.date.timeIntervalSinceReferenceDate
      let duration = max((node.double("duration") ?? 1200) / 1000, 0.15)
      glyph(phase: seconds / duration)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }

  private var variant: String {
    (node.string("variant") ?? "circle").lowercased().replacingOccurrences(of: "-", with: "_")
  }

  private var size: CGFloat { CGFloat(node.double("size") ?? 36) }
  private var color: Color {
    MaterialPalette.color(for: node, property: "color", default: .primary)
  }

  @ViewBuilder
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
  private func glyph(phase: Double) -> some View {
    switch variant {
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
      RoundedRectangle(cornerRadius: size * 0.05)
        .fill(color)
        .frame(width: size * 0.72, height: size * 0.72)
        .rotation3DEffect(.degrees(phase * 360), axis: (x: 1, y: 1, z: 0))
    case "double_bounce":
      ZStack {
        pulseCircle(phase: phase, offset: 0)
        pulseCircle(phase: phase, offset: 0.5)
      }
    case "wave", "piano_wave", "spinning_lines":
      bars(phase: phase)
    case "wandering_cubes", "dancing_square":
      wanderingSquares(phase: phase)
    case "fading_four":
      orbitingDots(count: 4, phase: phase, fading: true)
    case "fading_cube":
      foldingTiles(phase: phase, fading: true)
    case "pulse":
      pulseCircle(phase: phase, offset: 0)
    case "chasing_dots":
      orbitingDots(count: 2, phase: phase, fading: false)
    case "three_bounce", "three_in_out":
      bouncingDots(phase: phase)
    case "circle", "fading_circle", "spinning_circle":
      orbitingDots(count: 12, phase: phase, fading: true)
    case "cube_grid", "fading_grid", "pulsing_grid":
      grid(phase: phase)
    case "folding_cube":
      foldingTiles(phase: phase, fading: false)
    case "pumping_heart":
      Image(systemName: "heart.fill")
        .resizable()
        .scaledToFit()
        .foregroundColor(color)
        .scaleEffect(0.78 + 0.2 * waveValue(phase * 2))
    case "hour_glass", "pouring_hour_glass", "pouring_hour_glass_refined":
      Image(systemName: "hourglass")
        .resizable()
        .scaledToFit()
        .foregroundColor(color)
        .rotationEffect(.degrees(floor(phase * 2) * 180))
        .animation(.easeInOut(duration: 0.35), value: floor(phase * 2))
    case "ripple":
      ripple(phase: phase)
    case "dual_ring":
      rings(phase: phase, dual: true)
    case "ring", "wave_spinner":
      rings(phase: phase, dual: false)
    case "square_circle":
      RoundedRectangle(cornerRadius: size * (0.1 + 0.4 * waveValue(phase)))
        .fill(color)
        .frame(width: size * 0.72, height: size * 0.72)
        .rotationEffect(.degrees(phase * 180))
    default:
      rings(phase: phase, dual: false)
    }
  }

  private func waveValue(_ value: Double) -> CGFloat {
    CGFloat((sin(value * .pi * 2) + 1) / 2)
  }

  private func pulseCircle(phase: Double, offset: Double) -> some View {
    let value = waveValue(phase + offset)
    return Circle()
      .fill(color)
      .scaleEffect(0.3 + 0.7 * value)
      .opacity(0.3 + 0.7 * Double(1 - value))
  }

  private func bars(phase: Double) -> some View {
    HStack(alignment: .center, spacing: size * 0.06) {
      ForEach(0..<5, id: \.self) { index in
        RoundedRectangle(cornerRadius: size * 0.03)
          .fill(color)
          .frame(width: size * 0.11, height: size * (0.28 + 0.65 * waveValue(phase - Double(index) * 0.11)))
      }
    }
  }

  private func bouncingDots(phase: Double) -> some View {
    HStack(spacing: size * 0.1) {
      ForEach(0..<3, id: \.self) { index in
        Circle()
          .fill(color)
          .frame(width: size * 0.24, height: size * 0.24)
          .scaleEffect(0.45 + 0.55 * waveValue(phase - Double(index) * 0.16))
      }
    }
  }

  private func orbitingDots(count: Int, phase: Double, fading: Bool) -> some View {
    ZStack {
      ForEach(0..<count, id: \.self) { index in
        let step = Double(index) / Double(count)
        Circle()
          .fill(color)
          .frame(width: size * (count <= 4 ? 0.25 : 0.13), height: size * (count <= 4 ? 0.25 : 0.13))
          .offset(y: -size * 0.34)
          .rotationEffect(.degrees(step * 360 + (fading ? 0 : phase * 360)))
          .opacity(fading ? 0.2 + 0.8 * Double(waveValue(phase - step)) : 1)
      }
    }
    .rotationEffect(.degrees(fading ? phase * 80 : 0))
  }

  private func wanderingSquares(phase: Double) -> some View {
    ZStack {
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

  private func grid(phase: Double) -> some View {
    ZStack {
      ForEach(0..<9, id: \.self) { index in
        let row = index / 3
        let column = index % 3
        RoundedRectangle(cornerRadius: size * 0.025)
          .fill(color)
          .frame(width: size * 0.2, height: size * 0.2)
          .offset(x: CGFloat(column - 1) * size * 0.25, y: CGFloat(row - 1) * size * 0.25)
          .scaleEffect(0.35 + 0.65 * waveValue(phase - Double(index) * 0.07))
      }
    }
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

  private func rings(phase: Double, dual: Bool) -> some View {
    ZStack {
      Circle()
        .trim(from: 0.08, to: dual ? 0.46 : 0.78)
        .stroke(color, style: StrokeStyle(lineWidth: max(2, size * 0.1), lineCap: .round))
      if dual {
        Circle()
          .trim(from: 0.58, to: 0.9)
          .stroke(color.opacity(0.45), style: StrokeStyle(lineWidth: max(2, size * 0.1), lineCap: .round))
      }
    }
    .padding(size * 0.08)
    .rotationEffect(.degrees(phase * 360))
  }

  private func ripple(phase: Double) -> some View {
    ZStack {
      ForEach(0..<2, id: \.self) { index in
        let progress = (phase + Double(index) * 0.5).truncatingRemainder(dividingBy: 1)
        Circle()
          .stroke(color.opacity(1 - progress), lineWidth: max(1, size * 0.06))
          .scaleEffect(0.15 + progress * 0.85)
      }
    }
  }
}
