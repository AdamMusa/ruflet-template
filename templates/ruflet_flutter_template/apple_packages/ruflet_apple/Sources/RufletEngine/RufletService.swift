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
        + "to RufletAppView(services:)."
    case .invalidArguments(let detail):
      return "Invalid arguments: \(detail)"
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

  public init() {}

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
    for node in store.nodes.values
    where streamingTypes.contains(node.type.lowercased()) && instances[node.id] == nil {
      guard let service = service(for: node) as? RufletStreamingService else { continue }
      service.activate(node: node, context: context)
    }
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
