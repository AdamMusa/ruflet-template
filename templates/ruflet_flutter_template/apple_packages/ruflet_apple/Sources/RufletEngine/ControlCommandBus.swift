import Foundation
import RufletProtocol

/// Routes `invoke_control_method` to a *control* rather than to a service.
///
/// Ruflet controls carry imperative methods alongside their props — a `Video`
/// has `play`/`seek`, a `Map` has `move_to`, a `SearchBar` has `focus`, a
/// `Screenshot` has `capture`. Answering those needs the live view, not the
/// node: only the mounted `Video` owns its player, and only the mounted field
/// owns its focus state.
///
/// So a view registers a handler for its id while it is on screen and drops it
/// when it leaves. The session tries services first, this second, and replies
/// with an error when neither claims the call — because `Page#invoke` blocks a
/// Ruby thread and silence would hang the application.
@MainActor
public final class ControlCommandBus {
  public typealias Handler = (RufletMethodCall, @escaping RufletMethodCompletion) -> Void

  private var handlers: [Int: Handler] = [:]
  private var methodHandlers: [Int: [String: Handler]] = [:]

  public init() {}

  public func register(_ controlID: Int, handler: @escaping Handler) {
    handlers[controlID] = handler
  }

  public func unregister(_ controlID: Int) {
    handlers.removeValue(forKey: controlID)
  }

  /// Registers one mounted-view method without claiming every method on the
  /// control. Page uses this for `take_screenshot`: rasterisation belongs to
  /// its mounted SwiftUI root, while drawer, route and device methods continue
  /// to the Page service.
  public func register(_ controlID: Int, method: String, handler: @escaping Handler) {
    methodHandlers[controlID, default: [:]][method] = handler
  }

  public func unregister(_ controlID: Int, method: String) {
    methodHandlers[controlID]?[method] = nil
    if methodHandlers[controlID]?.isEmpty == true {
      methodHandlers[controlID] = nil
    }
  }

  public func handles(_ controlID: Int) -> Bool {
    handlers[controlID] != nil || methodHandlers[controlID]?.isEmpty == false
  }

  /// Dispatches, returning false when nothing is registered so the caller can
  /// answer with an error of its own.
  @discardableResult
  public func invoke(
    _ call: RufletMethodCall,
    completion: @escaping RufletMethodCompletion
  ) -> Bool {
    if let handler = methodHandlers[call.controlID]?[call.name] {
      handler(call, completion)
      return true
    }
    guard let handler = handlers[call.controlID] else { return false }
    handler(call, completion)
    return true
  }
}
