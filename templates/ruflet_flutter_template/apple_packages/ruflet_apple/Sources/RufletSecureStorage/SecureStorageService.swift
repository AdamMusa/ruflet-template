import Foundation
import RufletEngine
import RufletProtocol
import Security

#if canImport(UIKit)
  import UIKit
#endif

/// `SecureStorage` — the Keychain.
@MainActor
public final class SecureStorageService: RufletStreamingService {
  public static let wireType = "SecureStorage"

  private let service = Bundle.main.bundleIdentifier ?? "com.izeesoft.ruflet"
  private var targetID: Int?
  private var context: RufletServiceContext?
  private var control: ControlNode?
  private var protectedDataObservers: [NSObjectProtocol] = []

  public init() {}

  public func activate(node: ControlNode, context: RufletServiceContext) {
    control = node
    guard node.handlesEvent("change") else { return }
    targetID = node.id
    self.context = context
    #if canImport(UIKit)
      guard protectedDataObservers.isEmpty else { return }
      for notification in [
        UIApplication.protectedDataDidBecomeAvailableNotification,
        UIApplication.protectedDataWillBecomeUnavailableNotification
      ] {
        protectedDataObservers.append(NotificationCenter.default.addObserver(
          forName: notification,
          object: nil,
          queue: .main
        ) { [weak self] _ in
          Task { @MainActor in self?.reportProtectedDataAvailability() }
        })
      }
    #endif
  }

  deinit {
    protectedDataObservers.forEach(NotificationCenter.default.removeObserver)
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    switch call.name {
    case "set", "write":
      guard let key = call.argument("key")?.stringValue,
        let value = call.argument("value")?.stringValue
      else {
        return completion(
          .failure(RufletServiceError.invalidArguments("key and value are required")))
      }
      var attributes = query(key: key)
      SecItemDelete(attributes as CFDictionary)
      attributes[kSecValueData as String] = Data(value.utf8)
      let status = SecItemAdd(attributes as CFDictionary, nil)
      status == errSecSuccess
        ? completion(.success(.bool(true)))
        : completion(.failure(RufletServiceError.failed("Keychain error \(status)")))

    case "get", "read":
      guard let key = call.argument("key")?.stringValue else {
        return completion(.failure(RufletServiceError.invalidArguments("key is required")))
      }
      var attributes = query(key: key)
      attributes[kSecReturnData as String] = true
      attributes[kSecMatchLimit as String] = kSecMatchLimitOne
      var result: CFTypeRef?
      let status = SecItemCopyMatching(attributes as CFDictionary, &result)
      guard status == errSecSuccess, let data = result as? Data else {
        return completion(.success(.null))
      }
      completion(.success(.string(String(decoding: data, as: UTF8.self))))

    case "contains_key":
      guard let key = call.argument("key")?.stringValue else {
        return completion(.failure(RufletServiceError.invalidArguments("key is required")))
      }
      let status = SecItemCopyMatching(query(key: key) as CFDictionary, nil)
      completion(.success(.bool(status == errSecSuccess)))

    case "remove", "delete":
      guard let key = call.argument("key")?.stringValue else {
        return completion(.failure(RufletServiceError.invalidArguments("key is required")))
      }
      SecItemDelete(query(key: key) as CFDictionary)
      completion(.success(.bool(true)))

    case "clear", "delete_all":
      SecItemDelete(
        [
          kSecClass as String: kSecClassGenericPassword,
          kSecAttrService as String: service
        ] as CFDictionary)
      completion(.success(.bool(true)))

    case "get_all", "read_all":
      var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecReturnAttributes as String: true,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitAll
      ]
      var result: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &result)
      query.removeAll()
      guard status == errSecSuccess, let items = result as? [[String: Any]] else {
        return completion(.success(.map([:])))
      }
      var entries: [String: RufletValue] = [:]
      for item in items {
        guard let key = item[kSecAttrAccount as String] as? String else { continue }
        let data = item[kSecValueData as String] as? Data ?? Data()
        entries[key] = .string(String(decoding: data, as: UTF8.self))
      }
      completion(.success(.map(entries)))

    case "get_availability":
      completion(.success(.bool(true)))

    default:
      completion(
        .failure(
          RufletServiceError.unsupportedMethod(type: "SecureStorage", method: call.name)))
    }
  }

  private func query(key: String) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key
    ]
    if let options = appleOptions {
      if let group = options["group_id"]?.stringValue ?? options["groupId"]?.stringValue {
        query[kSecAttrAccessGroup as String] = group
      }
      if let account = options["account_name"]?.stringValue {
        query[kSecAttrService as String] = account
      }
      if let accessibility = options["accessibility"]?.stringValue {
        query[kSecAttrAccessible as String] = Self.accessibility(accessibility)
      }
      if options["synchronizable"]?.boolValue == true {
        query[kSecAttrSynchronizable as String] = kCFBooleanTrue
      }
    }
    return query
  }

  private var appleOptions: [String: RufletValue]? {
    #if os(macOS)
      return control?.map("macos_options") ?? control?.map("ios_options")
    #else
      return control?.map("ios_options") ?? control?.map("macos_options")
    #endif
  }

  private static func accessibility(_ name: String) -> CFString {
    switch name.lowercased().replacingOccurrences(of: "_", with: "") {
    case "passcode": return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
    case "unlockedthisdevice": return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    case "firstunlock": return kSecAttrAccessibleAfterFirstUnlock
    case "firstunlockthisdevice": return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    default: return kSecAttrAccessibleWhenUnlocked
    }
  }

  private func reportProtectedDataAvailability() {
    guard let targetID, let context else { return }
    #if canImport(UIKit)
      context.emitEvent(targetID, "change", .map([
        "available": .bool(UIApplication.shared.isProtectedDataAvailable)
      ]))
    #endif
  }
}
