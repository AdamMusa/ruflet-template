import Foundation
import RufletProtocol

#if canImport(AppKit)
  import AppKit
#endif
#if canImport(UIKit)
  import UIKit
#endif

/// The seven imperative operations exposed by Flet's `WindowService`.
public enum RufletWindowAction: Equatable {
  case center
  case close
  case destroy
  case startDragging
  case startResizing(edge: String)
  case toFront
  case waitUntilReadyToShow
}

public enum RufletWindowEventType: String, CaseIterable, Equatable, Sendable {
  case close
  case focus
  case blur
  case hide
  case show
  case maximize
  case unmaximize
  case minimize
  case restore
  case resize
  case resized
  case move
  case moved
  case leaveFullScreen = "leave-full-screen"
  case enterFullScreen = "enter-full-screen"
}

public struct RufletWindowStateSnapshot: Equatable {
  public let maximized: Bool
  public let minimized: Bool
  public let fullScreen: Bool
  public let alwaysOnTop: Bool
  public let focused: Bool
  public let visible: Bool
  public let width: Double
  public let height: Double
  public let top: Double
  public let left: Double
  public let opacity: Double

  public init(
    maximized: Bool, minimized: Bool, fullScreen: Bool, alwaysOnTop: Bool,
    focused: Bool, visible: Bool, width: Double, height: Double,
    top: Double, left: Double, opacity: Double
  ) {
    self.maximized = maximized
    self.minimized = minimized
    self.fullScreen = fullScreen
    self.alwaysOnTop = alwaysOnTop
    self.focused = focused
    self.visible = visible
    self.width = width
    self.height = height
    self.top = top
    self.left = left
    self.opacity = opacity
  }

  /// Exact fields from Flet's pinned `WindowState.toMap()`.
  public var wireProperties: [String: RufletValue] {
    [
      "maximized": .bool(maximized),
      "minimized": .bool(minimized),
      "full_screen": .bool(fullScreen),
      "always_on_top": .bool(alwaysOnTop),
      "focused": .bool(focused),
      "visible": .bool(visible),
      "width": .double(width),
      "height": .double(height),
      "top": .double(top),
      "left": .double(left),
      "opacity": .double(opacity),
    ]
  }
}

public struct RufletWindowEvent: Equatable {
  public let type: RufletWindowEventType
  public let state: RufletWindowStateSnapshot

  public init(type: RufletWindowEventType, state: RufletWindowStateSnapshot) {
    self.type = type
    self.state = state
  }
}

/// Property model consumed by AppKit. Keeping nullable axes independent is
/// important: Flet forwards `width`/`height`, min/max dimensions, and
/// `top`/`left` independently rather than requiring pairs.
public struct RufletWindowConfiguration: Equatable {
  public let title: String?
  public let width: Double?
  public let height: Double?
  public let minWidth: Double?
  public let minHeight: Double?
  public let maxWidth: Double?
  public let maxHeight: Double?
  public let top: Double?
  public let left: Double?
  public let aspectRatio: Double?
  public let alignment: CGPoint?

  public init(node: ControlNode, pageTitle: String?) {
    title = pageTitle
    width = node.double("width")
    height = node.double("height")
    minWidth = node.double("min_width")
    minHeight = node.double("min_height")
    maxWidth = node.double("max_width")
    maxHeight = node.double("max_height")
    top = node.double("top")
    left = node.double("left")
    aspectRatio = node.double("aspect_ratio")
    if let map = node.props["alignment"]?.mapValue {
      alignment = CGPoint(
        x: map["x"]?.doubleValue ?? 0,
        y: map["y"]?.doubleValue ?? 0)
    } else {
      alignment = nil
    }
  }
}

/// Injectable host boundary. It keeps command parsing independently testable
/// and keeps AppKit/UIKit details out of the protocol session.
@MainActor
public protocol RufletWindowHost: AnyObject {
  func configureLifecycle(
    preventClose: Bool,
    eventHandler: @escaping (RufletWindowEvent) -> Void)

  func perform(
    _ action: RufletWindowAction,
    completion: @escaping (Result<Void, Error>) -> Void)
}

extension RufletWindowHost {
  public func configureLifecycle(
    preventClose: Bool,
    eventHandler: @escaping (RufletWindowEvent) -> Void
  ) {}
}

@MainActor
public final class WindowService: RufletStreamingService {
  public static let wireType = "Window"

  private let host: RufletWindowHost

  public init() {
    self.host = NativeRufletWindowHost()
  }

  public init(host: RufletWindowHost) {
    self.host = host
  }

  /// Ruby configures the window by setting properties on the control, so the
  /// state is applied whenever the control appears or its props change, and
  /// the window reports back through `on_event` the way Flet's window service
  /// does.
  public func activate(node: ControlNode, context: RufletServiceContext) {
    let target = node.id
    host.configureLifecycle(preventClose: node.bool("prevent_close") ?? false) { event in
      let operations = event.state.wireProperties.map {
        ControlPatch.Operation.set(key: $0.key, value: $0.value)
      }
      context.store.apply(ControlPatch(controlID: target, operations: operations))
      if context.store.node(target)?.handlesEvent("event") == true {
        context.emitEvent(target, "event", .map(["type": .string(event.type.rawValue)]))
      }
    }
    #if canImport(AppKit)
      DispatchQueue.main.async {
        guard let window = NSApplication.shared.windows.first else { return }
        Self.apply(
          node, to: window,
          pageTitle: context.store.page?.string("title"))
      }
    #endif
  }

  #if canImport(AppKit)
    /// Every window property Flet carries that AppKit can express. The ones it
    /// cannot — a task-bar entry, a dock progress bar — are noted where they
    /// are read.
    static func apply(_ node: ControlNode, to window: NSWindow, pageTitle: String? = nil) {
      let configuration = RufletWindowConfiguration(node: node, pageTitle: pageTitle)
      if let title = configuration.title { window.title = title }
      if configuration.width != nil || configuration.height != nil {
        let current = window.contentLayoutRect.size
        window.setContentSize(NSSize(
          width: configuration.width ?? current.width,
          height: configuration.height ?? current.height))
      }
      if configuration.minWidth != nil || configuration.minHeight != nil {
        window.contentMinSize = NSSize(
          width: configuration.minWidth ?? window.contentMinSize.width,
          height: configuration.minHeight ?? window.contentMinSize.height)
      }
      if configuration.maxWidth != nil || configuration.maxHeight != nil {
        window.contentMaxSize = NSSize(
          width: configuration.maxWidth ?? window.contentMaxSize.width,
          height: configuration.maxHeight ?? window.contentMaxSize.height)
      }
      if let ratio = configuration.aspectRatio, ratio > 0 {
        window.contentAspectRatio = NSSize(width: ratio, height: 1)
      }
      if configuration.top != nil || configuration.left != nil,
        let screen = window.screen ?? NSScreen.main
      {
        var frame = window.frame
        if let left = configuration.left { frame.origin.x = left }
        if let top = configuration.top { frame.origin.y = screen.frame.maxY - top - frame.height }
        window.setFrameOrigin(frame.origin)
      } else if let alignment = configuration.alignment,
        let screen = window.screen ?? NSScreen.main
      {
        let available = screen.visibleFrame
        let unitX = min(max((alignment.x + 1) / 2, 0), 1)
        let unitY = min(max((alignment.y + 1) / 2, 0), 1)
        window.setFrameOrigin(NSPoint(
          x: available.minX + (available.width - window.frame.width) * unitX,
          y: available.minY + (available.height - window.frame.height) * (1 - unitY)))
      }

      var style = window.styleMask
      style.toggle(.resizable, on: node.bool("resizable") ?? true)
      style.toggle(.miniaturizable, on: node.bool("minimizable") ?? true)
      // A frameless window drops its title bar entirely; a hidden title bar
      // keeps the traffic lights over the content.
      style.toggle(.titled, on: node.bool("frameless") != true)
      style.toggle(.fullSizeContentView, on: node.bool("title_bar_hidden") == true)
      window.styleMask = style
      window.titlebarAppearsTransparent = node.bool("title_bar_hidden") == true
      window.isMovable = node.bool("movable") ?? true
      window.isMovableByWindowBackground = node.bool("movable") ?? true
      window.hasShadow = node.bool("shadow") ?? true
      window.ignoresMouseEvents = node.bool("ignore_mouse_events") ?? false
      window.alphaValue = node.double("opacity").map { CGFloat($0) } ?? 1

      // `maximizable` is the zoom button rather than a mask bit.
      window.standardWindowButton(.zoomButton)?.isEnabled = node.bool("maximizable") ?? true
      let hidesButtons = node.bool("title_bar_buttons_hidden") == true
      for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        window.standardWindowButton(button)?.isHidden = hidesButtons
      }

      if node.bool("always_on_top") == true {
        window.level = .floating
      } else if node.bool("always_on_bottom") == true {
        window.level = .init(Int(CGWindowLevelForKey(.desktopWindow)))
      } else {
        window.level = .normal
      }

      if let brightness = node.string("brightness") {
        window.appearance = NSAppearance(named: brightness == "dark" ? .darkAqua : .aqua)
      }

      let wantsFullScreen = node.bool("full_screen") == true
      if wantsFullScreen != window.styleMask.contains(.fullScreen) {
        window.toggleFullScreen(nil)
      }
      if let maximized = node.bool("maximized"), maximized != window.isZoomed {
        window.zoom(nil)
      }
      if let minimized = node.bool("minimized"), minimized != window.isMiniaturized {
        if minimized { window.miniaturize(nil) } else { window.deminiaturize(nil) }
      }
      if let visible = node.bool("visible"), visible != window.isVisible {
        if visible { window.orderFront(nil) } else { window.orderOut(nil) }
      }
      if let focused = node.bool("focused"), focused != window.isKeyWindow {
        if focused { window.makeKeyAndOrderFront(nil) } else { window.resignKey() }
      }

      // `badge_label` is the dock tile's badge, which belongs to the app
      // rather than the window; `progress_bar` and `skip_task_bar` have no
      // AppKit counterpart — macOS has no task bar, and a dock progress
      // indicator is drawn by the application, not set as a property.
      NSApplication.shared.dockTile.badgeLabel = node.string("badge_label")
      _ = node.double("progress_bar")
      _ = node.bool("skip_task_bar")
    }
  #endif

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    let action: RufletWindowAction
    switch call.name {
    case "center": action = .center
    case "close": action = .close
    case "destroy": action = .destroy
    case "start_dragging": action = .startDragging
    case "start_resizing":
      // Flet ignores an unknown/missing ResizeEdge rather than throwing.
      guard let edge = call.argument("edge")?.stringValue?.lowercased(),
        Self.resizeEdges.contains(edge)
      else { return completion(.success(.null)) }
      action = .startResizing(edge: edge)
    case "to_front": action = .toFront
    case "wait_until_ready_to_show": action = .waitUntilReadyToShow
    default:
      return completion(.failure(RufletServiceError.unsupportedMethod(
        type: Self.wireType, method: call.name)))
    }

    host.perform(action) { result in
      completion(result.map { .null })
    }
  }

  private static let resizeEdges: Set<String> = [
    "top", "bottom", "left", "right", "top_left", "top_right",
    "bottom_left", "bottom_right"
  ]
}

#if canImport(AppKit)
  @MainActor
  private final class RufletWindowDelegateProxy: NSObject, NSWindowDelegate {
    weak var forwardingDelegate: NSWindowDelegate?
    var preventClose = false
    var closeRequested: (() -> Void)?

    func windowShouldClose(_ sender: NSWindow) -> Bool {
      closeRequested?()
      guard !preventClose else { return false }
      return forwardingDelegate?.windowShouldClose?(sender) ?? true
    }

    override func responds(to selector: Selector!) -> Bool {
      super.responds(to: selector) || forwardingDelegate?.responds(to: selector) == true
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
      if forwardingDelegate?.responds(to: selector) == true { return forwardingDelegate }
      return super.forwardingTarget(for: selector)
    }
  }
#endif

@MainActor
public final class NativeRufletWindowHost: RufletWindowHost {
  #if canImport(AppKit)
    private var resizeMonitor: Any?
    private weak var lifecycleWindow: NSWindow?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private let delegateProxy = RufletWindowDelegateProxy()
    private var lifecycleHandler: ((RufletWindowEvent) -> Void)?
    private var lastZoomed = false
    private var lastVisible = false
  #endif

  public init() {}

  deinit {
    #if canImport(AppKit)
      if let resizeMonitor { NSEvent.removeMonitor(resizeMonitor) }
      for observer in lifecycleObservers { NotificationCenter.default.removeObserver(observer) }
      MainActor.assumeIsolated {
        if let lifecycleWindow,
          (lifecycleWindow.delegate as AnyObject?) === delegateProxy
        {
          lifecycleWindow.delegate = delegateProxy.forwardingDelegate
        }
      }
    #endif
  }

  public func configureLifecycle(
    preventClose: Bool,
    eventHandler: @escaping (RufletWindowEvent) -> Void
  ) {
    #if canImport(AppKit)
      lifecycleHandler = eventHandler
      delegateProxy.preventClose = preventClose
      installLifecycleIfPossible()
      DispatchQueue.main.async { [weak self] in self?.installLifecycleIfPossible() }
    #endif
  }

  public func perform(
    _ action: RufletWindowAction,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    #if canImport(AppKit)
      performAppKit(action, completion: completion)
    #elseif canImport(UIKit)
      performUIKit(action, completion: completion)
    #else
      completion(.failure(RufletServiceError.platformUnsupported(
        type: "Window", method: Self.methodName(action), platform: "Apple")))
    #endif
  }

  #if canImport(AppKit)
    private func installLifecycleIfPossible() {
      guard let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first else { return }
      delegateProxy.closeRequested = { [weak self] in self?.report(.close) }
      guard lifecycleWindow !== window else { return }

      if let lifecycleWindow,
        (lifecycleWindow.delegate as AnyObject?) === delegateProxy
      {
        lifecycleWindow.delegate = delegateProxy.forwardingDelegate
      }
      for observer in lifecycleObservers { NotificationCenter.default.removeObserver(observer) }
      lifecycleObservers.removeAll()

      lifecycleWindow = window
      lastZoomed = window.isZoomed
      lastVisible = window.isVisible
      if window.delegate !== delegateProxy {
        delegateProxy.forwardingDelegate = window.delegate
        window.delegate = delegateProxy
      }

      observe(NSWindow.didBecomeKeyNotification, as: .focus, window: window)
      observe(NSWindow.didResignKeyNotification, as: .blur, window: window)
      observe(NSWindow.didMiniaturizeNotification, as: .minimize, window: window)
      observe(NSWindow.didDeminiaturizeNotification, as: .restore, window: window)
      observe(NSWindow.didMoveNotification, as: .moved, window: window)
      observe(NSWindow.didEnterFullScreenNotification, as: .enterFullScreen, window: window)
      observe(NSWindow.didExitFullScreenNotification, as: .leaveFullScreen, window: window)
      lifecycleObservers.append(NotificationCenter.default.addObserver(
        forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.reportVisibility() }
      })
      lifecycleObservers.append(NotificationCenter.default.addObserver(
        forName: NSWindow.didResizeNotification, object: window, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.reportResize() }
      })
    }

    private func observe(
      _ name: Notification.Name,
      as type: RufletWindowEventType,
      window: NSWindow
    ) {
      lifecycleObservers.append(NotificationCenter.default.addObserver(
        forName: name, object: window, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.report(type) }
      })
    }

    private func reportResize() {
      guard let window = lifecycleWindow else { return }
      if window.isZoomed != lastZoomed {
        lastZoomed = window.isZoomed
        report(window.isZoomed ? .maximize : .unmaximize)
      }
      report(.resized)
    }

    private func reportVisibility() {
      guard let window = lifecycleWindow, window.isVisible != lastVisible else { return }
      lastVisible = window.isVisible
      report(window.isVisible ? .show : .hide)
    }

    private func report(_ type: RufletWindowEventType) {
      guard let window = lifecycleWindow else { return }
      lifecycleHandler?(RufletWindowEvent(type: type, state: snapshot(of: window)))
    }

    private func snapshot(of window: NSWindow) -> RufletWindowStateSnapshot {
      let frame = window.frame
      let content = window.contentLayoutRect.size
      let top = window.screen.map { Double($0.frame.maxY - frame.maxY) } ?? Double(frame.minY)
      return RufletWindowStateSnapshot(
        maximized: window.isZoomed,
        minimized: window.isMiniaturized,
        fullScreen: window.styleMask.contains(.fullScreen),
        alwaysOnTop: window.level.rawValue > NSWindow.Level.normal.rawValue,
        focused: window.isKeyWindow,
        visible: window.isVisible,
        width: Double(content.width),
        height: Double(content.height),
        top: top,
        left: Double(frame.minX),
        opacity: Double(window.alphaValue))
    }

    private func performAppKit(
      _ action: RufletWindowAction,
      completion: @escaping (Result<Void, Error>) -> Void
    ) {
      guard let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first else {
        return completion(.failure(RufletServiceError.unavailable("No Apple window is mounted")))
      }
      switch action {
      case .center:
        window.center()
      case .close:
        window.performClose(nil)
      case .destroy:
        window.orderOut(nil)
        window.close()
      case .startDragging:
        guard let event = NSApp.currentEvent else {
          return completion(.failure(RufletServiceError.unavailable(
            "Window.start_dragging must be called from a pointer event")))
        }
        window.performDrag(with: event)
      case .startResizing(let edge):
        guard NSEvent.pressedMouseButtons != 0 else {
          return completion(.failure(RufletServiceError.unavailable(
            "Window.start_resizing must be called from a pointer event")))
        }
        beginResize(window: window, edge: edge)
      case .toFront:
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
      case .waitUntilReadyToShow:
        // An NSWindow with a content view has completed AppKit construction.
        // This deliberately does not show it; Flet's method only waits.
        guard window.contentView != nil else {
          return completion(.failure(RufletServiceError.unavailable(
            "The Apple window is not ready to show")))
        }
      }
      completion(.success(()))
    }

    private func beginResize(window: NSWindow, edge: String) {
      if let resizeMonitor { NSEvent.removeMonitor(resizeMonitor) }
      let initialFrame = window.frame
      let initialPointer = NSEvent.mouseLocation
      resizeMonitor = NSEvent.addLocalMonitorForEvents(
        matching: [.leftMouseDragged, .leftMouseUp]
      ) { [weak self, weak window] event in
        guard let self, let window else { return event }
        if event.type == .leftMouseUp {
          if let monitor = self.resizeMonitor { NSEvent.removeMonitor(monitor) }
          self.resizeMonitor = nil
          return event
        }
        let dx = NSEvent.mouseLocation.x - initialPointer.x
        let dy = NSEvent.mouseLocation.y - initialPointer.y
        var frame = initialFrame
        if edge.contains("left") {
          frame.origin.x += dx
          frame.size.width -= dx
        } else if edge.contains("right") {
          frame.size.width += dx
        }
        if edge.contains("bottom") {
          frame.origin.y += dy
          frame.size.height -= dy
        } else if edge.contains("top") {
          frame.size.height += dy
        }
        let minSize = window.minSize
        if frame.width < minSize.width {
          if edge.contains("left") { frame.origin.x -= minSize.width - frame.width }
          frame.size.width = minSize.width
        }
        if frame.height < minSize.height {
          if edge.contains("bottom") { frame.origin.y -= minSize.height - frame.height }
          frame.size.height = minSize.height
        }
        window.setFrame(frame, display: true)
        return event
      }
    }
  #endif

  #if canImport(UIKit)
    private func performUIKit(
      _ action: RufletWindowAction,
      completion: @escaping (Result<Void, Error>) -> Void
    ) {
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
        ?? scenes.first?.windows.first
      switch action {
      case .toFront:
        guard let window else {
          return completion(.failure(RufletServiceError.unavailable("No Apple window is mounted")))
        }
        window.makeKeyAndVisible()
        completion(.success(()))
      case .waitUntilReadyToShow:
        guard window?.rootViewController != nil else {
          return completion(.failure(RufletServiceError.unavailable(
            "The Apple window is not ready to show")))
        }
        completion(.success(()))
      case .close, .destroy:
        guard let scene = window?.windowScene else {
          return completion(.failure(RufletServiceError.unavailable("No Apple window is mounted")))
        }
        UIApplication.shared.requestSceneSessionDestruction(
          scene.session, options: nil, errorHandler: nil)
        completion(.success(()))
      case .center, .startDragging, .startResizing:
        completion(.failure(RufletServiceError.platformUnsupported(
          type: "Window", method: Self.methodName(action), platform: "iOS")))
      }
    }
  #endif

  private static func methodName(_ action: RufletWindowAction) -> String {
    switch action {
    case .center: return "center"
    case .close: return "close"
    case .destroy: return "destroy"
    case .startDragging: return "start_dragging"
    case .startResizing: return "start_resizing"
    case .toFront: return "to_front"
    case .waitUntilReadyToShow: return "wait_until_ready_to_show"
    }
  }
}

#if canImport(AppKit)
  extension NSWindow.StyleMask {
    /// Reads better than an if/else pair at each of the four call sites.
    mutating func toggle(_ member: NSWindow.StyleMask, on: Bool) {
      if on { insert(member) } else { remove(member) }
    }
  }
#endif
