import Foundation
import RufletEngine
import RufletProtocol
import Security

#if canImport(UIKit)
  import UIKit
#endif

/// The Cupertino option map accepted by `flutter_secure_storage` through
/// Flet's `ios`/`macos` method arguments and `ios_options`/`macos_options`
/// control properties. Keeping the parser beside the Keychain owner prevents
/// the optional extension from quietly dropping options at the engine edge.
struct AppleSecureStorageOptions: Equatable {
  var accountName: String?
  var groupID: String?
  var accessibility = "unlocked"
  var synchronizable = false
  var label: String?
  var itemDescription: String?
  var comment: String?
  var isInvisible: Bool?
  var isNegative: Bool?
  var creationDate: Date?
  var lastModifiedDate: Date?
  var resultLimit: Int?
  var shouldReturnPersistentReference = false
  var authenticationUIBehavior: String?
  var accessControlFlags: [String] = []
  var usesDataProtectionKeychain = true

  init(_ value: RufletValue?) {
    guard let map = value?.mapValue else { return }
    accountName = map["account_name"]?.stringValue
    groupID = map["group_id"]?.stringValue ?? map["groupId"]?.stringValue
    accessibility = map["accessibility"]?.stringValue ?? "unlocked"
    synchronizable = map["synchronizable"]?.boolValue ?? false
    label = map["label"]?.stringValue
    itemDescription = map["description"]?.stringValue
    comment = map["comment"]?.stringValue
    isInvisible = map["is_invisible"]?.boolValue
    isNegative = map["is_negative"]?.boolValue
    creationDate = Self.date(map["creation_date"])
    lastModifiedDate = Self.date(map["last_modified_date"])
    resultLimit = map["result_limit"]?.intValue
    shouldReturnPersistentReference = map["is_persistent"]?.boolValue ?? false
    authenticationUIBehavior = map["auth_ui_behavior"]?.stringValue
    accessControlFlags = map["access_control_flags"]?.arrayValue?
      .compactMap(\.stringValue) ?? []
    usesDataProtectionKeychain = map["uses_data_protection_keychain"]?.boolValue ?? true
  }

  private static func date(_ value: RufletValue?) -> Date? {
    if let seconds = value?.doubleValue { return Date(timeIntervalSince1970: seconds) }
    guard let raw = value?.stringValue else { return nil }
    return ISO8601DateFormatter().date(from: raw)
  }
}

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
    targetID = node.id
    self.context = context
    #if canImport(UIKit)
      guard node.handlesEvent("change") else {
        removeProtectedDataObservers()
        return
      }
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
    let options = resolvedAppleOptions(for: call, node: node)
    switch call.name {
    case "set", "write":
      guard let key = call.argument("key")?.stringValue,
        let value = call.argument("value")?.stringValue
      else {
        return completion(
          .failure(RufletServiceError.invalidArguments("key and value are required")))
      }
      var attributes = query(key: key, options: options)
      SecItemDelete(attributes as CFDictionary)
      attributes[kSecValueData as String] = Data(value.utf8)
      let status = SecItemAdd(attributes as CFDictionary, nil)
      completion(Self.voidMutationResult(status: status, missingIsSuccess: false))

    case "get", "read":
      guard let key = call.argument("key")?.stringValue else {
        return completion(.failure(RufletServiceError.invalidArguments("key is required")))
      }
      var attributes = query(key: key, options: options)
      attributes[kSecReturnData as String] = true
      attributes[kSecMatchLimit as String] = kSecMatchLimitOne
      var result: CFTypeRef?
      let status = SecItemCopyMatching(attributes as CFDictionary, &result)
      if status == errSecItemNotFound {
        return completion(.success(.null))
      }
      guard status == errSecSuccess, let data = result as? Data else {
        return completion(.failure(RufletServiceError.failed("Keychain error \(status)")))
      }
      completion(.success(.string(String(decoding: data, as: UTF8.self))))

    case "contains_key":
      guard let key = call.argument("key")?.stringValue else {
        return completion(.failure(RufletServiceError.invalidArguments("key is required")))
      }
      let status = SecItemCopyMatching(query(key: key, options: options) as CFDictionary, nil)
      if status == errSecItemNotFound { return completion(.success(.bool(false))) }
      status == errSecSuccess
        ? completion(.success(.bool(true)))
        : completion(.failure(RufletServiceError.failed("Keychain error \(status)")))

    case "remove", "delete":
      guard let key = call.argument("key")?.stringValue else {
        return completion(.failure(RufletServiceError.invalidArguments("key is required")))
      }
      let status = SecItemDelete(query(key: key, options: options) as CFDictionary)
      completion(Self.voidMutationResult(status: status, missingIsSuccess: true))

    case "clear", "delete_all":
      let status = SecItemDelete(baseQuery(options: options) as CFDictionary)
      completion(Self.voidMutationResult(status: status, missingIsSuccess: true))

    case "get_all", "read_all":
      var query = baseQuery(options: options)
      query.merge([
        kSecReturnAttributes as String: true,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitAll
      ]) { _, new in new }
      var result: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &result)
      query.removeAll()
      if status == errSecItemNotFound {
        return completion(.success(.map([:])))
      }
      guard status == errSecSuccess, let items = result as? [[String: Any]] else {
        return completion(.failure(RufletServiceError.failed("Keychain error \(status)")))
      }
      var entries: [String: RufletValue] = [:]
      for item in items {
        guard let key = item[kSecAttrAccount as String] as? String else { continue }
        let data = item[kSecValueData as String] as? Data ?? Data()
        entries[key] = .string(String(decoding: data, as: UTF8.self))
      }
      completion(.success(.map(entries)))

    case "get_availability":
      completion(.success(.bool(Self.protectedDataAvailable)))

    default:
      completion(
        .failure(
          RufletServiceError.unsupportedMethod(type: "SecureStorage", method: call.name)))
    }
  }

  private func query(key: String, options: AppleSecureStorageOptions) -> [String: Any] {
    var query = baseQuery(options: options)
    query[kSecAttrAccount as String] = key
    return query
  }

  private func baseQuery(options: AppleSecureStorageOptions) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: options.accountName ?? service
    ]
    if let group = options.groupID { query[kSecAttrAccessGroup as String] = group }
    if options.synchronizable { query[kSecAttrSynchronizable as String] = kCFBooleanTrue }
    if let label = options.label { query[kSecAttrLabel as String] = label }
    if let description = options.itemDescription {
      query[kSecAttrDescription as String] = description
    }
    if let comment = options.comment { query[kSecAttrComment as String] = comment }
    if let invisible = options.isInvisible { query[kSecAttrIsInvisible as String] = invisible }
    if let negative = options.isNegative { query[kSecAttrIsNegative as String] = negative }
    if let creationDate = options.creationDate { query[kSecAttrCreationDate as String] = creationDate }
    if let modified = options.lastModifiedDate {
      query[kSecAttrModificationDate as String] = modified
    }
    if let limit = options.resultLimit {
      query[kSecMatchLimit as String] = limit == 1 ? kSecMatchLimitOne : limit
    }
    if options.shouldReturnPersistentReference {
      query[kSecReturnPersistentRef as String] = true
    }
    if let behavior = options.authenticationUIBehavior,
      let value = Self.authenticationUI(behavior)
    {
      query[kSecUseAuthenticationUI as String] = value
    }
    #if os(macOS)
      if #available(macOS 10.15, *) {
        query[kSecUseDataProtectionKeychain as String] = options.usesDataProtectionKeychain
      }
    #endif
    let protection = Self.accessibility(options.accessibility)
    let flags = Self.accessControlFlags(options.accessControlFlags)
    if flags.isEmpty {
      query[kSecAttrAccessible as String] = protection
    } else if let access = SecAccessControlCreateWithFlags(nil, protection, flags, nil) {
      query[kSecAttrAccessControl as String] = access
    }
    return query
  }

  func resolvedAppleOptions(
    for call: RufletMethodCall, node: ControlNode?
  ) -> AppleSecureStorageOptions {
    #if os(macOS)
      let argument = call.argument("macos")
      let property = node?.props["macos_options"] ?? control?.props["macos_options"]
        ?? node?.props["ios_options"] ?? control?.props["ios_options"]
    #else
      let argument = call.argument("ios")
      let property = node?.props["ios_options"] ?? control?.props["ios_options"]
        ?? node?.props["macos_options"] ?? control?.props["macos_options"]
    #endif
    return AppleSecureStorageOptions(argument?.isNull == false ? argument : property)
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

  private static func accessControlFlags(_ names: [String]) -> SecAccessControlCreateFlags {
    names.reduce(into: SecAccessControlCreateFlags()) { flags, name in
      switch name.lowercased().replacingOccurrences(of: "_", with: "") {
      case "userpresence": flags.insert(.userPresence)
      case "biometryany": flags.insert(.biometryAny)
      case "biometrycurrentset": flags.insert(.biometryCurrentSet)
      case "devicepasscode": flags.insert(.devicePasscode)
      case "or": flags.insert(.or)
      case "and": flags.insert(.and)
      case "privatekeyusage": flags.insert(.privateKeyUsage)
      case "applicationpassword": flags.insert(.applicationPassword)
      default: break
      }
    }
  }

  private static func authenticationUI(_ name: String) -> CFString? {
    switch name.lowercased().replacingOccurrences(of: "_", with: "") {
    case "allow": return kSecUseAuthenticationUIAllow
    case "fail": return kSecUseAuthenticationUIFail
    case "skip": return kSecUseAuthenticationUISkip
    default: return nil
    }
  }

  private static var protectedDataAvailable: Bool {
    #if canImport(UIKit)
      return UIApplication.shared.isProtectedDataAvailable
    #else
      return true
    #endif
  }

  /// `flutter_secure_storage` exposes write/delete/deleteAll as `Future<void>`.
  /// Centralizing their reply conversion keeps the native wire result null and
  /// lets tests prove it without requiring a signed Keychain entitlement.
  static func voidMutationResult(
    status: OSStatus, missingIsSuccess: Bool
  ) -> Result<RufletValue, Error> {
    if status == errSecSuccess || (missingIsSuccess && status == errSecItemNotFound) {
      return .success(.null)
    }
    return .failure(RufletServiceError.failed("Keychain error \(status)"))
  }

  private func removeProtectedDataObservers() {
    protectedDataObservers.forEach(NotificationCenter.default.removeObserver)
    protectedDataObservers.removeAll()
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
