import RufletProtocol
import SwiftUI

/// Apple-native port of pinned Flet `controls/snack_bar.dart`.
@MainActor
public struct SnackBarControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var lifecycle: RufletSnackBarLifecycle
  @Environment(\.layoutDirection) private var layoutDirection

  public init(control: RufletControl) {
    self.control = control
    _lifecycle = StateObject(wrappedValue: RufletSnackBarLifecycle(control: control))
  }

  public var body: some View {
    Group {
      if control.boolean("open", default: false) {
        if control.buildTextOrWidget("content") == nil {
          ErrorControl("SnackBar.content must be provided and visible")
        } else {
          snackBar
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .onAppear(perform: lifecycle.synchronize)
    .onChange(of: control.properties) { _ in lifecycle.synchronize() }
    .onDisappear(perform: lifecycle.cancel)
  }

  private var snackBar: some View {
    contentLayout
      .padding(parsePadding(control.dynamicValue("padding"))
        ?? EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
      .frame(width: effectiveWidth)
      .frame(maxWidth: behavior == .floating ? nil : .infinity, alignment: .leading)
      .background(backgroundColor)
      .clipShape(shape)
      .overlay { shapeBorder }
      .shadow(
        color: .black.opacity(elevation > 0 ? 0.2 : 0),
        radius: elevation,
        y: elevation / 2)
      .padding(effectiveMargin)
      .contentShape(Rectangle())
      .gesture(dismissGesture)
      .transition(.move(edge: .bottom).combined(with: .opacity))
      .accessibilityElement(children: .contain)
  }

  @ViewBuilder
  private var contentLayout: some View {
    if actionOverflows {
      VStack(alignment: .leading, spacing: 10) {
        contentRow
        actionView.frame(maxWidth: .infinity, alignment: .trailing)
      }
    } else {
      HStack(alignment: .center, spacing: 12) {
        contentRow
        actionView
      }
    }
  }

  private var contentRow: some View {
    HStack(spacing: 10) {
      control.buildTextOrWidget("content")!
        .frame(maxWidth: .infinity, alignment: .leading)
      if control.boolean("show_close_icon", default: false) {
        Button(action: lifecycle.dismiss) {
          Image(systemName: "xmark")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(parseColor(control.string("close_icon_color")) ?? .primary)
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
      }
    }
  }

  @ViewBuilder
  private var actionView: some View {
    switch RufletSnackBarAction(control: control) {
    case .control(let action):
      Button {
        action.triggerEvent("click")
      } label: {
        Text(action.string("label", default: "Action")!)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(parseColor(action.string("text_color")) ?? .accentColor)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(parseColor(action.string("bgcolor")) ?? .clear, in: Capsule())
      }
      .buttonStyle(.plain)

    case .text(let label):
      Button {
        control.triggerEvent("action")
      } label: {
        Text(label)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.accentColor)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
      }
      .buttonStyle(.plain)

    case .none:
      EmptyView()
    }
  }

  @ViewBuilder
  private var shapeBorder: some View {
    if let side = parseBorderSide(shapeDetails?["side"]) {
      shape.stroke(side.color, lineWidth: side.width)
    }
  }

  private var dismissGesture: some Gesture {
    DragGesture(minimumDistance: 12).onEnded { value in
      if shouldDismiss(translation: value.translation) { lifecycle.dismiss() }
    }
  }

  private func shouldDismiss(translation: CGSize) -> Bool {
    let threshold: CGFloat = 44
    switch parseDismissDirection(control.string("dismiss_direction"), .down)! {
    case .vertical: return abs(translation.height) >= threshold
    case .horizontal: return abs(translation.width) >= threshold
    case .up: return translation.height <= -threshold
    case .down: return translation.height >= threshold
    case .startToEnd:
      return layoutDirection == .leftToRight
        ? translation.width >= threshold : translation.width <= -threshold
    case .endToStart:
      return layoutDirection == .leftToRight
        ? translation.width <= -threshold : translation.width >= threshold
    case .none: return false
    }
  }

  private var behavior: RufletSnackBarBehavior {
    RufletSnackBarBehavior(rawValue: control.string("behavior")?.lowercased() ?? "") ?? .fixed
  }

  private var effectiveWidth: CGFloat? {
    behavior == .floating ? control.number("width").map { CGFloat($0) } : nil
  }

  private var effectiveMargin: EdgeInsets {
    guard behavior == .floating, effectiveWidth == nil else { return EdgeInsets() }
    return parseMargin(control.dynamicValue("margin"))
      ?? EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
  }

  private var backgroundColor: Color {
    parseColor(control.string("bgcolor")) ?? Color.rufletSnackBarBackground
  }

  private var elevation: CGFloat { CGFloat(max(control.number("elevation") ?? 6, 0)) }

  private var shapeDetails: [String: Any]? { rufletDictionary(control.dynamicValue("shape")) }
  private var shape: RufletCornerShape {
    let fallback = behavior == .floating ? 10.0 : 0.0
    let radius = parseBorderRadius(
      shapeDetails?["radius"] ?? shapeDetails?["border_radius"],
      RufletBorderRadius(
        topLeft: fallback, topRight: fallback,
        bottomLeft: fallback, bottomRight: fallback))!
    return RufletCornerShape(radius: radius)
  }

  private var actionOverflows: Bool {
    guard let label = RufletSnackBarAction(control: control).label else { return false }
    let threshold = control.number("action_overflow_threshold") ?? 0.25
    let width = Double(effectiveWidth ?? 360)
    return Double(label.count) * 8 + 36 > width * threshold
  }
}

enum RufletSnackBarBehavior: String { case fixed, floating }

enum RufletSnackBarAction: Equatable {
  case control(RufletControl)
  case text(String)
  case none

  @MainActor init(control: RufletControl) {
    if let action = control.child("action") { self = .control(action) }
    else if let text = control.value("action")?.text { self = .text(text) }
    else { self = .none }
  }

  @MainActor var label: String? {
    switch self {
    case .control(let control): return control.string("label", default: "Action")
    case .text(let text): return text
    case .none: return nil
    }
  }

  static func == (lhs: RufletSnackBarAction, rhs: RufletSnackBarAction) -> Bool {
    switch (lhs, rhs) {
    case (.none, .none): return true
    case (.text(let lhs), .text(let rhs)): return lhs == rhs
    case (.control(let lhs), .control(let rhs)): return lhs === rhs
    default: return false
    }
  }
}

@MainActor
final class RufletSnackBarLifecycle: ObservableObject {
  private let control: RufletControl
  private var timer: Task<Void, Never>?

  init(control: RufletControl) { self.control = control }

  func synchronize() {
    let open = control.boolean("open", default: false)
    let lastOpen = control.boolean("_open", default: false)
    if open && !lastOpen { show() }
    else if !open && lastOpen { closeFromControl() }
  }

  func cancel() {
    timer?.cancel()
    timer = nil
  }

  func dismiss() {
    let open = control.boolean("open", default: false)
    let lastOpen = control.boolean("_open", default: false)
    guard open || lastOpen else { return }
    cancel()
    control.updateProperties(
      ["_dismissed": .bool(true)], client: true, server: false, notify: true)
    control.updateProperties(
      ["_open": .bool(false)], client: true, server: false, notify: true)
    control.updateProperties(
      ["open": .bool(false)], client: true, server: true, notify: true)
    control.triggerEvent("dismiss")
  }

  private func show() {
    cancel()
    let generation = (control.integer("_show_generation", default: 0) ?? 0) + 1
    control.updateProperties(
      [
        "_open": .bool(true),
        "_dismissed": .bool(false),
        "_show_generation": .int(Int64(generation)),
      ],
      client: true,
      server: false,
      notify: true)
    control.triggerEvent("visible")
    guard !control.boolean("persist", default: false) else { return }
    let duration = max(parseDuration(control.dynamicValue("duration"), 4) ?? 4, 0)
    timer = Task { [weak self] in
      if duration > 0 {
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
      }
      guard !Task.isCancelled, let self,
            self.control.integer("_show_generation", default: 0) == generation,
            !self.control.boolean("_dismissed", default: false)
      else { return }
      self.dismiss()
    }
  }

  private func closeFromControl() {
    // `ScaffoldMessenger.removeCurrentSnackBar()` completes the pinned Dart
    // `closed` future as well, so an externally requested close follows the
    // same dismissed/open/event lifecycle as timeout, swipe, and close-icon.
    dismiss()
  }
}

private extension Color {
  static var rufletSnackBarBackground: Color {
    #if os(iOS)
    return Color(uiColor: .secondarySystemBackground)
    #elseif os(macOS)
    return Color(nsColor: .windowBackgroundColor)
    #endif
  }
}
