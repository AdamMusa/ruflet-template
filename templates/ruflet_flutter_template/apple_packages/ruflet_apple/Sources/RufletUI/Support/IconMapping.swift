import RufletEngine
import RufletProtocol
import SwiftUI

/// Resolves a Ruflet icon value to an SF Symbol.
///
/// Icons arrive as integers, not names: `Ruflet::Control#normalize_icon_prop`
/// runs every icon prop through `MaterialIconLookup.codepoint_for`, which
/// returns the icon's index in the gem's `icons.json`. `MaterialIconNames`
/// turns that back into the Material name, and the table below maps the name
/// onto the closest SF Symbol so the result looks native rather than like a
/// Material app wearing an Apple shell.
public enum IconMapping {
  /// The symbol for an icon prop, or nil when the value is empty.
  public static func symbol(for value: RufletValue?) -> String? {
    guard let value, !value.isNull else { return nil }
    guard let name = materialName(for: value) else { return nil }
    return symbol(forMaterialName: name)
  }

  public static func materialName(for value: RufletValue) -> String? {
    if let codepoint = value.intValue, let name = MaterialIconNames.name(forCodepoint: codepoint) {
      return name
    }
    // A host that registered its own control may pass a name straight through.
    return value.stringValue
  }

  public static func symbol(forMaterialName rawName: String) -> String {
    let name = canonical(rawName)
    if let mapped = table[name] { return mapped }

    // Variants share a base icon: ADD_OUTLINED, ADD_ROUNDED, ADD_SHARP all
    // mean ADD, and Apple has no equivalent distinction.
    for suffix in ["_outlined", "_rounded", "_sharp"] where name.hasSuffix(suffix) {
      let base = String(name.dropLast(suffix.count))
      if let mapped = table[base] { return mapped }
    }

    RufletLog.debug("No SF Symbol for Material icon `\(rawName)`")
    return "questionmark.square.dashed"
  }

  private static func canonical(_ name: String) -> String {
    name
      .lowercased()
      .replacingOccurrences(of: " ", with: "_")
      .replacingOccurrences(of: "-", with: "_")
      .replacingOccurrences(of: "icons.", with: "")
  }

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
    "sort": "arrow.up.arrow.down", "refresh": "arrow.clockwise", "sync": "arrow.triangle.2.circlepath",
    "edit": "pencil", "create": "pencil", "mode_edit": "pencil", "edit_note": "square.and.pencil",
    "delete": "trash", "delete_forever": "trash.fill", "delete_outline": "trash",
    "save": "square.and.arrow.down", "save_alt": "square.and.arrow.down",
    "download": "arrow.down.circle", "file_download": "arrow.down.circle",
    "upload": "arrow.up.circle", "file_upload": "arrow.up.circle", "upload_file": "doc.badge.arrow.up",
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
    "music_note": "music.note", "library_music": "music.note.list",
    "camera": "camera.fill", "camera_alt": "camera.fill",
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
    "pie_chart": "chart.pie.fill", "donut_large": "chart.pie", "insights": "chart.line.uptrend.xyaxis",
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
    "auto_awesome": "sparkles", "animation": "circle.hexagongrid", "rocket_launch": "paperplane.fill",
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
    "close_fullscreen": "arrow.down.right.and.arrow.up.left"
  ]
}

/// Renders an icon prop the way every icon-bearing control needs it.
struct RufletIcon: View {
  let value: RufletValue?
  var size: CGFloat?
  var color: Color?

  var body: some View {
    if let symbol = IconMapping.symbol(for: value) {
      Image(systemName: symbol)
        .font(size.map { Font.system(size: $0) })
        .modifier(ExplicitIconColor(color: color))
    }
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
