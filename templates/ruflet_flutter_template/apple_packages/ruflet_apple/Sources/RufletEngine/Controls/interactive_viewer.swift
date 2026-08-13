import RufletProtocol
import SwiftUI

/// Apple-native port of Flet's `InteractiveViewerControl`.
@MainActor
public struct InteractiveViewerControl: View {
  @ObservedObject public var control: RufletControl
  @State private var scale = 1.0
  @State private var offset = CGSize.zero
  @State private var savedTransform: RufletInteractiveTransform?
  @State private var viewportSize = CGSize.zero
  @State private var contentSize = CGSize.zero
  @State private var globalOrigin = CGPoint.zero
  @State private var interacting = false
  @State private var gestureStartScale = 1.0
  @State private var gestureStartOffset = CGSize.zero
  @State private var previousFocalPoint = CGPoint.zero
  @State private var lastUpdate = ProcessInfo.processInfo.systemUptime
  @State private var invokeToken: UUID?

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    if let content = control.child("content") {
      LayoutControl(control: control) {
        viewer(content)
      }
      .onAppear(perform: installInvokeListener)
      .onDisappear(perform: removeInvokeListener)
    } else {
      ErrorControl("InteractiveViewer.content must be provided and visible")
    }
  }

  private func viewer(_ content: RufletControl) -> some View {
    let view = GeometryReader { proxy in
      ControlWidget(control: content)
        .fixedSize(horizontal: !constrained, vertical: !constrained)
        .frame(
          maxWidth: constrained ? .infinity : nil,
          maxHeight: constrained ? .infinity : nil,
          alignment: parsedAlignment
        )
        .background {
          GeometryReader { childProxy in
            Color.clear.preference(
              key: RufletInteractiveContentSizeKey.self, value: childProxy.size)
          }
        }
        .scaleEffect(scale, anchor: parsedAlignment.rufletUnitPoint)
        .offset(offset)
        .onAppear {
          viewportSize = proxy.size
          globalOrigin = proxy.frame(in: .global).origin
        }
        .onChange(of: proxy.size) { viewportSize = $0 }
        .simultaneousGesture(interactionGesture)
        .overlay {
          RufletInteractivePointerBridge { phase, delta, local, global in
            handlePointerScroll(
              phase: phase,
              delta: delta,
              local: local,
              global: global
            )
          }
          .allowsHitTesting(false)
        }
    }
    .onPreferenceChange(RufletInteractiveContentSizeKey.self) { contentSize = $0 }

    if clipBehavior == "none" {
      return AnyView(view)
    }
    return AnyView(
      view.clipped(
        antialiased: clipBehavior == "antialias" || clipBehavior == "antialiaswithsavelayer"))
  }

  private var interactionGesture: some Gesture {
    SimultaneousGesture(
      MagnificationGesture(minimumScaleDelta: 0),
      DragGesture(minimumDistance: 0, coordinateSpace: .global)
    )
    .onChanged { value in
      let magnification = Double(value.first ?? 1)
      let drag = value.second
      let focal = drag?.location ?? previousFocalPoint
      if !interacting {
        interacting = true
        gestureStartScale = scale
        gestureStartOffset = offset
        previousFocalPoint = focal
        if !control.disabled { triggerStart(global: focal, magnification: magnification) }
      }

      if scaleEnabled {
        scale = clampedScale(gestureStartScale * magnification)
      }
      if panEnabled, let drag {
        offset = clampedOffset(
          CGSize(
            width: gestureStartOffset.width + drag.translation.width,
            height: gestureStartOffset.height + drag.translation.height
          ), at: scale)
      }
      if !control.disabled { triggerUpdate(global: focal, magnification: magnification) }
      previousFocalPoint = focal
    }
    .onEnded { value in
      let drag = value.second
      if panEnabled, let drag {
        let projected = CGSize(
          width: gestureStartOffset.width + drag.predictedEndTranslation.width,
          height: gestureStartOffset.height + drag.predictedEndTranslation.height
        )
        withAnimation(.easeOut(duration: inertiaDuration)) {
          offset = clampedOffset(projected, at: scale)
        }
      }
      if !control.disabled {
        let velocity = CGSize(
          width: (drag?.predictedEndTranslation.width ?? 0) - (drag?.translation.width ?? 0),
          height: (drag?.predictedEndTranslation.height ?? 0) - (drag?.translation.height ?? 0)
        )
        control.triggerEvent(
          "interaction_end",
          data: [
            "pc": .int(0),
            "v": pointValue(x: velocity.width * 4, y: velocity.height * 4),
          ])
      }
      interacting = false
    }
  }

  private func triggerStart(global: CGPoint, magnification: Double) {
    control.triggerEvent(
      "interaction_start",
      data: [
        "gfp": pointValue(x: global.x, y: global.y),
        "lfp": pointValue(x: global.x - globalOrigin.x, y: global.y - globalOrigin.y),
        "pc": .int(magnification == 1 ? 1 : 2),
        "ts": .int(timestamp),
      ])
  }

  private func triggerUpdate(global: CGPoint, magnification: Double) {
    let interval =
      Double(control.integer("interaction_update_interval", default: 200) ?? 200) / 1_000
    guard ProcessInfo.processInfo.systemUptime - lastUpdate > interval else { return }
    let delta = CGPoint(x: global.x - previousFocalPoint.x, y: global.y - previousFocalPoint.y)
    control.triggerEvent(
      "interaction_update",
      data: [
        "gfp": pointValue(x: global.x, y: global.y),
        "fpd": pointValue(x: delta.x, y: delta.y),
        "lfp": pointValue(x: global.x - globalOrigin.x, y: global.y - globalOrigin.y),
        "pc": .int(magnification == 1 ? 1 : 2),
        "hs": .double(magnification),
        "vs": .double(magnification),
        "s": .double(magnification),
        "rot": .double(0),
        "ts": .int(timestamp),
      ])
    lastUpdate = ProcessInfo.processInfo.systemUptime
  }

  private func handlePointerScroll(
    phase: RufletInteractivePointerPhase,
    delta: CGSize,
    local: CGPoint,
    global: CGPoint
  ) {
    guard !control.disabled else { return }
    let configuration = RufletInteractivePointerConfiguration(control: control)

    if phase == .began || !interacting {
      interacting = true
      previousFocalPoint = global
      triggerStart(global: global, magnification: 1)
    }

    if configuration.trackpadScrollCausesScale, scaleEnabled {
      let oldScale = scale
      let newScale = clampedScale(oldScale * configuration.scaleMultiplier(for: delta.height))
      let anchor = parsedAlignment.rufletUnitPoint
      let anchorPoint = CGPoint(
        x: viewportSize.width * anchor.x,
        y: viewportSize.height * anchor.y
      )
      let ratio = oldScale == 0 ? 1 : newScale / oldScale
      let focusedOffset = CGSize(
        width: offset.width + (local.x - anchorPoint.x) * (1 - ratio),
        height: offset.height + (local.y - anchorPoint.y) * (1 - ratio)
      )
      scale = newScale
      offset = clampedOffset(focusedOffset, at: newScale)
      triggerUpdate(global: global, magnification: ratio)
    } else if panEnabled {
      offset = clampedOffset(
        CGSize(width: offset.width + delta.width, height: offset.height + delta.height),
        at: scale
      )
      triggerUpdate(global: global, magnification: 1)
    }

    previousFocalPoint = global
    if phase == .ended || phase == .cancelled {
      control.triggerEvent(
        "interaction_end",
        data: [
          "pc": .int(0),
          "v": pointValue(x: 0, y: 0),
        ])
      interacting = false
    }
  }

  private func clampedScale(_ proposed: Double) -> Double {
    var minimum = minScale
    if constrained, contentSize.width > 0, contentSize.height > 0 {
      minimum = max(
        minimum,
        max(viewportSize.width / contentSize.width, viewportSize.height / contentSize.height))
    }
    return min(max(proposed, minimum), maxScale)
  }

  private func clampedOffset(_ proposed: CGSize, at scale: Double) -> CGSize {
    let margin = parseMargin(control.dynamicValue("boundary_margin")) ?? EdgeInsets()
    let maxX =
      max((contentSize.width * scale - viewportSize.width) / 2, 0) + margin.leading
      + margin.trailing
    let maxY =
      max((contentSize.height * scale - viewportSize.height) / 2, 0) + margin.top + margin.bottom
    return CGSize(
      width: min(max(proposed.width, -maxX), maxX),
      height: min(max(proposed.height, -maxY), maxY)
    )
  }

  private func installInvokeListener() {
    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { name, arguments in
      try await invoke(name, arguments: arguments)
    }
  }

  private func removeInvokeListener() {
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
  }

  private func invoke(_ name: String, arguments: RufletValue) async throws -> RufletValue {
    let values = arguments.map ?? [:]
    switch name {
    case "zoom":
      if let factor = values["factor"]?.number {
        scale = clampedScale(scale * factor)
        offset = clampedOffset(offset, at: scale)
      }
    case "pan":
      if let dx = values["dx"]?.number {
        offset = clampedOffset(
          CGSize(
            width: offset.width + dx,
            height: offset.height + (values["dy"]?.number ?? 0)
          ), at: scale)
      }
    case "reset":
      if let duration = parseDuration(values["animation_duration"].map(rufletAny)) {
        withAnimation(.linear(duration: duration)) {
          scale = 1
          offset = .zero
        }
      } else {
        scale = 1
        offset = .zero
      }
    case "save_state":
      savedTransform = RufletInteractiveTransform(scale: scale, offset: offset)
    case "restore_state":
      if let savedTransform {
        scale = savedTransform.scale
        offset = savedTransform.offset
      }
    default:
      throw RufletInteractiveViewerError.unknownMethod(name)
    }
    return .null
  }

  private func pointValue(x: CGFloat, y: CGFloat) -> RufletValue {
    ["x": .double(x), "y": .double(y)]
  }

  private var timestamp: Int64 { Int64(Date().timeIntervalSince1970 * 1_000) }
  private var minScale: Double { control.number("min_scale", default: 0.8) ?? 0.8 }
  private var maxScale: Double { control.number("max_scale", default: 2.5) ?? 2.5 }
  private var panEnabled: Bool { control.boolean("pan_enabled", default: true) }
  private var scaleEnabled: Bool { control.boolean("scale_enabled", default: true) }
  private var constrained: Bool { control.boolean("constrained", default: true) }
  private var parsedAlignment: Alignment {
    parseAlignment(control.dynamicValue("alignment"), .center)!.swiftUI
  }
  private var clipBehavior: String {
    control.string("clip_behavior", default: "hardEdge")!.lowercased()
  }
  private var inertiaDuration: TimeInterval {
    let friction =
      control.number("interaction_end_friction_coefficient", default: 0.0000135) ?? 0.0000135
    return min(max(0.18 / max(friction * 10_000, 0.01), 0.08), 1.2)
  }
}

@MainActor
struct RufletInteractivePointerConfiguration {
  let scaleFactor: Double
  let trackpadScrollCausesScale: Bool

  init(control: RufletControl) {
    scaleFactor = max(control.number("scale_factor", default: 200) ?? 200, 0.000_001)
    let trackpadScaling = control.boolean("trackpad_scroll_causes_scale", default: false)
    trackpadScrollCausesScale = trackpadScaling
  }

  func scaleMultiplier(for verticalDelta: CGFloat) -> Double {
    exp(-Double(verticalDelta) / scaleFactor)
  }
}

private struct RufletInteractiveTransform {
  let scale: Double
  let offset: CGSize
}

private struct RufletInteractiveContentSizeKey: PreferenceKey {
  static let defaultValue = CGSize.zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private enum RufletInteractiveViewerError: Error {
  case unknownMethod(String)
}

extension Alignment {
  fileprivate var rufletUnitPoint: UnitPoint {
    UnitPoint(
      x: horizontal == .leading ? 0 : (horizontal == .trailing ? 1 : 0.5),
      y: vertical == .top ? 0 : (vertical == .bottom ? 1 : 0.5)
    )
  }
}
