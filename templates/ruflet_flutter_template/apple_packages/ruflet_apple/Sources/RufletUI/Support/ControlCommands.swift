import RufletEngine
import RufletProtocol
import SwiftUI

/// How a mounted control claims its imperative methods.
///
/// Ruby calls `video.play` or `search_bar.focus` through
/// `invoke_control_method`, and only the live view can answer — it owns the
/// player, the focus state, the scroll reader. A view registers while it is on
/// screen and releases on the way out, so a call to a control that has been
/// navigated away from fails cleanly instead of reaching a stale object.
private struct RufletCommandBusKey: EnvironmentKey {
  static let defaultValue: ControlCommandBus? = nil
}

extension EnvironmentValues {
  public var rufletCommands: ControlCommandBus? {
    get { self[RufletCommandBusKey.self] }
    set { self[RufletCommandBusKey.self] = newValue }
  }
}

extension View {
  /// Handles `invoke_control_method` for `controlID` while this view is
  /// mounted.
  ///
  /// The handler runs on the main actor and must call `completion` exactly
  /// once — a Ruby thread is waiting on it.
  public func rufletCommandHandler(
    _ controlID: Int,
    handler: @escaping (RufletMethodCall, @escaping RufletMethodCompletion) -> Void
  ) -> some View {
    modifier(CommandHandlerModifier(controlID: controlID, handler: handler))
  }

  /// Claims one method while leaving the control's service-owned methods
  /// untouched.
  public func rufletCommandHandler(
    _ controlID: Int,
    method: String,
    handler: @escaping (RufletMethodCall, @escaping RufletMethodCompletion) -> Void
  ) -> some View {
    modifier(
      MethodCommandHandlerModifier(
        controlID: controlID, method: method, handler: handler))
  }
}

private struct CommandHandlerModifier: ViewModifier {
  let controlID: Int
  let handler: (RufletMethodCall, @escaping RufletMethodCompletion) -> Void

  @Environment(\.rufletCommands) private var bus

  func body(content: Content) -> some View {
    content
      .onAppear { bus?.register(controlID, handler: handler) }
      .onDisappear { bus?.unregister(controlID) }
  }
}

private struct MethodCommandHandlerModifier: ViewModifier {
  let controlID: Int
  let method: String
  let handler: (RufletMethodCall, @escaping RufletMethodCompletion) -> Void

  @Environment(\.rufletCommands) private var bus

  func body(content: Content) -> some View {
    content
      .onAppear { bus?.register(controlID, method: method, handler: handler) }
      .onDisappear { bus?.unregister(controlID, method: method) }
  }
}

/// The reply a control gives for a method it does not implement.
///
/// Named rather than inlined so every control refuses the same way, and so the
/// message says which control and which method rather than "failed".
public func rufletUnsupported(_ type: String, _ call: RufletMethodCall) -> Error {
  RufletServiceError.unsupportedMethod(type: type, method: call.name)
}
