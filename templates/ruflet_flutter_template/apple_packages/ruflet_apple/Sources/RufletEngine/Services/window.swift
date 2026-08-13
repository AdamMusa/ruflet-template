import Foundation
import RufletProtocol
#if os(macOS)
import AppKit
import SwiftUI
#endif

@MainActor
public final class WindowService: RufletInvokableService {
  #if os(macOS)
  private weak var window: NSWindow?
  private var delegate: RufletWindowDelegate?
  private var waitingForWindowObserver: NSObjectProtocol?
  private var parentListener: UUID?
  private var title: String?
  private var backgroundColor: String?
  private var width: Double?
  private var height: Double?
  private var minWidth: Double?
  private var minHeight: Double?
  private var maxWidth: Double?
  private var maxHeight: Double?
  private var top: Double?
  private var left: Double?
  private var opacity: Double?
  private var aspectRatio: Double?
  private var brightness: String?
  private var minimizable: Bool?
  private var maximizable: Bool?
  private var fullScreen: Bool?
  private var movable: Bool?
  private var resizable: Bool?
  private var alwaysOnTop: Bool?
  private var alwaysOnBottom: Bool?
  fileprivate var preventClose: Bool?
  private var minimized: Bool?
  private var maximized: Bool?
  private var alignment: RufletAlignment?
  private var badgeLabel: String?
  private var icon: String?
  private var hasShadow: Bool?
  private var visible: Bool?
  private var focused: Bool?
  private var frameless: Bool?
  private var titleBarHidden: Bool?
  private var titleBarButtonsHidden: Bool?
  private var skipTaskBar: Bool?
  private var progressBar: Double?
  private var ignoreMouseEvents: Bool?
  private var originalStyleMask: NSWindow.StyleMask?
  #endif

  public override func initialize() {
    #if os(macOS)
    if let app = NSApp,
       let window = app.keyWindow ?? app.mainWindow ?? app.windows.first {
      attach(to: window)
    } else {
      waitingForWindowObserver = NotificationCenter.default.addObserver(
        forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
      ) { [weak self] notification in
        Task { @MainActor in
          guard let self, let window = notification.object as? NSWindow else { return }
          self.attach(to: window)
        }
      }
    }
    #endif
  }

  public override func update() {
    #if os(macOS)
    applyProperties()
    #endif
  }

  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    #if os(macOS)
    guard let window else { throw RufletServiceError.unavailable("Window is not ready") }
    switch name {
    case "wait_until_ready_to_show": return nil
    case "to_front": NSApp.activate(ignoringOtherApps: true); window.orderFrontRegardless()
    case "center": window.center()
    case "close": window.performClose(nil)
    case "destroy": window.close()
    case "start_dragging":
      guard let event = NSApp.currentEvent else { throw RufletServiceError.unavailable("No pointer event") }
      window.performDrag(with: event)
    case "start_resizing":
      guard let edge = arguments["edge"]?.text else { throw RufletServiceError.missingArgument("edge") }
      try performResize(window: window, edge: edge)
    default: throw RufletServiceError.unknownMethod(service: "Window", method: name)
    }
    return nil
    #else
    throw RufletServiceError.unavailable("Window service is desktop-only")
    #endif
  }

  #if os(macOS)
  private func attach(to window: NSWindow) {
    guard self.window !== window else { return }
    if let waitingForWindowObserver {
      NotificationCenter.default.removeObserver(waitingForWindowObserver)
      self.waitingForWindowObserver = nil
    }
    self.window = window
    originalStyleMask = window.styleMask
    cacheState(window)
    let delegate = RufletWindowDelegate(service: self)
    self.delegate = delegate
    window.delegate = delegate
    super.initialize()
    parentListener = control.parent?.addListener { [weak self] in self?.pageChanged() }
    applyProperties()
  }

  private func pageChanged() {
    guard let nextTitle = control.parent?.string("title"), nextTitle != title else { return }
    applyProperties()
  }

  private func applyProperties() {
    guard let window, control.parent != nil else { return }
    let nextTitle = control.parent?.string("title")
    let nextBackground = control.string("bgcolor")
    let nextWidth = control.number("width")
    let nextHeight = control.number("height")
    let nextMinWidth = control.number("min_width")
    let nextMinHeight = control.number("min_height")
    let nextMaxWidth = control.number("max_width")
    let nextMaxHeight = control.number("max_height")
    let nextTop = control.number("top")
    let nextLeft = control.number("left")
    let nextFullScreen = control.boolean("full_screen")
    let nextMinimized = control.boolean("minimized")
    let nextMaximized = control.boolean("maximized")
    let nextAlignment = parseAlignmentValue(control.value("alignment"))
    let nextBadge = control.string("badge_label")
    let nextIcon = control.string("icon")
    let nextShadow = control.boolean("shadow")
    let nextOpacity = control.number("opacity")
    let nextAspectRatio = control.number("aspect_ratio")
    let nextBrightness = control.string("brightness")
    let nextMinimizable = control.boolean("minimizable")
    let nextMaximizable = control.boolean("maximizable")
    let nextAlwaysTop = control.boolean("always_on_top")
    let nextAlwaysBottom = control.boolean("always_on_bottom")
    let nextResizable = control.boolean("resizable")
    let nextMovable = control.boolean("movable")
    let nextPreventClose = control.boolean("prevent_close")
    let nextTitleBarHidden = control.boolean("title_bar_hidden")
    let nextTitleBarButtonsHidden = control.boolean("title_bar_buttons_hidden", default: false)
    let nextVisible = control.boolean("visible")
    let nextFocused = control.boolean("focused")
    let nextSkipTaskBar = control.boolean("skip_task_bar")
    let nextFrameless = control.boolean("frameless")
    let nextProgress = control.number("progress_bar")
    let nextIgnoreMouse = control.boolean("ignore_mouse_events")

    if let nextTitle, nextTitle != title { window.title = nextTitle; title = nextTitle }
    if let nextBackground, nextBackground != backgroundColor, let color = parseColor(nextBackground) {
      window.backgroundColor = NSColor(color); backgroundColor = nextBackground
    }
    if (nextWidth != nil || nextHeight != nil), (nextWidth != width || nextHeight != height),
       nextFullScreen != true, nextMaximized != true, nextMinimized != true {
      var frame = window.frame
      frame.size.width = nextWidth ?? frame.width
      frame.size.height = nextHeight ?? frame.height
      window.setFrame(frame, display: true)
      width = nextWidth; height = nextHeight
    }
    if (nextMinWidth != nil || nextMinHeight != nil), nextMinWidth != minWidth || nextMinHeight != minHeight {
      window.contentMinSize = NSSize(width: nextMinWidth ?? 0, height: nextMinHeight ?? 0)
      minWidth = nextMinWidth; minHeight = nextMinHeight
    }
    if (nextMaxWidth != nil || nextMaxHeight != nil), nextMaxWidth != maxWidth || nextMaxHeight != maxHeight {
      window.contentMaxSize = NSSize(width: nextMaxWidth ?? .greatestFiniteMagnitude,
                                     height: nextMaxHeight ?? .greatestFiniteMagnitude)
      maxWidth = nextMaxWidth; maxHeight = nextMaxHeight
    }
    if (nextTop != nil || nextLeft != nil), (nextTop != top || nextLeft != left),
       nextFullScreen != true, nextMaximized != true, nextMinimized != true {
      setPosition(top: nextTop, left: nextLeft, window: window)
      top = nextTop; left = nextLeft
    }
    if let nextOpacity, nextOpacity != opacity { window.alphaValue = nextOpacity; opacity = nextOpacity }
    if let nextAspectRatio, nextAspectRatio != aspectRatio {
      window.contentAspectRatio = NSSize(width: nextAspectRatio, height: 1); aspectRatio = nextAspectRatio
    }
    if let nextBrightness, nextBrightness != brightness {
      window.appearance = NSAppearance(named: nextBrightness.lowercased() == "dark" ? .darkAqua : .aqua)
      brightness = nextBrightness
    }
    if let nextMinimizable, nextMinimizable != minimizable {
      setStyle(.miniaturizable, enabled: nextMinimizable, window: window); minimizable = nextMinimizable
    }
    if nextMinimized != minimized {
      if nextMinimized == true { window.miniaturize(nil) }
      else if nextMinimized == false, nextMaximized != true { window.deminiaturize(nil) }
      minimized = nextMinimized
    }
    if let nextMaximizable, nextMaximizable != maximizable {
      window.standardWindowButton(.zoomButton)?.isEnabled = nextMaximizable; maximizable = nextMaximizable
    }
    if nextMaximized != maximized {
      if let nextMaximized, window.isZoomed != nextMaximized { window.zoom(nil) }
      maximized = nextMaximized
    }
    if let nextAlignment, nextAlignment != alignment { align(nextAlignment, window: window); alignment = nextAlignment }
    if let nextBadge, nextBadge != badgeLabel { NSApp.dockTile.badgeLabel = nextBadge; badgeLabel = nextBadge }
    if let nextIcon, nextIcon != icon,
       let source = control.backend.resolveAssetSource(.string(nextIcon)),
       let image = NSImage(contentsOfFile: source.path) { NSApp.applicationIconImage = image; icon = nextIcon }
    if let nextShadow, nextShadow != hasShadow { window.hasShadow = nextShadow; hasShadow = nextShadow }
    if let nextResizable, nextResizable != resizable {
      setStyle(.resizable, enabled: nextResizable, window: window); resizable = nextResizable
    }
    if let nextMovable, nextMovable != movable { window.isMovable = nextMovable; movable = nextMovable }
    if let nextFullScreen, nextFullScreen != fullScreen {
      if window.styleMask.contains(.fullScreen) != nextFullScreen { window.toggleFullScreen(nil) }
      fullScreen = nextFullScreen
    }
    if let nextAlwaysTop, nextAlwaysTop != alwaysOnTop { alwaysOnTop = nextAlwaysTop; updateWindowLevel(window) }
    if let nextAlwaysBottom, nextAlwaysBottom != alwaysOnBottom { alwaysOnBottom = nextAlwaysBottom; updateWindowLevel(window) }
    if let nextPreventClose, nextPreventClose != preventClose { preventClose = nextPreventClose }
    let effectiveHidden = nextTitleBarHidden ?? titleBarHidden ?? false
    if effectiveHidden != titleBarHidden || nextTitleBarButtonsHidden != titleBarButtonsHidden {
      window.titleVisibility = effectiveHidden ? .hidden : .visible
      window.titlebarAppearsTransparent = effectiveHidden
      for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        window.standardWindowButton(button)?.isHidden = nextTitleBarButtonsHidden
      }
      titleBarHidden = effectiveHidden; titleBarButtonsHidden = nextTitleBarButtonsHidden
    }
    if let nextVisible, nextVisible != visible {
      nextVisible ? window.orderFront(nil) : window.orderOut(nil); visible = nextVisible
    }
    if let nextFocused, nextFocused != focused {
      if nextFocused { window.makeKey() } else { window.resignKey() }
      focused = nextFocused
    }
    if let nextFrameless, nextFrameless != frameless {
      if nextFrameless { window.styleMask = .borderless }
      else { window.styleMask = originalStyleMask ?? [.titled, .closable, .miniaturizable, .resizable] }
      frameless = nextFrameless
    }
    if nextProgress != progressBar { updateDockProgress(nextProgress); progressBar = nextProgress }
    if let nextSkipTaskBar, nextSkipTaskBar != skipTaskBar {
      NSApp.setActivationPolicy(nextSkipTaskBar ? .accessory : .regular); skipTaskBar = nextSkipTaskBar
    }
    if let nextIgnoreMouse, nextIgnoreMouse != ignoreMouseEvents {
      window.ignoresMouseEvents = nextIgnoreMouse; ignoreMouseEvents = nextIgnoreMouse
    }
  }

  private func setStyle(_ style: NSWindow.StyleMask, enabled: Bool, window: NSWindow) {
    if enabled { window.styleMask.insert(style) } else { window.styleMask.remove(style) }
  }

  private func performResize(window: NSWindow, edge: String) throws {
    guard let firstEvent = NSApp.currentEvent else { throw RufletServiceError.unavailable("No pointer event") }
    let normalized = edge.lowercased().replacingOccurrences(of: "_", with: "")
      .replacingOccurrences(of: "-", with: "")
    let valid = ["top", "topleft", "topright", "left", "right", "bottom", "bottomleft", "bottomright"]
    guard valid.contains(normalized) else { throw RufletServiceError.invalidArgument("edge") }
    let startMouse = NSEvent.mouseLocation
    let startFrame = window.frame
    var event = firstEvent
    repeat {
      let mouse = NSEvent.mouseLocation
      let dx = mouse.x - startMouse.x
      let dy = mouse.y - startMouse.y
      var frame = startFrame
      if normalized.contains("left") {
        frame.origin.x += dx; frame.size.width -= dx
      } else if normalized.contains("right") {
        frame.size.width += dx
      }
      if normalized.contains("bottom") {
        frame.origin.y += dy; frame.size.height -= dy
      } else if normalized.contains("top") {
        frame.size.height += dy
      }
      let minimum = window.contentMinSize
      if frame.width >= minimum.width, frame.height >= minimum.height { window.setFrame(frame, display: true) }
      guard let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
      event = next
    } while event.type != .leftMouseUp
  }

  private func setPosition(top: Double?, left: Double?, window: NSWindow) {
    guard let screen = window.screen ?? NSScreen.main else { return }
    var frame = window.frame
    frame.origin.x = left ?? frame.origin.x
    if let top { frame.origin.y = screen.frame.maxY - top - frame.height }
    window.setFrameOrigin(frame.origin)
  }

  private func align(_ alignment: RufletAlignment, window: NSWindow) {
    guard let screen = window.screen ?? NSScreen.main else { return }
    let area = screen.visibleFrame
    let xFraction = (alignment.x + 1) / 2
    let yFraction = (1 - alignment.y) / 2
    window.setFrameOrigin(NSPoint(
      x: area.minX + (area.width - window.frame.width) * xFraction,
      y: area.minY + (area.height - window.frame.height) * yFraction))
  }

  private func updateWindowLevel(_ window: NSWindow) {
    if alwaysOnTop == true { window.level = .floating }
    else if alwaysOnBottom == true { window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow))) }
    else { window.level = .normal }
  }

  private func updateDockProgress(_ progress: Double?) {
    guard let progress, progress >= 0 else { NSApp.dockTile.contentView = nil; NSApp.dockTile.display(); return }
    let view = NSView(frame: NSRect(x: 0, y: 0, width: 128, height: 20))
    let indicator = NSProgressIndicator(frame: view.bounds)
    indicator.isIndeterminate = false; indicator.minValue = 0; indicator.maxValue = 1
    indicator.doubleValue = min(max(progress, 0), 1)
    view.addSubview(indicator); NSApp.dockTile.contentView = view; NSApp.dockTile.display()
  }

  private func cacheState(_ window: NSWindow) {
    let state = windowState(window)
    width = state.width; height = state.height; top = state.top; left = state.left
    opacity = state.opacity; minimized = state.minimized; maximized = state.maximized
    minimizable = state.minimizable; maximizable = state.maximizable
    fullScreen = state.fullScreen; resizable = state.resizable
    visible = state.visible; focused = state.focused
  }

  fileprivate func handleWindowEvent(_ name: String) {
    guard let window, !["resize", "resized", "move"].contains(name) else { return }
    let state = windowState(window)
    cacheState(window)
    control.backend.onWindowEvent(name, state: state)
  }

  fileprivate func handleWindowResize() {
    guard let window else { return }
    let nextMaximized = window.isZoomed
    guard nextMaximized != maximized else { return }
    handleWindowEvent(nextMaximized ? "maximize" : "unmaximize")
  }

  fileprivate func windowState(_ window: NSWindow) -> RufletWindowState {
    let screen = window.screen ?? NSScreen.main
    return RufletWindowState(
      maximized: window.isZoomed,
      minimized: window.isMiniaturized,
      fullScreen: window.styleMask.contains(.fullScreen),
      alwaysOnTop: window.level.rawValue > NSWindow.Level.normal.rawValue,
      focused: window.isKeyWindow,
      visible: window.isVisible,
      minimizable: window.styleMask.contains(.miniaturizable),
      maximizable: window.standardWindowButton(.zoomButton)?.isEnabled ?? false,
      resizable: window.styleMask.contains(.resizable),
      preventClose: preventClose ?? false,
      skipTaskBar: NSApp.activationPolicy() == .accessory,
      width: window.frame.width,
      height: window.frame.height,
      top: (screen?.frame.maxY ?? window.frame.maxY) - window.frame.maxY,
      left: window.frame.minX,
      opacity: window.alphaValue)
  }

  private func parseAlignmentValue(_ value: RufletValue?) -> RufletAlignment? {
    guard let map = value?.map else { return nil }
    return RufletAlignment(x: map["x"]?.number ?? 0, y: map["y"]?.number ?? 0)
  }
  #endif

  public override func dispose() {
    #if os(macOS)
    if let waitingForWindowObserver { NotificationCenter.default.removeObserver(waitingForWindowObserver) }
    if let parentListener { control.parent?.removeListener(parentListener) }
    if window?.delegate === delegate { window?.delegate = nil }
    waitingForWindowObserver = nil; parentListener = nil; delegate = nil
    super.dispose()
    #endif
  }
}

#if os(macOS)
@MainActor
private final class RufletWindowDelegate: NSObject, NSWindowDelegate {
  weak var service: WindowService?
  init(service: WindowService) { self.service = service }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    service?.handleWindowEvent("close")
    return service?.preventClose != true
  }
  func windowDidBecomeKey(_ notification: Notification) { service?.handleWindowEvent("focus") }
  func windowDidResignKey(_ notification: Notification) { service?.handleWindowEvent("blur") }
  func windowDidMiniaturize(_ notification: Notification) { service?.handleWindowEvent("minimize") }
  func windowDidDeminiaturize(_ notification: Notification) { service?.handleWindowEvent("restore") }
  func windowDidEnterFullScreen(_ notification: Notification) { service?.handleWindowEvent("enter-full-screen") }
  func windowDidExitFullScreen(_ notification: Notification) { service?.handleWindowEvent("leave-full-screen") }
  func windowDidMove(_ notification: Notification) { service?.handleWindowEvent("move") }
  func windowDidResize(_ notification: Notification) { service?.handleWindowResize() }
}
#endif
