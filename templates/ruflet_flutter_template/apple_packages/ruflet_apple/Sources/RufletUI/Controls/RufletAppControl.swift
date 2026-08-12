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
        node: node, endpoint: url,
        pageName: RufletAppEndpoint.pageName(configuration.url, inheriting: parentServerURL),
        configuration: configuration, extensions: extensions)
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
    // FletWebSocketBackendChannel constructs a fresh endpoint from scheme,
    // authority and path. Query and fragment belong to the page URL and are
    // intentionally absent from the socket handshake URL.
    components.query = nil
    components.fragment = nil
    return components.url
  }

  /// Flet's register payload identifies an app by at most the first two page
  /// path segments. An inherited native endpoint already ends in `/ws`, which
  /// is transport syntax and therefore not part of the page identity.
  static func pageName(_ raw: String?, inheriting parent: URL?) -> String {
    let source: URL
    let hasExplicitURL: Bool
    if let raw, !raw.isEmpty {
      guard let explicit = URL(string: raw) else { return "" }
      source = explicit
      hasExplicitURL = true
    } else {
      guard let parent else { return "" }
      source = parent
      hasExplicitURL = false
    }
    var segments = source.path.split(separator: "/").map(String.init)
    if !hasExplicitURL, segments.last?.lowercased() == "ws" {
      segments.removeLast()
    }
    return segments.prefix(2).joined(separator: "/")
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
    pageName: String,
    configuration: RufletAppConfiguration,
    extensions: [any RufletExtension.Type]
  ) {
    self.node = node
    self.configuration = configuration
    var capabilities = ClientCapabilities.current()
    capabilities.pageName = pageName
    _host = StateObject(wrappedValue: RufletHost(
      source: .server(endpoint), extensions: extensions, capabilities: capabilities,
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
      switch RufletAppPresentation.state(
        for: session.status, configuration: configuration,
        hasContent: session.store.node(RufletWireID.page)?
          .controlIDs(forKey: "views").isEmpty == false
      ) {
      case .content, .empty:
        EmptyView()
      case .loading(let message):
        RufletStatusView(message: message, isError: false)
      case .error(let message):
        RufletStatusView(message: message, isError: true)
      }
    }
  }
}

enum RufletAppPresentation {
  enum State: Equatable {
    case empty
    case loading(String)
    case error(String)
    case content
  }

  static func state(
    for status: RufletSession.Status, configuration: RufletAppConfiguration,
    hasContent: Bool = false
  ) -> State {
    // Once Flet has views it keeps them mounted through reconnects and runtime
    // failures; the loading/error placeholder is only the empty-page branch.
    if hasContent { return .content }
    switch status {
    case .connected:
      return .content
    case .crashed(let message):
      return configuration.showStartupScreen
        ? .error(configuration.formatError(message)) : .empty
    case .idle, .connecting, .disconnected, .failed:
      // Flet keeps `isLoading` true while reconnecting, including after a
      // transient channel error. The configured startup page remains visible
      // until registration succeeds; without it the placeholder stays empty.
      return configuration.showStartupScreen
        ? .loading(configuration.startupMessage) : .empty
    }
  }
}
