import RufletProtocol
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
struct RufletPageLifecycleMonitor<Content: View>: View {
  let onTransition: (String) -> Void
  @ViewBuilder let content: () -> Content
  #if os(iOS)
  @State private var paused = false
  #endif

  var body: some View {
    #if os(iOS)
    content()
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
        if paused { onTransition("restart") }
        paused = false
        onTransition("show")
      }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in onTransition("resume") }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in onTransition("inactive") }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
        onTransition("hide")
        onTransition("pause")
        paused = true
      }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in onTransition("detach") }
    #elseif os(macOS)
    content()
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.didUnhideNotification)) { _ in onTransition("show") }
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in onTransition("resume") }
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.didHideNotification)) { _ in onTransition("hide") }
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in onTransition("inactive") }
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in onTransition("detach") }
    #endif
  }
}

@MainActor
enum RufletPageCaptureRegistry {
  private static var captures: [ObjectIdentifier: (CGFloat) -> Data?] = [:]

  static func register(backend: RufletBackendProtocol, capture: @escaping (CGFloat) -> Data?) {
    captures[ObjectIdentifier(backend)] = capture
  }

  static func unregister(backend: RufletBackendProtocol) {
    captures.removeValue(forKey: ObjectIdentifier(backend))
  }

  static func capture(backend: RufletBackendProtocol, pixelRatio: CGFloat) -> Data? {
    captures[ObjectIdentifier(backend)]?(pixelRatio)
  }
}

#if os(iOS)
struct RufletPagePlatformBridge: UIViewRepresentable {
  let control: RufletControl
  let title: String

  func makeUIView(context: Context) -> UIView {
    let view = UIView(frame: .zero)
    view.isUserInteractionEnabled = false
    return view
  }

  func updateUIView(_ view: UIView, context: Context) {
    RufletPageCaptureRegistry.register(backend: control.backend) { [weak view] pixelRatio in
      guard let root = view?.window else { return nil }
      let format = UIGraphicsImageRendererFormat()
      format.scale = pixelRatio
      let renderer = UIGraphicsImageRenderer(bounds: root.bounds, format: format)
      return renderer.image { _ in root.drawHierarchy(in: root.bounds, afterScreenUpdates: true) }.pngData()
    }
  }

  static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
    // The registry is replaced by the next mounted Page bridge. The Page view
    // explicitly unregisters its backend on disappearance.
  }
}

@MainActor
func setAllowedAppleDeviceOrientations(_ values: [String]) async throws {
  guard #available(iOS 16.0, *),
        let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
  else { return }
  var mask: UIInterfaceOrientationMask = []
  for value in values.map({ $0.lowercased() }) {
    switch value {
    case "portraitup": mask.insert(.portrait)
    case "portraitdown": mask.insert(.portraitUpsideDown)
    case "landscapeleft": mask.insert(.landscapeLeft)
    case "landscaperight": mask.insert(.landscapeRight)
    default: break
    }
  }
  if mask.isEmpty { mask = .all }
  scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
}
#elseif os(macOS)
struct RufletPagePlatformBridge: NSViewRepresentable {
  let control: RufletControl
  let title: String

  func makeNSView(context: Context) -> NSView {
    NSView(frame: .zero)
  }

  func updateNSView(_ view: NSView, context: Context) {
    view.window?.title = title
    RufletPageCaptureRegistry.register(backend: control.backend) { [weak view] pixelRatio in
      guard let root = view?.window?.contentView else { return nil }
      let bounds = root.bounds
      guard bounds.width > 0, bounds.height > 0,
            let representation = NSBitmapImageRep(
              bitmapDataPlanes: nil,
              pixelsWide: max(Int((bounds.width * pixelRatio).rounded()), 1),
              pixelsHigh: max(Int((bounds.height * pixelRatio).rounded()), 1),
              bitsPerSample: 8,
              samplesPerPixel: 4,
              hasAlpha: true,
              isPlanar: false,
              colorSpaceName: .deviceRGB,
              bytesPerRow: 0,
              bitsPerPixel: 0),
            let graphics = NSGraphicsContext(bitmapImageRep: representation)
      else { return nil }
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = graphics
      graphics.cgContext.scaleBy(x: pixelRatio, y: pixelRatio)
      root.layer?.render(in: graphics.cgContext)
      NSGraphicsContext.restoreGraphicsState()
      return representation.representation(using: .png, properties: [:])
    }
  }
}

@MainActor
func setAllowedAppleDeviceOrientations(_ values: [String]) async throws {
  // macOS windows have no device-orientation contract.
}
#endif

@MainActor
func defaultApplePixelRatio() -> Double {
  #if os(iOS)
  Double(UIScreen.main.scale)
  #elseif os(macOS)
  Double(NSScreen.main?.backingScaleFactor ?? 1)
  #endif
}

@MainActor
struct RufletPageKeyboardMonitor: View {
  let enabled: Bool
  let onEvent: (RufletKeyboardEvent) -> Void
  let onBack: () -> Void

  var body: some View {
    RufletNativeKeyboardMonitor(enabled: enabled, onEvent: onEvent, onBack: onBack)
      .frame(width: 0, height: 0)
      .accessibilityHidden(true)
  }
}

#if os(iOS)
private struct RufletNativeKeyboardMonitor: UIViewControllerRepresentable {
  let enabled: Bool
  let onEvent: (RufletKeyboardEvent) -> Void
  let onBack: () -> Void

  func makeUIViewController(context: Context) -> RufletKeyboardViewController {
    RufletKeyboardViewController()
  }

  func updateUIViewController(_ controller: RufletKeyboardViewController, context: Context) {
    controller.enabled = enabled
    controller.onEvent = onEvent
    controller.onBack = onBack
    if enabled { controller.becomeFirstResponder() }
  }
}

private final class RufletKeyboardViewController: UIViewController {
  var enabled = false
  var onEvent: ((RufletKeyboardEvent) -> Void)?
  var onBack: (() -> Void)?
  override var canBecomeFirstResponder: Bool { enabled }

  override var keyCommands: [UIKeyCommand]? {
    guard enabled else { return nil }
    var commands = ("abcdefghijklmnopqrstuvwxyz0123456789").map { character in
      UIKeyCommand(input: String(character), modifierFlags: [], action: #selector(receive(_:)))
    }
    commands.append(UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(back)))
    return commands
  }

  @objc private func receive(_ command: UIKeyCommand) {
    guard let input = command.input else { return }
    let modifiers = command.modifierFlags
    onEvent?(RufletKeyboardEvent(
      key: input,
      isShiftPressed: modifiers.contains(.shift),
      isControlPressed: modifiers.contains(.control),
      isAltPressed: modifiers.contains(.alternate),
      isMetaPressed: modifiers.contains(.command)))
  }

  @objc private func back() { onBack?() }
}
#elseif os(macOS)
private struct RufletNativeKeyboardMonitor: NSViewRepresentable {
  let enabled: Bool
  let onEvent: (RufletKeyboardEvent) -> Void
  let onBack: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

  func updateNSView(_ view: NSView, context: Context) {
    context.coordinator.install(enabled: enabled, onEvent: onEvent, onBack: onBack)
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.remove()
  }

  final class Coordinator {
    private var monitor: Any?

    func install(
      enabled: Bool,
      onEvent: @escaping (RufletKeyboardEvent) -> Void,
      onBack: @escaping () -> Void
    ) {
      remove()
      guard enabled else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        if event.keyCode == 53 { onBack(); return event }
        let modifiers = event.modifierFlags
        onEvent(RufletKeyboardEvent(
          key: event.charactersIgnoringModifiers ?? "",
          isShiftPressed: modifiers.contains(.shift),
          isControlPressed: modifiers.contains(.control),
          isAltPressed: modifiers.contains(.option),
          isMetaPressed: modifiers.contains(.command)))
        return event
      }
    }

    func remove() {
      if let monitor { NSEvent.removeMonitor(monitor) }
      monitor = nil
    }
  }
}
#endif
