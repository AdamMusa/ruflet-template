import 'package:ruflet/ruflet.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

IOSOptions? parseIosOptions(dynamic value, [IOSOptions? defaultValue]) {
  if (value == null) return defaultValue;
  return IOSOptions(
    accountName: value["account_name"],
    groupId: value["group_id"],
    accessibility: parseKeychainAccessibility(value["accessibility"], KeychainAccessibility.unlocked),
    synchronizable: parseBool(value["synchronizable"], false)!,
    label: value["label"],
    description: value["description"],
    comment: value["comment"],
    isInvisible: parseBool(value["is_invisible"]),
    isNegative: parseBool(value["is_negative"]),
    creationDate: parseKeychainDate(value["creation_date"]),
    lastModifiedDate: parseKeychainDate(value["last_modified_date"]),
    resultLimit: parseInt(value["result_limit"]),
    shouldReturnPersistentReference: parseBool(value["is_persistent"], false)!,
    authenticationUIBehavior: value["auth_ui_behavior"],
    accessControlFlags: parseAccessControlFlags(value["access_control_flags"], const [])!,
  );
}

MacOsOptions? parseMacOptions(dynamic value, [MacOsOptions? defaultValue]) {
  if (value == null) return defaultValue;
  return MacOsOptions(
    accountName: value["account_name"],
    groupId: value["group_id"],
    accessibility: parseKeychainAccessibility(value["accessibility"], KeychainAccessibility.unlocked),
    synchronizable: parseBool(value["synchronizable"], false)!,
    label: value["label"],
    description: value["description"],
    comment: value["comment"],
    isInvisible: parseBool(value["is_invisible"]),
    isNegative: parseBool(value["is_negative"]),
    creationDate: parseKeychainDate(value["creation_date"]),
    lastModifiedDate: parseKeychainDate(value["last_modified_date"]),
    resultLimit: parseInt(value["result_limit"]),
    shouldReturnPersistentReference: parseBool(value["is_persistent"]),
    authenticationUIBehavior: value["auth_ui_behavior"],
    accessControlFlags: parseAccessControlFlags(value["access_control_flags"], const [])!,
    usesDataProtectionKeychain: parseBool(value["uses_data_protection_keychain"], true)!
  );
}

AndroidOptions? parseAndroidOptions(dynamic value, [AndroidOptions? defaultValue]) {
  if (value == null) return defaultValue;
  return AndroidOptions(
    resetOnError: parseBool(value['reset_on_error'], true)!,
    migrateOnAlgorithmChange: parseBool(value['migrate_on_algorithm_change'], true)!,
    enforceBiometrics: parseBool(value['enforce_biometrics'], false)!,
    keyCipherAlgorithm: parseKeyCipherAlgorithm(
      value['key_cipher_algorithm'],
      KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding
    )!,
    storageCipherAlgorithm: parseStorageCipherAlgorithm(
      value['storage_cipher_algorithm'],
      StorageCipherAlgorithm.AES_GCM_NoPadding
    )!,
    sharedPreferencesName: value['shared_preferences_name'],
    preferencesKeyPrefix: value['preferences_key_prefix'],
    biometricPromptTitle: value['biometric_prompt_title'],
    biometricPromptSubtitle: value['biometric_prompt_subtitle'],
  );
}

WindowsOptions? parseWindowsOptions(dynamic value, [WindowsOptions? defaultValue]) {
  if (value == null) return defaultValue;
  return WindowsOptions(
    useBackwardCompatibility: parseBool(value["use_backward_compatibility"], false)!,
  );
}

WebOptions? parseWebOptions(dynamic value, [WebOptions? defaultValue]) {
  if (value == null) return defaultValue;
  return WebOptions(
    dbName: value["db_name"] ?? "FlutterEncryptedStorage",
    publicKey: value["public_key"] ?? "FlutterSecureStorage",
    wrapKey: value["wrap_key"] ?? "",
    wrapKeyIv: value["wrap_key_iv"] ?? "",
    useSessionStorage: parseBool(value["use_session_storage"], false)!,
  );
}

/// A keychain item date. Ruby sends a `Time` as its `to_s`
/// (`2024-05-01 10:00:00 -0500`, or `2024-05-01 10:00:00 UTC` for a UTC
/// Time) or an ISO-8601 string, and a `Ruflet::Protocol.date_time` value
/// arrives already decoded.
DateTime? parseKeychainDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is! String) return null;
  // DateTime.tryParse reads a "Z" or an offset, not Ruby's " UTC".
  return DateTime.tryParse(value.endsWith(' UTC')
      ? '${value.substring(0, value.length - 4)}Z'
      : value);
}

KeychainAccessibility? parseKeychainAccessibility(String? value, [KeychainAccessibility? defaultValue]) {
  if (value == null) return defaultValue;
  return parseEnum(KeychainAccessibility.values, value, defaultValue);
}

KeyCipherAlgorithm? parseKeyCipherAlgorithm(String? value, [KeyCipherAlgorithm? defaultValue]) {
  if (value == null) return defaultValue;
  return parseEnum(KeyCipherAlgorithm.values, value, defaultValue);
}

StorageCipherAlgorithm? parseStorageCipherAlgorithm(String? value, [StorageCipherAlgorithm? defaultValue]) {
  if (value == null) return defaultValue;
  return parseEnum(StorageCipherAlgorithm.values, value, defaultValue);
}

AccessControlFlag? parseAccessControlFlag(String? value, [AccessControlFlag? defaultValue]) {
  if (value == null) return defaultValue;
  return parseEnum(AccessControlFlag.values, value, defaultValue);
}

List<AccessControlFlag>? parseAccessControlFlags(List<dynamic>? value, [List<AccessControlFlag>? defaultValue,]) {
  if (value == null) return defaultValue;

  return value
      .whereType<String>()
      .map((e) => parseAccessControlFlag(e)).nonNulls
      .whereType<AccessControlFlag>()
      .toList();
}
