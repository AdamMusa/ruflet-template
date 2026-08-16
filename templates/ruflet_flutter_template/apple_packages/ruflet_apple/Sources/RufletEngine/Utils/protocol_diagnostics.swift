import Foundation
import RufletProtocol

enum RufletProtocolDiagnostics {
  static var enabled: Bool {
    let mode = ProcessInfo.processInfo.environment["RUFLET_PROTOCOL_TRACE"] ?? "0"
    return mode != "0"
  }

  static func now() -> TimeInterval {
    ProcessInfo.processInfo.systemUptime
  }

  static func frame(
    _ direction: String,
    bytes: Int,
    message: RufletMessage,
    decodeMilliseconds: Double? = nil
  ) {
    guard enabled else { return }
    var fields = [
      "[RUFLET_NATIVE_PROTOCOL]",
      "t=\(String(format: "%.6f", now()))",
      direction,
      "bytes=\(bytes)",
      "action=\(message.action.rawValue)",
    ]
    if let decodeMilliseconds {
      fields.append("decode_ms=\(String(format: "%.3f", decodeMilliseconds))")
    }
    if let payload = message.payload.map {
      switch message.action {
      case .patchControl:
        fields.append("target=\(payload["id"]?.integer.map(String.init) ?? "nil")")
        fields.append("patch_items=\(payload["patch"]?.array?.count ?? 0)")
      case .controlEvent:
        fields.append("target=\(payload["target"]?.integer.map(String.init) ?? "nil")")
        fields.append("name=\(payload["name"]?.text ?? "nil")")
      case .updateControl:
        fields.append("target=\(payload["id"]?.integer.map(String.init) ?? "nil")")
        fields.append("properties=\(payload["properties"]?.map?.keys.sorted().joined(separator: ",") ?? "")")
      case .invokeControlMethod:
        fields.append("target=\(payload["control_id"]?.integer.map(String.init) ?? "nil")")
        fields.append("name=\(payload["name"]?.text ?? "nil")")
      case .registerClient, .sessionCrashed:
        break
      }
    }
    print(fields.joined(separator: " "))
  }

  static func timing(_ operation: String, milliseconds: Double, details: String = "") {
    guard enabled else { return }
    let suffix = details.isEmpty ? "" : " \(details)"
    print(
      "[RUFLET_NATIVE_PERF] t=\(String(format: "%.6f", now())) operation=\(operation) ms=\(String(format: "%.3f", milliseconds))\(suffix)"
    )
  }
}
