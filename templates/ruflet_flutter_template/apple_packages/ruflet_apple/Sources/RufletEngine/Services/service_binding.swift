import Foundation

/// Binds one service control to the first extension that can create it.
@MainActor
public final class ServiceBinding {
  public let control: RufletControl
  private let service: RufletService
  private var updateListener: UUID?

  public init(control: RufletControl, backend: RufletBackendProtocol) throws {
    self.control = control
    guard let service = backend.extensionRegistry.service(for: control) else {
      throw RufletServiceError.unavailable("Unknown service: \(control.type)")
    }
    self.service = service
    service.initialize()
    updateListener = control.addListener { [weak service] in service?.update() }
  }

  public func dispose() {
    if let updateListener {
      control.removeListener(updateListener)
      self.updateListener = nil
    }
    service.dispose()
  }
}
