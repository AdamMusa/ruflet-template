import RufletEngine
import RufletProtocol
import SwiftUI

/// Ruflet's nested application control. Ruflet owns this native wire name; the
/// vendored Flet control remains the behavioral reference, not an inbound alias.
struct RufletAppControlView: View {
  let node: ControlNode
  @Environment(\.rufletServerURL) private var parentServerURL
  @Environment(\.rufletExtensions) private var extensions

  var body: some View {
    let configuration = RufletAppConfiguration(node: node)
    if let error = configuration.validationError {
      RufletStatusView(message: error, isError: true)
    } else if let url = RufletAppEndpoint.resolve(configuration.url, inheriting: parentServerURL) {
      RufletNestedAppHost(
        node: node, endpoint: url, configuration: configuration, extensions: extensions)
        .id(url)
    } else {
      RufletStatusView(
        message: configuration.formatError(
          "RufletApp requires a server URL when it is not nested in a connected Ruflet session."),
        isError: true)
    }
  }

}

enum RufletAppEndpoint {
  static func resolve(_ raw: String?, inheriting parent: URL?) -> URL? {
    guard let raw, !raw.isEmpty else { return parent }
    guard var components = URLComponents(string: raw) else { return nil }
    guard let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https"
    else { return nil }
    components.scheme = scheme == "https" ? "wss" : "ws"
    let pagePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    components.path = pagePath.isEmpty ? "/ws" : "/\(pagePath)/ws"
    return components.url
  }
}

struct RufletAppConfiguration: Equatable {
  static let defaultErrorMessage = "The application encountered an error: {message}\n\n{details}"

  let url: String
  let reconnectInterval: TimeInterval
  let reconnectTimeout: TimeInterval?
  let showStartupScreen: Bool
  let startupMessage: String
  let errorMessage: String?
  let args: [String: RufletValue]?
  let forcePyodide: Bool?
  let validationError: String?

  init(node: ControlNode) {
    url = node.string("url") ?? ""
    // The pinned native WebSocket transport reconnects after 500 ms when the
    // control does not override the interval.
    reconnectInterval = Double(node.int("reconnect_interval_ms") ?? 500) / 1_000
    reconnectTimeout = node.int("reconnect_timeout_ms").map { Double($0) / 1_000 }
    showStartupScreen = node.bool("show_app_startup_screen") ?? false
    startupMessage = node.string("app_startup_screen_message") ?? ""
    errorMessage = node.string("app_error_message")
    forcePyodide = node.bool("force_pyodide")

    if let rawArgs = node.props["args"], !rawArgs.isNull {
      if let map = rawArgs.mapValue {
        args = map
        validationError = nil
      } else {
        args = nil
        validationError = "RufletApp.args must be a map."
      }
    } else {
      args = nil
      validationError = nil
    }
  }

  func formatError(_ rawError: String) -> String {
    guard !rawError.isEmpty else { return "" }
    let lines = rawError.components(separatedBy: .newlines)
    let message = lines.first ?? ""
    let details = lines.dropFirst().joined(separator: "\n")
    var result = (errorMessage ?? Self.defaultErrorMessage)
      .replacingOccurrences(of: "{message}", with: message)
    if details.isEmpty {
      result = result.replacingOccurrences(
        of: #"(\r?\n)*\{details\}"#, with: "", options: .regularExpression)
    } else {
      result = result.replacingOccurrences(of: "{details}", with: details)
    }
    while result.last?.isWhitespace == true { result.removeLast() }
    return result
  }
}

private struct RufletNestedAppHost: View {
  let node: ControlNode
  let configuration: RufletAppConfiguration
  @StateObject private var host: RufletHost
  @Environment(\.rufletEvents) private var parentEvents

  init(
    node: ControlNode,
    endpoint: URL,
    configuration: RufletAppConfiguration,
    extensions: [any RufletExtension.Type]
  ) {
    self.node = node
    self.configuration = configuration
    _host = StateObject(wrappedValue: RufletHost(
      source: .server(endpoint), extensions: extensions, capabilities: .current(),
      reconnectInterval: configuration.reconnectInterval,
      reconnectTimeout: configuration.reconnectTimeout))
  }

  var body: some View {
    Group {
      switch host.phase {
      case .starting:
        if configuration.showStartupScreen {
          RufletStatusView(
            message: configuration.startupMessage,
            isError: false)
        }
      case .failed(let message):
        RufletAppFailure(
          message: configuration.formatError(message),
          report: { parentEvents.fire(node, "error", data: .string(message)) })
      case .running(let session):
        RufletNestedSessionView(session: session, configuration: configuration)
      }
    }
    .task { await host.start() }
    .onAppear {
      // Pyodide and process arguments configure Flet's web runtime. Apple
      // still carries them on the node, but the native session never executes
      // a browser VM or rewrites its process arguments.
      _ = configuration.args
      _ = configuration.forcePyodide
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
  let configuration: RufletAppConfiguration

  var body: some View {
    ZStack {
      ControlView(id: RufletWireID.page, axis: .vertical)
        .environmentObject(session.store)
        .environment(\.rufletEvents, RufletEventSink.connected(to: session))
        .environment(\.rufletCommands, session.commands)
        .environment(\.rufletServerURL, session.serverURL)
      if case .crashed(let message) = session.status {
        RufletStatusView(message: configuration.formatError(message), isError: true)
      }
    }
  }
}
