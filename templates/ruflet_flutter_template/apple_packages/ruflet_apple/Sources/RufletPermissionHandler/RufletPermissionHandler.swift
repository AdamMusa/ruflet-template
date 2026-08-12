import RufletEngine

/// Native Apple implementation of Flet's `flet_permission_handler` package.
@MainActor
public enum RufletPermissionHandler: RufletExtension {
  public static func register(in registry: ServiceRegistry) {
    registry.register(PermissionHandlerService.self) { PermissionHandlerService() }
  }
}
