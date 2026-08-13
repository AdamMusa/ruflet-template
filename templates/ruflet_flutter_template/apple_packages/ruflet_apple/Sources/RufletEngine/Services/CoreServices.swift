import Foundation
import RufletProtocol

#if canImport(UIKit)
  import UIKit
#endif
#if canImport(SafariServices)
  import SafariServices
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

  public static func clipboardText(_ value: RufletValue?) throws -> String {
    guard case .string(let value)? = value else {
      throw RufletServiceError.invalidArguments("data must be a string")
    }
    return value
  }

  public static func clipboardFiles(_ value: RufletValue?) throws -> [String] {
    guard case .array(let values)? = value else {
      throw RufletServiceError.invalidArguments("files must be a list of paths")
    }
    return try values.map { value in
      guard case .string(let path) = value else {
        throw RufletServiceError.invalidArguments("files must contain only paths")
      }
      return path
    }
  }

  public static func consoleLogPath(fileManager: FileManager = .default) -> String? {
    FletStoragePathsSemantics.path(for: .applicationCache)?
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

/// AppLifecycleListener names and payload used by Flet's Page control.
public enum FletPageLifecycleSemantics {
  public enum State: String, CaseIterable, Sendable {
    case show, resume, hide, inactive, pause, detach, restart
  }

  public static func payload(_ state: State) -> RufletValue {
    .map(["state": .string(state.rawValue)])
  }

  /// Flutter's AppLifecycleListener emits `restart` only after an app that
  /// reached `pause` returns to the foreground. A fresh launch or a temporary
  /// inactive transition must not synthesize it.
  public static func foregroundStates(wasPaused: Bool) -> [State] {
    wasPaused ? [.show, .restart] : [.show]
  }
}

/// The directory mapping used by Flet's pinned `path_provider_foundation`
/// adapter. Apple "temporary" storage is the base caches directory, while
/// macOS scopes application cache/support paths below the application bundle id.
public enum FletStoragePathsSemantics {
  public enum Directory: Equatable {
    case applicationCache
    case applicationDocuments
    case applicationSupport
    case downloads
    case library
    case temporary
  }

  public static func path(
    for directory: Directory,
    bundleIdentifier: String? = Bundle.main.bundleIdentifier
  ) -> URL? {
    let searchDirectory: FileManager.SearchPathDirectory
    switch directory {
    case .applicationCache, .temporary: searchDirectory = .cachesDirectory
    case .applicationDocuments: searchDirectory = .documentDirectory
    case .applicationSupport: searchDirectory = .applicationSupportDirectory
    case .downloads: searchDirectory = .downloadsDirectory
    case .library: searchDirectory = .libraryDirectory
    }
    guard let rawPath = NSSearchPathForDirectoriesInDomains(
      searchDirectory, .userDomainMask, true).first else { return nil }
    var url = URL(fileURLWithPath: rawPath, isDirectory: true)
    #if os(macOS)
      if (directory == .applicationCache || directory == .applicationSupport),
        let bundleIdentifier, !bundleIdentifier.isEmpty
      {
        url.appendPathComponent(bundleIdentifier, isDirectory: true)
      }
    #endif
    return url
  }

  public static func createsDirectory(_ directory: Directory) -> Bool {
    directory == .applicationCache || directory == .applicationSupport
  }
}

public enum FletURLLauncherSemantics {
  public enum Mode: String, CaseIterable {
    case platformDefault = "platformDefault"
    case inAppWebView = "inAppWebView"
    case inAppBrowserView = "inAppBrowserView"
    case externalApplication = "externalApplication"
    case externalNonBrowserApplication = "externalNonBrowserApplication"

    public init(wireValue: String?) {
      let normalized = wireValue?
        .replacingOccurrences(of: "-", with: "")
        .replacingOccurrences(of: "_", with: "")
        .lowercased()
      switch normalized {
      case "inappwebview": self = .inAppWebView
      case "inappbrowserview": self = .inAppBrowserView
      case "externalapplication": self = .externalApplication
      case "externalnonbrowserapplication": self = .externalNonBrowserApplication
      default: self = .platformDefault
      }
    }
  }

  public enum ApplePlatform {
    case iOS
    case macOS
  }

  public struct ParsedURL: Equatable {
    public let url: URL
    public let target: String?
  }

  public static func parseURL(_ value: RufletValue?) -> ParsedURL? {
    let raw: String?
    let target: String?
    switch value {
    case .string(let value):
      raw = value
      target = nil
    case .map(let value):
      if case .string(let string)? = value["url"] { raw = string } else { raw = nil }
      if case .string(let string)? = value["target"] { target = string } else { target = nil }
    default:
      raw = nil
      target = nil
    }
    guard let raw, let url = URL(string: raw) else { return nil }
    return ParsedURL(url: url, target: target)
  }

  /// Flet resolves a `_blank` URL target to an external application only when
  /// the caller left the mode at its platform default.
  public static func resolvedMode(_ mode: Mode, target: String?) -> Mode {
    mode == .platformDefault && target == "_blank" ? .externalApplication : mode
  }

  public static func nativeMode(_ mode: Mode, url: URL, platform: ApplePlatform) -> Mode {
    guard platform == .iOS, mode == .platformDefault else { return mode }
    return ["http", "https"].contains(url.scheme?.lowercased() ?? "")
      ? .inAppBrowserView : .externalApplication
  }

  public static func supportsLaunch(_ mode: Mode, platform: ApplePlatform) -> Bool {
    switch platform {
    case .iOS: return true
    case .macOS: return mode == .platformDefault || mode == .externalApplication
    }
  }

  /// `url_launcher` 6.3.2 routes this query through `supportsMode`.
  public static func supportsClose(_ mode: Mode, platform: ApplePlatform) -> Bool {
    supportsLaunch(mode, platform: platform)
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
  private var lifecycleObservers: [NSObjectProtocol] = []
  private var wasPaused = false
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

    if node.type == "Page", lifecycleObservers.isEmpty {
      installLifecycleObservers()
    }

    if node.handlesEvent("locale_change") {
      if localeObserver == nil {
        localeObserver = NotificationCenter.default.addObserver(
          forName: NSLocale.currentLocaleDidChangeNotification,
          object: nil,
          queue: .main
        ) { [weak self] _ in
          Task { @MainActor in self?.reportLocales() }
        }
      }
    } else if let localeObserver {
      NotificationCenter.default.removeObserver(localeObserver)
      self.localeObserver = nil
    }

    #if canImport(AppKit)
      if node.handlesEvent("keyboard_event"), keyboardMonitor == nil {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
          Task { @MainActor in self?.reportKey(event) }
          return event
        }
      } else if !node.handlesEvent("keyboard_event"), let keyboardMonitor {
        NSEvent.removeMonitor(keyboardMonitor)
        self.keyboardMonitor = nil
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
    for observer in lifecycleObservers { NotificationCenter.default.removeObserver(observer) }
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

  private func reportLifecycle(_ state: FletPageLifecycleSemantics.State) {
    guard let targetID, let context else { return }
    // Flet deliberately uses triggerEventWithoutSubscribers for lifecycle
    // transitions; Ruby receives them even if the client-side handler flag was
    // not present in the last patch.
    context.emitEvent(targetID, "app_lifecycle_state_change",
                      FletPageLifecycleSemantics.payload(state))
  }

  private func installLifecycleObservers() {
    func observe(_ name: Notification.Name, _ state: FletPageLifecycleSemantics.State) {
      lifecycleObservers.append(NotificationCenter.default.addObserver(
        forName: name, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.reportLifecycle(state) }
      })
    }

    #if canImport(UIKit)
      lifecycleObservers.append(NotificationCenter.default.addObserver(
        forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          guard let self else { return }
          let states = FletPageLifecycleSemantics.foregroundStates(wasPaused: self.wasPaused)
          self.wasPaused = false
          for state in states { self.reportLifecycle(state) }
        }
      })
      observe(UIApplication.didBecomeActiveNotification, .resume)
      observe(UIApplication.willResignActiveNotification, .inactive)
      lifecycleObservers.append(NotificationCenter.default.addObserver(
        forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.wasPaused = true
          self?.reportLifecycle(.pause)
        }
      })
      observe(UIApplication.willTerminateNotification, .detach)
    #elseif canImport(AppKit)
      observe(NSApplication.didUnhideNotification, .show)
      observe(NSApplication.didBecomeActiveNotification, .resume)
      observe(NSApplication.didHideNotification, .hide)
      observe(NSApplication.willResignActiveNotification, .inactive)
      observe(NSApplication.willTerminateNotification, .detach)
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
      completion(.success(.map(FletAppleDeviceInfoSemantics.payload())))

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
        // Pinned Flet calls SystemChrome only on a mobile platform and still
        // completes the Page method successfully everywhere else.
        completion(.success(.null))
      #endif

    case "take_screenshot":
      // The mounted Page view claims this method and returns PNG bytes. If no
      // Page boundary is mounted, Flet's `_rootKey.currentContext` is null and
      // the method resolves to null rather than raising an unsupported error.
      completion(.success(.null))

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

/// Native edit-menu policy. BrowserContextMenu is web-only in Flet, so its
/// service never changes this value on Apple; native controls remain usable.
@MainActor
public enum RufletBrowserContextMenuPolicy {
  public private(set) static var isEnabled = true

  public static func setEnabled(_ enabled: Bool) {
    isEnabled = enabled
  }
}

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
    case "disable_menu":
      completion(.success(.null))
    case "enable_menu":
      completion(.success(.null))
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
      let text: String
      do {
        text = try FletCoreServiceSemantics.clipboardText(call.argument("data"))
      } catch {
        return completion(.failure(error))
      }
      #if canImport(UIKit)
        UIPasteboard.general.string = text
      #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
      let paths: [String]
      do {
        paths = try FletCoreServiceSemantics.clipboardFiles(call.argument("files"))
      } catch {
        return completion(.failure(error))
      }
      #if canImport(UIKit)
        completion(.failure(RufletServiceError.platformUnsupported(
          type: "Clipboard", method: call.name, platform: "iOS")))
      #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        let succeeded = NSPasteboard.general.writeObjects(
          paths.map { URL(fileURLWithPath: $0) as NSURL })
        completion(.success(.bool(succeeded)))
      #else
        completion(.failure(RufletServiceError.platformUnsupported(
          type: "Clipboard", method: call.name, platform: "this platform")))
      #endif

    case "get_files":
      #if canImport(UIKit)
        completion(.failure(RufletServiceError.platformUnsupported(
          type: "Clipboard", method: call.name, platform: "iOS")))
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
public enum FletSharedPreferencesSemantics {
  public static let storagePrefix = "flutter."

  public enum Method: String, CaseIterable, Equatable {
    case set
    case get
    case containsKey = "contains_key"
    case getKeys = "get_keys"
    case remove
    case clear
  }

  public static func method(_ name: String) throws -> Method {
    guard let method = Method(rawValue: name) else {
      throw RufletServiceError.unsupportedMethod(type: "SharedPreferences", method: name)
    }
    return method
  }

  public static func requiredString(_ value: RufletValue?, name: String) throws -> String {
    guard case .string(let value)? = value else {
      throw RufletServiceError.invalidArguments("\(name) must be a string")
    }
    return value
  }

  public static func storageKey(_ key: String) -> String { storagePrefix + key }

  public static func visibleKeys(_ storedKeys: some Sequence<String>, prefix: String) -> [String] {
    storedKeys.compactMap { key in
      guard key.hasPrefix(storagePrefix) else { return nil }
      let visible = String(key.dropFirst(storagePrefix.count))
      return visible.hasPrefix(prefix) ? visible : nil
    }
  }
}

@MainActor
public final class SharedPreferencesService: RufletService {
  public static let wireType = "SharedPreferences"
  public static let supportedMethods: [String] = [
    "set", "get", "contains_key", "get_keys", "remove", "clear",
  ]

  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    let method: FletSharedPreferencesSemantics.Method
    do {
      method = try FletSharedPreferencesSemantics.method(call.name)
    } catch {
      return completion(.failure(error))
    }

    switch method {
    case .set:
      do {
        let key = try FletSharedPreferencesSemantics.requiredString(
          call.argument("key"), name: "key")
        let value = try FletSharedPreferencesSemantics.requiredString(
          call.argument("value"), name: "value")
        defaults.set(value, forKey: FletSharedPreferencesSemantics.storageKey(key))
      } catch {
        return completion(.failure(error))
      }
      completion(.success(.bool(true)))

    case .get:
      do {
        let key = try FletSharedPreferencesSemantics.requiredString(
          call.argument("key"), name: "key")
        completion(.success(FletCoreServiceSemantics.nullableString(
          defaults.string(forKey: FletSharedPreferencesSemantics.storageKey(key)))))
      } catch {
        completion(.failure(error))
      }

    case .containsKey:
      do {
        let key = try FletSharedPreferencesSemantics.requiredString(
          call.argument("key"), name: "key")
        completion(.success(.bool(
          defaults.object(forKey: FletSharedPreferencesSemantics.storageKey(key)) != nil)))
      } catch {
        completion(.failure(error))
      }

    case .getKeys:
      do {
        let filter = try FletSharedPreferencesSemantics.requiredString(
          call.argument("key_prefix"), name: "key_prefix")
        let keys = FletSharedPreferencesSemantics.visibleKeys(
          defaults.dictionaryRepresentation().keys, prefix: filter)
        completion(.success(.array(keys.map(RufletValue.string))))
      } catch {
        completion(.failure(error))
      }

    case .remove:
      do {
        let key = try FletSharedPreferencesSemantics.requiredString(
          call.argument("key"), name: "key")
        defaults.removeObject(forKey: FletSharedPreferencesSemantics.storageKey(key))
        completion(.success(.bool(true)))
      } catch {
        completion(.failure(error))
      }

    case .clear:
      for key in defaults.dictionaryRepresentation().keys
      where key.hasPrefix(FletSharedPreferencesSemantics.storagePrefix) {
        defaults.removeObject(forKey: key)
      }
      completion(.success(.bool(true)))
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
    func path(_ directory: FletStoragePathsSemantics.Directory, nullable: Bool = false) {
      guard let url = FletStoragePathsSemantics.path(for: directory) else {
        if nullable { return completion(.success(.null)) }
        return completion(.failure(
          RufletServiceError.unavailable("StoragePaths could not resolve \(directory)")))
      }
      if FletStoragePathsSemantics.createsDirectory(directory) {
        do {
          try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
          return completion(.failure(RufletServiceError.failed(
            "Could not create storage directory at \(url.path): \(error.localizedDescription)")))
        }
      }
      completion(.success(.string(url.path)))
    }

    switch call.name {
    case "get_application_cache_directory":
      path(.applicationCache)
    case "get_application_documents_directory":
      path(.applicationDocuments)
    case "get_application_support_directory":
      path(.applicationSupport)
    case "get_downloads_directory":
      path(.downloads, nullable: true)
    case "get_library_directory":
      path(.library)
    case "get_temporary_directory":
      path(.temporary)
    case "get_external_cache_directories", "get_external_storage_directories":
      // The Flet adapter returns null, rather than an empty collection, on
      // every non-Android platform.
      completion(.success(.null))
    case "get_external_storage_directory":
      completion(.success(.null))
    case "get_console_log_filename":
      guard let cache = FletStoragePathsSemantics.path(for: .applicationCache) else {
        return completion(.failure(
          RufletServiceError.unavailable("StoragePaths could not resolve application cache")))
      }
      do {
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        completion(.success(.string(cache.appendingPathComponent("console.log").path)))
      } catch {
        completion(.failure(RufletServiceError.failed(
          "Could not create storage directory at \(cache.path): \(error.localizedDescription)")))
      }
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

  #if canImport(UIKit)
  private var inAppController: UIViewController?
  #endif

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    switch call.name {
    case "launch_url":
      guard let parsed = FletURLLauncherSemantics.parseURL(call.argument("url")) else {
        return completion(.failure(RufletServiceError.invalidArguments("url is required")))
      }
      let requestedMode = FletURLLauncherSemantics.Mode(
        wireValue: call.argument("mode")?.stringValue)
      let target = parsed.target ?? call.argument("web_only_window_name")?.stringValue
      let resolvedMode = FletURLLauncherSemantics.resolvedMode(requestedMode, target: target)
      if resolvedMode == .inAppWebView || resolvedMode == .inAppBrowserView {
        guard ["http", "https"].contains(parsed.url.scheme?.lowercased() ?? "") else {
          return completion(.failure(RufletServiceError.invalidArguments(
            "in-app web views require an http(s) URL")))
        }
      }
      #if canImport(UIKit)
        let mode = FletURLLauncherSemantics.nativeMode(
          resolvedMode, url: parsed.url, platform: .iOS)
        switch mode {
        case .inAppWebView, .inAppBrowserView:
          #if canImport(SafariServices)
            guard let presenter = RufletWindow.topViewController() else {
              return completion(.failure(
                RufletServiceError.unavailable("No window to present from")))
            }
            let controller = SFSafariViewController(url: parsed.url)
            inAppController = controller
            presenter.present(controller, animated: true) { completion(.success(.null)) }
          #else
            completion(.failure(RufletServiceError.platformUnsupported(
              type: Self.wireType, method: call.name, platform: "iOS")))
          #endif
        case .platformDefault, .externalApplication, .externalNonBrowserApplication:
          let options: [UIApplication.OpenExternalURLOptionsKey: Any] =
            mode == .externalNonBrowserApplication ? [.universalLinksOnly: true] : [:]
          UIApplication.shared.open(parsed.url, options: options) { _ in
            // Flet's `openWebBrowser` intentionally discards launchUrl's Bool.
            completion(.success(.null))
          }
        }
      #elseif canImport(AppKit)
        // Unsupported preferences fall back to the sole macOS system-open mode.
        _ = NSWorkspace.shared.open(parsed.url)
        completion(.success(.null))
      #else
        completion(.failure(RufletServiceError.unavailable("No URL handler on this platform")))
      #endif

    case "open_window":
      guard FletURLLauncherSemantics.parseURL(call.argument("url")) != nil else {
        return completion(.failure(RufletServiceError.invalidArguments("url is required")))
      }
      // Flet's non-web `openPopupBrowserWindow` is deliberately a no-op.
      completion(.success(.null))

    case "can_launch_url":
      guard let parsed = FletURLLauncherSemantics.parseURL(call.argument("url")) else {
        return completion(.success(.bool(false)))
      }
      #if canImport(UIKit)
        completion(.success(.bool(UIApplication.shared.canOpenURL(parsed.url))))
      #elseif canImport(AppKit)
        completion(.success(.bool(NSWorkspace.shared.urlForApplication(toOpen: parsed.url) != nil)))
      #else
        completion(.success(.bool(false)))
      #endif

    case "close_in_app_web_view":
      #if canImport(UIKit)
        guard let controller = inAppController else {
          return completion(.success(.null))
        }
        controller.dismiss(animated: true) { completion(.success(.null)) }
        inAppController = nil
      #else
        completion(.success(.null))
      #endif

    case "supports_launch_mode":
      let mode = FletURLLauncherSemantics.Mode(
        wireValue: call.argument("mode")?.stringValue)
      #if canImport(UIKit)
        completion(.success(.bool(FletURLLauncherSemantics.supportsLaunch(
          mode, platform: .iOS))))
      #elseif canImport(AppKit)
        completion(.success(.bool(FletURLLauncherSemantics.supportsLaunch(
          mode, platform: .macOS))))
      #else
        completion(.success(.bool(false)))
      #endif

    case "supports_close_for_launch_mode":
      let mode = FletURLLauncherSemantics.Mode(
        wireValue: call.argument("mode")?.stringValue)
      #if canImport(UIKit)
        completion(.success(.bool(FletURLLauncherSemantics.supportsClose(
          mode, platform: .iOS))))
      #elseif canImport(AppKit)
        completion(.success(.bool(FletURLLauncherSemantics.supportsClose(
          mode, platform: .macOS))))
      #else
        completion(.success(.bool(false)))
      #endif

    default:
      completion(
        .failure(
          RufletServiceError.unsupportedMethod(type: "UrlLauncher", method: call.name)))
    }
  }
}

/// `HapticFeedback` — the taptic engine on iOS and Force Touch feedback on macOS.
public enum FletHapticFeedbackSemantics {
  public enum Method: String, CaseIterable, Equatable {
    case heavyImpact = "heavy_impact"
    case lightImpact = "light_impact"
    case mediumImpact = "medium_impact"
    case vibrate
    case selectionClick = "selection_click"
  }

  public static func method(_ name: String) throws -> Method {
    guard let method = Method(rawValue: name) else {
      throw RufletServiceError.unsupportedMethod(type: "HapticFeedback", method: name)
    }
    return method
  }
}

@MainActor
public final class HapticFeedbackService: RufletService {
  public static let wireType = "HapticFeedback"
  public static let supportedMethods: [String] = [
    "heavy_impact", "light_impact", "medium_impact", "vibrate", "selection_click",
  ]

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    let method: FletHapticFeedbackSemantics.Method
    do {
      method = try FletHapticFeedbackSemantics.method(call.name)
    } catch {
      return completion(.failure(error))
    }

    #if os(iOS)
      switch method {
      case .lightImpact:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      case .mediumImpact:
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      case .heavyImpact, .vibrate:
        if method == .vibrate {
          #if canImport(AudioToolbox)
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
          #else
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
          #endif
        } else {
          UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
      case .selectionClick:
        UISelectionFeedbackGenerator().selectionChanged()
      }
    #elseif canImport(AppKit)
      let pattern: NSHapticFeedbackManager.FeedbackPattern
      switch method {
      case .selectionClick, .lightImpact: pattern = .alignment
      case .mediumImpact: pattern = .levelChange
      case .heavyImpact, .vibrate: pattern = .generic
      }
      NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    #else
      _ = method
    #endif
    completion(.success(.null))
  }
}

/// `Wakelock` — keeps the screen awake.
public enum FletWakelockSemantics {
  public enum Method: String, CaseIterable, Equatable {
    case enable
    case disable
    case isEnabled = "is_enabled"
  }

  public static func method(_ name: String) throws -> Method {
    guard let method = Method(rawValue: name) else {
      throw RufletServiceError.unsupportedMethod(type: "Wakelock", method: name)
    }
    return method
  }

  public static func nextEnabledState(current: Bool, method: Method) -> Bool {
    switch method {
    case .enable: return true
    case .disable: return false
    case .isEnabled: return current
    }
  }
}

@MainActor
public final class WakelockService: RufletService {
  public static let wireType = "Wakelock"
  public static let supportedMethods: [String] = ["enable", "disable", "is_enabled"]

  #if canImport(AppKit)
    private var assertion: NSObjectProtocol?
  #endif

  public init() {}

  deinit {
    #if canImport(AppKit)
      if let assertion { ProcessInfo.processInfo.endActivity(assertion) }
    #endif
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    let method: FletWakelockSemantics.Method
    do {
      method = try FletWakelockSemantics.method(call.name)
    } catch {
      return completion(.failure(error))
    }

    switch method {
    case .enable, .disable:
      let enable = method == .enable
      #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = enable
      #elseif canImport(AppKit)
        if enable, assertion == nil {
          assertion = ProcessInfo.processInfo.beginActivity(
            options: [.idleDisplaySleepDisabled], reason: "Ruflet wakelock")
        } else if !enable, let assertion {
          ProcessInfo.processInfo.endActivity(assertion)
          self.assertion = nil
        }
      #endif
      completion(.success(.null))

    case .isEnabled:
      #if os(iOS)
        completion(.success(.bool(UIApplication.shared.isIdleTimerDisabled)))
      #elseif canImport(AppKit)
        completion(.success(.bool(assertion != nil)))
      #else
        completion(.success(.bool(false)))
      #endif
    }
  }
}

/// `SemanticsService` — VoiceOver announcements.
public enum FletSemanticsAssertiveness: String, Equatable {
  case polite
  case assertive

  init(_ value: RufletValue?) {
    self = value?.stringValue?.lowercased() == "assertive" ? .assertive : .polite
  }
}

public struct FletSemanticsAnnouncement: Equatable {
  public enum Kind: Equatable { case message, tooltip }

  public let kind: Kind
  public let message: String
  public let rtl: Bool
  public let assertiveness: FletSemanticsAssertiveness
}

public struct FletAccessibilityFeatures: Equatable {
  public let accessibleNavigation: Bool
  public let boldText: Bool
  public let disableAnimations: Bool
  public let highContrast: Bool
  public let invertColors: Bool
  public let reduceMotion: Bool
  public let onOffSwitchLabels: Bool
  public let supportsAnnouncements: Bool

  public init(
    accessibleNavigation: Bool,
    boldText: Bool,
    disableAnimations: Bool,
    highContrast: Bool,
    invertColors: Bool,
    reduceMotion: Bool,
    onOffSwitchLabels: Bool,
    supportsAnnouncements: Bool
  ) {
    self.accessibleNavigation = accessibleNavigation
    self.boldText = boldText
    self.disableAnimations = disableAnimations
    self.highContrast = highContrast
    self.invertColors = invertColors
    self.reduceMotion = reduceMotion
    self.onOffSwitchLabels = onOffSwitchLabels
    self.supportsAnnouncements = supportsAnnouncements
  }

  public var wireValue: RufletValue {
    .map([
      "accessible_navigation": .bool(accessibleNavigation),
      "bold_text": .bool(boldText),
      "disable_animations": .bool(disableAnimations),
      "high_contrast": .bool(highContrast),
      "invert_colors": .bool(invertColors),
      "reduce_motion": .bool(reduceMotion),
      "on_off_switch_labels": .bool(onOffSwitchLabels),
      "supports_announcements": .bool(supportsAnnouncements),
    ])
  }
}

public enum FletSemanticsServiceSemantics {
  public static func announcement(_ call: RufletMethodCall) throws
    -> FletSemanticsAnnouncement
  {
    let kind: FletSemanticsAnnouncement.Kind
    switch call.name {
    case "announce_message": kind = .message
    case "announce_tooltip": kind = .tooltip
    default:
      throw RufletServiceError.unsupportedMethod(type: "SemanticsService", method: call.name)
    }
    return FletSemanticsAnnouncement(
      kind: kind,
      message: dartString(call.argument("message")),
      rtl: kind == .message && call.argument("rtl")?.boolValue == true,
      assertiveness: kind == .message
        ? FletSemanticsAssertiveness(call.argument("assertiveness")) : .polite)
  }

  public static func dartString(_ value: RufletValue?) -> String {
    switch value {
    case nil, .null: return "null"
    case .string(let value), .extended(_, let value): return value
    case .bool(let value): return value ? "true" : "false"
    case .int(let value): return String(value)
    case .double(let value): return String(value)
    case let value?: return value.description
    }
  }

  public static var currentFeatures: FletAccessibilityFeatures {
    #if canImport(UIKit)
      let reduceMotion = UIAccessibility.isReduceMotionEnabled
      return FletAccessibilityFeatures(
        accessibleNavigation: UIAccessibility.isVoiceOverRunning
          || UIAccessibility.isSwitchControlRunning,
        boldText: UIAccessibility.isBoldTextEnabled,
        disableAnimations: reduceMotion,
        highContrast: UIAccessibility.isDarkerSystemColorsEnabled,
        invertColors: UIAccessibility.isInvertColorsEnabled,
        reduceMotion: reduceMotion,
        onOffSwitchLabels: UIAccessibility.isOnOffSwitchLabelsEnabled,
        supportsAnnouncements: true)
    #elseif canImport(AppKit)
      let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
      return FletAccessibilityFeatures(
        accessibleNavigation: NSWorkspace.shared.isVoiceOverEnabled,
        boldText: false,
        disableAnimations: reduceMotion,
        highContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast,
        invertColors: NSWorkspace.shared.accessibilityDisplayShouldInvertColors,
        reduceMotion: reduceMotion,
        onOffSwitchLabels: false,
        supportsAnnouncements: true)
    #else
      return FletAccessibilityFeatures(
        accessibleNavigation: false, boldText: false, disableAnimations: false,
        highContrast: false, invertColors: false, reduceMotion: false,
        onOffSwitchLabels: false, supportsAnnouncements: false)
    #endif
  }
}

@MainActor
public final class SemanticsAnnouncementService: RufletService {
  public static let wireType = "SemanticsService"
  public static let supportedMethods: [String] = [
    "announce_message", "announce_tooltip", "get_accessibility_features",
  ]

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    if call.name == "get_accessibility_features" {
      return completion(.success(FletSemanticsServiceSemantics.currentFeatures.wireValue))
    }

    let announcement: FletSemanticsAnnouncement
    do {
      announcement = try FletSemanticsServiceSemantics.announcement(call)
    } catch {
      return completion(.failure(error))
    }
    #if canImport(UIKit)
      let spoken = NSMutableAttributedString(string: announcement.message)
      spoken.addAttribute(
        NSAttributedString.Key(rawValue: "UIAccessibilitySpeechAttributeQueueAnnouncement"),
        value: announcement.assertiveness == .polite,
        range: NSRange(location: 0, length: spoken.length))
      UIAccessibility.post(notification: .announcement, argument: spoken)
    #elseif canImport(AppKit)
      NSAccessibility.post(
        element: NSApp as Any,
        notification: .announcementRequested,
        userInfo: [
          .announcement: announcement.message,
          .priority: NSNumber(value:
            announcement.assertiveness == .assertive
              ? NSAccessibilityPriorityLevel.high.rawValue
              : NSAccessibilityPriorityLevel.low.rawValue),
        ])
    #endif
    completion(.success(.null))
  }
}
