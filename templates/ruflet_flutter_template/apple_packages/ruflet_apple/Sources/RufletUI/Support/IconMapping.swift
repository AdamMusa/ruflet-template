import RufletEngine
import RufletProtocol
import SwiftUI
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
    case systemSymbol(String)
  }

  /// Names suitable for an icon browser hosted by this Apple renderer.
  /// Incoming Material names remain a wire-compatibility concern only; an
  /// iOS/macOS UI never advertises Android's icon catalog.
  public static var searchableNames: [String] { MaterialIconNames.cupertino }

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
        // The wire name is cross-platform; the artwork is not. Apple must
        // always render native SF Symbols rather than leaking Android's
        // Material font whenever the curated table has no exact entry.
        return .systemSymbol(symbol(forMaterialName: descriptor.name))
      case .cupertino:
        return .systemSymbol(symbol(forCupertinoName: descriptor.name))
      }
    }

    guard let rawName = value.stringValue else { return nil }
    if rawName.lowercased().hasPrefix("cupertinoicons.") {
      return .systemSymbol(symbol(forCupertinoName: rawName))
    }
    if MaterialIconNames.material.contains(canonical(rawName).uppercased()) {
      let symbol = symbol(forMaterialName: rawName)
      return .systemSymbol(symbol)
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
    if let fallback = availableFallback(for: name) { return fallback }

    // Flet's two catalogs share many exact logical names. Resolve that exact
    // intersection through the Cupertino catalog before considering an icon
    // unmapped; never infer meaning from a substring of the Material name.
    if cupertinoNames.contains(name) {
      return symbol(forCupertinoName: name)
    }

    // Variants share a base icon: ADD_OUTLINED, ADD_ROUNDED, ADD_SHARP all
    // mean ADD, and Apple has no equivalent distinction.
    for suffix in ["_outlined", "_rounded", "_sharp"] where name.hasSuffix(suffix) {
      let base = String(name.dropLast(suffix.count))
      if let mapped = table[base], isAvailable(mapped) { return mapped }
      if let fallback = availableFallback(for: base) { return fallback }
      if cupertinoNames.contains(base) { return symbol(forCupertinoName: base) }
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
    if let fallback = cupertinoUnavailableFallbacks[name]?.first(where: isAvailable) {
      return fallback
    }

    let candidates = cupertinoCandidates(for: name)
    if let symbol = candidates.first(where: isAvailable) { return symbol }

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

  /// Internal test hook for corpus regressions. Mapping to a non-placeholder
  /// string is insufficient if that SF Symbol does not exist on the runtime.
  static func nativeSymbolExists(_ symbol: String) -> Bool {
    isAvailable(symbol)
  }

  private static let cupertinoNames = Set(MaterialIconNames.cupertino.map(canonical))

  /// Exact deployment-floor fallbacks for newer SF Symbols. These aliases are
  /// keyed by the full Cupertino wire name; no substring or category guessing
  /// is permitted in the Apple renderer.
  private static let cupertinoUnavailableFallbacks: [String: [String]] = [
    "doc_checkmark": ["doc.badge.checkmark", "checkmark.circle", "doc"],
    "doc_checkmark_fill": ["doc.badge.checkmark.fill", "checkmark.circle.fill", "doc.fill"],
    "rocket": ["rocket", "arrow.up.right"],
    "rocket_fill": ["rocket.fill", "rocket", "arrow.up.right"],
  ]

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

    // Flutter Cupertino vocabulary whose spelling is semantic rather than a
    // mechanical underscore-to-dot conversion. Keep every alias explicit: an
    // Apple icon must never be guessed from a substring of the wire name.
    "antenna_radiowaves_left_right": "antenna.radiowaves.left.and.right",
    "arrow_down_right_arrow_up_left": "arrow.down.right.and.arrow.up.left",
    "arrow_left_right": "arrow.left.arrow.right",
    "arrow_left_right_circle": "arrow.left.arrow.right.circle",
    "arrow_left_right_circle_fill": "arrow.left.arrow.right.circle.fill",
    "arrow_left_right_square": "arrow.left.arrow.right.square",
    "arrow_left_right_square_fill": "arrow.left.arrow.right.square.fill",
    "arrow_up_down": "arrow.up.arrow.down",
    "arrow_up_down_circle": "arrow.up.arrow.down.circle",
    "arrow_up_down_circle_fill": "arrow.up.arrow.down.circle.fill",
    "arrow_up_down_square": "arrow.up.arrow.down.square",
    "arrow_up_down_square_fill": "arrow.up.arrow.down.square.fill",
    "bars": "chart.bar", "battery_25_percent": "battery.25",
    "battery_75_percent": "battery.75", "battery_charging": "battery.100.bolt",
    "battery_empty": "battery.0", "battery_full": "battery.100",
    "bitcoin": "bitcoinsign", "bitcoin_circle": "bitcoinsign.circle",
    "bitcoin_circle_fill": "bitcoinsign.circle.fill", "bluetooth": "wave.3.right",
    "brightness": "sun.max", "brightness_solid": "sun.max.fill",
    "bubble_left_bubble_right": "bubble.left.and.bubble.right",
    "bubble_left_bubble_right_fill": "bubble.left.and.bubble.right.fill",
    "calendar_today": "calendar", "car_detailed": "car",
    "chart_bar_alt_fill": "chart.bar.fill", "chart_bar_circle_fill": "chart.bar.fill",
    "chart_bar_square": "chart.bar", "chart_bar_square_fill": "chart.bar.fill",
    "chat_bubble": "bubble.left", "chat_bubble_fill": "bubble.left.fill",
    "chat_bubble_2": "bubble.left.and.bubble.right",
    "chat_bubble_2_fill": "bubble.left.and.bubble.right.fill",
    "chat_bubble_text": "bubble.left", "chat_bubble_text_fill": "bubble.left.fill",
    "checkmark_alt": "checkmark", "checkmark_alt_circle": "checkmark.circle",
    "checkmark_alt_circle_fill": "checkmark.circle.fill", "chevron_back": "chevron.left",
    "circle_filled": "circle.fill", "clear_thick": "xmark",
    "clear_thick_circled": "xmark.circle", "cloud_download": "icloud.and.arrow.down",
    "cloud_download_fill": "icloud.and.arrow.down.fill", "cloud_upload": "icloud.and.arrow.up",
    "cloud_upload_fill": "icloud.and.arrow.up.fill", "collections": "square.stack",
    "collections_solid": "square.stack.fill", "color_filter": "circle.lefthalf.filled",
    "color_filter_fill": "circle.lefthalf.filled", "compass": "safari",
    "compass_fill": "safari.fill", "conversation_bubble": "bubble.left.and.bubble.right",
    "create": "pencil", "create_solid": "pencil", "delete_simple": "trash",
    "device_desktop": "desktopcomputer", "device_laptop": "laptopcomputer",
    "device_phone_landscape": "iphone.landscape", "device_phone_portrait": "iphone",
    "doc_chart": "doc.text", "doc_chart_fill": "doc.text.fill",
    "doc_checkmark": "doc.badge.checkmark", "doc_checkmark_fill": "doc.badge.checkmark.fill",
    "doc_person": "person.text.rectangle", "doc_person_fill": "person.text.rectangle.fill",
    "doc_text_search": "doc.text.magnifyingglass",
    "dot_radiowaves_left_right": "dot.radiowaves.left.and.right",
    "double_music_note": "music.note.list", "down_arrow": "arrow.down",
    "download_circle": "arrow.down.circle", "download_circle_fill": "arrow.down.circle.fill",
    "ellipsis_vertical": "ellipsis", "ellipsis_vertical_circle": "ellipsis.circle",
    "ellipsis_vertical_circle_fill": "ellipsis.circle.fill", "floppy_disk": "externaldrive",
    "fullscreen": "arrow.up.left.and.arrow.down.right",
    "fullscreen_exit": "arrow.down.right.and.arrow.up.left",
    "game_controller": "gamecontroller", "game_controller_solid": "gamecontroller.fill",
    "gamecontroller_alt_fill": "gamecontroller.fill", "gear_alt": "gearshape",
    "gear_alt_fill": "gearshape.fill", "gear_big": "gearshape",
    "gift_alt": "gift", "gift_alt_fill": "gift.fill", "graph_circle": "chart.xyaxis.line",
    "graph_circle_fill": "chart.xyaxis.line", "graph_square": "chart.xyaxis.line",
    "graph_square_fill": "chart.xyaxis.line", "group": "person.2",
    "group_solid": "person.2.fill", "house_alt": "house", "house_alt_fill": "house.fill",
    "infinite": "infinity", "lab_flask": "flask", "lab_flask_solid": "flask.fill",
    "layers": "square.3.layers.3d", "layers_fill": "square.3.layers.3d",
    "layers_alt": "square.3.layers.3d", "layers_alt_fill": "square.3.layers.3d",
    "loop": "arrow.triangle.2.circlepath", "loop_thick": "arrow.triangle.2.circlepath",
    "map_pin": "mappin", "map_pin_ellipse": "mappin.circle",
    "map_pin_slash": "mappin.slash", "mic_off": "mic.slash",
    "money_dollar": "dollarsign", "money_dollar_circle": "dollarsign.circle",
    "money_dollar_circle_fill": "dollarsign.circle.fill", "money_euro": "eurosign",
    "money_euro_circle": "eurosign.circle", "money_euro_circle_fill": "eurosign.circle.fill",
    "money_pound": "sterlingsign", "money_pound_circle": "sterlingsign.circle",
    "money_pound_circle_fill": "sterlingsign.circle.fill", "money_rubl": "rublesign",
    "money_rubl_circle": "rublesign.circle", "money_rubl_circle_fill": "rublesign.circle.fill",
    "money_yen": "yensign", "money_yen_circle": "yensign.circle",
    "money_yen_circle_fill": "yensign.circle.fill",
    "move": "arrow.up.and.down.and.arrow.left.and.right",
    "music_albums": "square.stack", "music_albums_fill": "square.stack.fill",
    "music_note_2": "music.note", "news": "newspaper", "news_solid": "newspaper.fill",
    "padlock": "lock", "padlock_solid": "lock.fill", "paw": "pawprint",
    "paw_solid": "pawprint.fill", "pen": "pencil", "pencil_ellipsis_rectangle": "square.and.pencil",
    "pencil_outline": "pencil", "person_2_alt": "person.2", "person_add": "person.badge.plus",
    "person_add_solid": "person.badge.plus", "person_alt": "person",
    "person_alt_circle": "person.crop.circle", "person_alt_circle_fill": "person.crop.circle.fill",
    "photo_camera_solid": "camera.fill", "piano": "pianokeys",
    "placemark": "mappin.circle", "placemark_fill": "mappin.circle.fill",
    "profile_circled": "person.crop.circle", "question_diamond": "questionmark.diamond",
    "question_diamond_fill": "questionmark.diamond.fill", "question_square": "questionmark.square",
    "question_square_fill": "questionmark.square.fill",
    "rectangle_arrow_up_right_arrow_down_left": "arrow.up.left.and.arrow.down.right",
    "rectangle_arrow_up_right_arrow_down_left_slash": "arrow.down.right.and.arrow.up.left",
    "rectangle_paperclip": "paperclip", "refresh": "arrow.clockwise",
    "refresh_bold": "arrow.clockwise", "refresh_circled": "arrow.clockwise.circle",
    "refresh_circled_solid": "arrow.clockwise.circle.fill", "refresh_thick": "arrow.clockwise",
    "refresh_thin": "arrow.clockwise", "reply": "arrowshape.turn.up.left",
    "reply_all": "arrowshape.turn.up.left.2", "reply_thick_solid": "arrowshape.turn.up.left.fill",
    "resize": "arrow.up.left.and.arrow.down.right",
    "resize_h": "arrow.left.and.right", "resize_v": "arrow.up.and.down",
    "return_icon": "arrow.turn.down.left", "rocket": "rocket", "rocket_fill": "rocket.fill",
    "scissors_alt": "scissors", "share": "square.and.arrow.up",
    "share_solid": "square.and.arrow.up.fill", "share_up": "square.and.arrow.up",
    "shopping_cart": "cart", "shuffle_medium": "shuffle", "shuffle_thick": "shuffle",
    "sort_down": "arrow.down", "sort_down_circle": "arrow.down.circle",
    "sort_down_circle_fill": "arrow.down.circle.fill", "sort_up": "arrow.up",
    "sort_up_circle": "arrow.up.circle", "sort_up_circle_fill": "arrow.up.circle.fill",
    "square_arrow_down_fill": "arrow.down.square.fill",
    "square_arrow_down_on_square": "square.and.arrow.down",
    "square_arrow_down_on_square_fill": "square.and.arrow.down.fill",
    "square_arrow_left_fill": "arrow.left.square.fill",
    "square_arrow_right_fill": "arrow.right.square.fill",
    "square_arrow_up_fill": "arrow.up.square.fill",
    "square_arrow_up_on_square": "square.and.arrow.up",
    "square_arrow_up_on_square_fill": "square.and.arrow.up.fill",
    "square_favorites": "heart.square", "square_favorites_fill": "heart.square.fill",
    "square_favorites_alt": "heart.square", "square_favorites_alt_fill": "heart.square.fill",
    "square_fill_line_vertical_square": "rectangle.split.2x1",
    "square_fill_line_vertical_square_fill": "rectangle.split.2x1.fill",
    "square_line_vertical_square": "rectangle.split.2x1",
    "square_line_vertical_square_fill": "rectangle.split.2x1.fill",
    "square_list": "list.bullet.rectangle", "square_list_fill": "list.bullet.rectangle.fill",
    "square_pencil": "square.and.pencil", "square_pencil_fill": "square.and.pencil",
    "switch_camera": "arrow.triangle.2.circlepath.camera",
    "switch_camera_solid": "arrow.triangle.2.circlepath.camera.fill",
    "tags": "tag", "tags_solid": "tag.fill", "tickets": "ticket",
    "tickets_fill": "ticket.fill", "time": "clock", "time_solid": "clock.fill",
    "today": "calendar", "today_fill": "calendar", "train_style_one": "tram",
    "train_style_two": "tram.fill", "tray_arrow_down": "tray.and.arrow.down",
    "tray_arrow_down_fill": "tray.and.arrow.down.fill", "tray_arrow_up": "tray.and.arrow.up",
    "tray_arrow_up_fill": "tray.and.arrow.up.fill", "up_arrow": "arrow.up",
    "upload_circle": "arrow.up.circle", "upload_circle_fill": "arrow.up.circle.fill",
    "video_camera": "video", "video_camera_solid": "video.fill", "videocam": "video",
    "videocam_fill": "video.fill", "videocam_circle": "video.circle",
    "videocam_circle_fill": "video.circle.fill", "volume_down": "speaker.wave.1",
    "volume_mute": "speaker.slash", "volume_off": "speaker.slash.fill",
    "volume_up": "speaker.wave.3", "wand_rays": "wand.and.rays",
    "wand_rays_inverse": "wand.and.rays.inverse", "wand_stars": "wand.and.stars",
    "wand_stars_inverse": "wand.and.stars.inverse", "zoom_in": "plus.magnifyingglass",
    "zoom_out": "minus.magnifyingglass",
  ]

  /// Material name to SF Symbol. Covers the icons Ruflet applications actually
  /// reach for; anything else falls back to a visible placeholder rather than
  /// disappearing, so a missing mapping is obvious on screen.
  private static let table: [String: String] = [
    // Navigation
    "add_home": "house.badge.plus", "add_home_work": "house.badge.plus",
    "broadcast_on_home": "house.badge.wifi", "home_work": "house",
    "home_repair_service": "wrench.and.screwdriver",
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
    "apps": "square.grid.2x2", "widgets": "square.grid.2x2.fill",
    "dashboard": "square.grid.2x2.fill",
    "home": "house", "home_filled": "house.fill",

    // Actions
    "search": "magnifyingglass", "settings": "gearshape.fill", "tune": "slider.horizontal.3",
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
    "photo_camera": "camera.fill", "photo": "photo", "image": "photo.fill",
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
    "view_list": "list.bullet", "view_module": "square.grid.3x3.fill",
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
    "auto_awesome": "sparkles", "animation": "circle.hexagongrid.fill",
    // Rocket is available on newer Apple systems. Resolution is runtime
    // guarded below, so deployment-floor devices receive a launch arrow while
    // current iOS/macOS render the actual native rocket requested by Ruby.
    "rocket": "rocket", "rocket_launch": "rocket.fill",
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
  private static let unavailableSymbolFallbacks: [String: [String]] = [
    "add_home": ["house.badge.plus", "house"],
    "add_home_work": ["house.badge.plus", "house"],
    "broadcast_on_home": ["house.badge.wifi", "house"],
    "rocket": ["rocket", "arrow.up.right", "arrow.up"],
    "rocket_launch": ["rocket.fill", "rocket", "arrow.up.right", "arrow.up"],
    "view_module": ["square.grid.3x3.fill", "square.grid.3x3", "square.grid.2x2.fill"],
    "widgets": ["square.grid.2x2.fill", "square.grid.2x2", "shippingbox.fill"],
    "animation": ["circle.hexagongrid.fill", "circle.hexagongrid", "arrow.triangle.2.circlepath"],
  ]

  private static func availableFallback(for materialName: String) -> String? {
    unavailableSymbolFallbacks[materialName]?.first(where: isAvailable)
  }
}

/// Renders an icon prop the way every icon-bearing control needs it.
public struct RufletIcon: View {
  public let value: RufletValue?
  public var size: CGFloat?
  public var color: Color?
  var symbolWeight: Font.Weight?
  var filled: Bool
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
