import Foundation
import RufletProtocol

/// An optional Ruflet extension an application chooses to link.
///
/// Ruflet's service surface reaches CoreMotion, CoreLocation and AVFoundation
/// capture — frameworks Apple gates behind privacy usage strings and flags
/// during App Store review. An app that never asks Ruby for the camera should
/// not carry the camera code, so those services live in their own modules and
/// are linked, not compiled in behind a flag: what you do not link is not in
/// the binary at all.
///
/// An extension may install service factories, native control builders, or
/// both. Keeping this protocol in `RufletEngine` lets independent Swift
/// package products such as `RufletCamera` and `RufletVideo` register with the
/// host without making the core engine import those packages.
///
/// The core engine registers everything that touches no gated API.
@MainActor
public protocol RufletExtension {
  /// Human-readable name, used when the engine reports why a service is
  /// missing.
  static var extensionName: String { get }

  /// Installs this extension into a session. Implementations can register
  /// services directly and, when their module depends on `RufletUI`, native
  /// control builders through `ControlRegistry`.
  static func register(in registry: ServiceRegistry)
}

public extension RufletExtension {
  static var extensionName: String { String(describing: Self.self) }
}

/// Source-compatible name used by the first Apple renderer prototypes.
///
/// New extension products should conform to `RufletExtension`; keeping this
/// alias means existing applications do not need a flag-day migration.
@available(*, deprecated, renamed: "RufletExtension")
public typealias RufletServiceBundle = RufletExtension

extension ServiceRegistry {
  /// Installs an optional extension once for this session.
  public func register(extension extensionType: any RufletExtension.Type) {
    guard markExtensionRegistered(extensionType.extensionName) else { return }
    extensionType.register(in: self)
  }

  public func register(extensions: [any RufletExtension.Type]) {
    for extensionType in extensions { register(extension: extensionType) }
  }

  @available(*, deprecated, renamed: "register(extension:)")
  public func register(bundle: any RufletServiceBundle.Type) {
    register(extension: bundle)
  }

  @available(*, deprecated, renamed: "register(extensions:)")
  public func register(bundles: [any RufletServiceBundle.Type]) {
    register(extensions: bundles)
  }
}

/// Answers `check_permission`/`request_permission` for whatever is linked.
///
/// The permission surface spans several optional modules, so the core service
/// keeps a list of probes and each bundle installs its own. A permission
/// nothing can answer reports "granted", which is the truth on Apple platforms
/// for anything the OS does not gate.
@MainActor
public enum RufletPermissions {
  /// Returns a Flet permission status for `permission`, or nil when this probe
  /// does not know about it.
  public typealias Probe = (_ permission: String) -> String?
  /// Requests `permission`, or returns false when this probe cannot.
  public typealias Request = (_ permission: String, _ completion: @escaping (String) -> Void) ->
    Bool

  private(set) static var probes: [Probe] = []
  private(set) static var requests: [Request] = []

  public static func installProbe(_ probe: @escaping Probe) {
    probes.append(probe)
  }

  public static func installRequest(_ request: @escaping Request) {
    requests.append(request)
  }

  public static func status(of permission: String) -> String {
    for probe in probes {
      if let status = probe(permission) { return status }
    }
    return "granted"
  }

  public static func request(_ permission: String, completion: @escaping (String) -> Void) {
    for request in requests where request(permission, completion) { return }
    completion(status(of: permission))
  }
}
