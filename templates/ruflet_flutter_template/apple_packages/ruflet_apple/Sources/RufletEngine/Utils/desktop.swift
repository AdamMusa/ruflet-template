import SwiftUI

#if os(macOS)
import AppKit
#endif

public enum RufletDesktopError: Error {
  case unavailable
}

@MainActor private var currentRufletWindow: AnyObject? {
  #if os(macOS)
  NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first
  #else
  nil
  #endif
}

@MainActor public func setWindowTitle(_ title: String) async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.title = title
  #endif
}

@MainActor public func setWindowBackgroundColor(_ color: Color) async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.backgroundColor = NSColor(color)
  #endif
}

@MainActor public func setWindowSize(_ width: Double?, _ height: Double?) async {
  #if os(macOS)
  guard let window = currentRufletWindow as? NSWindow else { return }
  var frame = window.frame
  frame.size = NSSize(width: width ?? frame.width, height: height ?? frame.height)
  window.setFrame(frame, display: true)
  #endif
}

@MainActor public func setWindowMinSize(_ width: Double?, _ height: Double?) async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.contentMinSize = NSSize(width: width ?? 0, height: height ?? 0)
  #endif
}

@MainActor public func setWindowMaxSize(_ width: Double?, _ height: Double?) async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.contentMaxSize = NSSize(
    width: width ?? .greatestFiniteMagnitude, height: height ?? .greatestFiniteMagnitude)
  #endif
}

@MainActor public func setWindowPosition(_ top: Double?, _ left: Double?) async {
  #if os(macOS)
  guard let window = currentRufletWindow as? NSWindow else { return }
  let screen = window.screen ?? NSScreen.main
  let x = left ?? window.frame.minX
  let y = top.map { (screen?.frame.maxY ?? window.frame.maxY) - $0 - window.frame.height }
    ?? window.frame.minY
  window.setFrameOrigin(NSPoint(x: x, y: y))
  #endif
}

@MainActor public func setWindowOpacity(_ opacity: Double) async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.alphaValue = min(max(opacity, 0), 1)
  #endif
}

@MainActor public func setWindowMinimizability(_ enabled: Bool) async {
  #if os(macOS)
  setWindowStyle(.miniaturizable, enabled: enabled)
  #endif
}

@MainActor public func setWindowMaximizability(_ enabled: Bool) async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.standardWindowButton(.zoomButton)?.isEnabled = enabled
  #endif
}

@MainActor public func setWindowResizability(_ enabled: Bool) async {
  #if os(macOS)
  setWindowStyle(.resizable, enabled: enabled)
  #endif
}

@MainActor public func setWindowMovability(_ enabled: Bool) async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.isMovable = enabled
  #endif
}

@MainActor public func setWindowFullScreen(_ enabled: Bool) async {
  #if os(macOS)
  guard let window = currentRufletWindow as? NSWindow,
        window.styleMask.contains(.fullScreen) != enabled else { return }
  window.toggleFullScreen(nil)
  #endif
}

@MainActor public func setWindowAlwaysOnTop(_ enabled: Bool) async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.level = enabled ? .floating : .normal
  #endif
}

@MainActor public func setWindowAlwaysOnBottom(_ enabled: Bool) async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.level = enabled
    ? NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow))) : .normal
  #endif
}

@MainActor public func setWindowPreventClose(_ enabled: Bool) async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.standardWindowButton(.closeButton)?.isEnabled = !enabled
  #endif
}

@MainActor public func setWindowTitleBarVisibility(
  _ hidden: Bool, _ buttonsHidden: Bool
) async {
  #if os(macOS)
  guard let window = currentRufletWindow as? NSWindow else { return }
  window.titleVisibility = hidden ? .hidden : .visible
  window.titlebarAppearsTransparent = hidden
  [.closeButton, .miniaturizeButton, .zoomButton].forEach {
    window.standardWindowButton($0)?.isHidden = buttonsHidden
  }
  #endif
}

@MainActor public func setWindowSkipTaskBar(_ skip: Bool) async {
  #if os(macOS)
  NSApp.setActivationPolicy(skip ? .accessory : .regular)
  #endif
}

@MainActor public func setWindowFrameless() async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.styleMask = .borderless
  #endif
}

@MainActor public func setWindowProgressBar(_ progress: Double) async {
  #if os(macOS)
  if progress < 0 { NSApp.dockTile.contentView = nil; NSApp.dockTile.display(); return }
  let view = NSView(frame: NSRect(x: 0, y: 0, width: 128, height: 20))
  let indicator = NSProgressIndicator(frame: view.bounds)
  indicator.isIndeterminate = false
  indicator.minValue = 0
  indicator.maxValue = 1
  indicator.doubleValue = min(max(progress, 0), 1)
  view.addSubview(indicator)
  NSApp.dockTile.contentView = view
  NSApp.dockTile.display()
  #endif
}

@MainActor public func setWindowShadow(_ enabled: Bool) async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.hasShadow = enabled
  #endif
}

@MainActor public func setWindowBadgeLabel(_ label: String) async {
  #if os(macOS)
  NSApp.dockTile.badgeLabel = label
  #endif
}

@MainActor public func setWindowIcon(_ path: String) async {
  #if os(macOS)
  if let image = NSImage(contentsOfFile: path) { NSApp.applicationIconImage = image }
  #endif
}

@MainActor public func setWindowAlignment(
  _ alignment: RufletAlignment, animate: Bool = true
) async {
  #if os(macOS)
  guard let window = currentRufletWindow as? NSWindow,
        let screen = window.screen ?? NSScreen.main else { return }
  let area = screen.visibleFrame
  window.setFrameOrigin(NSPoint(
    x: area.minX + (area.width - window.frame.width) * ((alignment.x + 1) / 2),
    y: area.minY + (area.height - window.frame.height) * ((1 - alignment.y) / 2)))
  #endif
}

@MainActor public func setWindowAspectRatio(_ value: Double) async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.contentAspectRatio = NSSize(width: value, height: 1)
  #endif
}

@MainActor public func setWindowBrightness(_ value: String) async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.appearance = NSAppearance(
    named: value.lowercased() == "dark" ? .darkAqua : .aqua)
  #endif
}

@MainActor public func minimizeWindow() async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.miniaturize(nil)
  #endif
}

@MainActor public func restoreWindow() async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.deminiaturize(nil)
  #endif
}

@MainActor public func maximizeWindow() async {
  #if os(macOS)
  guard let window = currentRufletWindow as? NSWindow, !window.isZoomed else { return }
  window.zoom(nil)
  #endif
}

@MainActor public func unmaximizeWindow() async {
  #if os(macOS)
  guard let window = currentRufletWindow as? NSWindow, window.isZoomed else { return }
  window.zoom(nil)
  #endif
}

@MainActor public func showWindow() async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.orderFront(nil)
  #endif
}

@MainActor public func hideWindow() async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.orderOut(nil)
  #endif
}

@MainActor public func focusWindow() async {
  #if os(macOS)
  NSApp.activate(ignoringOtherApps: true)
  (currentRufletWindow as? NSWindow)?.makeKeyAndOrderFront(nil)
  #endif
}

@MainActor public func windowToFront() async { await focusWindow() }

@MainActor public func startDraggingWindow() async {
  #if os(macOS)
  guard let event = NSApp.currentEvent else { return }
  (currentRufletWindow as? NSWindow)?.performDrag(with: event)
  #endif
}

@MainActor public func startResizingWindow(_ edge: RufletWindowResizeEdge) async {
  #if os(macOS)
  guard let window = currentRufletWindow as? NSWindow,
        var event = NSApp.currentEvent else { return }
  let startMouse = NSEvent.mouseLocation
  let startFrame = window.frame
  repeat {
    let mouse = NSEvent.mouseLocation
    let dx = mouse.x - startMouse.x
    let dy = mouse.y - startMouse.y
    var frame = startFrame
    switch edge {
    case .left, .topLeft, .bottomLeft:
      frame.origin.x += dx
      frame.size.width -= dx
    case .right, .topRight, .bottomRight:
      frame.size.width += dx
    default: break
    }
    switch edge {
    case .bottom, .bottomLeft, .bottomRight:
      frame.origin.y += dy
      frame.size.height -= dy
    case .top, .topLeft, .topRight:
      frame.size.height += dy
    default: break
    }
    if frame.width >= window.contentMinSize.width,
       frame.height >= window.contentMinSize.height {
      window.setFrame(frame, display: true)
    }
    guard let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
    event = next
  } while event.type != .leftMouseUp
  #endif
}

@MainActor public func blurWindow() async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.resignKey()
  #endif
}

@MainActor public func destroyWindow() async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.close()
  #endif
}

@MainActor public func waitUntilReadyToShow() async {}

@MainActor public func centerWindow() async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.center()
  #endif
}

@MainActor public func closeWindow() async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.performClose(nil)
  #endif
}

@MainActor public func isFocused() async -> Bool {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.isKeyWindow ?? false
  #else
  false
  #endif
}

@MainActor public func setIgnoreMouseEvents(_ ignore: Bool) async {
  #if os(macOS)
  (currentRufletWindow as? NSWindow)?.ignoresMouseEvents = ignore
  #endif
}

@MainActor public func getWindowState() async throws -> RufletWindowState {
  #if os(macOS)
  guard let window = currentRufletWindow as? NSWindow else { throw RufletDesktopError.unavailable }
  let screen = window.screen ?? NSScreen.main
  return RufletWindowState(
    maximized: window.isZoomed, minimized: window.isMiniaturized,
    fullScreen: window.styleMask.contains(.fullScreen),
    alwaysOnTop: window.level.rawValue > NSWindow.Level.normal.rawValue,
    focused: window.isKeyWindow, visible: window.isVisible,
    minimizable: window.styleMask.contains(.miniaturizable),
    maximizable: window.standardWindowButton(.zoomButton)?.isEnabled ?? false,
    resizable: window.styleMask.contains(.resizable), preventClose: false,
    skipTaskBar: NSApp.activationPolicy() == .accessory,
    width: window.frame.width, height: window.frame.height,
    top: (screen?.frame.maxY ?? window.frame.maxY) - window.frame.maxY,
    left: window.frame.minX, opacity: window.alphaValue)
  #else
  throw RufletDesktopError.unavailable
  #endif
}

#if os(macOS)
@MainActor private func setWindowStyle(_ style: NSWindow.StyleMask, enabled: Bool) {
  guard let window = currentRufletWindow as? NSWindow else { return }
  if enabled { window.styleMask.insert(style) } else { window.styleMask.remove(style) }
}
#endif
