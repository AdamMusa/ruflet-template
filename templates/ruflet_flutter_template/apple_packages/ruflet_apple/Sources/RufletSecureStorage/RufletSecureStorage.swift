import RufletEngine

/// Native Apple implementation of Flet's `flet_secure_storage` package.
@MainActor
public enum RufletSecureStorage: RufletExtension {
  public static func register(in registry: ServiceRegistry) {
    registry.register(SecureStorageService.self) { SecureStorageService() }
    registry.markStreaming([SecureStorageService.wireType])
  }
}
