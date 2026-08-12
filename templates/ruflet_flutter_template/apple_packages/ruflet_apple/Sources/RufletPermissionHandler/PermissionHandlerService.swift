import Foundation
import RufletEngine
import RufletProtocol

#if canImport(UIKit)
  import UIKit
#endif
#if canImport(AppKit)
  import AppKit
#endif

/// `PermissionHandler` — the permissions Apple platforms actually gate.
///
/// The gated ones live behind optional modules, so this asks whatever is
/// linked through `RufletPermissions`. Anything nothing can answer reports
/// "granted", which is the truth for a permission the OS does not gate.
@MainActor
public final class PermissionHandlerService: RufletService {
  public static let wireType = "PermissionHandler"

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    let permission = call.argument("permission")?.stringValue?.lowercased() ?? ""

    switch call.name {
    case "get_status", "check_permission":
      completion(.success(.string(RufletPermissions.status(of: permission))))

    case "request", "request_permission":
      RufletPermissions.request(permission) { status in
        completion(.success(.string(status)))
      }

    case "open_app_settings":
      #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
          return completion(.success(.bool(true)))
        }
      #elseif canImport(AppKit)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
          NSWorkspace.shared.open(url)
          return completion(.success(.bool(true)))
        }
      #endif
      completion(.success(.bool(false)))

    default:
      completion(
        .failure(
          RufletServiceError.unsupportedMethod(type: "PermissionHandler", method: call.name)))
    }
  }
}
