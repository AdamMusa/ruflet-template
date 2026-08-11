import RufletEngine
import RufletProtocol
import SwiftUI

/// Ruflet's nested application control. Ruflet owns this native wire name; the
/// vendored Flet control remains the behavioral reference, not an inbound alias.
struct RufletAppControlView: View {
  let node: ControlNode
  @Environment(\.rufletServerURL) private var parentServerURL

  var body: some View {
    if let url = RufletAppEndpoint.resolve(node.string("url"), inheriting: parentServerURL) {
      RufletNestedAppHost(node: node, endpoint: url)
    } else {
      RufletStatusView(
        message: node.string("app_error_message")
          ?? "RufletApp requires a server URL when it is not nested in a connected Ruflet session.",
        isError: true)
    }
  }

}

enum RufletAppEndpoint {
  static func resolve(_ raw: String?, inheriting parent: URL?) -> URL? {
    guard let raw, !raw.isEmpty else { return parent }
    guard var components = URLComponents(string: raw) else { return nil }
    if components.scheme == "http" { components.scheme = "ws" }
    if components.scheme == "https" { components.scheme = "wss" }
    if components.path.isEmpty || components.path == "/" { components.path = "/ws" }
    return components.url
  }
}

private struct RufletNestedAppHost: View {
  let node: ControlNode
  @StateObject private var host: RufletHost
  @Environment(\.rufletEvents) private var parentEvents

  init(node: ControlNode, endpoint: URL) {
    self.node = node
    let interval = Duration.milliseconds(node.int("reconnect_interval_ms") ?? 1_000)
    let timeout = node.int("reconnect_timeout_ms").map { Duration.milliseconds($0) }
    _host = StateObject(wrappedValue: RufletHost(
      source: .server(endpoint), capabilities: .current(),
      reconnectInterval: interval, reconnectTimeout: timeout))
  }

  var body: some View {
    Group {
      switch host.phase {
      case .starting:
        if node.bool("show_app_startup_screen") != false {
          RufletStatusView(
            message: node.string("app_startup_screen_message") ?? "Starting the Ruflet application…",
            isError: false)
        }
      case .failed(let message):
        RufletAppFailure(
          message: node.string("app_error_message") ?? message,
          report: { parentEvents.fire(node, "error", data: .string(message)) })
      case .running(let session):
        RufletNestedSessionView(session: session)
      }
    }
    .task { await host.start() }
    .onAppear {
      // Pyodide and process arguments configure Flet's web runtime. Apple
      // still carries them on the node, but the native session never executes
      // a browser VM or rewrites its process arguments.
      _ = node.map("args")
      _ = node.bool("force_pyodide")
    }
  }
}

private struct RufletAppFailure: View {
  let message: String
  let report: () -> Void

  var body: some View {
    RufletStatusView(message: message, isError: true).onAppear(perform: report)
  }
}

private struct RufletNestedSessionView: View {
  @ObservedObject var session: RufletSession

  var body: some View {
    ZStack {
      ControlView(id: RufletWireID.page, axis: .vertical)
        .environmentObject(session.store)
        .environment(\.rufletEvents, RufletEventSink.connected(to: session))
        .environment(\.rufletCommands, session.commands)
        .environment(\.rufletServerURL, session.serverURL)
      if case .crashed(let message) = session.status {
        RufletStatusView(message: message, isError: true)
      }
    }
  }
}
