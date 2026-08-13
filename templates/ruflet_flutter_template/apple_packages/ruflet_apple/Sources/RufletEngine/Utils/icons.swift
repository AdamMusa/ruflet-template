import CoreText
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Native Apple artwork resolved from a Flet icon wire value.
///
/// Material integer values are protocol identities only. They are never
/// rendered with the Material font on Apple: each value is translated to an
/// SF Symbol or to the corresponding glyph in Apple's Cupertino icon family.
public enum RufletAppleIcon: Equatable, Sendable {
  case systemSymbol(String)
  case cupertinoGlyph(UInt32)
}

/// Canonical Flet Material/Cupertino wire catalogs and their Apple artwork.
public enum RufletAppleIconCatalog {
  public static let materialFirstCode = 65_536
  public static let cupertinoFirstCode = 131_072

  public static var materialCount: Int { catalogs.materialNamesByCode.count }
  public static var cupertinoCount: Int { catalogs.cupertinoNamesByCode.count }

  public static func icon(for code: Int) -> RufletAppleIcon? {
    if let name = catalogs.cupertinoNamesByCode[code],
       let glyph = catalogs.cupertinoGlyphs[name]
    {
      return .cupertinoGlyph(glyph)
    }

    guard let materialName = catalogs.materialNamesByCode[code] else { return nil }
    return icon(forMaterialName: materialName)
  }

  public static func icon(forMaterialName rawName: String) -> RufletAppleIcon? {
    let name = canonical(rawName)

    for candidate in materialSemanticCandidates(name) {
      if let glyph = cupertinoGlyph(named: candidate) {
        return .cupertinoGlyph(glyph)
      }
      if let symbol = explicitSystemSymbols[candidate], systemSymbolExists(symbol) {
        return .systemSymbol(symbol)
      }
      if let symbol = systemSymbolCandidate(for: candidate), systemSymbolExists(symbol) {
        return .systemSymbol(symbol)
      }
    }
    return nil
  }

  public static func icon(forCupertinoName rawName: String) -> RufletAppleIcon? {
    cupertinoGlyph(named: rawName).map(RufletAppleIcon.cupertinoGlyph)
  }

  public static func materialName(for code: Int) -> String? {
    catalogs.materialNamesByCode[code]
  }

  public static func cupertinoName(for code: Int) -> String? {
    catalogs.cupertinoNamesByCode[code]
  }

  private static func cupertinoGlyph(named rawName: String) -> UInt32? {
    catalogs.cupertinoGlyphs[canonical(rawName).uppercased()]
  }

  private static func materialSemanticCandidates(_ name: String) -> [String] {
    var result: [String] = []
    func append(_ value: String) {
      if !result.contains(value) { result.append(value) }
    }

    if let exact = materialToCupertino[name] { append(exact) }
    append(name)

    var base = name
    for suffix in ["_outlined", "_rounded", "_sharp"] where base.hasSuffix(suffix) {
      base.removeLast(suffix.count)
      if let exact = materialToCupertino[base] { append(exact) }
      append(base)
      break
    }
    return result
  }

  private static func systemSymbolCandidate(for name: String) -> String? {
    let candidate = name
      .replacingOccurrences(of: "_fill", with: ".fill")
      .replacingOccurrences(of: "_filled", with: ".fill")
      .replacingOccurrences(of: "_", with: ".")
    return candidate.isEmpty ? nil : candidate
  }

  private static func canonical(_ rawName: String) -> String {
    rawName
      .lowercased()
      .replacingOccurrences(of: "cupertinoicons.", with: "")
      .replacingOccurrences(of: "icons.", with: "")
      .replacingOccurrences(of: "-", with: "_")
      .replacingOccurrences(of: " ", with: "_")
  }

  private static func systemSymbolExists(_ name: String) -> Bool {
    #if canImport(UIKit)
    return UIImage(systemName: name) != nil
    #elseif canImport(AppKit)
    return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    #else
    return false
    #endif
  }

  /// Vocabulary changes between Material names and Apple's native catalog.
  /// Variant suffixes are handled independently above.
  private static let materialToCupertino: [String: String] = [
    "account_circle": "person_circle",
    "add_circle": "add_circled_solid",
    "add_circle_outline": "add_circled",
    "animation": "circle_grid_hex_fill",
    "apps": "square_grid_2x2",
    "arrow_back": "chevron_back",
    "arrow_back_ios": "chevron_back",
    "arrow_back_ios_new": "chevron_back",
    "arrow_drop_down": "chevron_down",
    "arrow_drop_up": "chevron_up",
    "arrow_forward": "chevron_forward",
    "arrow_forward_ios": "chevron_forward",
    "auto_awesome": "sparkles",
    "bar_chart": "chart_bar_fill",
    "cancel": "clear_circled_solid",
    "check": "check_mark",
    "check_circle": "check_mark_circled_solid",
    "check_circle_outline": "check_mark_circled",
    "close": "clear",
    "delete": "delete",
    "done": "check_mark",
    "done_all": "checkmark_alt_circle_fill",
    "email": "mail_solid",
    "expand_less": "chevron_up",
    "expand_more": "chevron_down",
    "favorite": "heart_fill",
    "favorite_border": "heart",
    "folder": "folder_fill",
    "folder_open": "folder_open",
    "grid_view": "square_grid_2x2",
    "home": "home",
    "hub": "circle_grid_hex_fill",
    "image": "photo_fill",
    "keyboard_arrow_down": "chevron_down",
    "keyboard_arrow_left": "chevron_left",
    "keyboard_arrow_right": "chevron_right",
    "keyboard_arrow_up": "chevron_up",
    "mail": "mail_solid",
    "menu": "bars",
    "more_horiz": "ellipsis",
    "more_vert": "ellipsis_vertical",
    "pause": "pause_solid",
    "person": "person_fill",
    "photo": "photo",
    "photo_library": "photo_on_rectangle",
    "pie_chart": "chart_pie_fill",
    "play_arrow": "play_arrow_solid",
    "play_circle": "play_circle_fill",
    "radio_button_checked": "circle_filled",
    "remove": "minus",
    "remove_circle": "minus_circle_fill",
    "rocket": "rocket",
    "rocket_launch": "rocket",
    "search": "search",
    "send": "paperplane_fill",
    "settings": "settings_solid",
    "share": "share",
    "show_chart": "graph_square",
    "star": "star_fill",
    "star_border": "star",
    "stop": "stop_fill",
    "widgets": "square_grid_2x2_fill",
  ]

  private static let explicitSystemSymbols: [String: String] = [
    "add_home": "house.badge.plus",
    "add_home_work": "house.badge.plus",
    "broadcast_on_home": "house.badge.wifi",
    "home_work": "house",
    "home_repair_service": "wrench.and.screwdriver",
    "add": "plus",
    "add_circle": "plus.circle.fill",
    "add_circle_outline": "plus.circle",
    "add_box": "plus.square",
    "remove": "minus",
    "remove_circle": "minus.circle.fill",
    "remove_circle_outline": "minus.circle",
    "close": "xmark",
    "clear": "xmark",
    "cancel": "xmark.circle.fill",
    "check": "checkmark",
    "done": "checkmark",
    "done_all": "checkmark.circle.fill",
    "check_circle": "checkmark.circle.fill",
    "check_circle_outline": "checkmark.circle",
    "check_box": "checkmark.square.fill",
    "check_box_outline_blank": "square",
    "arrow_back": "chevron.left",
    "arrow_forward": "chevron.right",
    "arrow_back_ios": "chevron.left",
    "arrow_back_ios_new": "chevron.left",
    "arrow_forward_ios": "chevron.right",
    "arrow_upward": "arrow.up",
    "arrow_downward": "arrow.down",
    "arrow_left": "arrow.left",
    "arrow_right": "arrow.right",
    "arrow_drop_down": "chevron.down",
    "arrow_drop_up": "chevron.up",
    "arrow_drop_down_circle": "chevron.down.circle.fill",
    "keyboard_arrow_down": "chevron.down",
    "keyboard_arrow_up": "chevron.up",
    "keyboard_arrow_left": "chevron.left",
    "keyboard_arrow_right": "chevron.right",
    "expand_more": "chevron.down",
    "expand_less": "chevron.up",
    "chevron_left": "chevron.left",
    "chevron_right": "chevron.right",
    "first_page": "chevron.left.2",
    "last_page": "chevron.right.2",
    "menu": "line.3.horizontal",
    "more_vert": "ellipsis",
    "more_horiz": "ellipsis",
    "apps": "square.grid.2x2",
    "widgets": "square.grid.2x2.fill",
    "dashboard": "square.grid.2x2.fill",
    "home": "house",
    "home_filled": "house.fill",
    "search": "magnifyingglass",
    "settings": "gearshape.fill",
    "tune": "slider.horizontal.3",
    "filter_list": "line.3.horizontal.decrease",
    "filter_alt": "line.3.horizontal.decrease.circle",
    "sort": "arrow.up.arrow.down",
    "refresh": "arrow.clockwise",
    "sync": "arrow.triangle.2.circlepath",
    "edit": "pencil",
    "create": "pencil",
    "mode_edit": "pencil",
    "edit_note": "square.and.pencil",
    "delete": "trash",
    "delete_forever": "trash.fill",
    "delete_outline": "trash",
    "save": "square.and.arrow.down",
    "save_alt": "square.and.arrow.down",
    "download": "arrow.down.circle",
    "file_download": "arrow.down.circle",
    "upload": "arrow.up.circle",
    "file_upload": "arrow.up.circle",
    "upload_file": "doc.badge.arrow.up",
    "share": "square.and.arrow.up",
    "ios_share": "square.and.arrow.up",
    "content_copy": "doc.on.doc",
    "content_paste": "doc.on.clipboard",
    "content_cut": "scissors",
    "undo": "arrow.uturn.backward",
    "redo": "arrow.uturn.forward",
    "print": "printer",
    "open_in_new": "arrow.up.forward.square",
    "link": "link",
    "code": "chevron.left.forwardslash.chevron.right",
    "attach_file": "paperclip",
    "send": "paperplane.fill",
    "reply": "arrowshape.turn.up.left",
    "forward": "arrowshape.turn.up.right",
    "logout": "rectangle.portrait.and.arrow.right",
    "login": "arrow.right.square",
    "exit_to_app": "rectangle.portrait.and.arrow.right",
    "zoom_in": "plus.magnifyingglass",
    "zoom_out": "minus.magnifyingglass",
    "fullscreen": "arrow.up.left.and.arrow.down.right",
    "fullscreen_exit": "arrow.down.right.and.arrow.up.left",
    "open_with": "arrow.up.left.and.arrow.down.right",
    "unfold_less": "arrow.up.and.down.and.arrow.left.and.right",
    "drag_handle": "line.3.horizontal",
    "drag_indicator": "line.3.horizontal",
    "info": "info.circle",
    "info_outline": "info.circle",
    "help": "questionmark.circle",
    "help_outline": "questionmark.circle",
    "question_mark": "questionmark",
    "warning": "exclamationmark.triangle.fill",
    "warning_amber": "exclamationmark.triangle",
    "error": "exclamationmark.octagon.fill",
    "error_outline": "exclamationmark.octagon",
    "report_problem": "exclamationmark.triangle",
    "priority_high": "exclamationmark",
    "verified": "checkmark.seal.fill",
    "verified_user": "checkmark.shield.fill",
    "new_releases": "burst.fill",
    "block": "nosign",
    "do_not_disturb": "moon.zzz",
    "star": "star.fill",
    "star_border": "star",
    "star_outline": "star",
    "star_half": "star.leadinghalf.filled",
    "grade": "star.fill",
    "favorite": "heart.fill",
    "favorite_border": "heart",
    "thumb_up": "hand.thumbsup.fill",
    "thumb_down": "hand.thumbsdown.fill",
    "bookmark": "bookmark.fill",
    "bookmark_border": "bookmark",
    "flag": "flag.fill",
    "label": "tag.fill",
    "visibility": "eye",
    "visibility_off": "eye.slash",
    "lock": "lock.fill",
    "lock_open": "lock.open.fill",
    "lock_outline": "lock",
    "key": "key.fill",
    "shield": "shield.fill",
    "security": "lock.shield",
    "fingerprint": "touchid",
    "vpn_key": "key.fill",
    "person": "person.fill",
    "person_outline": "person",
    "people": "person.2.fill",
    "group": "person.3.fill",
    "account_circle": "person.crop.circle",
    "account_box": "person.crop.square",
    "supervisor_account": "person.2.badge.gearshape",
    "face": "face.smiling",
    "mail": "envelope.fill",
    "email": "envelope.fill",
    "mail_outline": "envelope",
    "inbox": "tray.fill",
    "drafts": "envelope.open",
    "message": "message.fill",
    "chat": "bubble.left.fill",
    "chat_bubble": "bubble.left.fill",
    "chat_bubble_outline": "bubble.left",
    "forum": "bubble.left.and.bubble.right.fill",
    "comment": "bubble.right",
    "call": "phone.fill",
    "phone": "phone.fill",
    "call_end": "phone.down.fill",
    "videocam": "video.fill",
    "videocam_off": "video.slash.fill",
    "notifications": "bell.fill",
    "notifications_none": "bell",
    "notifications_off": "bell.slash.fill",
    "notifications_active": "bell.badge.fill",
    "play_arrow": "play.fill",
    "play_circle": "play.circle.fill",
    "play_circle_outline": "play.circle",
    "pause": "pause.fill",
    "pause_circle": "pause.circle.fill",
    "stop": "stop.fill",
    "skip_next": "forward.end.fill",
    "skip_previous": "backward.end.fill",
    "fast_forward": "forward.fill",
    "fast_rewind": "backward.fill",
    "replay": "arrow.counterclockwise",
    "shuffle": "shuffle",
    "repeat": "repeat",
    "volume_up": "speaker.wave.2.fill",
    "volume_down": "speaker.wave.1.fill",
    "volume_off": "speaker.slash.fill",
    "volume_mute": "speaker.fill",
    "mic": "mic.fill",
    "mic_off": "mic.slash.fill",
    "headphones": "headphones",
    "audiotrack": "music.note",
    "music_note": "music.note",
    "library_music": "music.note.list",
    "camera": "camera.fill",
    "camera_alt": "camera.fill",
    "cameraswitch": "arrow.triangle.2.circlepath.camera",
    "photo_camera": "camera.fill",
    "photo": "photo",
    "image": "photo.fill",
    "photo_library": "photo.on.rectangle",
    "collections": "square.stack",
    "movie": "film",
    "video_library": "film.stack",
    "album": "square.stack.fill",
    "folder": "folder.fill",
    "folder_open": "folder.fill",
    "create_new_folder": "folder.badge.plus",
    "insert_drive_file": "doc.fill",
    "description": "doc.text.fill",
    "article": "doc.richtext",
    "note": "note.text",
    "notes": "note.text",
    "assignment": "list.clipboard",
    "list": "list.bullet",
    "list_alt": "list.bullet.rectangle",
    "format_list_bulleted": "list.bullet",
    "format_list_numbered": "list.number",
    "table_chart": "tablecells",
    "grid_view": "square.grid.2x2",
    "view_list": "list.bullet",
    "view_module": "square.grid.3x3.fill",
    "view_column": "rectangle.split.3x1",
    "view_stream": "rectangle.split.1x2",
    "tab": "rectangle.split.3x1",
    "crop_square": "square.dashed",
    "attach_money": "dollarsign.circle",
    "receipt": "receipt",
    "shopping_cart": "cart.fill",
    "shopping_bag": "bag.fill",
    "store": "storefront",
    "payment": "creditcard.fill",
    "credit_card": "creditcard.fill",
    "bar_chart": "chart.bar.fill",
    "show_chart": "chart.line.uptrend.xyaxis",
    "pie_chart": "chart.pie.fill",
    "donut_large": "chart.pie",
    "insights": "chart.line.uptrend.xyaxis",
    "trending_up": "arrow.up.right",
    "trending_down": "arrow.down.right",
    "trending_flat": "arrow.right",
    "analytics": "chart.bar.xaxis",
    "timeline": "chart.xyaxis.line",
    "leaderboard": "chart.bar.fill",
    "schedule": "clock",
    "access_time": "clock",
    "timer": "timer",
    "alarm": "alarm.fill",
    "history": "clock.arrow.circlepath",
    "today": "calendar",
    "event": "calendar",
    "date_range": "calendar",
    "calendar_today": "calendar",
    "calendar_month": "calendar",
    "place": "mappin.circle.fill",
    "location_on": "mappin.circle.fill",
    "location_off": "location.slash",
    "my_location": "location.fill",
    "map": "map.fill",
    "navigation": "location.north.fill",
    "explore": "safari",
    "near_me": "location.north.fill",
    "directions": "arrow.triangle.turn.up.right.diamond.fill",
    "flight": "airplane",
    "directions_car": "car.fill",
    "train": "tram.fill",
    "directions_walk": "figure.walk",
    "directions_bike": "bicycle",
    "wifi": "wifi",
    "wifi_off": "wifi.slash",
    "bluetooth": "dot.radiowaves.left.and.right",
    "signal_cellular_alt": "cellularbars",
    "battery_full": "battery.100",
    "battery_charging_full": "battery.100.bolt",
    "power_settings_new": "power",
    "brightness_high": "sun.max.fill",
    "brightness_low": "sun.min.fill",
    "brightness_6": "sun.max",
    "dark_mode": "moon.fill",
    "light_mode": "sun.max.fill",
    "flash_on": "bolt.fill",
    "flash_off": "bolt.slash.fill",
    "flashlight_off": "flashlight.off.fill",
    "flashlight_on": "flashlight.on.fill",
    "phone_iphone": "iphone",
    "tablet": "ipad",
    "laptop": "laptopcomputer",
    "computer": "desktopcomputer",
    "devices": "laptopcomputer.and.iphone",
    "watch": "applewatch",
    "tv": "tv",
    "keyboard": "keyboard",
    "mouse": "computermouse",
    "storage": "internaldrive",
    "memory": "memorychip",
    "cloud": "cloud.fill",
    "cloud_upload": "icloud.and.arrow.up",
    "cloud_download": "icloud.and.arrow.down",
    "cloud_off": "icloud.slash",
    "backup": "arrow.clockwise.icloud",
    "format_bold": "bold",
    "format_italic": "italic",
    "format_underlined": "underline",
    "format_size": "textformat.size",
    "text_fields": "textformat",
    "title": "textformat",
    "translate": "character.bubble",
    "format_align_center": "text.aligncenter",
    "format_align_left": "text.alignleft",
    "format_align_right": "text.alignright",
    "format_align_justify": "text.justify",
    "linear_scale": "slider.horizontal.below.rectangle",
    "palette": "paintpalette.fill",
    "brush": "paintbrush.fill",
    "color_lens": "paintpalette",
    "colorize": "eyedropper",
    "wb_sunny": "sun.max.fill",
    "wb_cloudy": "cloud.fill",
    "ac_unit": "snowflake",
    "water_drop": "drop.fill",
    "umbrella": "umbrella.fill",
    "thermostat": "thermometer",
    "air": "wind",
    "circle": "circle.fill",
    "square": "square.fill",
    "rectangle": "rectangle.fill",
    "lightbulb": "lightbulb.fill",
    "bolt": "bolt.fill",
    "extension": "puzzlepiece.fill",
    "build": "hammer.fill",
    "handyman": "wrench.and.screwdriver.fill",
    "science": "flask.fill",
    "school": "graduationcap.fill",
    "work": "briefcase.fill",
    "language": "globe",
    "public": "globe",
    "pets": "pawprint.fill",
    "local_fire_department": "flame.fill",
    "restaurant": "fork.knife",
    "local_cafe": "cup.and.saucer.fill",
    "fitness_center": "dumbbell.fill",
    "sports_esports": "gamecontroller.fill",
    "emoji_events": "trophy.fill",
    "auto_awesome": "sparkles",
    "animation": "circle.hexagongrid.fill",
    "rocket": "rocket",
    "rocket_launch": "rocket.fill",
    "psychology": "brain",
    "gavel": "hammer",
    "qr_code": "qrcode",
    "qr_code_scanner": "qrcode.viewfinder",
    "hub": "point.3.connected.trianglepath.dotted",
    "barcode": "barcode",
    "nfc": "wave.3.right",
    "sensors": "sensor.fill",
    "accessibility": "figure.stand",
    "accessible": "figure.roll",
    "touch_app": "hand.tap.fill",
    "waving_hand": "hand.wave.fill",
    "radio_button_checked": "circle.inset.filled",
    "toggle_on": "switch.2",
    "more_time": "clock.badge.checkmark",
    "hourglass_empty": "hourglass",
    "pending": "ellipsis.circle",
    "cached": "arrow.triangle.2.circlepath",
    "swap_horiz": "arrow.left.arrow.right",
    "swap_vert": "arrow.up.arrow.down",
    "open_in_full": "arrow.up.left.and.arrow.down.right",
    "close_fullscreen": "arrow.down.right.and.arrow.up.left",
  ]

  private struct Catalogs {
    let materialNamesByCode: [Int: String]
    let cupertinoNamesByCode: [Int: String]
    let cupertinoGlyphs: [String: UInt32]

    init() {
      materialNamesByCode = Self.names(resource: "material_icons")
      cupertinoNamesByCode = Self.names(resource: "cupertino_icons")
      cupertinoGlyphs = Self.glyphs(resource: "cupertino_glyphs")
    }

    private static func names(resource: String) -> [Int: String] {
      guard let url = resourceURL(
        name: resource,
        extension: "json",
        subdirectory: "IconCatalog"),
        let data = try? Data(contentsOf: url),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: NSNumber]
      else {
        preconditionFailure("Missing Ruflet icon catalog resource: \(resource).json")
      }
      return Dictionary(uniqueKeysWithValues: object.map { (Int($0.value.int64Value), $0.key) })
    }

    private static func glyphs(resource: String) -> [String: UInt32] {
      guard let url = resourceURL(
        name: resource,
        extension: "json",
        subdirectory: "IconCatalog"),
        let data = try? Data(contentsOf: url),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: NSNumber]
      else {
        preconditionFailure("Missing Ruflet icon glyph resource: \(resource).json")
      }
      return object.mapValues { UInt32(truncating: $0) }
    }

    private static func resourceURL(
      name: String,
      extension fileExtension: String,
      subdirectory: String
    ) -> URL? {
      Bundle.module.url(
        forResource: name,
        withExtension: fileExtension,
        subdirectory: subdirectory)
        ?? Bundle.module.url(forResource: name, withExtension: fileExtension)
    }
  }

  private static let catalogs = Catalogs()
}

@MainActor
public struct RufletAppleIconView: View {
  public let icon: RufletAppleIcon
  public var size: CGFloat
  public var weight: Font.Weight

  public init(icon: RufletAppleIcon, size: CGFloat = 24, weight: Font.Weight = .regular) {
    self.icon = icon
    self.size = size
    self.weight = weight
  }

  public var body: some View {
    switch icon {
    case .systemSymbol(let name):
      Image(systemName: name).font(.system(size: size, weight: weight))
    case .cupertinoGlyph(let scalar):
      Text(String(UnicodeScalar(scalar)!))
        .font(.custom(RufletCupertinoIconFont.postScriptName, size: size))
    }
  }
}

private enum RufletCupertinoIconFont {
  static let postScriptName = "CupertinoIcons"

  static func register() {
    _ = registration
  }

  private static let registration: Void = {
    guard let url = Bundle.module.url(
      forResource: "CupertinoIcons",
      withExtension: "ttf",
      subdirectory: "CupertinoIcons")
      ?? Bundle.module.url(forResource: "CupertinoIcons", withExtension: "ttf")
    else {
      preconditionFailure("Missing bundled CupertinoIcons.ttf")
    }
    var error: Unmanaged<CFError>?
    let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    if !registered,
       let description = error?.takeRetainedValue().localizedDescription,
       !description.localizedCaseInsensitiveContains("already")
    {
      preconditionFailure("Unable to register CupertinoIcons.ttf: \(description)")
    }
  }()
}

public extension RufletAppleIconView {
  static func registered(
    icon: RufletAppleIcon,
    size: CGFloat = 24,
    weight: Font.Weight = .regular
  ) -> RufletAppleIconView {
    RufletCupertinoIconFont.register()
    return RufletAppleIconView(icon: icon, size: size, weight: weight)
  }
}
