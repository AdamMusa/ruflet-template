import RufletProtocol

/// Apple-native counterpart of Flet's BrowserContextMenu service.
///
/// Flutter's service toggles a browser-only global. Apple has no browser
/// context-menu singleton, so both recognized commands are deterministic
/// successful no-ops; unknown commands still fail exactly like Flet.
@MainActor
public final class BrowserContextMenuService: RufletInvokableService {
  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    switch name {
    case "disable_menu", "enable_menu": return nil
    default:
      throw RufletServiceError.unknownMethod(service: "BrowserContextMenu", method: name)
    }
  }
}
