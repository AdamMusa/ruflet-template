import RufletEngine

@MainActor
public struct RufletPermissionHandlerExtension: RufletExtension {
  public init() {}

  public func createService(for control: RufletControl) -> RufletService? {
    control.type == "PermissionHandler" ? PermissionHandlerService(control: control) : nil
  }
}
