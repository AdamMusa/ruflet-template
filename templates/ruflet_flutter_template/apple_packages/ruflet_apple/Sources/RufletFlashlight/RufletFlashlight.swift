import RufletEngine

/// Native Apple implementation of Flet's `flet_flashlight` package.
@MainActor
public enum RufletFlashlight: RufletExtension {
  public static func register(in registry: ServiceRegistry) {
    registry.registerNamed("Flashlight") { FlashlightService() }
  }
}
