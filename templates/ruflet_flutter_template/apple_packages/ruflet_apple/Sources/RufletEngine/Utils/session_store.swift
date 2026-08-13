/// Apple port of Flet's non-web process session store.
///
/// The pinned non-web implementation intentionally does not persist values:
/// every read returns `nil` and writes are ignored. This keeps reconnect
/// registration behavior identical without introducing cookies or a platform
/// persistence fallback.
public enum RufletSessionStore {
  public static func getSessionID() -> String? {
    get("sessionId")
  }

  public static func setSessionID(_ value: String?) {
    set("sessionId", value ?? "")
  }

  public static func get(_ name: String) -> String? {
    nil
  }

  public static func set(_ name: String, _ value: String) {}
}
