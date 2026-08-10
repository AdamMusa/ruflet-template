import Foundation
import RufletProtocol

#if canImport(UIKit)
  import UIKit
#endif
#if canImport(AppKit)
  import AppKit
#endif

/// Page-level methods, invoked by Ruby against control id 1.
///
/// `Page#show_drawer` and friends are `invoke` calls rather than patches, so
/// the engine answers them by writing an `_open` flag onto the drawer control —
/// which is what `DrawerPresenter` watches — and replying so the waiting Ruby
/// thread is released.
@MainActor
public final class PageService: RufletService {
  public static let wireType = "Page"

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    switch call.name {
    case "show_drawer", "close_drawer", "show_end_drawer", "close_end_drawer":
      let key = call.name.contains("end") ? "end_drawer" : "drawer"
      guard let drawerID = node?.controlID(forKey: key) else {
        return completion(.failure(RufletServiceError.unavailable("No \(key) is defined")))
      }
      context.store.setLocalProperty(
        drawerID, key: "_open", value: .bool(call.name.hasPrefix("show")))
      completion(.success(.null))

    case "scroll_to":
      // Scroll position is owned by SwiftUI's own scroll views; there is no way
      // to drive one imperatively without a ScrollViewReader per control, which
      // the renderer does not install. Report it rather than pretend.
      completion(
        .failure(
          RufletServiceError.unsupportedMethod(type: "Page", method: "scroll_to")))

    default:
      completion(
        .failure(RufletServiceError.unsupportedMethod(type: "Page", method: call.name)))
    }
  }
}

/// `Clipboard` — the system pasteboard.
@MainActor
public final class ClipboardService: RufletService {
  public static let wireType = "Clipboard"

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    switch call.name {
    case "set":
      let text = call.argument("data")?.stringValue ?? ""
      #if canImport(UIKit)
        UIPasteboard.general.string = text
      #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
      #endif
      completion(.success(.null))

    case "get":
      #if canImport(UIKit)
        completion(.success(.string(UIPasteboard.general.string ?? "")))
      #elseif canImport(AppKit)
        completion(.success(.string(NSPasteboard.general.string(forType: .string) ?? "")))
      #else
        completion(.success(.null))
      #endif

    case "set_files":
      let paths = (call.argument("files")?.arrayValue ?? []).compactMap(\.stringValue)
      #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(paths.map { URL(fileURLWithPath: $0) as NSURL })
        completion(.success(.null))
      #else
        completion(
          .failure(RufletServiceError.unavailable("File pasteboards are macOS-only")))
      #endif

    case "get_files":
      #if canImport(AppKit)
        let urls =
          NSPasteboard.general.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []
        completion(.success(.array(urls.map { .string($0.path) })))
      #else
        completion(.success(.array([])))
      #endif

    case "set_image":
      #if canImport(UIKit)
        if case .binary(let bytes)? = call.argument("data"),
          let image = UIImage(data: Data(bytes))
        {
          UIPasteboard.general.image = image
          return completion(.success(.null))
        }
      #elseif canImport(AppKit)
        if case .binary(let bytes)? = call.argument("data"),
          let image = NSImage(data: Data(bytes))
        {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.writeObjects([image])
          return completion(.success(.null))
        }
      #endif
      completion(.failure(RufletServiceError.invalidArguments("data must be image bytes")))

    case "get_image":
      #if canImport(UIKit)
        if let data = UIPasteboard.general.image?.pngData() {
          return completion(.success(.binary([UInt8](data))))
        }
      #elseif canImport(AppKit)
        if let data = NSPasteboard.general.data(forType: .tiff) {
          return completion(.success(.binary([UInt8](data))))
        }
      #endif
      completion(.success(.null))

    default:
      completion(
        .failure(RufletServiceError.unsupportedMethod(type: "Clipboard", method: call.name)))
    }
  }
}

/// `SharedPreferences` — `UserDefaults`, namespaced so a Ruflet app cannot
/// collide with the host app's own keys.
@MainActor
public final class SharedPreferencesService: RufletService {
  public static let wireType = "SharedPreferences"

  /// The prefix Flet's shared_preferences plugin uses on Apple platforms, kept
  /// so a value written by the Flutter engine is still readable here.
  private let prefix = "flutter."
  private let defaults = UserDefaults.standard

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    switch call.name {
    case "set":
      guard let key = call.argument("key")?.stringValue else {
        return completion(.failure(RufletServiceError.invalidArguments("key is required")))
      }
      defaults.set(plainValue(call.argument("value")), forKey: prefix + key)
      completion(.success(.bool(true)))

    case "get":
      guard let key = call.argument("key")?.stringValue else {
        return completion(.failure(RufletServiceError.invalidArguments("key is required")))
      }
      completion(.success(rufletValue(defaults.object(forKey: prefix + key))))

    case "contains_key":
      guard let key = call.argument("key")?.stringValue else {
        return completion(.failure(RufletServiceError.invalidArguments("key is required")))
      }
      completion(.success(.bool(defaults.object(forKey: prefix + key) != nil)))

    case "get_keys":
      let filter = (call.argument("key_prefix")?.stringValue ?? "")
      let keys = defaults.dictionaryRepresentation().keys
        .filter { $0.hasPrefix(prefix + filter) }
        .map { String($0.dropFirst(prefix.count)) }
      completion(.success(.array(keys.sorted().map(RufletValue.string))))

    case "remove":
      guard let key = call.argument("key")?.stringValue else {
        return completion(.failure(RufletServiceError.invalidArguments("key is required")))
      }
      defaults.removeObject(forKey: prefix + key)
      completion(.success(.bool(true)))

    case "clear":
      for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
        defaults.removeObject(forKey: key)
      }
      completion(.success(.bool(true)))

    default:
      completion(
        .failure(
          RufletServiceError.unsupportedMethod(type: "SharedPreferences", method: call.name)))
    }
  }

  private func plainValue(_ value: RufletValue?) -> Any? {
    switch value {
    case .string(let text): return text
    case .int(let number): return number
    case .double(let number): return number
    case .bool(let flag): return flag
    case .array(let items): return items.compactMap { plainValue($0) }
    case .map(let entries): return entries.compactMapValues { plainValue($0) }
    default: return nil
    }
  }

  private func rufletValue(_ value: Any?) -> RufletValue {
    switch value {
    case let text as String: return .string(text)
    case let flag as Bool: return .bool(flag)
    case let number as Int: return .int(Int64(number))
    case let number as Double: return .double(number)
    case let items as [Any]: return .array(items.map { rufletValue($0) })
    case let entries as [String: Any]: return .map(entries.mapValues { rufletValue($0) })
    default: return .null
    }
  }
}

/// `SecureStorage` — the Keychain.
@MainActor
public final class SecureStorageService: RufletService {
  public static let wireType = "SecureStorage"

  private let service = Bundle.main.bundleIdentifier ?? "com.izeesoft.ruflet"

  public init() {}

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
        // errSecItemNotFound simply means the keychain holds nothing for this
        // service, which is an empty map rather than a failure.
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
      // The keychain is always present on Apple platforms; the method exists
      // because Android's encrypted storage is not.
      completion(.success(.bool(true)))

    default:
      completion(
        .failure(
          RufletServiceError.unsupportedMethod(type: "SecureStorage", method: call.name)))
    }
  }

  private func query(key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key
    ]
  }
}

/// `StoragePaths` — the standard directories, answered with the same names
/// Flet's path_provider service uses.
@MainActor
public final class StoragePathsService: RufletService {
  public static let wireType = "StoragePaths"

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    func path(_ directory: FileManager.SearchPathDirectory) -> RufletValue {
      let urls = FileManager.default.urls(for: directory, in: .userDomainMask)
      return urls.first.map { RufletValue.string($0.path) } ?? .null
    }

    switch call.name {
    case "get_application_cache_directory":
      completion(.success(path(.cachesDirectory)))
    case "get_application_documents_directory":
      completion(.success(path(.documentDirectory)))
    case "get_application_support_directory":
      completion(.success(path(.applicationSupportDirectory)))
    case "get_downloads_directory":
      completion(.success(path(.downloadsDirectory)))
    case "get_library_directory":
      completion(.success(path(.libraryDirectory)))
    case "get_temporary_directory":
      completion(.success(.string(NSTemporaryDirectory())))
    case "get_external_cache_directories", "get_external_storage_directories":
      // Android-only in Flet; an empty list is the honest answer here.
      completion(.success(.array([])))
    case "get_external_storage_directory":
      completion(.success(.null))
    case "get_console_log_filename":
      completion(.success(.null))
    default:
      completion(
        .failure(
          RufletServiceError.unsupportedMethod(type: "StoragePaths", method: call.name)))
    }
  }
}

/// `UrlLauncher` — opens links in the browser or an in-app view.
@MainActor
public final class UrlLauncherService: RufletService {
  public static let wireType = "UrlLauncher"

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    switch call.name {
    case "launch_url", "open_window":
      guard let raw = call.argument("url")?.stringValue, let url = URL(string: raw) else {
        return completion(.failure(RufletServiceError.invalidArguments("url is required")))
      }
      #if canImport(UIKit)
        UIApplication.shared.open(url, options: [:]) { opened in
          completion(.success(.bool(opened)))
        }
      #elseif canImport(AppKit)
        completion(.success(.bool(NSWorkspace.shared.open(url))))
      #else
        completion(.failure(RufletServiceError.unavailable("No URL handler on this platform")))
      #endif

    case "can_launch_url":
      guard let raw = call.argument("url")?.stringValue, let url = URL(string: raw) else {
        return completion(.success(.bool(false)))
      }
      #if canImport(UIKit)
        completion(.success(.bool(UIApplication.shared.canOpenURL(url))))
      #elseif canImport(AppKit)
        completion(.success(.bool(NSWorkspace.shared.urlForApplication(toOpen: url) != nil)))
      #else
        completion(.success(.bool(false)))
      #endif

    case "close_in_app_web_view":
      completion(.success(.null))

    case "supports_launch_mode":
      // Only the external browser is offered, so that is the only mode.
      let mode = call.argument("mode")?.stringValue?.lowercased() ?? ""
      completion(.success(.bool(mode.isEmpty || mode.contains("external"))))

    case "supports_close_for_launch_mode":
      completion(.success(.bool(false)))

    default:
      completion(
        .failure(
          RufletServiceError.unsupportedMethod(type: "UrlLauncher", method: call.name)))
    }
  }
}

/// `HapticFeedback` — the taptic engine on iOS; a no-op elsewhere.
@MainActor
public final class HapticFeedbackService: RufletService {
  public static let wireType = "HapticFeedback"

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    #if os(iOS)
      switch call.name {
      case "light_impact":
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      case "medium_impact":
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      case "heavy_impact", "vibrate":
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
      case "selection_click":
        UISelectionFeedbackGenerator().selectionChanged()
      default:
        return completion(
          .failure(
            RufletServiceError.unsupportedMethod(type: "HapticFeedback", method: call.name)))
      }
      completion(.success(.null))
    #else
      // A Mac has no haptics; succeeding quietly is better than failing a call
      // an application makes for polish rather than for behaviour.
      completion(.success(.null))
    #endif
  }
}

/// `Wakelock` — keeps the screen awake.
@MainActor
public final class WakelockService: RufletService {
  public static let wireType = "Wakelock"

  #if canImport(AppKit)
    private var assertion: Any?
  #endif

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    switch call.name {
    case "enable", "disable":
      let enable = call.name == "enable"
      #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = enable
      #elseif canImport(AppKit)
        if enable {
          assertion = ProcessInfo.processInfo.beginActivity(
            options: [.idleDisplaySleepDisabled], reason: "Ruflet wakelock")
        } else if let token = assertion as? NSObjectProtocol {
          ProcessInfo.processInfo.endActivity(token)
          assertion = nil
        }
      #endif
      completion(.success(.null))

    case "is_enabled":
      #if os(iOS)
        completion(.success(.bool(UIApplication.shared.isIdleTimerDisabled)))
      #elseif canImport(AppKit)
        completion(.success(.bool(assertion != nil)))
      #else
        completion(.success(.bool(false)))
      #endif

    default:
      completion(
        .failure(RufletServiceError.unsupportedMethod(type: "Wakelock", method: call.name)))
    }
  }
}

/// `SemanticsService` — VoiceOver announcements.
@MainActor
public final class SemanticsAnnouncementService: RufletService {
  public static let wireType = "SemanticsService"

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    if call.name == "get_accessibility_features" {
      return completion(.success(Self.accessibilityFeatures()))
    }

    guard call.name == "announce_message" || call.name == "announce_tooltip" else {
      return completion(
        .failure(
          RufletServiceError.unsupportedMethod(type: "SemanticsService", method: call.name)))
    }
    let message = call.argument("message")?.stringValue ?? ""
    #if canImport(UIKit)
      UIAccessibility.post(notification: .announcement, argument: message)
    #elseif canImport(AppKit)
      NSAccessibility.post(
        element: NSApp as Any,
        notification: .announcementRequested,
        userInfo: [.announcement: message])
    #endif
    completion(.success(.null))
  }

  /// The keys Flutter's `AccessibilityFeatures` exposes, filled in from the
  /// platform's own settings so a Ruby app can branch on them the same way.
  private static func accessibilityFeatures() -> RufletValue {
    #if canImport(UIKit)
      return .map([
        "accessible_navigation": .bool(UIAccessibility.isVoiceOverRunning),
        "bold_text": .bool(UIAccessibility.isBoldTextEnabled),
        "disable_animations": .bool(UIAccessibility.isReduceMotionEnabled),
        "high_contrast": .bool(UIAccessibility.isDarkerSystemColorsEnabled),
        "invert_colors": .bool(UIAccessibility.isInvertColorsEnabled),
        "reduce_motion": .bool(UIAccessibility.isReduceMotionEnabled)
      ])
    #elseif canImport(AppKit)
      let defaults = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
      return .map([
        "accessible_navigation": .bool(NSWorkspace.shared.isVoiceOverEnabled),
        "bold_text": .bool(false),
        "disable_animations": .bool(defaults),
        "high_contrast": .bool(NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast),
        "invert_colors": .bool(NSWorkspace.shared.accessibilityDisplayShouldInvertColors),
        "reduce_motion": .bool(defaults)
      ])
    #else
      return .map([:])
    #endif
  }
}
