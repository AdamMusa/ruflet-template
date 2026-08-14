import SwiftUI

enum RufletShimmerDirection: String, CaseIterable, RufletStringEnum {
  case ltr, rtl, ttb, btt
}

/// Apple-native port of Flet's `shimmer.dart`.
@MainActor
public struct ShimmerControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      if control.child("content") == nil {
        ErrorControl("Shimmer.content must be specified")
      } else if let gradient = resolvedGradient {
        RufletShimmerView(
          content: control.buildWidget("content")!,
          gradient: gradient,
          direction: direction,
          period: period,
          loop: max(control.integer("loop", default: 0) ?? 0, 0),
          enabled: !control.disabled)
      } else {
        ErrorControl("Shimmer requires either gradient or base/highlight colors")
      }
    }
  }

  private var resolvedGradient: RufletGradientSpec? {
    if let gradient = parseGradient(control.dynamicValue("gradient")) { return gradient }
    guard let base = parseColor(control.string("base_color")),
          let highlight = parseColor(control.string("highlight_color"))
    else { return nil }
    return .linear(
      Gradient(colors: [base, highlight, base]),
      start: .leading,
      end: .trailing,
      tileMode: .clamp)
  }

  private var direction: RufletShimmerDirection {
    parseEnum(RufletShimmerDirection.self, control.string("direction"), .ltr)!
  }

  private var period: TimeInterval {
    max(parseDuration(control.dynamicValue("period"), 1.5) ?? 1.5, 0)
  }
}

private struct RufletShimmerView: View {
  let content: AnyView
  let gradient: RufletGradientSpec
  let direction: RufletShimmerDirection
  let period: TimeInterval
  let loop: Int
  let enabled: Bool
  @State private var progress = -1.0
  @State private var completedLoops = 0

  var body: some View {
    content
      .overlay {
        GeometryReader { proxy in
          RufletGradientShapeStyle(gradient: gradient)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .offset(offset(for: proxy.size))
        }
        .mask(content)
      }
      .onAppear(perform: start)
      .onChange(of: enabled) { _ in start() }
  }

  private func offset(for size: CGSize) -> CGSize {
    switch direction {
    case .ltr: CGSize(width: progress * size.width, height: 0)
    case .rtl: CGSize(width: -progress * size.width, height: 0)
    case .ttb: CGSize(width: 0, height: progress * size.height)
    case .btt: CGSize(width: 0, height: -progress * size.height)
    }
  }

  private func start() {
    guard enabled, period > 0, loop == 0 || completedLoops < loop else { return }
    progress = -1
    withAnimation(.linear(duration: period)) { progress = 1 }
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: rufletSleepNanoseconds(period))
      guard enabled else { return }
      completedLoops += 1
      start()
    }
  }
}
