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

/// Injectable host boundary. It keeps command parsing independently testable
/// and keeps AppKit/UIKit details out of the protocol session.
@MainActor
public protocol RufletWindowHost: AnyObject {
  func perform(
    _ action: RufletWindowAction,
    completion: @escaping (Result<Void, Error>) -> Void)
}

@MainActor
public final class WindowService: RufletService {
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
    #if canImport(AppKit)
      let target = node.id
      DispatchQueue.main.async {
        guard let window = NSApplication.shared.windows.first else { return }
        Self.apply(node, to: window)
        context.emitEvent(target, "event", .map(["type": .string("resized")]))
      }
    #endif
  }

  #if canImport(AppKit)
    /// Every window property Flet carries that AppKit can express. The ones it
    /// cannot — a task-bar entry, a dock progress bar — are noted where they
    /// are read.
    static func apply(_ node: ControlNode, to window: NSWindow) {
      if let width = node.double("width"), let height = node.double("height") {
        window.setContentSize(NSSize(width: width, height: height))
      }
      if let minWidth = node.double("min_width"), let minHeight = node.double("min_height") {
        window.contentMinSize = NSSize(width: minWidth, height: minHeight)
      }
      if let maxWidth = node.double("max_width"), let maxHeight = node.double("max_height") {
        window.contentMaxSize = NSSize(width: maxWidth, height: maxHeight)
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
      if node.bool("maximized") == true, !window.isZoomed { window.zoom(nil) }
      if node.bool("minimized") == true, !window.isMiniaturized { window.miniaturize(nil) }
      if node.bool("focused") == true { window.makeKeyAndOrderFront(nil) }

      // `badge_label` is the dock tile's badge, which belongs to the app
      // rather than the window; `progress_bar` and `skip_task_bar` have no
      // AppKit counterpart — macOS has no task bar, and a dock progress
      // indicator is drawn by the application, not set as a property.
      NSApplication.shared.dockTile.badgeLabel = node.string("badge_label")
      _ = node.double("progress_bar")
      _ = node.bool("skip_task_bar")
      _ = node.bool("prevent_close")
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

@MainActor
public final class NativeRufletWindowHost: RufletWindowHost {
  #if canImport(AppKit)
    private var resizeMonitor: Any?
  #endif

  public init() {}

  deinit {
    #if canImport(AppKit)
      if let resizeMonitor { NSEvent.removeMonitor(resizeMonitor) }
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
