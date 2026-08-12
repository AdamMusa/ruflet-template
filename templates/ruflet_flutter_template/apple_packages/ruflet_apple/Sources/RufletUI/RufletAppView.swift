import RufletEngine
import RufletProtocol
import SwiftUI

/// The root of a Ruflet application.
///
/// Everything a template app needs: hand it either a running runtime's URL or
/// an embedded-project configuration, and it connects, renders and reports
/// events. The Ruby application is unchanged and unaware.
public struct RufletAppView: View {
  @StateObject private var host: RufletHost

  /// Attaches to a runtime that is already listening — a `ruflet run` server
  /// during development, or a VM the platform layer started and whose port the
  /// app already knows.
  public init(
    serverURL: URL,
    extensions: [any RufletExtension.Type] = [],
    capabilities: ClientCapabilities = .current(),
    reconnectInterval: TimeInterval = 1,
    reconnectTimeout: TimeInterval? = nil
  ) {
    _host = StateObject(
      wrappedValue: RufletHost(
        source: .server(serverURL), extensions: extensions, capabilities: capabilities,
        reconnectInterval: reconnectInterval, reconnectTimeout: reconnectTimeout))
  }

  @available(*, deprecated, message: "Use init(serverURL:extensions:capabilities:reconnectInterval:reconnectTimeout:)")
  public init(
    serverURL: URL,
    services: [any RufletServiceBundle.Type],
    capabilities: ClientCapabilities = .current(),
    reconnectInterval: TimeInterval = 1,
    reconnectTimeout: TimeInterval? = nil
  ) {
    self.init(
      serverURL: serverURL, extensions: services, capabilities: capabilities,
      reconnectInterval: reconnectInterval, reconnectTimeout: reconnectTimeout)
  }

  /// Boots the embedded mruby VM from a project in the app bundle, then
  /// connects to the port it publishes.
  ///
  /// This keeps VM startup on the native side, exactly as the Objective-C
  /// bridge does for the Flutter engine.
  public init(
    embeddedProject configuration: EmbeddedRuntime.Configuration,
    extensions: [any RufletExtension.Type] = [],
    capabilities: ClientCapabilities = .current()
  ) {
    _host = StateObject(
      wrappedValue: RufletHost(
        source: .embedded(configuration), extensions: extensions, capabilities: capabilities))
  }

  @available(*, deprecated, message: "Use init(embeddedProject:extensions:capabilities:)")
  public init(
    embeddedProject configuration: EmbeddedRuntime.Configuration,
    services: [any RufletServiceBundle.Type],
    capabilities: ClientCapabilities = .current()
  ) {
    self.init(
      embeddedProject: configuration, extensions: services, capabilities: capabilities)
  }

  /// Boots the Ruby project packaged into the app bundle.
  ///
  /// Fails loudly when nothing is packaged rather than showing an empty screen,
  /// because a self-contained build without its project is a build mistake.
  /// Boots the Ruby project packaged into the app bundle.
  ///
  /// `extensions` names the optional modules this target links —
  /// `RufletMotion`, `RufletLocation`, `RufletMedia`. Everything that touches
  /// no privacy-gated framework is always available; the rest is opt-in so an
  /// app that never uses the camera neither carries the code nor gets asked
  /// for a usage string.
  ///
  /// ```swift
  /// RufletAppView(extensions: [RufletCamera.self, RufletVideo.self])
  /// ```
  public init(
    extensions: [any RufletExtension.Type] = [],
    capabilities: ClientCapabilities = .current()
  ) {
    let source: RufletHost.Source
    if let root = BundledProject.locate() {
      source = .embedded(EmbeddedRuntime.Configuration(projectRoot: root))
    } else {
      source = .missingProject
    }
    _host = StateObject(
      wrappedValue: RufletHost(
        source: source, extensions: extensions, capabilities: capabilities))
  }

  @available(*, deprecated, message: "Use init(extensions:capabilities:)")
  public init(
    services: [any RufletServiceBundle.Type],
    capabilities: ClientCapabilities = .current()
  ) {
    self.init(extensions: services, capabilities: capabilities)
  }

  public var body: some View {
    Group {
      switch host.phase {
      case .starting:
        RufletStatusView(message: "Starting the Ruby runtime…", isError: false)
      case .failed(let message):
        RufletStatusView(message: message, isError: true)
      case .running(let session):
        RufletSessionView(session: session)
      }
    }
    .task { await host.start() }
  }
}

/// Renders one connected session.
struct RufletSessionView: View {
  @ObservedObject var session: RufletSession
  var nativeScene: RufletNativeScene?
  var sceneRegistry: RufletNativeSceneRegistry?

  init(
    session: RufletSession,
    nativeScene: RufletNativeScene? = nil,
    sceneRegistry: RufletNativeSceneRegistry? = nil
  ) {
    self.session = session
    self.nativeScene = nativeScene
    self.sceneRegistry = sceneRegistry
  }

  var body: some View {
    ZStack {
      ControlView(id: RufletWireID.page, axis: .vertical)
        .environmentObject(session.store)
        .environment(\.rufletEvents, RufletEventSink.connected(to: session))
        // Controls with imperative methods (`video.play`, `search_bar.focus`)
        // claim them here while they are mounted.
        .environment(\.rufletCommands, session.commands)
        .environment(\.rufletServerURL, session.serverURL)
        .environment(\.rufletNativeScene, nativeScene)

      switch session.status {
      case .crashed(let message):
        RufletStatusView(message: message, isError: true)
      case .connecting, .idle:
        // The page arrives within a frame or two of connecting; showing a
        // spinner for that would flash.
        EmptyView()
      case .failed(let message):
        RufletStatusView(message: message, isError: true)
      case .connected, .disconnected:
        EmptyView()
      }
    }
    .onAppear { bindScenesIfRegistered() }
    .onChange(of: session.status) { _ in bindScenesIfRegistered() }
  }

  private func bindScenesIfRegistered() {
    guard session.status == .connected else { return }
    sceneRegistry?.bind(to: session)
  }
}

/// Startup and failure states.
///
/// Failures are shown rather than logged: a runtime that did not start is the
/// single most common thing to get wrong when wiring this up, and a blank
/// screen says nothing about it.
struct RufletStatusView: View {
  let message: String
  let isError: Bool

  var body: some View {
    VStack(spacing: 12) {
      if isError {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.largeTitle)
          .foregroundColor(.orange)
      } else {
        ProgressView()
      }
      Text(message)
        .font(.callout)
        .multilineTextAlignment(.center)
        .foregroundColor(isError ? .primary : .secondary)
        .textSelection(.enabled)
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// Owns the runtime and the session for the lifetime of the view.
@MainActor
public final class RufletHost: ObservableObject {
  public enum Source {
    case server(URL)
    case embedded(EmbeddedRuntime.Configuration)
    case missingProject
  }

  public enum Phase {
    case starting
    case running(RufletSession)
    case failed(String)
  }

  @Published public private(set) var phase: Phase = .starting

  private let source: Source
  private let extensions: [any RufletExtension.Type]
  private let capabilities: ClientCapabilities
  private let reconnectInterval: TimeInterval
  private let reconnectTimeout: TimeInterval?
  private var started = false

  public init(
    source: Source,
    extensions: [any RufletExtension.Type] = [],
    capabilities: ClientCapabilities,
    reconnectInterval: TimeInterval = 1,
    reconnectTimeout: TimeInterval? = nil
  ) {
    self.source = source
    self.extensions = extensions
    self.capabilities = capabilities
    self.reconnectInterval = reconnectInterval
    self.reconnectTimeout = reconnectTimeout
  }


  @available(*, deprecated, message: "Use init(source:extensions:capabilities:reconnectInterval:reconnectTimeout:)")
  public convenience init(
    source: Source,
    services: [any RufletServiceBundle.Type],
    capabilities: ClientCapabilities,
    reconnectInterval: TimeInterval = 1,
    reconnectTimeout: TimeInterval? = nil
  ) {
    self.init(
      source: source, extensions: services, capabilities: capabilities,
      reconnectInterval: reconnectInterval, reconnectTimeout: reconnectTimeout)
  }

  public func start() async {
    guard !started else { return }
    started = true

    switch source {
    case .server(let url):
      connect(to: url)

    case .missingProject:
      phase = .failed(
        """
        No packaged Ruby project was found in the app bundle. Add the project \
        directory (the one holding main.rb) as a bundle resource, or name it \
        with RufletEmbeddedProject in Info.plist.
        """)

    case .embedded(let configuration):
      // Booting blocks until the runtime publishes its port, so it runs off
      // the main actor and the UI keeps its startup state until it answers.
      let runtime = EmbeddedRuntime(configuration: configuration)
      do {
        let port = try await Task.detached(priority: .userInitiated) {
          try runtime.start()
        }.value
        connect(to: WebSocketTransport.endpoint(port: port))
      } catch {
        phase = .failed(error.localizedDescription)
      }
    }
  }

  private func connect(to url: URL) {
    let session = RufletSession(
      serverURL: url, capabilities: capabilities,
      reconnectInterval: reconnectInterval, reconnectTimeout: reconnectTimeout)
    session.services.register(extensions: extensions)
    phase = .running(session)
    session.start()
  }
}
