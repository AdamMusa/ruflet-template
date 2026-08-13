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

  public init(_ extensions: [any RufletExtension]) {
    self.extensions = extensions
    for item in extensions { item.ensureInitialized() }
  }

  /// Union of every native view type claimed by the installed extensions.
  public var renderedControlTypes: Set<String> {
    extensions.reduce(into: []) { result, item in
      result.formUnion(item.renderedControlTypes)
    }
  }

  public var serviceControlTypes: Set<String> {
    extensions.reduce(into: []) { result, item in
      result.formUnion(item.serviceControlTypes)
    }
  }

  public func view(for control: RufletControl) -> AnyView? {
    for item in extensions {
      if let view = item.createView(for: control) { return view }
    }
    return nil
  }

  public func service(for control: RufletControl) -> RufletService? {
    for item in extensions {
      if let service = item.createService(for: control) { return service }
    }
    return nil
  }

  public func appleIcon(for iconCode: Int) -> RufletAppleIcon? {
    for item in extensions {
      if let icon = item.createAppleIcon(for: iconCode) { return icon }
    }
    return nil
  }
}
