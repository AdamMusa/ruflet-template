import SwiftUI

@MainActor
public protocol RufletExtension {
  /// Exact wire control types for which this extension creates native views.
  ///
  /// Flet's extension dispatch is type-driven. Declaring that same contract
  /// makes renderer registration auditable without constructing app screens.
  var renderedControlTypes: Set<String> { get }
  /// Exact wire control types for which this extension creates services.
  var serviceControlTypes: Set<String> { get }
  func ensureInitialized()
  func createView(for control: RufletControl) -> AnyView?
  func createService(for control: RufletControl) -> RufletService?
  func createAppleIcon(for iconCode: Int) -> RufletAppleIcon?
}

public extension RufletExtension {
  var renderedControlTypes: Set<String> { [] }
  var serviceControlTypes: Set<String> { [] }
  func ensureInitialized() {}
  func createView(for control: RufletControl) -> AnyView? { nil }
  func createService(for control: RufletControl) -> RufletService? { nil }
  func createAppleIcon(for iconCode: Int) -> RufletAppleIcon? { nil }
}

@MainActor
public final class RufletExtensionRegistry: ObservableObject {
  public let extensions: [any RufletExtension]
  private let viewExtensions: [String: any RufletExtension]
  private let serviceExtensions: [String: any RufletExtension]

  public init(_ extensions: [any RufletExtension]) {
    self.extensions = extensions
    var views: [String: any RufletExtension] = [:]
    var services: [String: any RufletExtension] = [:]
    // Preserve Flet's ordered, first-extension-wins dispatch while avoiding a
    // linear scan through every optional extension for every SwiftUI control.
    for item in extensions {
      for type in item.renderedControlTypes where views[type] == nil { views[type] = item }
      for type in item.serviceControlTypes where services[type] == nil { services[type] = item }
    }
    viewExtensions = views
    serviceExtensions = services
    for item in extensions { item.ensureInitialized() }
  }

  /// Union of every native view type claimed by the installed extensions.
  public var renderedControlTypes: Set<String> {
    Set(viewExtensions.keys)
  }

  public var serviceControlTypes: Set<String> {
    Set(serviceExtensions.keys)
  }

  public func view(for control: RufletControl) -> AnyView? {
    viewExtensions[control.type]?.createView(for: control)
  }

  public func service(for control: RufletControl) -> RufletService? {
    serviceExtensions[control.type]?.createService(for: control)
  }

  public func appleIcon(for iconCode: Int) -> RufletAppleIcon? {
    for item in extensions {
      if let icon = item.createAppleIcon(for: iconCode) { return icon }
    }
    return nil
  }
}
