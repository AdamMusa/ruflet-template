import Foundation
import RufletProtocol

#if canImport(UIKit)
  import UIKit
#endif
#if canImport(GameController)
  import GameController
#endif
#if canImport(AppKit)
  import AppKit
#endif
#if canImport(AudioToolbox)
  import AudioToolbox
#endif

/// Small, source-derived value conversions shared by the native service
/// adapters. Keeping them explicit prevents Apple framework convenience
/// values (for example an empty pasteboard string) from changing Flet's wire
/// result shape.
public enum FletCoreServiceSemantics {
  public static func nullableString(_ value: String?) -> RufletValue {
    value.map(RufletValue.string) ?? .null
  }

  public static func sharedPreferenceString(_ value: RufletValue?) throws -> String {
    guard case .string(let value)? = value else {
      throw RufletServiceError.invalidArguments("value must be a string")
    }
    return value
  }

  public static func consoleLogPath(fileManager: FileManager = .default) -> String? {
    fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
      .appendingPathComponent("console.log").path
  }

  /// Mirrors Flet's `convertToUint8List`: MessagePack binary and arrays made
  /// exclusively of byte-sized integers are accepted; every other shape is
  /// rejected instead of being stringified by the generic value accessors.
  public static func imageBytes(_ value: RufletValue?) -> [UInt8]? {
    switch value {
    case .binary(let bytes):
      return bytes
    case .array(let values):
      let integers = values.compactMap { value -> Int? in
        guard case .int(let integer) = value else { return nil }
        return Int(integer)
      }
      guard integers.count == values.count,
        integers.allSatisfy({ (0...255).contains($0) })
      else { return nil }
      return integers.map(UInt8.init)
    default:
      return nil
    }
  }
}

/// Page-level methods, invoked by Ruby against control id 1.
///
/// `Page#show_drawer` and friends are `invoke` calls rather than patches, so
/// the engine answers them by writing an `_open` flag onto the drawer control —
/// which is what `DrawerPresenter` watches — and replying so the waiting Ruby
/// thread is released.
@MainActor
public final class PageService: RufletStreamingService {
  public static let wireType = "Page"

  private var targetID: Int?
  private var context: RufletServiceContext?
  private var localeObserver: NSObjectProtocol?
  #if canImport(AppKit)
    private var keyboardMonitor: Any?
  #endif
  #if canImport(GameController) && !os(macOS)
    private var keyboardConnectObserver: NSObjectProtocol?
    private var keyboardDisconnectObserver: NSObjectProtocol?
  #endif

  public init() {}

  public func activate(node: ControlNode, context: RufletServiceContext) {
    targetID = node.id
    self.context = context

    if node.handlesEvent("locale_change"), localeObserver == nil {
      localeObserver = NotificationCenter.default.addObserver(
        forName: NSLocale.currentLocaleDidChangeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.reportLocales() }
      }
    }

    #if canImport(AppKit)
      if node.handlesEvent("keyboard_event"), keyboardMonitor == nil {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
          Task { @MainActor in self?.reportKey(event) }
          return event
        }
      }
    #endif
    #if canImport(GameController) && !os(macOS)
      if node.handlesEvent("keyboard_event"), keyboardConnectObserver == nil {
        keyboardConnectObserver = NotificationCenter.default.addObserver(
          forName: .GCKeyboardDidConnect,
          object: nil,
          queue: .main
        ) { [weak self] notification in
          Task { @MainActor in
            self?.bindKeyboard(notification.object as? GCKeyboard)
          }
        }
        keyboardDisconnectObserver = NotificationCenter.default.addObserver(
          forName: .GCKeyboardDidDisconnect,
          object: nil,
          queue: .main
        ) { [weak self] _ in
          Task { @MainActor in self?.bindKeyboard(GCKeyboard.coalesced) }
        }
        bindKeyboard(GCKeyboard.coalesced)
      }
    #endif
  }

  deinit {
    if let localeObserver { NotificationCenter.default.removeObserver(localeObserver) }
    #if canImport(AppKit)
      if let keyboardMonitor { NSEvent.removeMonitor(keyboardMonitor) }
    #endif
    #if canImport(GameController) && !os(macOS)
      if let keyboardConnectObserver {
        NotificationCenter.default.removeObserver(keyboardConnectObserver)
      }
      if let keyboardDisconnectObserver {
        NotificationCenter.default.removeObserver(keyboardDisconnectObserver)
      }
      GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = nil
    #endif
  }

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

    case "push_route":
      guard let route = call.argument("route")?.stringValue else {
        return completion(.failure(RufletServiceError.invalidArguments("route is required")))
      }
      guard let node else {
        return completion(.failure(RufletServiceError.unknownTarget(call.controlID)))
      }
      context.store.setLocalProperty(node.id, key: "route", value: .string(route))
      completion(.success(.null))

    case "get_device_info":
      var info: [String: RufletValue] = [
        "os": .string(Self.platformName),
        "os_version": .string(ProcessInfo.processInfo.operatingSystemVersionString),
        "locale": .string(Locale.current.identifier)
      ]
      #if canImport(UIKit)
        info["model"] = .string(UIDevice.current.model)
        info["device_name"] = .string(UIDevice.current.name)
      #elseif canImport(AppKit)
        info["model"] = .string("Mac")
        info["device_name"] = .string(Host.current().localizedName ?? "Mac")
      #endif
      completion(.success(.map(info)))

    case "set_allowed_device_orientations":
      #if os(iOS)
        let values = call.argument("orientations")?.arrayValue?.compactMap(\.stringValue) ?? []
        let mask = Self.orientationMask(values)
        if #available(iOS 16.0, *) {
          for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
          }
        }
        completion(.success(.null))
      #else
        completion(.failure(RufletServiceError.platformUnsupported(
          type: node?.type ?? "Page", method: call.name, platform: Self.platformName)))
      #endif

    case "take_screenshot":
      completion(.failure(RufletServiceError.platformUnsupported(
        type: node?.type ?? "Page", method: call.name, platform: Self.platformName)))

    case "confirm_pop":
      guard let node else {
        return completion(.failure(RufletServiceError.unknownTarget(call.controlID)))
      }
      let shouldPop = call.argument("should_pop")?.boolValue ?? false
      if shouldPop {
        // Flet completes the pending PopScope decision, then its navigator
        // reports `view_pop` on Page with the route it removed. The Apple host
        // has a server-owned view stack rather than a local Navigator, so the
        // equivalent completion is the same Page event; Ruby then supplies the
        // shorter authoritative `views` list.
        let route = node.string("route") ?? String(node.id)
        context.emitEvent(
          RufletWireID.page, "view_pop", .map(["route": .string(route)]))
      }
      completion(.success(.null))

    case "scroll_to":
      guard let node else {
        return completion(.failure(RufletServiceError.unknownTarget(call.controlID)))
      }
      // Flet's Page method drives the top View's ScrollableControl. Keep the
      // command on Page so the mounted Apple host (which owns UIScrollView /
      // NSScrollView) can execute it, including repeated identical calls.
      guard let viewID = node.controlIDs(forKey: "views").last else {
        return completion(.failure(RufletServiceError.unavailable("Page has no active View")))
      }
      var command = call.args.mapValue ?? [:]
      command["target_id"] = .int(Int64(viewID))
      command["token"] = .string(UUID().uuidString)
      context.store.setLocalProperty(node.id, key: "_scroll_command", value: .map(command))
      completion(.success(.null))

    default:
      completion(
        .failure(RufletServiceError.unsupportedMethod(type: "Page", method: call.name)))
    }
  }

  private static var platformName: String {
    #if os(iOS)
      return "iOS"
    #elseif os(macOS)
      return "macOS"
    #else
      return "this Apple platform"
    #endif
  }

  private func reportLocales() {
    guard let targetID, let context else { return }
    let locales = Locale.preferredLanguages.map { identifier -> RufletValue in
      let locale = Locale(identifier: identifier)
      // Locale.language and Locale.region arrived in iOS 16, and this package
      // ships to iOS 15, so the older accessors carry the earlier releases.
      if #available(iOS 16.0, macOS 13.0, *) {
        return .map([
          "language_code": .string(locale.language.languageCode?.identifier ?? identifier),
          "country_code": locale.region.map { .string($0.identifier) } ?? .null,
          "script_code": locale.language.script.map { .string($0.identifier) } ?? .null
        ])
      } else {
        return .map([
          "language_code": .string(locale.languageCode ?? identifier),
          "country_code": locale.regionCode.map { RufletValue.string($0) } ?? .null,
          "script_code": locale.scriptCode.map { RufletValue.string($0) } ?? .null
        ])
      }
    }
    context.emitEvent(targetID, "locale_change", .map(["locales": .array(locales)]))
  }

  #if canImport(AppKit)
    private func reportKey(_ event: NSEvent) {
      guard let targetID, let context else { return }
      let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      context.emitEvent(targetID, "keyboard_event", .map([
        "key": .string(event.charactersIgnoringModifiers ?? ""),
        "shift": .bool(flags.contains(.shift)),
        "ctrl": .bool(flags.contains(.control)),
        "alt": .bool(flags.contains(.option)),
        "meta": .bool(flags.contains(.command))
      ]))
    }
  #endif

  #if canImport(GameController) && !os(macOS)
    /// `HardwareKeyboard` is process-global in Flutter. GameController exposes
    /// the same hardware-keyboard stream on Apple platforms without installing
    /// a hidden text field or stealing focus from a rendered TextField.
    private func bindKeyboard(_ keyboard: GCKeyboard?) {
      keyboard?.keyboardInput?.keyChangedHandler = { [weak self] input, key, code, pressed in
        guard pressed else { return }
        Task { @MainActor in self?.reportKey(input: input, key: key, code: code) }
      }
    }

    private func reportKey(input: GCKeyboardInput, key: GCDeviceButtonInput, code: GCKeyCode) {
      guard let targetID, let context else { return }
      let shift = Self.pressed(input, .leftShift) || Self.pressed(input, .rightShift)
      let ctrl = Self.pressed(input, .leftControl) || Self.pressed(input, .rightControl)
      let alt = Self.pressed(input, .leftAlt) || Self.pressed(input, .rightAlt)
      let meta = Self.pressed(input, .leftGUI) || Self.pressed(input, .rightGUI)
      context.emitEvent(targetID, "keyboard_event", .map([
        "key": .string(Self.keyName(code, shifted: shift) ?? key.localizedName ?? ""),
        "shift": .bool(shift),
        "ctrl": .bool(ctrl),
        "alt": .bool(alt),
        "meta": .bool(meta)
      ]))
    }

    private static func pressed(_ input: GCKeyboardInput, _ code: GCKeyCode) -> Bool {
      input.button(forKeyCode: code)?.isPressed == true
    }

    private static func keyName(_ code: GCKeyCode, shifted: Bool) -> String? {
      let letters: [(GCKeyCode, Character)] = [
        (.keyA, "a"), (.keyB, "b"), (.keyC, "c"), (.keyD, "d"), (.keyE, "e"),
        (.keyF, "f"), (.keyG, "g"), (.keyH, "h"), (.keyI, "i"), (.keyJ, "j"),
        (.keyK, "k"), (.keyL, "l"), (.keyM, "m"), (.keyN, "n"), (.keyO, "o"),
        (.keyP, "p"), (.keyQ, "q"), (.keyR, "r"), (.keyS, "s"), (.keyT, "t"),
        (.keyU, "u"), (.keyV, "v"), (.keyW, "w"), (.keyX, "x"), (.keyY, "y"),
        (.keyZ, "z")
      ]
      if let character = letters.first(where: { $0.0 == code })?.1 {
        let value = String(character)
        return shifted ? value.uppercased() : value
      }
      let printable: [GCKeyCode: (String, String)] = [
        .one: ("1", "!"), .two: ("2", "@"), .three: ("3", "#"),
        .four: ("4", "$"), .five: ("5", "%"), .six: ("6", "^"),
        .seven: ("7", "&"), .eight: ("8", "*"), .nine: ("9", "("),
        .zero: ("0", ")"), .spacebar: (" ", " "), .hyphen: ("-", "_"),
        .equalSign: ("=", "+"), .openBracket: ("[", "{"),
        .closeBracket: ("]", "}"), .backslash: ("\\", "|"),
        .semicolon: (";", ":"), .quote: ("'", "\""),
        .graveAccentAndTilde: ("`", "~"), .comma: (",", "<"),
        .period: (".", ">"), .slash: ("/", "?")
      ]
      if let pair = printable[code] { return shifted ? pair.1 : pair.0 }
      let named: [GCKeyCode: String] = [
        .returnOrEnter: "Enter", .escape: "Escape", .deleteOrBackspace: "Backspace",
        .tab: "Tab", .deleteForward: "Delete", .home: "Home", .end: "End",
        .pageUp: "Page Up", .pageDown: "Page Down", .leftArrow: "Arrow Left",
        .rightArrow: "Arrow Right", .upArrow: "Arrow Up", .downArrow: "Arrow Down"
      ]
      return named[code]
    }
  #endif

  #if os(iOS)
    private static func orientationMask(_ names: [String]) -> UIInterfaceOrientationMask {
      guard !names.isEmpty else { return .all }
      var mask: UIInterfaceOrientationMask = []
      for name in names.map({ $0.lowercased() }) {
        switch name {
        case "portrait_up", "portrait": mask.insert(.portrait)
        case "portrait_down": mask.insert(.portraitUpsideDown)
        case "landscape_left": mask.insert(.landscapeLeft)
        case "landscape_right": mask.insert(.landscapeRight)
        default: continue
        }
      }
      return mask.isEmpty ? .all : mask
    }
  #endif
}

/// Browser context-menu policy is a web-only host concern. Keeping it as a
/// real service means Ruby receives an immediate, classified answer instead
/// of timing out or being told the method is unknown.
@MainActor
public final class BrowserContextMenuService: RufletService {
  public static let wireType = "BrowserContextMenu"
  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    switch call.name {
    case "disable_menu", "enable_menu":
      #if os(iOS)
        let platform = "iOS"
      #elseif os(macOS)
        let platform = "macOS"
      #else
        let platform = "this Apple platform"
      #endif
      completion(.failure(RufletServiceError.platformUnsupported(
        type: Self.wireType, method: call.name, platform: platform)))
    default:
      completion(.failure(RufletServiceError.unsupportedMethod(
        type: Self.wireType, method: call.name)))
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
      let text: String?
      if case .string(let value)? = call.argument("data") { text = value } else { text = nil }
      #if canImport(UIKit)
        UIPasteboard.general.string = text
      #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        if let text { NSPasteboard.general.setString(text, forType: .string) }
      #endif
      completion(.success(.null))

    case "get":
      #if canImport(UIKit)
        completion(.success(FletCoreServiceSemantics.nullableString(UIPasteboard.general.string)))
      #elseif canImport(AppKit)
        completion(.success(FletCoreServiceSemantics.nullableString(
          NSPasteboard.general.string(forType: .string))))
      #else
        completion(.success(.null))
      #endif

    case "set_files":
      let paths = (call.argument("files")?.arrayValue ?? []).compactMap(\.stringValue)
      #if canImport(UIKit)
        UIPasteboard.general.urls = paths.map { URL(fileURLWithPath: $0) }
        completion(.success(.null))
      #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(paths.map { URL(fileURLWithPath: $0) as NSURL })
        completion(.success(.null))
      #else
        completion(
          .failure(RufletServiceError.unavailable("File pasteboards are macOS-only")))
      #endif

    case "get_files":
      #if canImport(UIKit)
        completion(.success(.array((UIPasteboard.general.urls ?? []).map { .string($0.path) })))
      #elseif canImport(AppKit)
        let urls =
          NSPasteboard.general.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []
        completion(.success(.array(urls.map { .string($0.path) })))
      #else
        completion(.success(.array([])))
      #endif

    case "set_image":
      guard let bytes = FletCoreServiceSemantics.imageBytes(call.argument("data")) else {
        return completion(.failure(
          RufletServiceError.invalidArguments("data must be image bytes")))
      }
      #if canImport(UIKit)
        if let image = UIImage(data: Data(bytes))
        {
          UIPasteboard.general.image = image
          return completion(.success(.null))
        }
      #elseif canImport(AppKit)
        if let image = NSImage(data: Data(bytes))
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
      let value: String
      do {
        value = try FletCoreServiceSemantics.sharedPreferenceString(call.argument("value"))
      } catch {
        return completion(.failure(error))
      }
      defaults.set(value, forKey: prefix + key)
      completion(.success(.bool(true)))

    case "get":
      guard let key = call.argument("key")?.stringValue else {
        return completion(.failure(RufletServiceError.invalidArguments("key is required")))
      }
      completion(.success(FletCoreServiceSemantics.nullableString(
        defaults.string(forKey: prefix + key))))

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
      // The Flet adapter returns null, rather than an empty collection, on
      // every non-Android platform.
      completion(.success(.null))
    case "get_external_storage_directory":
      completion(.success(.null))
    case "get_console_log_filename":
      completion(.success(FletCoreServiceSemantics.nullableString(
        FletCoreServiceSemantics.consoleLogPath())))
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
        if call.name == "vibrate" {
          #if canImport(AudioToolbox)
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
          #else
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
          #endif
        } else {
          UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
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
        "reduce_motion": .bool(UIAccessibility.isReduceMotionEnabled),
        "on_off_switch_labels": .bool(UIAccessibility.shouldDifferentiateWithoutColor),
        "supports_announcements": .bool(true)
      ])
    #elseif canImport(AppKit)
      let defaults = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
      return .map([
        "accessible_navigation": .bool(NSWorkspace.shared.isVoiceOverEnabled),
        "bold_text": .bool(false),
        "disable_animations": .bool(defaults),
        "high_contrast": .bool(NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast),
        "invert_colors": .bool(NSWorkspace.shared.accessibilityDisplayShouldInvertColors),
        "reduce_motion": .bool(defaults),
        "on_off_switch_labels": .bool(false),
        "supports_announcements": .bool(true)
      ])
    #else
      return .map([:])
    #endif
  }
}
