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
