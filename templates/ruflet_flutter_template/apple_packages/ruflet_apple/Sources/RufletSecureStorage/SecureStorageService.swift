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
    groupID = map["group_id"]?.stringValue
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
    accessControlFlags = Self.accessControlFlags(map["access_control_flags"])
    usesDataProtectionKeychain = map["uses_data_protection_keychain"]?.boolValue ?? true
  }

  private static func date(_ value: RufletValue?) -> Date? {
    if let seconds = value?.doubleValue { return Date(timeIntervalSince1970: seconds) }
    guard let raw = value?.stringValue else { return nil }
    return ISO8601DateFormatter().date(from: raw)
  }

  private static func accessControlFlags(_ value: RufletValue?) -> [String] {
    let names = [
      "devicePasscode", "biometryAny", "biometryCurrentSet", "userPresence",
      "watch", "or", "and", "applicationPassword", "privateKeyUsage",
    ]
    return value?.arrayValue?.compactMap { value in
      guard case .string(let candidate) = value else { return nil }
      return names.first { $0.caseInsensitiveCompare(candidate) == .orderedSame }
    } ?? []
  }
}

/// `SecureStorage` — the Keychain.
@MainActor
public final class SecureStorageService: RufletStreamingService {
  public static let wireType = "SecureStorage"

  private let service = "flutter_secure_storage_service"
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
    case "set":
      guard case .string(let key)? = call.argument("key"),
        case .string(let value)? = call.argument("value")
      else {
        return completion(
          .failure(RufletServiceError.invalidArguments("key and value are required")))
      }
      var attributes = query(key: key, options: options)
      if case .success(true) = containsKey(key: key, options: options) {
        let update = [kSecValueData as String: Data(value.utf8)]
        let status = SecItemUpdate(attributes as CFDictionary, update as CFDictionary)
        if status == errSecSuccess {
          return completion(.success(.null))
        }
        _ = delete(key: key, options: options)
      }
      attributes[kSecValueData as String] = Data(value.utf8)
      let status = SecItemAdd(attributes as CFDictionary, nil)
      completion(Self.voidMutationResult(status: status, missingIsSuccess: false))

    case "get":
      guard case .string(let key)? = call.argument("key") else {
        return completion(.failure(RufletServiceError.invalidArguments("key is required")))
      }
      var attributes = query(key: key, options: options)
      attributes[kSecReturnData as String] = true
      attributes[kSecMatchLimit as String] = kSecMatchLimitOne
      var result: CFTypeRef?
      let status = SecItemCopyMatching(attributes as CFDictionary, &result)
      completion(Self.readResult(status: status, data: result as? Data))

    case "contains_key":
      guard case .string(let key)? = call.argument("key") else {
        return completion(.failure(RufletServiceError.invalidArguments("key is required")))
      }
      completion(containsKey(key: key, options: options).map(RufletValue.bool))

    case "remove":
      guard case .string(let key)? = call.argument("key") else {
        return completion(.failure(RufletServiceError.invalidArguments("key is required")))
      }
      completion(delete(key: key, options: options))

    case "clear":
      completion(delete(key: nil, options: options))

    case "get_all":
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
      guard status == errSecSuccess else {
        return completion(.failure(RufletServiceError.failed("Keychain error \(status)")))
      }
      let items = result as? [[String: Any]] ?? []
      completion(.success(.map(Self.decodedEntries(items))))

    case "get_availability":
      completion(.success(.bool(Self.protectedDataAvailable)))

    default:
      completion(
        .failure(
          RufletServiceError.unsupportedMethod(type: "SecureStorage", method: call.name)))
    }
  }

  func query(
    key: String,
    options: AppleSecureStorageOptions,
    synchronizable: Bool? = nil,
    includeAccessProtection: Bool = true
  ) -> [String: Any] {
    var query = baseQuery(
      options: options,
      synchronizable: synchronizable,
      includeAccessProtection: includeAccessProtection)
    query[kSecAttrAccount as String] = key
    return query
  }

  func baseQuery(
    options: AppleSecureStorageOptions,
    synchronizable: Bool? = nil,
    includeAccessProtection: Bool = true
  ) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: options.accountName ?? service
    ]
    #if os(iOS)
      if let group = options.groupID { query[kSecAttrAccessGroup as String] = group }
    #endif
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
      query[kSecMatchLimit as String] = limit == 1 ? kSecMatchLimitOne : kSecMatchLimitAll
    }
    if options.shouldReturnPersistentReference {
      query[kSecReturnPersistentRef as String] = true
    }
    if let behavior = options.authenticationUIBehavior,
      !behavior.isEmpty
    {
      query[kSecUseAuthenticationUI as String] = behavior
    }
    #if os(macOS)
      if #available(macOS 10.15, *) {
        query[kSecUseDataProtectionKeychain as String] = options.usesDataProtectionKeychain
      }
    #endif
    if includeAccessProtection {
      let protection = Self.accessibility(options.accessibility)
      let flags = Self.accessControlFlags(options.accessControlFlags)
      if flags.isEmpty {
        query[kSecAttrAccessible as String] = protection
        query[kSecAttrSynchronizable as String] = synchronizable ?? options.synchronizable
      } else if let access = SecAccessControlCreateWithFlags(nil, protection, flags, nil) {
        query[kSecAttrAccessControl as String] = access
      }
    } else {
      query[kSecAttrSynchronizable as String] = synchronizable ?? options.synchronizable
    }
    return query
  }

  private func containsKey(
    key: String, options: AppleSecureStorageOptions
  ) -> Result<Bool, Error> {
    let synchronized = SecItemCopyMatching(
      query(key: key, options: options, synchronizable: true) as CFDictionary, nil)
    if synchronized == errSecSuccess { return .success(true) }
    if synchronized != errSecItemNotFound {
      return .failure(RufletServiceError.failed("Keychain error \(synchronized)"))
    }
    let local = SecItemCopyMatching(
      query(key: key, options: options, synchronizable: false) as CFDictionary, nil)
    return Self.containsResult(synchronized: synchronized, local: local)
  }

  private func delete(
    key: String?, options: AppleSecureStorageOptions
  ) -> Result<RufletValue, Error> {
    func status(synchronizable: Bool) -> OSStatus {
      let attributes: [String: Any]
      if let key {
        attributes = query(
          key: key, options: options, synchronizable: synchronizable,
          includeAccessProtection: false)
      } else {
        attributes = baseQuery(
          options: options, synchronizable: synchronizable,
          includeAccessProtection: false)
      }
      return SecItemDelete(attributes as CFDictionary)
    }
    return Self.deleteResult(synchronized: status(synchronizable: true),
                             local: status(synchronizable: false))
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
    switch name.lowercased() {
    case "passcode": return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
    case "unlocked_this_device": return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    case "first_unlock": return kSecAttrAccessibleAfterFirstUnlock
    case "first_unlock_this_device": return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    default: return kSecAttrAccessibleWhenUnlocked
    }
  }

  private static func accessControlFlags(_ names: [String]) -> SecAccessControlCreateFlags {
    names.reduce(into: SecAccessControlCreateFlags()) { flags, name in
      switch name.lowercased() {
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

  /// The pinned Darwin plug-in uses `String(data:encoding:)`: invalid or
  /// absent bytes are a successful null read, not replacement-decoded text.
  static func readResult(
    status: OSStatus, data: Data?
  ) -> Result<RufletValue, Error> {
    if status == errSecItemNotFound { return .success(.null) }
    guard status == errSecSuccess else {
      return .failure(RufletServiceError.failed("Keychain error \(status)"))
    }
    guard let data, let value = String(data: data, encoding: .utf8) else {
      return .success(.null)
    }
    return .success(.string(value))
  }

  /// `readAll` omits entries that do not contain a key or strict UTF-8 value.
  static func decodedEntries(_ items: [[String: Any]]) -> [String: RufletValue] {
    var entries: [String: RufletValue] = [:]
    for item in items {
      guard let key = item[kSecAttrAccount as String] as? String,
        let data = item[kSecValueData as String] as? Data,
        let value = String(data: data, encoding: .utf8)
      else { continue }
      entries[key] = .string(value)
    }
    return entries
  }

  static func containsResult(
    synchronized: OSStatus, local: OSStatus
  ) -> Result<Bool, Error> {
    if synchronized == errSecSuccess { return .success(true) }
    if synchronized != errSecItemNotFound {
      return .failure(RufletServiceError.failed("Keychain error \(synchronized)"))
    }
    if local == errSecSuccess { return .success(true) }
    if local == errSecItemNotFound { return .success(false) }
    return .failure(RufletServiceError.failed("Keychain error \(local)"))
  }

  static func deleteResult(
    synchronized: OSStatus, local: OSStatus
  ) -> Result<RufletValue, Error> {
    if synchronized == errSecSuccess || local == errSecSuccess
      || (synchronized == errSecItemNotFound && local == errSecItemNotFound)
    {
      return .success(.null)
    }
    let status = synchronized != errSecItemNotFound ? synchronized : local
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
