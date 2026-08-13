import Foundation
import RufletProtocol
import Security

public enum RufletKeychainAccessibility: String, CaseIterable, Sendable {
  case passcode
  case unlocked
  case unlockedThisDevice = "unlocked_this_device"
  case firstUnlock = "first_unlock"
  case firstUnlockThisDevice = "first_unlock_this_device"

  static func parse(_ value: String?) -> Self {
    guard let value else { return .unlocked }
    return allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame } ?? .unlocked
  }

  var securityValue: CFString {
    switch self {
    case .passcode: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
    case .unlocked: kSecAttrAccessibleWhenUnlocked
    case .unlockedThisDevice: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    case .firstUnlock: kSecAttrAccessibleAfterFirstUnlock
    case .firstUnlockThisDevice: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    }
  }
}

public enum RufletAccessControlFlag: String, CaseIterable, Sendable {
  case userPresence
  case biometryAny
  case biometryCurrentSet
  case devicePasscode
  case or
  case and
  case privateKeyUsage
  case applicationPassword

  var securityValue: SecAccessControlCreateFlags {
    switch self {
    case .userPresence: .userPresence
    case .biometryAny: .biometryAny
    case .biometryCurrentSet: .biometryCurrentSet
    case .devicePasscode: .devicePasscode
    case .or: .or
    case .and: .and
    case .privateKeyUsage: .privateKeyUsage
    case .applicationPassword: .applicationPassword
    }
  }
}

public struct RufletKeychainOptions: Equatable, Sendable {
  public var service: String?
  public var accessGroup: String?
  public var accessibility: RufletKeychainAccessibility
  public var synchronizable: Bool
  public var label: String?
  public var itemDescription: String?
  public var comment: String?
  public var isInvisible: Bool?
  public var isNegative: Bool?
  public var creationDate: Date?
  public var modificationDate: Date?
  public var resultLimit: Int?
  public var returnsPersistentReference: Bool
  public var authenticationUIBehavior: String?
  public var accessControlFlags: [RufletAccessControlFlag]
  public var usesDataProtectionKeychain: Bool

  public init(
    service: String? = nil,
    accessGroup: String? = nil,
    accessibility: RufletKeychainAccessibility = .unlocked,
    synchronizable: Bool = false,
    label: String? = nil,
    itemDescription: String? = nil,
    comment: String? = nil,
    isInvisible: Bool? = nil,
    isNegative: Bool? = nil,
    creationDate: Date? = nil,
    modificationDate: Date? = nil,
    resultLimit: Int? = nil,
    returnsPersistentReference: Bool = false,
    authenticationUIBehavior: String? = nil,
    accessControlFlags: [RufletAccessControlFlag] = [],
    usesDataProtectionKeychain: Bool = true
  ) {
    self.service = service
    self.accessGroup = accessGroup
    self.accessibility = accessibility
    self.synchronizable = synchronizable
    self.label = label
    self.itemDescription = itemDescription
    self.comment = comment
    self.isInvisible = isInvisible
    self.isNegative = isNegative
    self.creationDate = creationDate
    self.modificationDate = modificationDate
    self.resultLimit = resultLimit
    self.returnsPersistentReference = returnsPersistentReference
    self.authenticationUIBehavior = authenticationUIBehavior
    self.accessControlFlags = accessControlFlags
    self.usesDataProtectionKeychain = usesDataProtectionKeychain
  }

  public static func parse(_ value: RufletValue?, default defaultValue: Self = Self()) -> Self {
    guard let map = value?.map else { return defaultValue }
    let date = ISO8601DateFormatter()
    return Self(
      service: map["account_name"]?.text ?? defaultValue.service,
      accessGroup: map["group_id"]?.text ?? defaultValue.accessGroup,
      accessibility: .parse(map["accessibility"]?.text ?? defaultValue.accessibility.rawValue),
      synchronizable: map["synchronizable"]?.bool ?? defaultValue.synchronizable,
      label: map["label"]?.text ?? defaultValue.label,
      itemDescription: map["description"]?.text ?? defaultValue.itemDescription,
      comment: map["comment"]?.text ?? defaultValue.comment,
      isInvisible: map["is_invisible"]?.bool ?? defaultValue.isInvisible,
      isNegative: map["is_negative"]?.bool ?? defaultValue.isNegative,
      creationDate: map["creation_date"]?.text.flatMap(date.date) ?? defaultValue.creationDate,
      modificationDate: map["last_modified_date"]?.text.flatMap(date.date) ?? defaultValue.modificationDate,
      resultLimit: map["result_limit"]?.integer ?? defaultValue.resultLimit,
      returnsPersistentReference: map["is_persistent"]?.bool ?? defaultValue.returnsPersistentReference,
      authenticationUIBehavior: map["auth_ui_behavior"]?.text ?? defaultValue.authenticationUIBehavior,
      accessControlFlags: map["access_control_flags"]?.array?.compactMap {
        guard let value = $0.text else { return nil }
        return RufletAccessControlFlag.allCases.first {
          $0.rawValue.caseInsensitiveCompare(value) == .orderedSame
        }
      } ?? defaultValue.accessControlFlags,
      usesDataProtectionKeychain: map["uses_data_protection_keychain"]?.bool
        ?? defaultValue.usesDataProtectionKeychain)
  }
}

public enum RufletSecureStorageError: Error, Equatable, Sendable {
  case missingKey
  case missingValue
  case invalidUTF8
  case accessControl(String)
  case security(OSStatus, String)
  case unknownMethod(String)
}
