import Foundation
import RufletProtocol

/// A method call from Ruby, in flight.
///
/// `Page#invoke` blocks a Ruby thread (or arms a timeout) on every call, so
/// every request must be answered — a handler that returns nothing leaves
/// application code waiting for its timeout. `RufletSession` therefore replies
/// with an error for unknown targets and methods rather than staying silent.
public struct RufletMethodCall {
  public let controlID: Int
  public let callID: String
  public let name: String
  public let args: RufletValue

  public init(controlID: Int, callID: String, name: String, args: RufletValue) {
    self.controlID = controlID
    self.callID = callID
    self.name = name
    self.args = args
  }

  public func argument(_ key: String) -> RufletValue? {
    args[key]
  }
}

public typealias RufletMethodCompletion = (Result<RufletValue, Error>) -> Void

/// Something Ruby can invoke methods on: a page service (`Clipboard`,
/// `SharedPreferences`, …) or a control with imperative methods.
///
/// Main-actor isolated because every implementation touches UIKit/AppKit, the
/// store, or both — and because the session that drives them is.
@MainActor
public protocol RufletService: AnyObject {
  /// The wire type this handles, e.g. `"Clipboard"`.
  static var wireType: String { get }

  /// Runs `call` and reports the result. Called on the main actor.
  func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  )
}

/// What a service is allowed to reach back into.
public struct RufletServiceContext {
  /// Reads the current control tree, so a service can inspect its own props.
  public let store: ControlStore
  /// Reports an event the way a control does, for services that push
  /// (sensors, connectivity, battery, shake detection).
  public let emitEvent: (_ target: Int, _ name: String, _ data: RufletValue) -> Void

  public init(
    store: ControlStore,
    emitEvent: @escaping (_ target: Int, _ name: String, _ data: RufletValue) -> Void
  ) {
    self.store = store
    self.emitEvent = emitEvent
  }
}

public enum RufletServiceError: LocalizedError, Equatable {
  case unknownTarget(Int)
  case unsupportedMethod(type: String, method: String)
  /// The service exists, in a module this target did not link.
  case moduleNotLinked(type: String, bundle: String)
  case invalidArguments(String)
  /// The upstream command exists, but the current Apple platform has no
  /// equivalent API. This is intentionally distinct from an unknown method
  /// and from a temporarily unavailable device (for example, no camera).
  case platformUnsupported(type: String, method: String, platform: String)
  case unavailable(String)
  case failed(String)

  public var errorDescription: String? {
    switch self {
    case .unknownTarget(let id):
      return "No control with id \(id) is registered in this session"
    case .unsupportedMethod(let type, let method):
      return "\(type) does not implement `\(method)` in the Ruflet Apple engine"
    case .moduleNotLinked(let type, let bundle):
      return
        "\(type) is provided by the \(bundle) module, which this app does not link. "
        + "Add \(bundle) to the target's package dependencies and pass \(bundle).self "
        + "to RufletAppView(extensions:)."
    case .invalidArguments(let detail):
      return "Invalid arguments: \(detail)"
    case .platformUnsupported(let type, let method, let platform):
      return "\(type).\(method) is not supported on \(platform)"
    case .unavailable(let detail):
      return detail
    case .failed(let detail):
      return detail
    }
  }
}

/// A service that starts sampling as soon as its control exists, rather than
/// waiting to be invoked.
@MainActor
public protocol RufletStreamingService: RufletService {
  func activate(node: ControlNode, context: RufletServiceContext)
}

/// Maps wire types onto the service objects that implement them.
///
/// Registration is by type rather than by id because Ruby creates services
/// lazily — `page.clipboard` mints a `Clipboard` control the first time it is
/// touched — so the engine cannot know the ids in advance. Instances are cached
/// per control id, since services such as sensors hold subscriptions.
@MainActor
public final class ServiceRegistry {
  private var factories: [String: () -> RufletService] = [:]
  private var instances: [Int: RufletService] = [:]
  private var registeredExtensionNames: Set<String> = []
  private var registeredExtensions: [any RufletExtension.Type] = []

  public init() {}

  /// Returns true only for the first installation of an extension in this
  /// session. Extension registration can have process-wide side effects (for
  /// example installing a permission probe), so hosts must not replay it when
  /// reconnecting the same session.
  func markExtensionRegistered(_ name: String) -> Bool {
    registeredExtensionNames.insert(name).inserted
  }

  public func hasExtension(_ name: String) -> Bool {
    registeredExtensionNames.contains(name)
  }

  func retainRegisteredExtension(_ extensionType: any RufletExtension.Type) {
    registeredExtensions.append(extensionType)
  }

  public func register<S: RufletService>(_ type: S.Type, factory: @escaping () -> S) {
    factories[S.wireType.lowercased()] = factory
  }

  /// For a service that implements several wire types, such as the motion
  /// sensors, which differ only in which feed they read.
  public func registerNamed(_ wireType: String, factory: @escaping () -> RufletService) {
    factories[wireType.lowercased()] = factory
  }

  public func service(for node: ControlNode) -> RufletService? {
    if let existing = instances[node.id] { return existing }
    if let instance = extensionService(for: node) { return instance }
    guard let factory = factories[node.type.lowercased()] else { return nil }
    let instance = factory()
    instances[node.id] = instance
    return instance
  }

  /// The services that push rather than answer.
  ///
  /// Ruby configures a sensor and then simply waits for `on_change` without
  /// ever calling a method, so these have to start the moment their control
  /// appears. Every other service stays uninstantiated until it is invoked —
  /// creating a `Battery` nobody asked for would switch on battery monitoring
  /// for an application that never reads it.
  ///
  /// Declared by whichever bundle provides them rather than listed here, since
  /// the core no longer knows what an optional module registers.
  private var streamingTypes: Set<String> = []

  public func markStreaming(_ wireTypes: [String]) {
    streamingTypes.formUnion(wireTypes.map { $0.lowercased() })
  }

  public func activateStreamingServices(in store: ControlStore, context: RufletServiceContext) {
    for node in store.nodes.values {
      let service: RufletStreamingService?
      if streamingTypes.contains(node.type.lowercased()) {
        service = self.service(for: node) as? RufletStreamingService
      } else {
        service = extensionService(for: node) as? RufletStreamingService
      }
      guard let service else { continue }
      // Flet calls a service's `update()` whenever its control properties
      // change. Re-presenting the current node gives native streaming
      // services the same lifecycle hook; each service owns the decision to
      // keep, restart, or stop its subscription from the new configuration.
      service.activate(node: node, context: context)
    }
  }

  private func extensionService(for node: ControlNode) -> RufletService? {
    if let existing = instances[node.id] { return existing }
    for extensionType in registeredExtensions {
      guard let service = extensionType.createService(for: node) else { continue }
      instances[node.id] = service
      return service
    }
    return nil
  }

  public func handles(_ wireType: String) -> Bool {
    factories[wireType.lowercased()] != nil
  }

  /// Drops cached instances for controls that no longer exist, releasing any
  /// subscriptions they hold.
  public func prune(liveIDs: Set<Int>) {
    instances = instances.filter { liveIDs.contains($0.key) }
  }
}
