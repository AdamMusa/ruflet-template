import RufletEngine

/// Native Apple implementation of Flet's `flet_audio` package.
@MainActor
public enum RufletAudio: RufletExtension {
  public static func register(in registry: ServiceRegistry) {
    registry.registerNamed("Audio") { AudioService() }
    // Flet services receive `update()` whenever wire properties change.
    // Audio owns a persistent player, so it requires the same lifecycle hook.
    registry.markStreaming(["Audio"])
  }
}
