import Foundation
import RufletEngine
import RufletProtocol
import SwiftUI

/// One native Apple scene known to Ruflet's multi-view page.
public struct RufletNativeScene: Identifiable, Equatable {
  public let id: Int
  public let sessionIdentifier: String
  public let initialData: [String: RufletValue]
}

/// Mirrors Flet's `platformDispatcher.views` registry for Apple scenes.
///
/// Scene delegates register actual `UISceneSession`/`NSWindow` lifetimes here.
/// Once the Ruflet session is connected the registry emits the same
/// subscriber-independent `multi_view_add` and `multi_view_remove` events that
/// Flet emits, including the platform view id and launch data.
@MainActor
public final class RufletNativeSceneRegistry: ObservableObject {
  @Published public private(set) var scenes: [RufletNativeScene] = []

  private var nextID = 1
  private weak var session: RufletSession?
  private var announced: Set<Int> = []

  public init() {}

  @discardableResult
  public func connect(
    sessionIdentifier: String,
    initialData: [String: RufletValue] = [:]
  ) -> RufletNativeScene {
    if let existing = scenes.first(where: { $0.sessionIdentifier == sessionIdentifier }) {
      return existing
    }
    let scene = RufletNativeScene(
      id: nextID, sessionIdentifier: sessionIdentifier, initialData: initialData)
    nextID += 1
    scenes.append(scene)
    announceAddition(scene)
    return scene
  }

  public func disconnect(sessionIdentifier: String) {
    guard let index = scenes.firstIndex(where: { $0.sessionIdentifier == sessionIdentifier })
    else { return }
    let scene = scenes.remove(at: index)
    guard announced.remove(scene.id) != nil, let session else { return }
    session.dispatchEvent(
      target: RufletWireID.page, name: "multi_view_remove", data: .int(Int64(scene.id)))
  }

  public func bind(to session: RufletSession) {
    guard self.session !== session else { return }
    self.session = session
    announced.removeAll()
    for scene in scenes { announceAddition(scene) }
  }

  private func announceAddition(_ scene: RufletNativeScene) {
    guard let session, announced.insert(scene.id).inserted else { return }
    session.dispatchEvent(
      target: RufletWireID.page,
      name: "multi_view_add",
      data: .map([
        "view_id": .int(Int64(scene.id)),
        "initial_data": .map(scene.initialData),
      ]))
  }
}

private struct RufletNativeSceneKey: EnvironmentKey {
  static let defaultValue: RufletNativeScene? = nil
}

extension EnvironmentValues {
  public var rufletNativeScene: RufletNativeScene? {
    get { self[RufletNativeSceneKey.self] }
    set { self[RufletNativeSceneKey.self] = newValue }
  }
}

/// Process-wide host used by scene-based Apple runners.
///
/// Every scene shares one runtime and one Ruflet session, exactly as Flet's
/// `ViewCollection` shares one backend. Creating a separate `RufletAppView`
/// per scene would incorrectly create a separate Ruby application per window.
@MainActor
public final class RufletMultiViewApplication {
  public let host: RufletHost
  public let scenes = RufletNativeSceneRegistry()

  public init(
    extensions: [any RufletExtension.Type] = [],
    capabilities: ClientCapabilities = .current()
  ) {
    var capabilities = capabilities
    capabilities.multiView = true
    let source: RufletHost.Source
    if let root = BundledProject.locate() {
      source = .embedded(EmbeddedRuntime.Configuration(projectRoot: root))
    } else {
      source = .missingProject
    }
    host = RufletHost(
      source: source, extensions: extensions, capabilities: capabilities)
  }

  /// Attaches every native Apple scene to the server URL already resolved by
  /// Flutter. This is the entry used by both Ruflet build modes: an embedded
  /// loopback URL for `--self`, or the developer's configured backend URL for
  /// a server-driven build.
  public init(
    serverURL: URL,
    extensions: [any RufletExtension.Type] = [],
    capabilities: ClientCapabilities = .current()
  ) {
    var capabilities = capabilities
    capabilities.multiView = true
    host = RufletHost(
      source: .server(serverURL), extensions: extensions, capabilities: capabilities)
  }

  @available(*, deprecated, message: "Use init(extensions:capabilities:)")
  public convenience init(
    services: [any RufletServiceBundle.Type],
    capabilities: ClientCapabilities = .current()
  ) {
    self.init(extensions: services, capabilities: capabilities)
  }

  @discardableResult
  public func connect(
    sessionIdentifier: String,
    initialData: [String: RufletValue] = [:]
  ) -> RufletNativeScene {
    scenes.connect(sessionIdentifier: sessionIdentifier, initialData: initialData)
  }

  public func disconnect(sessionIdentifier: String) {
    scenes.disconnect(sessionIdentifier: sessionIdentifier)
  }
}

/// The root view installed into each native scene by the runner.
public struct RufletMultiViewAppView: View {
  @ObservedObject private var host: RufletHost
  @ObservedObject private var registry: RufletNativeSceneRegistry
  private let scene: RufletNativeScene

  public init(application: RufletMultiViewApplication, scene: RufletNativeScene) {
    host = application.host
    registry = application.scenes
    self.scene = scene
  }

  public var body: some View {
    Group {
      switch host.phase {
      case .starting:
        RufletStatusView(message: "Starting the Ruby runtime…", isError: false)
      case .failed(let message):
        RufletStatusView(message: message, isError: true)
      case .running(let session):
        RufletSessionView(session: session, nativeScene: scene, sceneRegistry: registry)
      }
    }
    .task { await host.start() }
  }
}

/// Converts scene launch metadata without inventing a platform-specific wire
/// format. Property-list values are the values UIKit and AppKit provide.
public enum RufletSceneInitialData {
  public static func convert(_ value: Any) -> RufletValue? {
    switch value {
    case let value as String: return .string(value)
    case let value as Bool: return .bool(value)
    case let value as Int: return .int(Int64(value))
    case let value as NSNumber: return .double(value.doubleValue)
    case let value as [Any]: return .array(value.compactMap(convert))
    case let value as [String: Any]: return .map(value.compactMapValues(convert))
    default: return nil
    }
  }
}
