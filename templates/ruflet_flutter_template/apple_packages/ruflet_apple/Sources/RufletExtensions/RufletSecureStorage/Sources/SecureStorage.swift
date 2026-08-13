import Foundation
import RufletEngine
import RufletProtocol
import Security

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public final class SecureStorageService: RufletService {
  private let storage = AppleKeychainStorage()
  private var invokeToken: UUID?
  private var availabilityObservers: [NSObjectProtocol] = []

  public required init(control: RufletControl) {
    super.init(control: control)
  }

  public override func initialize() {
    invokeToken = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { return .null }
      return try self.invoke(name, arguments: arguments)
    }
    update()
  }

  public override func update() {
    let listen = control.boolean("on_change", default: false)
    if listen && availabilityObservers.isEmpty { registerAvailabilityObservers() }
    if !listen && !availabilityObservers.isEmpty { removeAvailabilityObservers() }
  }

  public override func dispose() {
    removeAvailabilityObservers()
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
  }

  private func invoke(_ name: String, arguments: RufletValue) throws -> RufletValue {
    let options = options(for: arguments)
    switch name {
    case "set":
      guard let key = arguments["key"]?.text else { throw RufletSecureStorageError.missingKey }
      guard let value = arguments["value"]?.text else { throw RufletSecureStorageError.missingValue }
      try storage.set(value, forKey: key, options: options)
      return .null
    case "get":
      guard let key = arguments["key"]?.text else { throw RufletSecureStorageError.missingKey }
      return try storage.get(key, options: options).map(RufletValue.string) ?? .null
    case "get_all":
      return .map(try storage.getAll(options: options).mapValues(RufletValue.string))
    case "contains_key":
      guard let key = arguments["key"]?.text else { throw RufletSecureStorageError.missingKey }
      return .bool(try storage.contains(key, options: options))
    case "remove":
      guard let key = arguments["key"]?.text else { throw RufletSecureStorageError.missingKey }
      try storage.remove(key, options: options)
      return .null
    case "clear":
      try storage.clear(options: options)
      return .null
    case "get_availability":
      return .bool(protectedDataAvailable)
    default:
      throw RufletSecureStorageError.unknownMethod(name)
    }
  }

  private func options(for arguments: RufletValue) -> RufletKeychainOptions {
    #if os(iOS)
    let configured = RufletKeychainOptions.parse(control.value("ios_options"))
    return RufletKeychainOptions.parse(arguments["ios"], default: configured)
    #elseif os(macOS)
    let configured = RufletKeychainOptions.parse(control.value("macos_options"))
    return RufletKeychainOptions.parse(arguments["macos"], default: configured)
    #endif
  }

  private var protectedDataAvailable: Bool {
    #if os(iOS)
    UIApplication.shared.isProtectedDataAvailable
    #elseif os(macOS)
    NSApplication.shared.isProtectedDataAvailable
    #endif
  }

  private func registerAvailabilityObservers() {
    #if os(iOS)
    let names: [Notification.Name] = [
      UIApplication.protectedDataDidBecomeAvailableNotification,
      UIApplication.protectedDataWillBecomeUnavailableNotification,
    ]
    availabilityObservers = names.map { name in
      NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        Task { @MainActor in self?.emitAvailability() }
      }
    }
    #elseif os(macOS)
    // macOS exposes the current protected-data state but no corresponding
    // availability-change notification.
    #endif
  }

  private func removeAvailabilityObservers() {
    availabilityObservers.forEach(NotificationCenter.default.removeObserver)
    availabilityObservers.removeAll()
  }

  private func emitAvailability() {
    control.triggerEvent("change", data: .map(["available": .bool(protectedDataAvailable)]))
  }
}

private struct AppleKeychainStorage {
  func set(_ value: String, forKey key: String, options: RufletKeychainOptions) throws {
    guard let data = value.data(using: .utf8) else { throw RufletSecureStorageError.invalidUTF8 }
    var matching = query(key: key, options: options)
    let status = SecItemCopyMatching(matching as CFDictionary, nil)
    if status == errSecSuccess {
      let update: [CFString: Any] = [kSecValueData: data]
      let updateStatus = SecItemUpdate(matching as CFDictionary, update as CFDictionary)
      try check(updateStatus)
      return
    }
    guard status == errSecItemNotFound else { try check(status); return }
    matching.merge(try attributes(options)) { current, _ in current }
    matching[kSecValueData] = data
    try check(SecItemAdd(matching as CFDictionary, nil))
  }

  func get(_ key: String, options: RufletKeychainOptions) throws -> String? {
    var query = query(key: key, options: options)
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    try check(status)
    guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
      throw RufletSecureStorageError.invalidUTF8
    }
    return value
  }

  func getAll(options: RufletKeychainOptions) throws -> [String: String] {
    var query = query(key: nil, options: options)
    query[kSecReturnAttributes] = true
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitAll
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return [:] }
    try check(status)
    let items = result as? [[CFString: Any]] ?? (result as? [CFString: Any]).map { [$0] } ?? []
    return Dictionary(uniqueKeysWithValues: items.compactMap { item in
      guard
        let key = item[kSecAttrAccount] as? String,
        let data = item[kSecValueData] as? Data,
        let value = String(data: data, encoding: .utf8)
      else { return nil }
      return (key, value)
    })
  }

  func contains(_ key: String, options: RufletKeychainOptions) throws -> Bool {
    let status = SecItemCopyMatching(query(key: key, options: options) as CFDictionary, nil)
    if status == errSecItemNotFound { return false }
    try check(status)
    return true
  }

  func remove(_ key: String, options: RufletKeychainOptions) throws {
    let status = SecItemDelete(query(key: key, options: options) as CFDictionary)
    if status != errSecItemNotFound { try check(status) }
  }

  func clear(options: RufletKeychainOptions) throws {
    let status = SecItemDelete(query(key: nil, options: options) as CFDictionary)
    if status != errSecItemNotFound { try check(status) }
  }

  private func query(key: String?, options: RufletKeychainOptions) -> [CFString: Any] {
    var query: [CFString: Any] = [kSecClass: kSecClassGenericPassword]
    if let key { query[kSecAttrAccount] = key }
    if let service = options.service { query[kSecAttrService] = service }
    query[kSecAttrSynchronizable] = options.synchronizable
    #if os(iOS)
    if let accessGroup = options.accessGroup { query[kSecAttrAccessGroup] = accessGroup }
    #elseif os(macOS)
    query[kSecUseDataProtectionKeychain] = options.usesDataProtectionKeychain
    #endif
    return query
  }

  private func attributes(_ options: RufletKeychainOptions) throws -> [CFString: Any] {
    var attributes: [CFString: Any] = [:]
    if let label = options.label { attributes[kSecAttrLabel] = label }
    if let description = options.itemDescription { attributes[kSecAttrDescription] = description }
    if let comment = options.comment { attributes[kSecAttrComment] = comment }
    if let invisible = options.isInvisible { attributes[kSecAttrIsInvisible] = invisible }
    if let negative = options.isNegative { attributes[kSecAttrIsNegative] = negative }
    if let creationDate = options.creationDate { attributes[kSecAttrCreationDate] = creationDate }
    if let modificationDate = options.modificationDate { attributes[kSecAttrModificationDate] = modificationDate }
    if options.accessControlFlags.isEmpty {
      attributes[kSecAttrAccessible] = options.accessibility.securityValue
    } else {
      let flags = options.accessControlFlags.reduce(into: SecAccessControlCreateFlags()) {
        $0.insert($1.securityValue)
      }
      var error: Unmanaged<CFError>?
      guard let access = SecAccessControlCreateWithFlags(
        nil, options.accessibility.securityValue, flags, &error)
      else {
        let message = error?.takeRetainedValue().localizedDescription ?? "Unknown access-control error"
        throw RufletSecureStorageError.accessControl(message)
      }
      attributes[kSecAttrAccessControl] = access
    }
    return attributes
  }

  private func check(_ status: OSStatus) throws {
    guard status == errSecSuccess else {
      let message = SecCopyErrorMessageString(status, nil) as String? ?? "Security error (status)"
      throw RufletSecureStorageError.security(status, message)
    }
  }
}
