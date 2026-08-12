import RufletEngine
import RufletProtocol
import SwiftUI
import CoreText

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// Resolves a Ruflet icon value to its native rendering source.
///
/// Icons arrive as integers in distinct Material and Cupertino codepoint
/// ranges. On Apple, both families resolve to the closest native SF Symbol:
/// Ruby can keep using one logical icon such as `home`, while iOS/macOS render
/// Apple's `house` artwork. The wire family is still retained while resolving
/// the name, so Material and Cupertino aliases can use different vocabulary.
public enum IconMapping {
  public enum Family: Equatable, Sendable {
    case material
    case cupertino
  }

  public static let placeholderSymbol = "questionmark.square.dashed"

  public enum Rendering: Equatable, Sendable {
    case materialGlyph(codepoint: Int, name: String)
    case systemSymbol(String)
  }

  /// The same platform-family policy used by Ruflet's icon search. Keeping it
  /// next to resolution prevents an Apple host from accidentally presenting
  /// Material names and then resolving them as Cupertino (or vice versa).
  public static func preferredFamily(forPlatform rawPlatform: String) -> Family {
    switch rawPlatform.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "ios", "macos": return .cupertino
    default: return .material
    }
  }

  /// Names suitable for a platform icon browser. The generated wire catalogs
  /// remain the source of truth; this is not a hand-maintained screen list.
  public static func searchableNames(forPlatform platform: String) -> [String] {
    switch preferredFamily(forPlatform: platform) {
    case .material: return MaterialIconNames.material
    case .cupertino: return MaterialIconNames.cupertino
    }
  }

  public static func symbol(forName name: String, family: Family) -> String {
    switch family {
    case .material: return symbol(forMaterialName: name)
    case .cupertino: return symbol(forCupertinoName: name)
    }
  }

  /// Resolves either wire family to native Apple artwork.
  public static func rendering(for value: RufletValue?) -> Rendering? {
    guard let value, !value.isNull else { return nil }
    if let wireCodepoint = value.intValue,
      let descriptor = MaterialIconNames.descriptor(forCodepoint: wireCodepoint)
    {
      switch descriptor.family {
      case .material:
        let symbol = symbol(forMaterialName: descriptor.name)
        if symbol != placeholderSymbol { return .systemSymbol(symbol) }
        if let codepoint = MaterialIconGlyphs.codepoint(forWireCodepoint: wireCodepoint) {
          // SF Symbols does not contain an honest equivalent for every one of
          // Flutter's 8,000+ Material icons. Preserve the exact Android/Web
          // glyph in those cases instead of showing an unrelated question
          // mark. Curated semantic matches above still use native artwork.
          return .materialGlyph(codepoint: codepoint, name: descriptor.name)
        }
        return .systemSymbol(placeholderSymbol)
      case .cupertino:
        return .systemSymbol(symbol(forCupertinoName: descriptor.name))
      }
    }

    guard let rawName = value.stringValue else { return nil }
    if rawName.lowercased().hasPrefix("cupertinoicons.") {
      return .systemSymbol(symbol(forCupertinoName: rawName))
    }
    if let codepoint = MaterialIconGlyphs.codepoint(forName: rawName) {
      let symbol = symbol(forMaterialName: rawName)
      return symbol == placeholderSymbol
        ? .materialGlyph(codepoint: codepoint, name: canonical(rawName).uppercased())
        : .systemSymbol(symbol)
    }
    return .systemSymbol(symbol(forMaterialName: rawName))
  }

  /// The symbol for an icon prop, or nil when the value is empty.
  public static func symbol(for value: RufletValue?) -> String? {
    guard let value, !value.isNull else { return nil }
    if let codepoint = value.intValue,
      let descriptor = MaterialIconNames.descriptor(forCodepoint: codepoint)
    {
      switch descriptor.family {
      case .material:
        return symbol(forName: descriptor.name, family: .material)
      case .cupertino:
        return symbol(forName: descriptor.name, family: .cupertino)
      }
    }

    // Custom hosts may send a name instead of the standard integer protocol.
    guard let name = value.stringValue else { return nil }
    if name.lowercased().hasPrefix("cupertinoicons.") {
      return symbol(forCupertinoName: name)
    }
    return symbol(forName: name, family: .material)
  }

  public static func materialName(for value: RufletValue) -> String? {
    if let codepoint = value.intValue,
      let descriptor = MaterialIconNames.descriptor(forCodepoint: codepoint),
      descriptor.family == .material
    {
      return descriptor.name
    }
    // A host that registered its own control may pass a name straight through.
    return value.stringValue
  }

  public static func symbol(forMaterialName rawName: String) -> String {
    let name = canonical(rawName)
    if let mapped = table[name], isAvailable(mapped) { return mapped }
    if let fallback = unavailableSymbolFallbacks[name], isAvailable(fallback) { return fallback }

    // Variants share a base icon: ADD_OUTLINED, ADD_ROUNDED, ADD_SHARP all
    // mean ADD, and Apple has no equivalent distinction.
    for suffix in ["_outlined", "_rounded", "_sharp"] where name.hasSuffix(suffix) {
      let base = String(name.dropLast(suffix.count))
      if let mapped = table[base], isAvailable(mapped) { return mapped }
      if let fallback = unavailableSymbolFallbacks[base], isAvailable(fallback) { return fallback }
    }

    RufletLog.debug("No SF Symbol for Material icon `\(rawName)`")
    return placeholderSymbol
  }

  /// Resolves Flutter's Cupertino icon catalog to SF Symbols. Cupertino icon
  /// names are largely derived from SF Symbols, so the general conversion
  /// covers the full catalog while the small semantic table handles names
  /// where Flutter and Apple use different vocabulary.
  public static func symbol(forCupertinoName rawName: String) -> String {
    let unqualified = rawName.replacingOccurrences(
      of: "cupertinoicons.", with: "", options: [.caseInsensitive, .anchored])
    let name = canonical(unqualified)
    if let mapped = cupertinoTable[name], isAvailable(mapped) { return mapped }

    let candidates = cupertinoCandidates(for: name)
    if let symbol = candidates.first(where: isAvailable) { return symbol }

    // Shared semantic names can still use the curated Material-to-SF mapping.
    let materialSymbol = symbol(forMaterialName: name)
    if materialSymbol != placeholderSymbol, isAvailable(materialSymbol) {
      return materialSymbol
    }

    // Flutter's Cupertino catalog can contain symbols introduced after the
    // application's minimum Apple OS. Preserve a native, semantic image in
    // that case instead of dropping the icon. Arbitrary extension names do not
    // take this path and remain an explicit placeholder.
    if cupertinoNames.contains(name) {
      return semanticCupertinoFallback(for: name)
    }

    RufletLog.debug("No SF Symbol for Cupertino icon `\(rawName)`")
    return placeholderSymbol
  }

  private static func canonical(_ name: String) -> String {
    name
      .lowercased()
      .replacingOccurrences(of: " ", with: "_")
      .replacingOccurrences(of: "-", with: "_")
      .replacingOccurrences(of: "icons.", with: "")
  }

  private static func cupertinoCandidates(for name: String) -> [String] {
    let dotted = name.replacingOccurrences(of: "_", with: ".")
    let native =
      dotted
      .replacingOccurrences(of: ".circled", with: ".circle")
      .replacingOccurrences(of: ".solid", with: ".fill")

    var candidates = [native]
    if native.hasSuffix(".fill") {
      candidates.append(String(native.dropLast(".fill".count)))
    }
    if native.hasSuffix(".circle") {
      candidates.append(String(native.dropLast(".circle".count)))
    }
    return candidates
  }

  private static func isAvailable(_ symbol: String) -> Bool {
    #if canImport(UIKit)
      return UIImage(systemName: symbol) != nil
    #elseif canImport(AppKit)
      return NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil
    #else
      return true
    #endif
  }

  private static func semanticCupertinoFallback(for name: String) -> String {
    let semanticSymbols: [(String, String)] = [
      ("airplane", "airplane"), ("alarm", "alarm"),
      ("antenna", "antenna.radiowaves.left.and.right"),
      ("arrow", "arrow.right"), ("back", "chevron.left"), ("forward", "chevron.right"),
      ("battery", "battery.100"), ("bell", "bell"), ("bluetooth", "wave.3.right"),
      ("book", "book"), ("bookmark", "bookmark"), ("briefcase", "briefcase"),
      ("bus", "bus"), ("calendar", "calendar"), ("camera", "camera"), ("car", "car"),
      ("cart", "cart"), ("chart", "chart.bar"), ("chat", "bubble.left"),
      ("check", "checkmark"), ("chevron", "chevron.right"), ("circle", "circle"),
      ("clock", "clock"), ("cloud", "cloud"), ("compass", "safari"),
      ("creditcard", "creditcard"), ("delete", "trash"), ("doc", "doc"),
      ("download", "arrow.down.circle"), ("drop", "drop"), ("envelope", "envelope"),
      ("exclamation", "exclamationmark.triangle"), ("eye", "eye"), ("face", "face.smiling"),
      ("film", "film"), ("flag", "flag"), ("flame", "flame"), ("folder", "folder"),
      ("game", "gamecontroller"), ("gear", "gearshape"), ("globe", "globe"),
      ("hammer", "hammer"), ("hand", "hand.raised"), ("heart", "heart"),
      ("home", "house"), ("house", "house"), ("info", "info.circle"),
      ("keyboard", "keyboard"), ("leaf", "leaf"), ("lightbulb", "lightbulb"),
      ("link", "link"), ("list", "list.bullet"), ("location", "mappin"),
      ("lock", "lock"), ("mail", "envelope"), ("map", "map"), ("mic", "mic"),
      ("minus", "minus"), ("moon", "moon"), ("music", "music.note"),
      ("paint", "paintbrush"), ("paperplane", "paperplane"), ("pause", "pause"),
      ("pencil", "pencil"), ("person", "person"), ("phone", "phone"),
      ("photo", "photo"), ("play", "play"), ("plus", "plus"), ("printer", "printer"),
      ("question", "questionmark.circle"), ("rectangle", "rectangle"),
      ("scissors", "scissors"), ("search", "magnifyingglass"), ("settings", "gearshape"),
      ("share", "square.and.arrow.up"), ("shield", "shield"), ("snow", "snowflake"),
      ("speaker", "speaker.wave.2"), ("square", "square"), ("star", "star"),
      ("stop", "stop"), ("sun", "sun.max"), ("tag", "tag"), ("text", "textformat"),
      ("timer", "timer"), ("train", "tram"), ("trash", "trash"),
      ("upload", "arrow.up.circle"), ("video", "video"), ("wave", "waveform"),
      ("wifi", "wifi"), ("wind", "wind"), ("wrench", "wrench"), ("xmark", "xmark"),
    ]

    return semanticSymbols.first(where: { name.contains($0.0) })?.1 ?? "app"
  }

  /// Internal test hook for corpus regressions. Mapping to a non-placeholder
  /// string is insufficient if that SF Symbol does not exist on the runtime.
  static func nativeSymbolExists(_ symbol: String) -> Bool {
    isAvailable(symbol)
  }

  private static let cupertinoNames = Set(MaterialIconNames.cupertino.map(canonical))

  /// Cupertino names whose SF Symbol spelling is not a mechanical dotted
  /// conversion. This is platform vocabulary, not per-screen presentation.
  private static let cupertinoTable: [String: String] = [
    "add": "plus", "add_circled": "plus.circle", "add_circled_solid": "plus.circle.fill",
    "clear": "xmark", "clear_circled": "xmark.circle", "clear_circled_solid": "xmark.circle.fill",
    "delete": "trash", "delete_solid": "trash.fill",
    "remove": "minus", "minus_circle": "minus.circle", "minus_circle_fill": "minus.circle.fill",
    "check_mark": "checkmark", "check_mark_circled": "checkmark.circle",
    "check_mark_circled_solid": "checkmark.circle.fill",
    "back": "chevron.left", "forward": "chevron.right",
    "left_chevron": "chevron.left", "right_chevron": "chevron.right",
    "up_chevron": "chevron.up", "down_chevron": "chevron.down",
    "home": "house", "home_fill": "house.fill",
    "search": "magnifyingglass", "search_circle": "magnifyingglass.circle",
    "search_circle_fill": "magnifyingglass.circle.fill",
    "settings": "gearshape", "settings_solid": "gearshape.fill",
    "person": "person", "person_fill": "person.fill",
    "person_circle": "person.crop.circle", "person_circle_fill": "person.crop.circle.fill",
    "folder": "folder", "folder_fill": "folder.fill", "folder_open": "folder.fill",
    "play_arrow": "play.fill", "play_arrow_solid": "play.fill",
    "play_circle": "play.circle", "play_circle_fill": "play.circle.fill",
    "pause": "pause.fill", "stop": "stop.fill",
    "photo_camera": "camera.fill", "photo": "photo", "photo_fill": "photo.fill",
    "square_arrow_up": "square.and.arrow.up", "square_arrow_down": "square.and.arrow.down",
    "square_arrow_left": "arrow.left.square", "square_arrow_right": "arrow.right.square",
    "doc": "doc", "doc_fill": "doc.fill", "doc_text": "doc.text", "doc_text_fill": "doc.text.fill",
    "chart_bar": "chart.bar", "chart_bar_fill": "chart.bar.fill",
    "chart_pie": "chart.pie", "chart_pie_fill": "chart.pie.fill",
    "ellipsis": "ellipsis", "ellipsis_circle": "ellipsis.circle",
    "info": "info.circle", "info_circle": "info.circle", "info_circle_fill": "info.circle.fill",
    "question": "questionmark", "question_circle": "questionmark.circle",
    "question_circle_fill": "questionmark.circle.fill",
    "exclamationmark_triangle": "exclamationmark.triangle",
    "exclamationmark_triangle_fill": "exclamationmark.triangle.fill",
  ]

  /// Material name to SF Symbol. Covers the icons Ruflet applications actually
  /// reach for; anything else falls back to a visible placeholder rather than
  /// disappearing, so a missing mapping is obvious on screen.
  private static let table: [String: String] = [
    // Navigation
    "add": "plus", "add_circle": "plus.circle.fill", "add_circle_outline": "plus.circle",
    "add_box": "plus.square", "remove": "minus", "remove_circle": "minus.circle.fill",
    "remove_circle_outline": "minus.circle", "close": "xmark", "clear": "xmark",
    "cancel": "xmark.circle.fill", "check": "checkmark", "done": "checkmark",
    "done_all": "checkmark.circle.fill", "check_circle": "checkmark.circle.fill",
    "check_circle_outline": "checkmark.circle", "check_box": "checkmark.square.fill",
    "check_box_outline_blank": "square",
    "arrow_back": "chevron.left", "arrow_forward": "chevron.right",
    "arrow_back_ios": "chevron.left", "arrow_forward_ios": "chevron.right",
    "arrow_upward": "arrow.up", "arrow_downward": "arrow.down",
    "arrow_left": "arrow.left", "arrow_right": "arrow.right",
    "arrow_drop_down": "chevron.down", "arrow_drop_up": "chevron.up",
    "arrow_drop_down_circle": "chevron.down.circle.fill",
    "keyboard_arrow_down": "chevron.down", "keyboard_arrow_up": "chevron.up",
    "keyboard_arrow_left": "chevron.left", "keyboard_arrow_right": "chevron.right",
    "expand_more": "chevron.down", "expand_less": "chevron.up",
    "chevron_left": "chevron.left", "chevron_right": "chevron.right",
    "first_page": "chevron.left.2", "last_page": "chevron.right.2",
    "menu": "line.3.horizontal", "more_vert": "ellipsis", "more_horiz": "ellipsis",
    "apps": "square.grid.2x2", "widgets": "square.grid.2x2", "dashboard": "square.grid.2x2.fill",
    "home": "house", "home_filled": "house.fill",

    // Actions
    "search": "magnifyingglass", "settings": "gearshape", "tune": "slider.horizontal.3",
    "filter_list": "line.3.horizontal.decrease", "filter_alt": "line.3.horizontal.decrease.circle",
    "sort": "arrow.up.arrow.down", "refresh": "arrow.clockwise",
    "sync": "arrow.triangle.2.circlepath",
    "edit": "pencil", "create": "pencil", "mode_edit": "pencil", "edit_note": "square.and.pencil",
    "delete": "trash", "delete_forever": "trash.fill", "delete_outline": "trash",
    "save": "square.and.arrow.down", "save_alt": "square.and.arrow.down",
    "download": "arrow.down.circle", "file_download": "arrow.down.circle",
    "upload": "arrow.up.circle", "file_upload": "arrow.up.circle",
    "upload_file": "doc.badge.arrow.up",
    "share": "square.and.arrow.up", "ios_share": "square.and.arrow.up",
    "content_copy": "doc.on.doc", "content_paste": "doc.on.clipboard",
    "content_cut": "scissors", "undo": "arrow.uturn.backward", "redo": "arrow.uturn.forward",
    "print": "printer", "open_in_new": "arrow.up.forward.square", "link": "link",
    "code": "chevron.left.forwardslash.chevron.right",
    "attach_file": "paperclip", "send": "paperplane.fill", "reply": "arrowshape.turn.up.left",
    "forward": "arrowshape.turn.up.right", "logout": "rectangle.portrait.and.arrow.right",
    "login": "arrow.right.square", "exit_to_app": "rectangle.portrait.and.arrow.right",
    "zoom_in": "plus.magnifyingglass", "zoom_out": "minus.magnifyingglass",
    "fullscreen": "arrow.up.left.and.arrow.down.right",
    "fullscreen_exit": "arrow.down.right.and.arrow.up.left",
    "open_with": "arrow.up.left.and.arrow.down.right",
    "unfold_less": "arrow.up.and.down.and.arrow.left.and.right",
    "drag_handle": "line.3.horizontal", "drag_indicator": "line.3.horizontal",

    // Status
    "info": "info.circle", "info_outline": "info.circle", "help": "questionmark.circle",
    "help_outline": "questionmark.circle", "question_mark": "questionmark",
    "warning": "exclamationmark.triangle.fill", "warning_amber": "exclamationmark.triangle",
    "error": "exclamationmark.octagon.fill", "error_outline": "exclamationmark.octagon",
    "report_problem": "exclamationmark.triangle", "priority_high": "exclamationmark",
    "verified": "checkmark.seal.fill", "verified_user": "checkmark.shield.fill",
    "new_releases": "burst.fill", "block": "nosign", "do_not_disturb": "moon.zzz",

    // Content
    "star": "star.fill", "star_border": "star", "star_outline": "star",
    "star_half": "star.leadinghalf.filled", "grade": "star.fill",
    "favorite": "heart.fill", "favorite_border": "heart", "thumb_up": "hand.thumbsup.fill",
    "thumb_down": "hand.thumbsdown.fill", "bookmark": "bookmark.fill",
    "bookmark_border": "bookmark", "flag": "flag.fill", "label": "tag.fill",
    "visibility": "eye", "visibility_off": "eye.slash",
    "lock": "lock.fill", "lock_open": "lock.open.fill", "lock_outline": "lock",
    "key": "key.fill", "shield": "shield.fill", "security": "lock.shield",
    "fingerprint": "touchid", "vpn_key": "key.fill",

    // People and communication
    "person": "person.fill", "person_outline": "person", "people": "person.2.fill",
    "group": "person.3.fill", "account_circle": "person.crop.circle",
    "account_box": "person.crop.square", "supervisor_account": "person.2.badge.gearshape",
    "face": "face.smiling", "mail": "envelope.fill", "email": "envelope.fill",
    "mail_outline": "envelope", "inbox": "tray.fill", "drafts": "envelope.open",
    "message": "message.fill", "chat": "bubble.left.fill",
    "chat_bubble": "bubble.left.fill", "chat_bubble_outline": "bubble.left",
    "forum": "bubble.left.and.bubble.right.fill", "comment": "bubble.right",
    "call": "phone.fill", "phone": "phone.fill", "call_end": "phone.down.fill",
    "videocam": "video.fill", "videocam_off": "video.slash.fill",
    "notifications": "bell.fill", "notifications_none": "bell",
    "notifications_off": "bell.slash.fill", "notifications_active": "bell.badge.fill",

    // Media
    "play_arrow": "play.fill", "play_circle": "play.circle.fill",
    "play_circle_outline": "play.circle", "pause": "pause.fill",
    "pause_circle": "pause.circle.fill", "stop": "stop.fill",
    "skip_next": "forward.end.fill", "skip_previous": "backward.end.fill",
    "fast_forward": "forward.fill", "fast_rewind": "backward.fill",
    "replay": "arrow.counterclockwise", "shuffle": "shuffle", "repeat": "repeat",
    "volume_up": "speaker.wave.2.fill", "volume_down": "speaker.wave.1.fill",
    "volume_off": "speaker.slash.fill", "volume_mute": "speaker.fill",
    "mic": "mic.fill", "mic_off": "mic.slash.fill", "headphones": "headphones",
    "audiotrack": "music.note", "music_note": "music.note", "library_music": "music.note.list",
    "camera": "camera.fill", "camera_alt": "camera.fill",
    "cameraswitch": "arrow.triangle.2.circlepath.camera",
    "photo_camera": "camera.fill", "photo": "photo", "image": "photo",
    "photo_library": "photo.on.rectangle", "collections": "square.stack",
    "movie": "film", "video_library": "film.stack", "album": "square.stack.fill",

    // Files
    "folder": "folder.fill", "folder_open": "folder.fill",
    "create_new_folder": "folder.badge.plus", "insert_drive_file": "doc.fill",
    "description": "doc.text.fill", "article": "doc.richtext",
    "note": "note.text", "notes": "note.text", "assignment": "list.clipboard",
    "list": "list.bullet", "list_alt": "list.bullet.rectangle",
    "format_list_bulleted": "list.bullet", "format_list_numbered": "list.number",
    "table_chart": "tablecells", "grid_view": "square.grid.2x2",
    "view_list": "list.bullet", "view_module": "square.grid.3x2",
    "view_column": "rectangle.split.3x1", "view_stream": "rectangle.split.1x2",
    "tab": "rectangle.split.3x1", "crop_square": "square.dashed",
    "attach_money": "dollarsign.circle", "receipt": "receipt",
    "shopping_cart": "cart.fill", "shopping_bag": "bag.fill",
    "store": "storefront", "payment": "creditcard.fill", "credit_card": "creditcard.fill",

    // Charts
    "bar_chart": "chart.bar.fill", "show_chart": "chart.line.uptrend.xyaxis",
    "pie_chart": "chart.pie.fill", "donut_large": "chart.pie",
    "insights": "chart.line.uptrend.xyaxis",
    "trending_up": "arrow.up.right", "trending_down": "arrow.down.right",
    "trending_flat": "arrow.right", "analytics": "chart.bar.xaxis",
    "timeline": "chart.xyaxis.line", "leaderboard": "chart.bar.fill",

    // Time and place
    "schedule": "clock", "access_time": "clock", "timer": "timer",
    "alarm": "alarm.fill", "history": "clock.arrow.circlepath",
    "today": "calendar", "event": "calendar", "date_range": "calendar",
    "calendar_today": "calendar", "calendar_month": "calendar",
    "place": "mappin.circle.fill", "location_on": "mappin.circle.fill",
    "location_off": "location.slash", "my_location": "location.fill",
    "map": "map.fill", "navigation": "location.north.fill", "explore": "safari",
    "near_me": "location.north.fill", "directions": "arrow.triangle.turn.up.right.diamond.fill",
    "flight": "airplane", "directions_car": "car.fill", "train": "tram.fill",
    "directions_walk": "figure.walk", "directions_bike": "bicycle",

    // Device and system
    "wifi": "wifi", "wifi_off": "wifi.slash",
    "bluetooth": "dot.radiowaves.left.and.right",
    "signal_cellular_alt": "cellularbars", "battery_full": "battery.100",
    "battery_charging_full": "battery.100.bolt", "power_settings_new": "power",
    "brightness_high": "sun.max.fill", "brightness_low": "sun.min.fill",
    "brightness_6": "sun.max", "dark_mode": "moon.fill", "light_mode": "sun.max.fill",
    "flash_on": "bolt.fill", "flash_off": "bolt.slash.fill",
    "flashlight_on": "flashlight.on.fill", "flashlight_off": "flashlight.off.fill",
    "phone_iphone": "iphone", "tablet": "ipad", "laptop": "laptopcomputer",
    "computer": "desktopcomputer", "devices": "laptopcomputer.and.iphone",
    "watch": "applewatch", "tv": "tv", "keyboard": "keyboard", "mouse": "computermouse",
    "storage": "internaldrive", "memory": "memorychip", "cloud": "cloud.fill",
    "cloud_upload": "icloud.and.arrow.up", "cloud_download": "icloud.and.arrow.down",
    "cloud_off": "icloud.slash", "backup": "arrow.clockwise.icloud",

    // Text formatting
    "format_bold": "bold", "format_italic": "italic",
    "format_underlined": "underline", "format_size": "textformat.size",
    "text_fields": "textformat", "title": "textformat", "translate": "character.bubble",
    "format_align_left": "text.alignleft", "format_align_center": "text.aligncenter",
    "format_align_right": "text.alignright", "format_align_justify": "text.justify",
    "linear_scale": "slider.horizontal.below.rectangle",
    "palette": "paintpalette.fill", "brush": "paintbrush.fill",
    "color_lens": "paintpalette", "colorize": "eyedropper",

    // Weather
    "wb_sunny": "sun.max.fill", "wb_cloudy": "cloud.fill",
    "ac_unit": "snowflake", "water_drop": "drop.fill", "umbrella": "umbrella.fill",
    "thermostat": "thermometer", "air": "wind",

    // Misc
    "circle": "circle.fill", "square": "square.fill", "rectangle": "rectangle.fill",
    "lightbulb": "lightbulb.fill", "bolt": "bolt.fill", "extension": "puzzlepiece.fill",
    "build": "hammer.fill", "handyman": "wrench.and.screwdriver.fill",
    "science": "flask.fill", "school": "graduationcap.fill", "work": "briefcase.fill",
    "language": "globe", "public": "globe", "pets": "pawprint.fill",
    "local_fire_department": "flame.fill", "restaurant": "fork.knife",
    "local_cafe": "cup.and.saucer.fill", "fitness_center": "dumbbell.fill",
    "sports_esports": "gamecontroller.fill", "emoji_events": "trophy.fill",
    "auto_awesome": "sparkles", "animation": "circle.hexagongrid",
    "rocket_launch": "rocket.fill",
    "psychology": "brain", "gavel": "hammer",
    "qr_code": "qrcode", "qr_code_scanner": "qrcode.viewfinder",
    "hub": "point.3.connected.trianglepath.dotted",
    "barcode": "barcode", "nfc": "wave.3.right", "sensors": "sensor.fill",
    "accessibility": "figure.stand", "accessible": "figure.roll",
    "touch_app": "hand.tap.fill", "waving_hand": "hand.wave.fill",
    "radio_button_checked": "circle.inset.filled", "toggle_on": "switch.2",
    "more_time": "clock.badge.checkmark", "hourglass_empty": "hourglass",
    "pending": "ellipsis.circle", "cached": "arrow.triangle.2.circlepath",
    "swap_horiz": "arrow.left.arrow.right", "swap_vert": "arrow.up.arrow.down",
    "open_in_full": "arrow.up.left.and.arrow.down.right",
    "close_fullscreen": "arrow.down.right.and.arrow.up.left",
  ]

  /// Semantic fallbacks for symbols introduced after Ruflet's deployment
  /// floor. A current Apple OS should show the closest native meaning; older
  /// systems still receive a visible native icon rather than a blank image.
  private static let unavailableSymbolFallbacks: [String: String] = [
    "rocket_launch": "paperplane.fill",
  ]
}

/// Registers and exposes the exact font shipped with the pinned Flutter SDK.
/// Registration is process-idempotent and remains internal to RufletUI's
/// resource bundle, so an application does not have to edit Info.plist.
enum MaterialIconsFont {
  static let registrationSucceeded: Bool = {
    guard let url = Bundle.module.url(
      forResource: "MaterialIcons-Regular", withExtension: "otf") else { return false }
    var error: Unmanaged<CFError>?
    let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    if registered { return true }
    // CoreText reports alreadyRegistered when another Ruflet view initialized
    // the font first; the named font being constructible is authoritative.
    let font = CTFontCreateWithName(
      MaterialIconGlyphs.postScriptName as CFString, 16, nil)
    return CTFontCopyPostScriptName(font) as String == MaterialIconGlyphs.postScriptName
  }()

  static func font(size: CGFloat) -> Font {
    _ = registrationSucceeded
    return .custom(MaterialIconGlyphs.postScriptName, size: size)
  }

  static func glyphString(codepoint: Int) -> String? {
    UnicodeScalar(codepoint).map(String.init)
  }
}

/// Renders an icon prop the way every icon-bearing control needs it.
public struct RufletIcon: View {
  public let value: RufletValue?
  public var size: CGFloat?
  public var color: Color?
  var symbolWeight: Font.Weight?
  var filled: Bool
  @Environment(\.layoutDirection) private var layoutDirection
  @Environment(\.rufletExtensions) private var extensions

  public init(value: RufletValue?, size: CGFloat? = nil, color: Color? = nil) {
    self.value = value
    self.size = size
    self.color = color
    symbolWeight = nil
    filled = false
  }

  init(
    value: RufletValue?, size: CGFloat?, color: Color?,
    symbolWeight: Font.Weight?, filled: Bool
  ) {
    self.value = value
    self.size = size
    self.color = color
    self.symbolWeight = symbolWeight
    self.filled = filled
  }

  public var body: some View {
    if let code = value?.intValue,
      let custom = RufletExtensionRenderer.buildIcon(
        code: code, extensions: extensions)
    {
      custom
        .font(size.map { Font.system(size: $0, weight: symbolWeight ?? .regular) })
        .modifier(ExplicitIconColor(color: color))
        .accessibilityHidden(true)
    } else {
      standardIcon
    }
  }

  @ViewBuilder
  private var standardIcon: some View {
    switch IconMapping.rendering(for: value) {
    case .materialGlyph(let codepoint, let name):
      if let glyph = MaterialIconsFont.glyphString(codepoint: codepoint) {
        Text(glyph)
          .font(MaterialIconsFont.font(size: size ?? 24))
          .lineLimit(1)
          .frame(width: size ?? 24, height: size ?? 24, alignment: .center)
          .scaleEffect(
            x: layoutDirection == .rightToLeft
              && MaterialIconGlyphs.matchesTextDirection(name: name) ? -1 : 1,
            y: 1)
          .modifier(ExplicitIconColor(color: color))
          .accessibilityHidden(true)
      }
    case .systemSymbol(let symbol):
      Image(systemName: symbol)
        .font(size.map { Font.system(size: $0, weight: symbolWeight ?? .regular) })
        .modifier(IconSymbolFill(filled: filled))
        .modifier(ExplicitIconColor(color: color))
    case nil:
      EmptyView()
    }
  }
}

private struct IconSymbolFill: ViewModifier {
  let filled: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if filled { content.symbolVariant(.fill) } else { content }
  }
}

/// Passing nil to `foregroundColor` clears the inherited button/list style on
/// some SwiftUI releases. Omitted Ruby colour means inherit, so apply the
/// modifier only for an explicit colour.
private struct ExplicitIconColor: ViewModifier {
  let color: Color?

  func body(content: Content) -> some View {
    if let color { content.foregroundColor(color) } else { content }
  }
}
