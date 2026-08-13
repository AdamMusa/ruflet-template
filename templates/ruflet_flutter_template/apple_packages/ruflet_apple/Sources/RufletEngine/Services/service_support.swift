import Foundation
import RufletProtocol
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public enum RufletServiceError: Error, Equatable, Sendable {
  case unknownMethod(service: String, method: String)
  case missingArgument(String)
  case invalidArgument(String)
  case unsupportedValue(String)
  case unavailable(String)
}

@MainActor
open class RufletInvokableService: RufletService {
  private var invokeListener: UUID?

  open override func initialize() {
    invokeListener = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { throw RufletServiceError.unavailable("Service was disposed") }
      return try await self.invoke(name, arguments: arguments.map ?? [:]) ?? .null
    }
  }

  open func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    throw RufletServiceError.unknownMethod(service: control.type, method: name)
  }

  open override func dispose() {
    if let invokeListener {
      control.removeInvokeMethodListener(invokeListener)
      self.invokeListener = nil
    }
  }
}

extension RufletValue {
  var serviceData: Data? {
    switch self {
    case .binary(let data): return data
    case .array(let values):
      let bytes = values.compactMap { value -> UInt8? in
        guard let integer = value.integer, (0 ... 255).contains(integer) else { return nil }
        return UInt8(integer)
      }
      return bytes.count == values.count ? Data(bytes) : nil
    default: return nil
    }
  }
}

func serviceStringArray(_ value: RufletValue?) -> [String]? {
  guard let values = value?.array else { return nil }
  return values.map { $0.text ?? String(describing: $0) }
}

func serviceTimestamp(_ date: Date) -> RufletValue {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  let payload = Data(formatter.string(from: date).replacingOccurrences(of: "Z", with: "+00:00").utf8)
  return .extensionValue(type: 1, payload: payload)
}

#if os(iOS)
@MainActor
func servicePresentationController() throws -> UIViewController {
  let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
  guard let root = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow })?.rootViewController
    ?? scenes.flatMap(\.windows).first?.rootViewController
  else { throw RufletServiceError.unavailable("No presentation controller") }
  var controller = root
  while let presented = controller.presentedViewController { controller = presented }
  if let navigation = controller as? UINavigationController { return navigation.visibleViewController ?? navigation }
  if let tabs = controller as? UITabBarController { return tabs.selectedViewController ?? tabs }
  return controller
}
#endif
