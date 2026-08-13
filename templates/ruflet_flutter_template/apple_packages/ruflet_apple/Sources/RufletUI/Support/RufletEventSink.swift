import RufletEngine
import RufletProtocol
import SwiftUI

/// How a rendered control reports back.
///
/// Closures rather than a reference to `RufletSession` so the renderer has no
/// dependency on the transport: SwiftUI previews and view tests can hand in a
/// recording sink, and a host embedding the views can route events wherever it
/// likes.
public struct RufletEventSink {
  /// Sends a `control_event`. `Page#dispatch_event` writes the value back onto
  /// the control for `change`/`select`/`select_change` before calling the Ruby
  /// handler, so a scalar in `data` keeps both sides in step.
  public var send: (_ target: Int, _ name: String, _ data: RufletValue) -> Void

  /// Writes a value into the local store without a round trip, so a native
  /// control tracks the finger while Ruby catches up.
  public var setLocal: (_ target: Int, _ key: String, _ value: RufletValue) -> Void

  /// Records a locally-owned native edit without publishing the store's
  /// coarse whole-tree revision. Platform text inputs use this while UIKit or
  /// AppKit owns the live buffer.
  public var stageLocal: (_ target: Int, _ key: String, _ value: RufletValue) -> Void

  /// Sends an `update_control`: state Ruby should know about but did not ask to
  /// be notified of.
  public var update: (_ target: Int, _ props: [String: RufletValue]) -> Void

  public init(
    send: @escaping (Int, String, RufletValue) -> Void = { _, _, _ in },
    setLocal: @escaping (Int, String, RufletValue) -> Void = { _, _, _ in },
    stageLocal: ((Int, String, RufletValue) -> Void)? = nil,
    update: @escaping (Int, [String: RufletValue]) -> Void = { _, _ in }
  ) {
    self.send = send
    self.setLocal = setLocal
    self.stageLocal = stageLocal ?? setLocal
    self.update = update
  }

  /// Fires `name` only when Ruby attached a handler, so an unlistened gesture
  /// costs nothing on the wire.
  public func fire(
    _ node: ControlNode,
    _ name: String,
    data: RufletValue = .null
  ) {
    guard let registeredName = node.handledEventName(name) else { return }
    send(node.id, registeredName, data)
  }

  /// The change path every value-carrying control shares: write locally so the
  /// control stays responsive, then tell Ruby.
  public func commit(
    _ node: ControlNode,
    key: String = "value",
    value: RufletValue,
    event: String = "change"
  ) {
    setLocal(node.id, key, value)
    guard node.handlesEvent(event) else { return }
    send(node.id, event, value)
  }

  @MainActor
  public static func connected(to session: RufletSession) -> RufletEventSink {
    RufletEventSink(
      send: { target, name, data in
        session.dispatchEvent(target: target, name: name, data: data)
      },
      setLocal: { target, key, value in
        session.store.setLocalProperty(target, key: key, value: value)
      },
      stageLocal: { target, key, value in
        session.store.stageLocalProperty(target, key: key, value: value)
      },
      update: { target, props in
        session.updateControl(id: target, props: props)
      })
  }
}

private struct RufletEventSinkKey: EnvironmentKey {
  static let defaultValue = RufletEventSink()
}

private struct RufletServerURLKey: EnvironmentKey {
  static let defaultValue: URL? = nil
}

private struct RufletExtensionsKey: EnvironmentKey {
  static let defaultValue: [any RufletExtension.Type] = []
}

extension EnvironmentValues {
  public var rufletEvents: RufletEventSink {
    get { self[RufletEventSinkKey.self] }
    set { self[RufletEventSinkKey.self] = newValue }
  }

  /// Endpoint inherited by nested `RufletApp` controls when their own `url`
  /// is empty, the native equivalent of Flet's relative page URI.
  public var rufletServerURL: URL? {
    get { self[RufletServerURLKey.self] }
    set { self[RufletServerURLKey.self] = newValue }
  }

  /// Optional native packages linked by the root host. Nested `RufletApp`
  /// sessions inherit the same extension registry, matching FletBackend's
  /// extension propagation instead of silently losing Camera/Map/etc.
  var rufletExtensions: [any RufletExtension.Type] {
    get { self[RufletExtensionsKey.self] }
    set { self[RufletExtensionsKey.self] = newValue }
  }
}
