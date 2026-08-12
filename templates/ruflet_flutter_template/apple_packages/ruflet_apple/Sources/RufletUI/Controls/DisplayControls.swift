import RufletEngine
import RufletProtocol
import SwiftUI
#if canImport(ImageIO)
  import ImageIO
#endif
#if canImport(WebKit)
  import WebKit
#endif

/// `Text` — the control every Ruflet app starts with.
///
/// Its content is `value`, optionally composed from `spans` (Flet's
/// `TextSpan`), and its appearance comes from either inline props or a `style`
/// map. `selectable` makes the text user-selectable; `on_tap` reports taps.
struct TextControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @Environment(\.openURL) private var openURL
  @Environment(\.rufletSelectionAreaChange) private var selectionAreaChange

  var body: some View {
    let document = RufletRichTextDocument(
      value: node.string("value") ?? "",
      spanIDs: node.controlIDs(forKey: "spans"),
      resolve: store.node)
    let presentation = RufletTextPresentation(node: node)
    let style = RufletTextStyle.forText(node: node, hasSpans: !document.runs.isEmpty)

    renderedText(style: style, document: document)
      .multilineTextAlignment(alignment)
      .lineLimit(presentation.maxLines)
      .truncationMode(presentation.truncationMode)
      .lineSpacing(style.swiftUILineSpacing)
      // Flet passes no_wrap only to Text.softWrap. SelectableText has no
      // softWrap argument at all, so selectable paragraphs must keep wrapping.
      .fixedSize(horizontal: presentation.usesUnwrappedLayout, vertical: false)
      .frame(maxWidth: node.double("max_width").map { CGFloat($0) })
      .background(style.backgroundColor)
      .modifier(TextSelectionCursor(node: node))
      .modifier(SelectableTextTapReporter(node: node, events: events))
      .modifier(TextOverflowClip(mode: presentation.overflow))
      .modifier(
        TextSemanticLabel(
          value: document.accessibilityLabel(
            rootLabel: node.props["semantics_label"]?.stringValue)))
  }

  @ViewBuilder
  private func renderedText(
    style: RufletTextStyle, document: RufletRichTextDocument
  ) -> some View {
    let attributed = document.attributedString(rootStyle: style)
    if node.bool("selectable") == true || selectionAreaChange != nil
      || document.runs.contains(where: \.tracksPointer)
    {
      RufletSelectableRichText(
        node: node, document: document, attributed: attributed, events: events,
        selectionAreaChange: selectionAreaChange,
        activate: activateSpan, hover: hoverSpan)
    } else {
      Text(attributed)
        .modifier(
          InteractiveSelection(enabled: node.bool("enable_interactive_selection") != false))
        .environment(\.openURL, spanURLAction)
    }
  }

  private func activateSpan(_ id: Int) {
    guard let span = store.node(id), span.bool("disabled") != true else { return }
    if let raw = span.string("url"), let url = URL(string: raw) { openURL(url) }
    events.fire(span, "click")
  }

  private func hoverSpan(_ id: Int, _ entered: Bool) {
    guard let span = store.node(id), span.bool("disabled") != true else { return }
    events.fire(span, entered ? "enter" : "exit")
  }

  private var spanURLAction: OpenURLAction {
    OpenURLAction { url in
      guard let id = RufletSpanLink.id(from: url) else { return .systemAction }
      activateSpan(id)
      return .handled
    }
  }

  private var alignment: TextAlignment {
    switch node.string("text_align")?.lowercased() {
    case "center": return .center
    case "right", "end": return .trailing
    default: return .leading
    }
  }

}

enum RufletTextOverflow: String, Equatable {
  case clip, fade, ellipsis, visible
}

/// Source-derived Text/SelectableText constructor choices. Keeping them as a
/// value also makes it impossible for SwiftUI layout convenience to silently
/// turn no_wrap into maxLines=1, which Flutter does not do.
struct RufletTextPresentation: Equatable {
  let selectable: Bool
  let noWrap: Bool
  let maxLines: Int?
  let overflow: RufletTextOverflow

  init(node: ControlNode) {
    selectable = node.bool("selectable") == true
    noWrap = node.bool("no_wrap") == true
    maxLines = node.int("max_lines")
    if node.bool("ellipsis") == true {
      overflow = .ellipsis
    } else {
      overflow = RufletTextOverflow(rawValue: node.string("overflow")?.lowercased() ?? "") ?? .clip
    }
  }

  var usesUnwrappedLayout: Bool { !selectable && noWrap }
  var truncationMode: Text.TruncationMode { .tail }
}

private struct SelectableTextTapReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink

  func body(content: Content) -> some View {
    if node.bool("selectable") == true {
      content.modifier(TapReporter(node: node, events: events))
    } else {
      content
    }
  }
}

private struct TextOverflowClip: ViewModifier {
  let mode: RufletTextOverflow

  func body(content: Content) -> some View {
    if mode == .clip { content.clipped() } else { content }
  }
}

private struct TextSemanticLabel: ViewModifier {
  let value: String?

  func body(content: Content) -> some View {
    if let value { content.accessibilityLabel(Text(value)) } else { content }
  }
}

/// `enable_interactive_selection: false` takes selection away even from a
/// control that `selectable` would otherwise allow.
private struct InteractiveSelection: ViewModifier {
  let enabled: Bool

  func body(content: Content) -> some View {
    if enabled {
      content
    } else {
      content.textSelection(.disabled)
    }
  }
}

/// `show_selection_cursor` and its three measurements describe the caret a
/// selectable Text shows. SwiftUI paints selection from the accent colour, so
/// the cursor colour is applied as the tint and its width and height set the
/// minimum the selection can draw at.
private struct TextSelectionCursor: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    guard node.bool("selectable") == true,
      node.bool("show_selection_cursor") == true
    else { return AnyView(content) }
    return AnyView(
      content
        .tint(MaterialPalette.color(node.string("selection_cursor_color"))))
  }
}

private struct SelectableText: ViewModifier {
  let enabled: Bool

  func body(content: Content) -> some View {
    if enabled, #available(iOS 15.0, macOS 12.0, *) {
      content.textSelection(.enabled)
    } else {
      content
    }
  }
}

/// `Icon` — an SF Symbol resolved from the Material index Ruby sends.
///
/// Flutter draws Material Symbols, a variable font, so `fill`, `weight`,
/// `grade` and `optical_size` move its FILL, wght, GRAD and opsz axes. SF
/// Symbols expresses the first two as a fill variant and a font weight, and
/// `grade` — Material's finer adjustment to the same stroke — folds into that
/// weight because Apple has no separate axis for it.
struct IconControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

  var body: some View {
    let glyph = RufletIconGlyph(node: node)

    symbol(glyph)
      // SwiftUI exposes optical sizing through the glyph's point size; the
      // exact Material font still owns the named icon's outline.
      .modifier(IconOpticalSize(value: node.double("optical_size")))
      .modifier(IconShadows(value: node.props["shadows"]))
      .modifier(IconBlendMode(name: node.string("blend_mode")))
      .modifier(TapReporter(node: node, events: events))
  }

  /// Material values retain the bundled Flutter font. Cupertino values retain
  /// native SF Symbols, where the expressible weight/grade axes are folded
  /// into the native symbol font.
  @ViewBuilder
  private func symbol(_ glyph: RufletIconGlyph) -> some View {
    let value = node.props["name"] ?? node.props["icon"]
    let color = MaterialPalette.color(node.string("color"))
    RufletIcon(
      value: value,
      size: glyph.scaledSize(textScale: textScale),
      color: color,
      symbolWeight: glyph.symbolWeight,
      filled: glyph.isFilled)
  }
}

/// The icon axes Flet carries. Flutter's static MaterialIcons-Regular font
/// ignores unsupported variation axes; native Cupertino symbols can express
/// the discrete weight ladder below.
struct RufletIconGlyph: Equatable {
  let size: CGFloat
  let appliesTextScaling: Bool
  let fill: Double?
  let weight: Double?
  let grade: Double?

  init(node: ControlNode) {
    size = node.double("size").map { CGFloat($0) } ?? RufletThemeDefaults.materialIconButtonSize
    appliesTextScaling = node.bool("apply_text_scaling") == true
    fill = node.double("fill")
    weight = node.double("weight")
    grade = node.double("grade")
  }

  /// Flutter multiplies the icon's size by the ambient text scaler only when
  /// `applyTextScaling` is set. `@ScaledMetric` supplies the same factor.
  func scaledSize(textScale: CGFloat) -> CGFloat {
    appliesTextScaling ? size * textScale : size
  }

  /// Material's FILL axis runs 0…1 between the outlined and filled cuts of the
  /// same glyph; SF Symbols only has the two ends, so the midpoint decides.
  var isFilled: Bool {
    guard let fill else { return false }
    return fill >= 0.5
  }

  /// wght runs 100…900 over the nine named weights, and a positive grade nudges
  /// the result one step heavier, a negative one step lighter.
  var symbolWeight: Font.Weight? {
    guard weight != nil || grade != nil else { return nil }
    let axis = weight ?? 400
    let base = Int((axis / 100).rounded()) - 1
    let step: Int
    if let grade, grade != 0 {
      step = grade > 0 ? 1 : -1
    } else {
      step = 0
    }
    let index = min(max(base + step, 0), Self.weightLadder.count - 1)
    return Self.weightLadder[index]
  }

  private static let weightLadder: [Font.Weight] = [
    .ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black
  ]
}

/// Passing nil to `foregroundColor` clears the inherited style, so an omitted
/// Ruby colour must leave the modifier off entirely.
private struct IconGlyphColor: ViewModifier {
  let color: Color?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let color {
      content.foregroundColor(color)
    } else {
      content
    }
  }
}

/// Flutter's `BoxShadow` list, painted behind the glyph. `parseBoxShadow`
/// defaults an omitted colour to black and an omitted offset to zero.
private struct IconShadows: ViewModifier {
  let value: RufletValue?

  func body(content: Content) -> some View {
    var result = AnyView(content)
    for shadow in value?.arrayValue ?? [] {
      guard let map = shadow.mapValue else { continue }
      result = AnyView(
        result.shadow(
          color: MaterialPalette.color(map["color"]?.stringValue, default: .black),
          radius: CGFloat(map["blur_radius"]?.doubleValue ?? 0),
          x: CGFloat(map["offset"]?.mapValue?["x"]?.doubleValue ?? 0),
          y: CGFloat(map["offset"]?.mapValue?["y"]?.doubleValue ?? 0)))
    }
    return result
  }
}

/// Flutter composites the icon's colour filter with `BlendMode.srcIn` when no
/// mode is given, which is what an unmodified SwiftUI foreground already does.
private struct IconBlendMode: ViewModifier {
  let name: String?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let name {
      content.blendMode(ControlProps.blendMode(name))
    } else {
      content
    }
  }
}

/// `Image` — a local bundle resource, a data URI, or a remote URL.
struct ImageControlView: View {
  let node: ControlNode
  @Environment(\.rufletServerURL) private var serverURL

  private var presentation: RufletImagePresentation { RufletImagePresentation(node: node) }

  var body: some View {
    content
      .modifier(ImageColorFilter(node: node))
      .clipShape(RoundedRectangle(cornerRadius: ControlProps.cornerRadius(node.props["border_radius"]) ?? 0))
      .modifier(ImageSemantics(node: node))
  }

  @ViewBuilder
  private var content: some View {
    if case .binary(let data) = RufletImageSource(node: node) {
      PlatformImageView(
        data: data, repeatMode: presentation.repeatMode,
        interpolation: presentation.interpolation,
        cacheWidth: presentation.cacheWidth, cacheHeight: presentation.cacheHeight)
        .modifier(ImageFit(fit: presentation.fit))
    } else if case .remote(let url) = RufletImageSource(node: node) {
      if url.isFileURL, let data = try? Data(contentsOf: url) {
        PlatformImageView(
          data: data, repeatMode: presentation.repeatMode,
          interpolation: presentation.interpolation,
          cacheWidth: presentation.cacheWidth, cacheHeight: presentation.cacheHeight)
          .modifier(ImageFit(fit: presentation.fit))
      } else {
        RemoteImage(
          url: url,
          errorContentID: node.controlID(forKey: "error_content"),
          placeholder: placeholder,
          presentation: presentation)
          .modifier(ImageFit(fit: presentation.fit))
      }
    } else if case .asset(let name) = RufletImageSource(node: node) {
      if let data = RufletImageSource.packagedData(named: name) {
        PlatformImageView(
          data: data, repeatMode: presentation.repeatMode,
          interpolation: presentation.interpolation,
          cacheWidth: presentation.cacheWidth, cacheHeight: presentation.cacheHeight)
          .modifier(ImageFit(fit: presentation.fit))
      } else if let url = RufletImageAssetURL.imageAsset(name, relativeTo: serverURL) {
        RemoteImage(
          url: url,
          errorContentID: node.controlID(forKey: "error_content"),
          placeholder: placeholder,
          presentation: presentation)
          .modifier(ImageFit(fit: presentation.fit))
      } else {
        // Asset catalog lookup is the final packaged-asset fallback.
        Image(name)
          .resizable(resizingMode: presentation.repeatMode.swiftUI)
          .interpolation(presentation.interpolation)
          .modifier(ImageFit(fit: presentation.fit))
      }
    } else if case .invalid = RufletImageSource(node: node),
      let errorContentID = node.controlID(forKey: "error_content")
    {
      ControlView(id: errorContentID, axis: .none)
    } else if case .empty = RufletImageSource(node: node) {
      Text("A valid src value must be specified.")
        .font(.caption)
        .foregroundColor(.secondary)
    } else if case .invalid(let description) = RufletImageSource(node: node) {
      Text("Error decoding src: \(description)")
        .font(.caption)
        .foregroundColor(.secondary)
    } else {
      Text("Image must have \"src\" specified.")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  private var placeholder: AnyView? {
    guard let value = node.props["placeholder_src"] else { return nil }
    switch RufletImageSource(value: value) {
    case .binary(let data):
      return AnyView(PlatformImageView(
        data: data, repeatMode: presentation.repeatMode,
        interpolation: presentation.interpolation,
        cacheWidth: presentation.cacheWidth, cacheHeight: presentation.cacheHeight)
        .modifier(ImageFit(fit: presentation.placeholderFit)))
    case .remote(let url) where url.isFileURL:
      guard let data = try? Data(contentsOf: url) else { return nil }
      return AnyView(PlatformImageView(
        data: data, repeatMode: presentation.repeatMode,
        interpolation: presentation.interpolation,
        cacheWidth: presentation.cacheWidth, cacheHeight: presentation.cacheHeight)
        .modifier(ImageFit(fit: presentation.placeholderFit)))
    case .remote(let url):
      // Flet resolves `placeholder_src` through the same image-provider path
      // as `src`, including HTTP(S) images. Do not silently drop a remote
      // placeholder just because the primary image is also asynchronous.
      return AnyView(
        RemoteImage(url: url, errorContentID: nil, presentation: presentation)
          .modifier(ImageFit(fit: presentation.placeholderFit)))
    case .asset(let name):
      if let data = RufletImageSource.packagedData(named: name) {
        return AnyView(PlatformImageView(
          data: data, repeatMode: presentation.repeatMode,
          interpolation: presentation.interpolation,
          cacheWidth: presentation.cacheWidth, cacheHeight: presentation.cacheHeight)
          .modifier(ImageFit(fit: presentation.placeholderFit)))
      }
      if let url = RufletImageAssetURL.imageAsset(name, relativeTo: serverURL) {
        return AnyView(
          RemoteImage(url: url, errorContentID: nil, presentation: presentation)
            .modifier(ImageFit(fit: presentation.placeholderFit)))
      }
      return AnyView(
        Image(name)
          .resizable(resizingMode: presentation.repeatMode.swiftUI)
          .interpolation(presentation.interpolation)
          .modifier(ImageFit(fit: presentation.placeholderFit)))
    default:
      return nil
    }
  }
}

/// Constructor values used by Flutter's `Image` and Flet's frame-fade wrapper.
/// Keeping them independent of the network loader makes omission/default
/// semantics executable without snapshots or I/O.
struct RufletImagePresentation: Equatable {
  enum RepeatMode: String, Equatable {
    case noRepeat = "norepeat"
    case repeatImage = "repeat"
    case repeatX = "repeatx"
    case repeatY = "repeaty"

    init(_ raw: String?) {
      switch raw?.lowercased().replacingOccurrences(of: "_", with: "") {
      case "repeat": self = .repeatImage
      case "repeatx": self = .repeatX
      case "repeaty": self = .repeatY
      default: self = .noRepeat
      }
    }

    var swiftUI: Image.ResizingMode { self == .noRepeat ? .stretch : .tile }
  }

  let repeatMode: RepeatMode
  let filterQuality: String
  let antiAlias: Bool
  let gaplessPlayback: Bool
  let cacheWidth: Int?
  let cacheHeight: Int?
  let fit: String?
  let placeholderFit: String?
  let fadeInDuration: Double
  let fadeInCurve: String
  let fadeOutDuration: Double
  let fadeOutCurve: String
  /// Image tinting is opt-in. An omitted colour must never acquire a renderer
  /// palette default; Apple displays the source pixels unchanged.
  let explicitColorToken: String?

  var interpolation: Image.Interpolation {
    switch filterQuality {
    case "none": return .none
    case "low": return .low
    case "high": return .high
    default: return .medium
    }
  }

  init(node: ControlNode) {
    repeatMode = RepeatMode(node.string("repeat"))
    filterQuality = node.string("filter_quality")?.lowercased() ?? "medium"
    antiAlias = node.bool("anti_alias") ?? false
    gaplessPlayback = node.bool("gapless_playback") ?? false
    cacheWidth = node.int("cache_width")
    cacheHeight = node.int("cache_height")
    fit = Self.nonEmpty(node.string("fit"))
    placeholderFit = Self.nonEmpty(node.string("placeholder_fit")) ?? fit
    let fadeIn = Self.animation(node.props["fade_in_animation"], defaultMilliseconds: 250,
                                defaultCurve: "easeinout")
    let fadeOut = Self.animation(node.props["placeholder_fade_out_animation"],
                                 defaultMilliseconds: 150, defaultCurve: "easeout")
    fadeInDuration = fadeIn.duration
    fadeInCurve = fadeIn.curve
    fadeOutDuration = fadeOut.duration
    fadeOutCurve = fadeOut.curve
    explicitColorToken = Self.nonEmpty(node.string("color"))
  }

  private static func animation(
    _ value: RufletValue?, defaultMilliseconds: Double, defaultCurve: String
  ) -> (duration: Double, curve: String) {
    guard let value else { return (defaultMilliseconds / 1000, defaultCurve) }
    // RufletValue intentionally offers coercing accessors, but Flet's parser
    // branches on the runtime type. An integer duration such as `500` must
    // not be coerced to boolean true and turned into one second.
    if case .bool(true) = value { return (1, "linear") }
    if let milliseconds = value.doubleValue { return (max(milliseconds, 0) / 1000, "linear") }
    return (
      max(value["duration"]?.doubleValue ?? 0, 0) / 1000,
      value["curve"]?.stringValue?.lowercased() ?? "linear")
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty
    else { return nil }
    return value
  }
}

/// The forms accepted by Flet's `getSrc`: bytes, data URIs, network/file URLs,
/// and packaged assets. Resolution is deliberately separate from SwiftUI so
/// byte/data-URI behavior is covered without a network or snapshot test.
enum RufletImageSource: Equatable {
  case binary(Data)
  case remote(URL)
  case asset(String)
  case empty
  case invalid(String)
  case missing

  init(node: ControlNode) {
    if case .binary = node.props["src"] {
      self.init(value: node.props["src"])
      return
    }
    if let base64 = node.string("src_base64"), let data = Data(base64Encoded: base64) {
      self = .binary(data)
      return
    }
    self.init(value: node.props["src"])
  }

  /// Flet's `ResolvedAssetSource.from` is also used by controls whose source
  /// property is not named `src` (notably CircleAvatar's two image layers).
  /// Keep resolution value-based so every such control accepts the same wire
  /// forms: bytes, URLs, asset paths and unadorned Base64 strings.
  init(value: RufletValue?) {
    guard let value else {
      self = .missing
      return
    }
    if case .null = value {
      self = .missing
      return
    }
    if case .binary(let bytes) = value {
      self = bytes.isEmpty ? .empty : .binary(Data(bytes))
      return
    }
    guard let rawSource = value.stringValue else {
      self = .invalid("\(value) is not a supported source type.")
      return
    }
    let source = rawSource.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !source.isEmpty else {
      self = .empty
      return
    }
    if let data = Self.dataURI(source) {
      self = .binary(data)
    } else if source.range(of: "<svg", options: [.caseInsensitive]) != nil {
      // ResolvedAssetSource accepts inline SVG markup. Keep it byte-backed so
      // the platform decoder/plugin boundary receives the actual document,
      // rather than treating the XML as a packaged asset name.
      self = .binary(Data(source.utf8))
    } else if let url = URL(string: source),
      let scheme = url.scheme?.lowercased(),
      scheme == "http" || scheme == "https" || scheme == "file"
    {
      self = .remote(url)
    } else if source.contains(".") {
      // Flet resolves anything that looks like a path before attempting
      // Base64, so `avatar.png` can never be mistaken for encoded bytes.
      self = .asset(source)
    } else if let data = Data(base64Encoded: source), !data.isEmpty {
      self = .binary(data)
    } else {
      self = .asset(source)
    }
  }

  static func dataURI(_ source: String) -> Data? {
    guard source.lowercased().hasPrefix("data:"), let comma = source.firstIndex(of: ",")
    else { return nil }
    let metadata = source[..<comma].lowercased()
    let payload = String(source[source.index(after: comma)...])
    if metadata.contains(";base64") { return Data(base64Encoded: payload) }
    return payload.removingPercentEncoding?.data(using: .utf8)
  }

  static func packagedData(named name: String) -> Data? {
    let source = name.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let candidate = URL(fileURLWithPath: source)
    let stem = candidate.deletingPathExtension().lastPathComponent
    let ext = candidate.pathExtension.isEmpty ? nil : candidate.pathExtension
    let directory = candidate.deletingLastPathComponent().path == "."
      ? nil : candidate.deletingLastPathComponent().path
    for bundle in [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks {
      if let url = bundle.url(forResource: stem, withExtension: ext, subdirectory: directory),
        let data = try? Data(contentsOf: url)
      {
        return data
      }
    }
    return nil
  }
}

/// Flet's native `getAssetSrc`: ordinary Image assets are relative to the
/// current page URI, while MarkdownBody's `imageDirectory` is the origin.
/// Keeping the two policies explicit prevents packaged assets from being
/// confused with remote relative assets.
enum RufletImageAssetURL {
  static func imageAsset(_ path: String, relativeTo pageURL: URL?) -> URL? {
    guard let pageURL = networkPageURL(pageURL) else { return nil }
    let suffix = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    guard !suffix.isEmpty else { return nil }
    var components = URLComponents(url: pageURL, resolvingAgainstBaseURL: false)
    let base = pageURL.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    components?.path = "/" + (base + suffix).joined(separator: "/")
    components?.query = nil
    components?.fragment = nil
    return components?.url
  }

  static func markdownAsset(_ path: String, relativeTo pageURL: URL?) -> URL? {
    guard let pageURL = networkPageURL(pageURL) else { return nil }
    let suffix = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    guard !suffix.isEmpty else { return nil }
    var components = URLComponents(url: pageURL, resolvingAgainstBaseURL: false)
    components?.path = "/" + suffix.joined(separator: "/")
    components?.query = nil
    components?.fragment = nil
    return components?.url
  }

  private static func networkPageURL(_ value: URL?) -> URL? {
    guard let value, var components = URLComponents(url: value, resolvingAgainstBaseURL: false)
    else { return nil }
    switch components.scheme?.lowercased() {
    case "ws":
      components.scheme = "http"
      components.path = "/"
    case "wss":
      components.scheme = "https"
      components.path = "/"
    case "http", "https": break
    default: return nil
    }
    return components.url
  }
}

private struct ImageColorFilter: ViewModifier {
  let node: ControlNode

  @ViewBuilder
  func body(content: Content) -> some View {
    if let color = MaterialPalette.color(RufletImagePresentation(node: node).explicitColorToken) {
      content
        .colorMultiply(color)
        .blendMode(ControlProps.blendMode(node.string("color_blend_mode")))
    } else {
      content
    }
  }
}

private struct ImageSemantics: ViewModifier {
  let node: ControlNode

  @ViewBuilder
  func body(content: Content) -> some View {
    if node.bool("exclude_from_semantics") == true {
      content.accessibilityHidden(true)
    } else if let label = node.string("semantics_label"), !label.isEmpty {
      content.accessibilityLabel(label)
    } else {
      content
    }
  }
}

private struct ImageFit: ViewModifier {
  let fit: String?

  func body(content: Content) -> some View {
    // Flet's BoxFit; `contain` is Flutter's default for Image.
    switch fit?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "cover":
      return AnyView(content.aspectRatio(contentMode: .fill).clipped())
    case "fitwidth", "fitheight":
      // Unlike cover, fitWidth/fitHeight preserve the full image on the
      // unconstrained axis. The common width/height wrapper supplies which
      // dimension is tight.
      return AnyView(content.aspectRatio(contentMode: .fit))
    case "fill":
      return AnyView(content)
    case "none", "scaledown", nil:
      return AnyView(content.fixedSize())
    default:
      return AnyView(content.aspectRatio(contentMode: .fit))
    }
  }
}

/// Loads a remote image without a third-party dependency, so the package stays
/// self-contained.
private struct RemoteImage: View {
  let url: URL
  let errorContentID: Int?
  let placeholder: AnyView?
  let presentation: RufletImagePresentation
  var onLoad: () -> Void = {}
  var onError: (String) -> Void = { _ in }

  init(
    url: URL,
    errorContentID: Int?,
    placeholder: AnyView? = nil,
    presentation: RufletImagePresentation = RufletImagePresentation(
      node: ControlNode(id: 0, type: "Image")),
    onLoad: @escaping () -> Void = {},
    onError: @escaping (String) -> Void = { _ in }
  ) {
    self.url = url
    self.errorContentID = errorContentID
    self.placeholder = placeholder
    self.presentation = presentation
    self.onLoad = onLoad
    self.onError = onError
  }

  @State private var data: Data?
  @State private var failed = false

  var body: some View {
    ZStack {
      if data == nil && !failed, let placeholder {
        placeholder
          .transition(.opacity)
          .animation(
            RufletCurve.animation(
              presentation.fadeOutCurve, duration: presentation.fadeOutDuration),
            value: data == nil && !failed)
      }
      if let data {
        PlatformImageView(
          data: data, repeatMode: presentation.repeatMode,
          interpolation: presentation.interpolation,
          cacheWidth: presentation.cacheWidth, cacheHeight: presentation.cacheHeight)
          .transition(.opacity)
      } else if failed {
        if let errorContentID {
          ControlView(id: errorContentID, axis: .none)
        } else {
          Color.clear
        }
      } else if placeholder == nil {
        Color.clear
      }
    }
    .task(id: url) { await load() }
    .onChange(of: url) { _ in
      failed = false
      if !presentation.gaplessPlayback { data = nil }
    }
    .animation(
      RufletCurve.animation(presentation.fadeInCurve, duration: presentation.fadeInDuration),
      value: data != nil)
  }

  private func load() async {
    do {
      let (bytes, response) = try await URLSession.shared.data(from: url)
      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        throw RemoteImageError.httpStatus(http.statusCode)
      }
      guard Self.canDecode(bytes) else { throw RemoteImageError.invalidImage }
      data = bytes
      onLoad()
    } catch {
      failed = true
      onError(error.localizedDescription)
    }
  }

  static func canDecode(_ data: Data) -> Bool {
    if RufletSVGDocument.isSVG(data) { return true }
    #if canImport(UIKit)
      return UIImage(data: data) != nil
    #elseif canImport(AppKit)
      return NSImage(data: data) != nil
    #else
      return false
    #endif
  }
}

private enum RemoteImageError: LocalizedError {
  case httpStatus(Int)
  case invalidImage

  var errorDescription: String? {
    switch self {
    case .httpStatus(let status): return "Image request failed with HTTP status \(status)."
    case .invalidImage: return "Image data could not be decoded."
    }
  }
}

/// Bridges raw bytes to an `Image` on both platforms.
struct PlatformImageView: View {
  let data: Data
  var repeatMode: RufletImagePresentation.RepeatMode = .noRepeat
  var interpolation: Image.Interpolation = .medium
  var cacheWidth: Int? = nil
  var cacheHeight: Int? = nil

  var body: some View {
    if RufletSVGDocument.isSVG(data) {
      RufletSVGDocumentView(data: data)
    } else {
    #if canImport(UIKit)
      if let image = RufletDecodedImage.uiImage(data, width: cacheWidth, height: cacheHeight) {
        Image(uiImage: image)
          .resizable(resizingMode: repeatMode.swiftUI)
          .interpolation(interpolation)
      }
    #elseif canImport(AppKit)
      if let image = RufletDecodedImage.nsImage(data, width: cacheWidth, height: cacheHeight) {
        Image(nsImage: image)
          .resizable(resizingMode: repeatMode.swiftUI)
          .interpolation(interpolation)
      }
    #endif
    }
  }
}

private enum RufletDecodedImage {
  private static func thumbnail(_ data: Data, width: Int?, height: Int?) -> CGImage? {
    guard let requested = [width, height].compactMap({ $0 }).filter({ $0 > 0 }).max(),
      let source = CGImageSourceCreateWithData(data as CFData, nil)
    else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: requested,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }

  #if canImport(UIKit)
    static func uiImage(_ data: Data, width: Int?, height: Int?) -> UIImage? {
      if let thumbnail = thumbnail(data, width: width, height: height) {
        return UIImage(cgImage: thumbnail)
      }
      return UIImage(data: data)
    }
  #endif

  #if canImport(AppKit)
    static func nsImage(_ data: Data, width: Int?, height: Int?) -> NSImage? {
      if let thumbnail = thumbnail(data, width: width, height: height) {
        return NSImage(cgImage: thumbnail, size: .zero)
      }
      return NSImage(data: data)
    }
  #endif
}

enum RufletSVGDocument {
  static func isSVG(_ data: Data) -> Bool {
    guard let prefix = String(data: data.prefix(4_096), encoding: .utf8)?.lowercased()
    else { return false }
    return prefix.contains("<svg")
  }
}

/// Apple has no SwiftUI SVG image primitive. WebKit is the native system SVG
/// renderer on both supported platforms, so the document stays vector-backed
/// without recreating Flutter's `SvgPicture` painter.
private struct RufletSVGDocumentView: View {
  let data: Data

  var body: some View {
    #if canImport(WebKit)
      RufletSVGWebView(data: data)
    #else
      Color.clear
    #endif
  }
}

#if canImport(WebKit) && canImport(UIKit)
  private struct RufletSVGWebView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> WKWebView {
      let view = WKWebView(frame: .zero)
      view.isOpaque = false
      view.backgroundColor = .clear
      view.scrollView.isScrollEnabled = false
      view.isUserInteractionEnabled = false
      return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
      view.loadHTMLString(Self.html(data), baseURL: nil)
    }

    fileprivate static func html(_ data: Data) -> String {
      let svg = String(data: data, encoding: .utf8) ?? ""
      return "<style>html,body,svg{margin:0;width:100%;height:100%;overflow:hidden}</style>\(svg)"
    }
  }
#elseif canImport(WebKit) && canImport(AppKit)
  private struct RufletSVGWebView: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> WKWebView {
      let view = WKWebView(frame: .zero)
      view.setValue(false, forKey: "drawsBackground")
      return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
      view.loadHTMLString(Self.html(data), baseURL: nil)
    }

    fileprivate static func html(_ data: Data) -> String {
      let svg = String(data: data, encoding: .utf8) ?? ""
      return "<style>html,body,svg{margin:0;width:100%;height:100%;overflow:hidden}</style>\(svg)"
    }
  }
#endif

/// Flutter's `LinearProgressIndicator` geometry.
///
/// `year2023` still defaults to true upstream, so an unconfigured bar is the
/// original Material 3 shape: square ends, a track that runs the full width and
/// no stop indicator. `year_2023: false` opts into the 2024 revision, which
/// rounds the ends, leaves a gap before the remaining track and puts a dot at
/// the far end.
struct RufletLinearProgressMetrics: Equatable {
  /// Flutter ramps the 2024 track gap in over the first one percent so a
  /// sliver of progress does not suddenly open a full four-point seam.
  static let trackGapRampDownThreshold = 0.01

  let value: Double?
  let height: CGFloat
  let cornerRadius: CGFloat
  let trackGap: CGFloat?
  let stopIndicatorRadius: CGFloat?

  init(node: ControlNode) {
    let year2023 = node.bool("year_2023") != false
    if let raw = node.double("value") {
      value = min(max(raw, 0), 1)
    } else {
      value = nil
    }
    height = node.double("bar_height").map { CGFloat($0) }
      ?? RufletThemeDefaults.linearProgressHeight
    cornerRadius = ControlProps.cornerRadius(node.props["border_radius"])
      ?? (year2023 ? 0 : RufletThemeDefaults.linearProgressCornerRadius)
    if year2023 {
      // Flutter drops all three 2024 measurements before they reach the
      // painter rather than defaulting them, so the old bar cannot show a gap
      // or a stop dot even when Ruby sent one.
      trackGap = nil
      stopIndicatorRadius = nil
    } else {
      trackGap = node.double("track_gap").map { CGFloat($0) }
        ?? RufletThemeDefaults.linearProgressTrackGap
      stopIndicatorRadius = node.double("stop_indicator_radius").map { CGFloat($0) }
        ?? RufletThemeDefaults.linearProgressStopIndicatorRadius
    }
  }

  /// The gap closes while the bar is indeterminate and again once it is full,
  /// so a finished bar has no seam in it.
  var effectiveTrackGap: CGFloat {
    guard let value, value < 1, let trackGap, trackGap > 0 else { return 0 }
    let ramp = min(max(value, 0), Self.trackGapRampDownThreshold)
      / Self.trackGapRampDownThreshold
    return trackGap * CGFloat(ramp)
  }

  func activeWidth(in width: CGFloat) -> CGFloat {
    guard let value else { return 0 }
    return width * CGFloat(value)
  }

  /// The leading edge of the remaining track, which the gap pushes right.
  func trackOrigin(in width: CGFloat) -> CGFloat {
    guard let value else { return 0 }
    if value >= 1 { return width }
    guard effectiveTrackGap > 0 else { return 0 }
    return min(width, activeWidth(in: width) + effectiveTrackGap)
  }

  /// Flutter limits the stop dot to half the bar's height, and never draws one
  /// on an indeterminate bar.
  var resolvedStopIndicatorRadius: CGFloat? {
    guard value != nil, let stopIndicatorRadius, stopIndicatorRadius > 0 else { return nil }
    return min(stopIndicatorRadius, height / 2)
  }

  /// The dot sits half a bar-height in from the trailing edge, whatever its
  /// own radius is.
  func stopIndicatorCentre(in width: CGFloat) -> CGFloat {
    width - height / 2
  }
}

/// Decides whether Apple can delegate the whole presentation to its native
/// ProgressView. Flet's behavioral fields (value and accessibility strings)
/// do not opt out of native appearance; only an explicit visual DSL property
/// does. This keeps unstyled Ruflet apps native instead of painting a Material
/// indicator on iOS/macOS.
enum RufletProgressAppearance {
  static func usesNativeLinear(_ node: ControlNode) -> Bool {
    [
      "color", "bgcolor", "bar_height", "border_radius", "track_gap",
      "stop_indicator_color", "stop_indicator_radius", "year_2023",
    ].allSatisfy { !hasExplicitValue(node.props[$0]) }
  }

  static func usesNativeCircular(_ node: ControlNode) -> Bool {
    [
      "color", "bgcolor", "stroke_width", "stroke_align", "stroke_cap",
      "track_gap", "track_gap_fallback", "size_constraints", "padding", "year2023",
      "year_2023",
    ].allSatisfy { !hasExplicitValue(node.props[$0]) }
  }

  static func value(_ node: ControlNode) -> Double? {
    node.double("value").map { min(max($0, 0), 1) }
  }

  private static func hasExplicitValue(_ value: RufletValue?) -> Bool {
    guard let value else { return false }
    return !value.isNull
  }
}

/// `ProgressBar` — Flutter's `LinearProgressIndicator`.
///
/// Drawn rather than delegated to SwiftUI's linear `ProgressView`, which
/// exposes neither the bar's height nor the 2024 track gap and stop indicator.
struct ProgressBarControlView: View {
  let node: ControlNode
  @State private var sweep: CGFloat = 0
  @Environment(\.layoutDirection) private var layoutDirection

  @ViewBuilder
  var body: some View {
    if RufletProgressAppearance.usesNativeLinear(node) {
      Group {
        if let value = RufletProgressAppearance.value(node) {
          ProgressView(value: value, total: 1)
        } else {
          ProgressView()
        }
      }
      .progressViewStyle(.linear)
      // Keep the native ProgressView, but feed it Flutter's resolved semantic
      // colour rather than replacing an omitted value with an Apple default.
      .tint(progressColor)
      .modifier(ProgressSemanticsValue(node: node))
    } else {
      let metrics = RufletLinearProgressMetrics(node: node)
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          bar(metrics, width: proxy.size.width)
        }
        // Flutter's painter resolves its fractional endpoints through
        // TextDirection. Mirroring the native drawing surface preserves the
        // same leading edge and trailing stop-dot behavior in RTL.
        .scaleEffect(x: layoutDirection == .rightToLeft ? -1 : 1, y: 1)
      }
      .frame(height: metrics.height)
      .modifier(ProgressSemanticsValue(node: node))
    }
  }

  /// Flutter paints the track, then the stop indicator, then the active
  /// indicator over both.
  @ViewBuilder
  private func bar(_ metrics: RufletLinearProgressMetrics, width: CGFloat) -> some View {
    let shape = RoundedRectangle(cornerRadius: metrics.cornerRadius)
    let origin = metrics.trackOrigin(in: width)

    shape
      .fill(trackColor)
      .frame(width: max(0, width - origin))
      .offset(x: origin)

    if let radius = metrics.resolvedStopIndicatorRadius {
      Circle()
        .fill(stopIndicatorColor)
        .frame(width: radius * 2, height: radius * 2)
        .offset(x: metrics.stopIndicatorCentre(in: width) - radius)
    }

    if metrics.value != nil {
      shape
        .fill(progressColor)
        .frame(width: metrics.activeWidth(in: width))
    } else {
      // Flutter runs two lines across the track over 1800ms; one travelling
      // segment reads the same way without a per-frame animation driver.
      shape
        .fill(progressColor)
        .frame(width: width * 0.4)
        .offset(x: -width * 0.4 + sweep * width * 1.4)
        .onAppear { sweep = 1 }
        .animation(
          .linear(duration: RufletThemeDefaults.linearProgressIndeterminateDuration)
            .repeatForever(autoreverses: false),
          value: sweep)
    }
  }

  private var progressColor: Color {
    MaterialPalette.color(for: node, property: "color", default: .primary)
  }

  private var trackColor: Color {
    MaterialPalette.color(for: node, property: "bgcolor", default: .clear)
  }

  private var stopIndicatorColor: Color {
    let token = RufletThemeDefaults.resolvedDisplayColorToken(
      for: node, property: "stop_indicator_color")
    return MaterialPalette.color(token, default: progressColor)
  }
}

/// Flutter's `CircularProgressIndicator` geometry.
///
/// The 2023 shape centres a 4pt stroke on the edge of a 36pt box and paints no
/// track; the 2024 revision moves the stroke fully inside a 40pt box, adds 4pt
/// of padding, rounds the ends and leaves a gap at both ends of the arc.
struct RufletCircularProgressMetrics: Equatable {
  /// A trimmed span of the ring, in turns from the top.
  struct Arc: Equatable {
    var from: CGFloat
    var to: CGFloat
  }

  let value: Double?
  let width: CGFloat
  let height: CGFloat
  let diameter: CGFloat
  let strokeWidth: CGFloat
  let strokeAlign: CGFloat
  let trackGap: CGFloat?
  let strokeCap: CGLineCap
  let trackCap: CGLineCap
  let drawsTrack: Bool
  let padding: EdgeInsets?

  init(node: ControlNode) {
    // Flet's Dart client reads the serialized camelCase name while Ruflet's
    // public Ruby DSL exposes `year_2023`. Accept both at the renderer
    // boundary, with the canonical Ruby spelling taking precedence.
    let year2023 = (node.bool("year_2023") ?? node.bool("year2023")) != false
    let indeterminate = node.double("value") == nil
    if let raw = node.double("value") {
      value = min(max(raw, 0), 1)
    } else {
      value = nil
    }

    strokeWidth = node.double("stroke_width").map { CGFloat($0) }
      ?? RufletThemeDefaults.circularProgressStrokeWidth
    strokeAlign = node.double("stroke_align").map { CGFloat($0) } ?? (year2023 ? 0 : -1)

    let constraints = ControlProps.sizeConstraints(node.props["size_constraints"])
    let defaultMinimum = year2023
      ? RufletThemeDefaults.circularProgressLegacyDiameter
      : RufletThemeDefaults.circularProgressDiameter
    // Flet wraps the indicator in a SizedBox, whose tight constraint wins over
    // the ConstrainedBox minimum the widget carries.
    width = Self.resolveDimension(
      requested: node.double("width").map { CGFloat($0) },
      minimum: constraints?.minWidth ?? defaultMinimum,
      maximum: constraints?.maxWidth)
    height = Self.resolveDimension(
      requested: node.double("height").map { CGFloat($0) },
      minimum: constraints?.minHeight ?? defaultMinimum,
      maximum: constraints?.maxHeight)
    diameter = min(width, height)

    let cap = RufletStrokeCap(node.string("stroke_cap"))
    if let cap {
      strokeCap = cap.lineCap
      trackCap = cap.lineCap
    } else if year2023 {
      // Flutter squares off the indeterminate arc and butts the determinate
      // one when no cap was asked for; the track is always round.
      strokeCap = indeterminate ? .square : .butt
      trackCap = .round
    } else {
      strokeCap = .round
      trackCap = .round
    }

    if year2023 {
      // Flutter drops the gap before the painter sees it, so the 2023 ring
      // cannot show one even when Ruby sent a measurement.
      trackGap = nil
    } else {
      trackGap = node.double("track_gap").map { CGFloat($0) }
        ?? RufletThemeDefaults.circularProgressTrackGap
    }

    // The 2023 shape has no track at all, and the 2024 one only shows it while
    // the ring is determinate.
    drawsTrack = node.props["bgcolor"]?.stringValue != nil || (!year2023 && !indeterminate)

    if node.props["padding"] == nil, !year2023 {
      padding = RufletThemeDefaults.circularProgressPadding
    } else {
      // An explicit padding is applied by the shared control modifiers, so
      // applying it again here would double it.
      padding = nil
    }
  }

  private static func resolveDimension(
    requested: CGFloat?, minimum: CGFloat, maximum: CGFloat?
  ) -> CGFloat {
    // The outer LayoutControl's tight width/height wins over the indicator's
    // own ConstrainedBox. Without one, CustomPaint settles at its minimum.
    if let requested { return requested }
    return min(maximum ?? minimum, minimum)
  }

  /// Flutter offsets the arc's bounds by half the stroke against the align
  /// axis, so -1 keeps the whole stroke inside the box and 0 straddles it.
  var strokeInset: CGFloat {
    strokeWidth / 2 * -strokeAlign
  }

  private var arcRadius: CGFloat {
    max((diameter + strokeWidth * strokeAlign) / 2, 0.0001)
  }

  /// Flutter measures the gap in points and converts it against the arc's
  /// radius, leaving the same angular gap at both ends of the active arc.
  var gapTurns: CGFloat {
    guard let trackGap, trackGap > 0, let value, value > 0 else { return 0 }
    return (strokeWidth + trackGap) / arcRadius / (2 * .pi)
  }

  var valueArc: Arc? {
    guard let value else { return nil }
    return Arc(from: 0, to: CGFloat(value))
  }

  /// The track runs from the end of the active arc back round to its start,
  /// minus a gap at each end. A nearly full ring leaves no room for it.
  var trackArc: Arc? {
    guard drawsTrack else { return nil }
    guard let value else { return Arc(from: 0, to: 1) }
    let gap = gapTurns
    guard gap > 0 else { return Arc(from: 0, to: 1) }
    let from = CGFloat(value) + gap
    let to = 1 - gap
    return from < to ? Arc(from: from, to: to) : nil
  }
}

/// Flutter's `StrokeCap`, which Flet passes through by name.
enum RufletStrokeCap: String {
  case butt
  case round
  case square

  init?(_ raw: String?) {
    guard let raw, let parsed = RufletStrokeCap(rawValue: raw.lowercased()) else { return nil }
    self = parsed
  }

  var lineCap: CGLineCap {
    switch self {
    case .butt: return .butt
    case .round: return .round
    case .square: return .square
    }
  }
}

/// `ProgressRing` — Flutter's `CircularProgressIndicator`.
struct ProgressRingControlView: View {
  let node: ControlNode
  @State private var rotation = Angle.zero

  @ViewBuilder
  var body: some View {
    if RufletProgressAppearance.usesNativeCircular(node) {
      Group {
        if let value = RufletProgressAppearance.value(node) {
          ProgressView(value: value, total: 1)
        } else {
          ProgressView()
        }
      }
      .progressViewStyle(.circular)
      .tint(progressColor)
      .modifier(ProgressSemanticsValue(node: node))
    } else {
      let metrics = RufletCircularProgressMetrics(node: node)
      ZStack {
        if let track = metrics.trackArc {
          arc(metrics, from: track.from, to: track.to)
            .stroke(trackColor, style: style(metrics, cap: metrics.trackCap))
            .rotationEffect(.degrees(-90))
        }

        if let active = metrics.valueArc {
          arc(metrics, from: active.from, to: active.to)
            .stroke(progressColor, style: style(metrics, cap: metrics.strokeCap))
            .rotationEffect(.degrees(-90))
        } else {
          arc(metrics, from: 0.12, to: 0.72)
            .stroke(progressColor, style: style(metrics, cap: metrics.strokeCap))
            .rotationEffect(rotation)
            .onAppear { rotation = .degrees(360) }
            .animation(
              .linear(duration: RufletThemeDefaults.circularProgressIndeterminateDuration)
                .repeatForever(autoreverses: false),
              value: rotation)
        }
      }
      .frame(width: metrics.width, height: metrics.height)
      .padding(metrics.padding ?? EdgeInsets())
      .modifier(ProgressSemanticsValue(node: node))
    }
  }

  private func arc(
    _ metrics: RufletCircularProgressMetrics,
    from: CGFloat,
    to: CGFloat
  ) -> some Shape {
    Ellipse()
      .inset(by: metrics.strokeInset)
      .trim(from: from, to: to)
  }

  private func style(_ metrics: RufletCircularProgressMetrics, cap: CGLineCap) -> StrokeStyle {
    StrokeStyle(lineWidth: metrics.strokeWidth, lineCap: cap)
  }

  private var progressColor: Color {
    MaterialPalette.color(for: node, property: "color", default: .primary)
  }

  private var trackColor: Color {
    MaterialPalette.color(for: node, property: "bgcolor", default: .clear)
  }
}

/// Flutter defaults a determinate indicator's spoken value to its percentage;
/// `semantics_value` replaces that, and an indeterminate indicator has none.
enum RufletProgressSemantics {
  static func label(_ node: ControlNode) -> String? {
    node.string("semantics_label")
  }

  static func spokenValue(_ node: ControlNode) -> String? {
    if let explicit = node.double("semantics_value") { return String(explicit) }
    guard let value = node.double("value") else { return nil }
    return "\(Int((min(max(value, 0), 1) * 100).rounded()))"
  }
}

private struct ProgressSemanticsValue: ViewModifier {
  let node: ControlNode

  @ViewBuilder
  func body(content: Content) -> some View {
    if let label = RufletProgressSemantics.label(node),
      let spoken = RufletProgressSemantics.spokenValue(node) {
      content.accessibilityLabel(label).accessibilityValue(spoken)
    } else if let label = RufletProgressSemantics.label(node) {
      content.accessibilityLabel(label)
    } else if let spoken = RufletProgressSemantics.spokenValue(node) {
      content.accessibilityValue(spoken)
    } else {
      content
    }
  }
}

/// Flutter's `CircleAvatar` sizing.
///
/// `radius` is shorthand for identical minimum and maximum radii, and the three
/// being absent together is its own case: the avatar is then a fixed 40pt
/// circle rather than one free to grow. A lone `min_radius` leaves the maximum
/// at infinity, which has no SwiftUI counterpart and so stays unbounded.
struct RufletCircleAvatarDiameter: Equatable {
  let minimum: CGFloat
  let maximum: CGFloat?

  init(node: ControlNode) {
    let radius = node.double("radius")
    let minRadius = node.double("min_radius")
    let maxRadius = node.double("max_radius")

    guard radius != nil || minRadius != nil || maxRadius != nil else {
      minimum = RufletThemeDefaults.circleAvatarRadius * 2
      maximum = RufletThemeDefaults.circleAvatarRadius * 2
      return
    }

    minimum = CGFloat(2 * (radius ?? minRadius ?? 0))
    maximum = (radius ?? maxRadius).map { CGFloat(2 * $0) }
  }
}

/// Both CircleAvatar slots pass through the same `ResolvedAssetSource` path
/// as Image in Flet. Keeping the pair as a value makes that upstream contract
/// directly testable without loading a bundle resource or reaching a network.
struct RufletCircleAvatarImageSources: Equatable {
  let background: RufletImageSource
  let foreground: RufletImageSource

  init(node: ControlNode) {
    background = RufletImageSource(value: node.props["background_image_src"])
    foreground = RufletImageSource(value: node.props["foreground_image_src"])
  }
}

/// CircleAvatar colours after resolving explicit Ruflet values over the
/// pinned Flutter theme roles. The native Apple view consumes these semantic
/// defaults; they are not inferred from a screenshot.
struct RufletCircleAvatarAppearance: Equatable {
  let backgroundColorToken: String?
  let foregroundColorToken: String?

  init(node: ControlNode) {
    backgroundColorToken = RufletThemeDefaults.resolvedDisplayColorToken(
      for: node, property: "bgcolor")
    foregroundColorToken = RufletThemeDefaults.resolvedDisplayColorToken(
      for: node, property: "color")
  }
}

/// `buildTextOrWidget` accepts either a control or a scalar. Keeping that
/// distinction outside the View makes the wire-provider behavior executable
/// in focused tests.
enum RufletCircleAvatarContent: Equatable {
  case control(Int)
  case text(String)
  case empty

  init(node: ControlNode) {
    if let id = node.controlID(forKey: "content") {
      self = .control(id)
    } else if let text = node.string("content") {
      self = .text(text)
    } else {
      self = .empty
    }
  }
}

/// `CircleAvatar` — an image, initials, or a coloured circle.
///
/// Flutter layers the two images the way its decorations stack: the background
/// image sits over the fill, the child between them, and the foreground image
/// on top. Each reports its own failure, which is why `image_error` carries
/// the slot that failed rather than a message.
struct CircleAvatarControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let diameter = RufletCircleAvatarDiameter(node: node)
    let sources = RufletCircleAvatarImageSources(node: node)
    let appearance = RufletCircleAvatarAppearance(node: node)
    let content = RufletCircleAvatarContent(node: node)

    ZStack {
      Circle().fill(backgroundColor(appearance))

      avatarImage(source: sources.background, slot: "background")

      switch content {
      case .control(let contentID):
        ControlView(id: contentID, axis: .none)
      case .text(let text):
        // `buildTextOrWidget` wraps scalar values in Text instead of requiring
        // a nested control on the wire.
        Text(text)
      case .empty:
        EmptyView()
      }

      avatarImage(source: sources.foreground, slot: "foreground")
    }
    .frame(
      minWidth: diameter.minimum, maxWidth: diameter.maximum,
      minHeight: diameter.minimum, maxHeight: diameter.maximum)
    // CircleAvatar installs Material titleMedium around its child and disables
    // text scaling so initials cannot escape the circle. Both are semantic
    // constructor behavior even though the actual font remains native.
    .rufletTextStyle(RufletTextStyle(map: ["theme_style": .string("title_medium")]))
    .dynamicTypeSize(.medium)
    .foregroundColor(foregroundColor(appearance))
    .animation(.easeInOut(duration: 0.2), value: diameter)
    .animation(.easeInOut(duration: 0.2), value: appearance)
  }

  @ViewBuilder
  private func avatarImage(source: RufletImageSource, slot: String) -> some View {
    Group {
      switch source {
      case .binary(let data):
        if RemoteImage.canDecode(data) {
          PlatformImageView(data: data)
            .aspectRatio(contentMode: .fill)
            .clipShape(Circle())
        } else {
          Color.clear.onAppear { reportImageError(slot) }
        }
      case .remote(let url):
        if url.isFileURL {
          LocalAvatarImage(url: url, slot: slot, node: node)
        } else {
          RemoteImage(
            url: url,
            errorContentID: nil,
            onError: { _ in reportImageError(slot) })
            .aspectRatio(contentMode: .fill)
            .clipShape(Circle())
        }
      case .asset(let name):
        if let data = RufletImageSource.packagedData(named: name),
          RemoteImage.canDecode(data)
        {
          PlatformImageView(data: data)
            .aspectRatio(contentMode: .fill)
            .clipShape(Circle())
        } else {
          // Asset-catalog images remain a native Image lookup. Unlike a
          // DecorationImage provider, SwiftUI exposes no failure callback.
          Image(name)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipShape(Circle())
        }
      case .empty, .invalid, .missing:
        EmptyView()
      }
    }
    // Flutter's foreground/background DecorationImages are presentation, not
    // separate semantic nodes; only the avatar's content should be announced.
    .accessibilityHidden(true)
  }

  private func reportImageError(_ slot: String) {
    events.fire(node, "image_error", data: .string(slot))
  }

  private func backgroundColor(_ appearance: RufletCircleAvatarAppearance) -> Color {
    MaterialPalette.color(appearance.backgroundColorToken, default: .clear)
  }

  private func foregroundColor(_ appearance: RufletCircleAvatarAppearance) -> Color? {
    MaterialPalette.color(appearance.foregroundColorToken)
  }
}

/// File image providers are synchronous in Flutter. Resolve file URLs locally
/// rather than sending them through URLSession, and preserve the same slot
/// name in CircleAvatar's shared `image_error` event.
private struct LocalAvatarImage: View {
  let url: URL
  let slot: String
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Group {
      if let data = try? Data(contentsOf: url), RemoteImage.canDecode(data) {
        PlatformImageView(data: data)
          .aspectRatio(contentMode: .fill)
          .clipShape(Circle())
      } else {
        Color.clear.onAppear {
          events.fire(node, "image_error", data: .string(slot))
        }
      }
    }
  }
}

/// `Badge` — a count or dot anchored to its content's corner.
struct BadgeControlView: View {
  let node: ControlNode
  @Environment(\.layoutDirection) private var layoutDirection

  var body: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
        .overlay(alignment: ControlProps.alignment(node.props["alignment"]) ?? .topTrailing) {
          marker
        }
    } else if let text = node.string("content") {
      Text(text)
        .overlay(alignment: ControlProps.alignment(node.props["alignment"]) ?? .topTrailing) {
          marker
        }
    } else if RufletBadgeSemantics.isVisible(node) {
      // Badge returns the marker directly when `child` is null; alignment and
      // offset only participate in the child-backed Stack path.
      RufletBadgeMarker(badge: node)
    } else {
      EmptyView()
    }
  }

  @ViewBuilder
  private var marker: some View {
    if RufletBadgeSemantics.isVisible(node) {
      RufletBadgeMarker(badge: node)
        .offset(RufletBadgeSemantics.markerOffset(
          node, layoutDirection: layoutDirection))
    }
  }
}

/// `Markdown` — Flutter's `MarkdownBody`, rebuilt block by block.
///
/// Handing the whole source to Foundation's Markdown parser produced one
/// inline run, which left the style sheet, the code theme and the extension
/// set with nowhere to land. The document is therefore split into blocks here
/// and only each block's *inline* spans go to Foundation, which is also what
/// keeps links, emphasis and code spans coming from the platform.
struct MarkdownControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @Environment(\.rufletServerURL) private var serverURL

  var body: some View {
    let sheet = RufletMarkdownStyleSheet(node: node)
    let document = RufletMarkdownDocument(node: node)

    VStack(alignment: .leading, spacing: sheet.blockSpacing) {
      ForEach(Array(document.blocks.enumerated()), id: \.offset) { entry in
        MarkdownBlockView(
          node: node,
          block: entry.element,
          sheet: sheet,
          imageErrorContentID: node.controlID(forKey: "image_error_content"),
          imageBaseURL: serverURL)
      }
    }
    // MarkdownBody stretches its children when `fitContent` is off and sizes
    // its column to the content when `shrinkWrap` is on.
    .frame(maxWidth: document.fitsContent ? nil : CGFloat.infinity, alignment: .leading)
    .frame(maxHeight: document.shrinksWrap ? nil : CGFloat.infinity, alignment: .top)
    .tint(sheet.linkColor)
    .environment(\.openURL, markdownURLAction)
  }

  /// Flet reports every link tap and additionally opens the link itself only
  /// when `auto_follow_links` is set.
  private var markdownURLAction: OpenURLAction {
    OpenURLAction { url in
      events.fire(node, "tap_link", data: .string(url.absoluteString))
      return RufletMarkdownLinkBehavior.follows(
        automatically: node.bool("auto_follow_links") == true,
        target: node.string("auto_follow_links_target")) ? .systemAction : .handled
    }
  }
}

enum RufletMarkdownLinkBehavior {
  /// On native Flutter targets the URL target only changes `_blank` from the
  /// platform default to an external application; every target still launches
  /// the URL. It is a web-window hint, not permission to suppress navigation.
  static func follows(automatically: Bool, target: String?) -> Bool {
    automatically
  }
}

/// Flet's `extension_set`, which selects one of the `markdown` package's four
/// presets. Each preset is a list of block and inline syntaxes, so what it
/// really decides is which spellings mean anything in the source.
enum RufletMarkdownExtensionSet: Equatable {
  case none
  case commonMark
  case gitHubWeb
  case gitHubFlavored

  init(_ raw: String?) {
    switch raw?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "commonmark": self = .commonMark
    case "githubweb": self = .gitHubWeb
    case "githubflavored": self = .gitHubFlavored
    default: self = .none
    }
  }

  /// `FencedCodeBlockSyntax` is in every preset except `none`.
  var allowsFencedCode: Bool { self != .none }

  /// `TableSyntax`, `StrikethroughSyntax` and `AutolinkExtensionSyntax` arrive
  /// together in the two GitHub presets.
  var allowsGitHubSyntaxes: Bool { self == .gitHubWeb || self == .gitHubFlavored }
}

/// The blocks `MarkdownBody` renders, parsed from the source under whichever
/// syntaxes the extension set turned on.
struct RufletMarkdownDocument: Equatable {
  enum Block: Equatable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case code(language: String, source: String)
    case quote(text: String)
    case listItem(marker: String, text: String, depth: Int)
    case taskListItem(marker: String, text: String, depth: Int, checked: Bool)
    case image(source: String, alternate: String)
    case latex(source: String)
    case table(rows: [[String]])
    case rule
  }

  let blocks: [Block]
  let extensions: RufletMarkdownExtensionSet
  let fitsContent: Bool
  let shrinksWrap: Bool

  init(node: ControlNode) {
    extensions = RufletMarkdownExtensionSet(node.string("extension_set"))
    fitsContent = node.bool("fit_content") != false
    shrinksWrap = node.bool("shrink_wrap") != false
    blocks = Self.parse(
      node.rufletString("value"),
      extensions: extensions,
      // CommonMark folds a lone newline into a space; `soft_line_break` asks
      // for it to break the line instead.
      softLineBreak: node.bool("soft_line_break") == true)
  }

  static func parse(
    _ source: String,
    extensions: RufletMarkdownExtensionSet,
    softLineBreak: Bool
  ) -> [Block] {
    let lines = source.components(separatedBy: "\n")
    let separator = softLineBreak ? "\n" : " "
    var blocks: [Block] = []
    var paragraph: [String] = []
    var quote: [String] = []
    var index = 0

    func flushParagraph() {
      guard !paragraph.isEmpty else { return }
      let text = paragraph.joined(separator: separator)
      paragraph.removeAll()
      blocks.append(imageBlock(text) ?? .paragraph(text: text))
    }

    func flushQuote() {
      guard !quote.isEmpty else { return }
      blocks.append(.quote(text: quote.joined(separator: separator)))
      quote.removeAll()
    }

    while index < lines.count {
      let line = lines[index]
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      if trimmed.isEmpty {
        flushParagraph()
        flushQuote()
        index += 1
        continue
      }

      if extensions.allowsFencedCode, let fence = fenceMarker(trimmed) {
        flushParagraph()
        flushQuote()
        let language = String(trimmed.dropFirst(fence.count))
          .trimmingCharacters(in: .whitespaces)
        var body: [String] = []
        index += 1
        while index < lines.count,
          !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(fence)
        {
          body.append(lines[index])
          index += 1
        }
        if index < lines.count { index += 1 }
        blocks.append(.code(language: language, source: body.joined(separator: "\n")))
        continue
      }

      if trimmed.hasPrefix("$$") {
        flushParagraph()
        flushQuote()
        let (block, next) = latexBlock(lines, from: index)
        blocks.append(block)
        index = next
        continue
      }

      if isRule(trimmed) {
        flushParagraph()
        flushQuote()
        blocks.append(.rule)
        index += 1
        continue
      }

      if let heading = headingBlock(trimmed) {
        flushParagraph()
        flushQuote()
        blocks.append(heading)
        index += 1
        continue
      }

      if trimmed.hasPrefix(">") {
        flushParagraph()
        quote.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
        index += 1
        continue
      }

      if let item = listItem(line, allowsTasks: extensions.allowsGitHubSyntaxes) {
        flushParagraph()
        flushQuote()
        blocks.append(item)
        index += 1
        continue
      }

      if extensions.allowsGitHubSyntaxes, trimmed.contains("|"),
        index + 1 < lines.count,
        isTableDivider(lines[index + 1].trimmingCharacters(in: .whitespaces))
      {
        flushParagraph()
        flushQuote()
        var rows = [tableCells(trimmed)]
        index += 2
        while index < lines.count {
          let candidate = lines[index].trimmingCharacters(in: .whitespaces)
          guard candidate.contains("|") else { break }
          rows.append(tableCells(candidate))
          index += 1
        }
        blocks.append(.table(rows: rows))
        continue
      }

      flushQuote()
      paragraph.append(trimmed)
      index += 1
    }

    flushParagraph()
    flushQuote()
    return blocks
  }

  static func fenceMarker(_ line: String) -> String? {
    for marker in ["```", "~~~"] where line.hasPrefix(marker) {
      return marker
    }
    return nil
  }

  static func isRule(_ line: String) -> Bool {
    let stripped = line.replacingOccurrences(of: " ", with: "")
    guard stripped.count >= 3 else { return false }
    return ["-", "*", "_"].contains { marker in
      stripped.allSatisfy { String($0) == marker }
    }
  }

  static func headingBlock(_ line: String) -> Block? {
    let hashes = line.prefix { $0 == "#" }
    guard (1...6).contains(hashes.count) else { return nil }
    let rest = line.dropFirst(hashes.count)
    guard rest.hasPrefix(" ") else { return nil }
    return .heading(level: hashes.count, text: rest.trimmingCharacters(in: .whitespaces))
  }

  /// Nesting is measured the way the `markdown` package does it, in pairs of
  /// leading spaces.
  static func listItem(_ line: String, allowsTasks: Bool = false) -> Block? {
    let indent = line.prefix { $0 == " " }.count
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    for marker in ["- ", "* ", "+ "] where trimmed.hasPrefix(marker) {
      let body = String(trimmed.dropFirst(marker.count))
      if allowsTasks, let task = taskList(body) {
        return .taskListItem(
          marker: "\u{2022}", text: task.text, depth: indent / 2, checked: task.checked)
      }
      return .listItem(
        marker: "\u{2022}",
        text: body,
        depth: indent / 2)
    }
    let digits = trimmed.prefix { $0.isNumber }
    guard !digits.isEmpty, trimmed.dropFirst(digits.count).hasPrefix(". ") else { return nil }
    let body = String(trimmed.dropFirst(digits.count + 2))
    if allowsTasks, let task = taskList(body) {
      return .taskListItem(
        marker: "\(digits).", text: task.text, depth: indent / 2, checked: task.checked)
    }
    return .listItem(
      marker: "\(digits).",
      text: body,
      depth: indent / 2)
  }

  private static func taskList(_ value: String) -> (checked: Bool, text: String)? {
    guard value.count >= 3, value.hasPrefix("[") else { return nil }
    let flagIndex = value.index(after: value.startIndex)
    let closeIndex = value.index(after: flagIndex)
    guard value[closeIndex] == "]" else { return nil }
    let flag = value[flagIndex]
    guard flag == " " || flag == "x" || flag == "X" else { return nil }
    return (
      flag != " ",
      String(value[value.index(after: closeIndex)...]).trimmingCharacters(in: .whitespaces))
  }

  static func isTableDivider(_ line: String) -> Bool {
    guard line.contains("-"), line.contains("|") else { return false }
    return line.allSatisfy { "|-: ".contains($0) }
  }

  static func tableCells(_ line: String) -> [String] {
    var row = line
    if row.hasPrefix("|") { row.removeFirst() }
    if row.hasSuffix("|") { row.removeLast() }
    return row.components(separatedBy: "|").map {
      $0.trimmingCharacters(in: .whitespaces)
    }
  }

  /// A paragraph that is nothing but an image is the only place Flutter's
  /// `imageBuilder` — and therefore `image_error_content` — can be honoured,
  /// since a SwiftUI `Text` cannot carry an image run inline.
  static func imageBlock(_ text: String) -> Block? {
    guard text.hasPrefix("!["), text.hasSuffix(")"),
      let closing = text.firstIndex(of: "]"),
      text.index(after: closing) < text.endIndex,
      text[text.index(after: closing)] == "("
    else { return nil }
    let alternate = String(text[text.index(text.startIndex, offsetBy: 2)..<closing])
    let start = text.index(closing, offsetBy: 2)
    let source = String(text[start..<text.index(before: text.endIndex)])
    return .image(source: source, alternate: alternate)
  }

  /// `LatexBlockSyntax` delimits display maths with `$$`, either on one line or
  /// spread over several.
  static func latexBlock(_ lines: [String], from start: Int) -> (Block, Int) {
    let opening = String(lines[start].trimmingCharacters(in: .whitespaces).dropFirst(2))
    if opening.hasSuffix("$$") {
      return (.latex(source: String(opening.dropLast(2))), start + 1)
    }

    var body: [String] = opening.isEmpty ? [] : [opening]
    var index = start + 1
    while index < lines.count,
      !lines[index].trimmingCharacters(in: .whitespaces).hasSuffix("$$")
    {
      body.append(lines[index])
      index += 1
    }
    if index < lines.count {
      let closing = lines[index].trimmingCharacters(in: .whitespaces)
      let remainder = String(closing.dropLast(2))
      if !remainder.isEmpty { body.append(remainder) }
      index += 1
    }
    return (.latex(source: body.joined(separator: "\n")), index)
  }
}

/// Flutter's `MarkdownStyleSheet`, resolved from `md_style_sheet` over
/// `MarkdownStyleSheet.fromTheme`.
///
/// `code_style_sheet` is the separate sheet Flet hands its code builder, which
/// is why the code block's own padding, decoration and text style are read
/// from a different map than everything around it.
struct RufletMarkdownStyleSheet {
  let extensions: RufletMarkdownExtensionSet
  let paragraph: RufletTextStyle
  let headings: [RufletTextStyle]
  let blockquote: RufletTextStyle
  let listBullet: RufletTextStyle
  let tableHead: RufletTextStyle
  let tableBody: RufletTextStyle
  let checkbox: RufletTextStyle
  let inlineCode: RufletTextStyle
  let emphasis: RufletTextStyle
  let strong: RufletTextStyle
  let deletion: RufletTextStyle
  let link: RufletTextStyle
  let latex: RufletTextStyle
  let latexFontSize: CGFloat
  let codeFontSize: CGFloat
  let codeForeground: Color?
  let linkColor: Color?
  let blockSpacing: CGFloat
  let listIndent: CGFloat
  let paragraphPadding: EdgeInsets
  let headingPaddings: [EdgeInsets]
  let listBulletPadding: EdgeInsets
  let paragraphAlignment: Alignment
  let headingAlignments: [Alignment]
  let blockquoteAlignment: Alignment
  let codeBlockAlignment: Alignment
  let orderedListAlignment: Alignment
  let unorderedListAlignment: Alignment
  let tableHeadTextAlignment: TextAlignment
  let codeBlockPadding: EdgeInsets
  let codeBlockBackground: Color
  let codeBlockRadius: CGFloat
  let blockquotePadding: EdgeInsets
  let blockquoteBackground: Color
  let blockquoteRadius: CGFloat
  let ruleColor: Color
  let ruleThickness: CGFloat
  let tablePadding: EdgeInsets
  let tableCellPadding: EdgeInsets
  let tableBorderColor: Color

  init(node: ControlNode) {
    let sheet = node.map("md_style_sheet")
    let codeSheet = node.map("code_style_sheet")
    let theme = RufletMarkdownCodeTheme(value: node.props["code_theme"])

    extensions = RufletMarkdownExtensionSet(node.string("extension_set"))

    // The type ramp `MarkdownStyleSheet.fromTheme` reads out of `TextTheme`.
    paragraph = Self.style(sheet, "p_text_style", theme: "bodyMedium")
    headings = [
      Self.style(sheet, "h1_text_style", theme: "headlineSmall"),
      Self.style(sheet, "h2_text_style", theme: "titleLarge"),
      Self.style(sheet, "h3_text_style", theme: "titleMedium"),
      Self.style(sheet, "h4_text_style", theme: "bodyLarge"),
      Self.style(sheet, "h5_text_style", theme: "bodyLarge"),
      Self.style(sheet, "h6_text_style", theme: "bodyLarge")
    ]
    blockquote = Self.style(sheet, "blockquote_text_style", theme: "bodyMedium")
    listBullet = Self.style(sheet, "list_bullet_text_style", theme: "bodyMedium")
    tableHead = Self.style(sheet, "table_head_text_style", theme: "bodyMedium")
    tableBody = Self.style(sheet, "table_body_text_style", theme: "bodyMedium")
    var checkboxStyle = Self.style(sheet, "checkbox_text_style", theme: "bodyMedium")
    if checkboxStyle.color == nil {
      checkboxStyle.color = MaterialPalette.color(
        RufletThemeDefaults.resolvedDisplayColorToken(for: node, property: "link_color"))
    }
    checkbox = checkboxStyle

    inlineCode = Self.inlineStyle(
      sheet, "code_text_style", defaultStyle: {
        var style = RufletTextStyle(map: ["theme_style": .string("bodyMedium")])
        style.fontFamily = "monospace"
        style.size = RufletThemeDefaults.markdownBodyFontSize
          * RufletThemeDefaults.markdownCodeFontScale
        return style
      }())
    emphasis = Self.inlineStyle(
      sheet, "em_text_style", defaultStyle: RufletTextStyle(map: ["italic": .bool(true)]))
    strong = Self.inlineStyle(
      sheet, "strong_text_style", defaultStyle: RufletTextStyle(map: ["weight": .string("bold")]))
    deletion = Self.inlineStyle(
      sheet, "del_text_style", defaultStyle: RufletTextStyle(
        map: ["decoration": .int(Int64(RufletTextStyle.TextDecoration.lineThrough.rawValue))]))
    link = Self.inlineStyle(
      sheet, "a_text_style", defaultStyle: RufletTextStyle(
        map: ["color": .string(
          RufletThemeDefaults.resolvedDisplayColorToken(
            for: node, property: "link_color") ?? "primary")]))

    let latexStyle = RufletTextStyle(map: node.map("latex_style") ?? [:])
    latex = latexStyle
    let scale = node.double("latex_scale_factor").map { CGFloat($0) }
      ?? RufletThemeDefaults.markdownLatexScaleFactor
    latexFontSize = (latexStyle.size ?? RufletThemeDefaults.markdownBodyFontSize) * scale

    let code = Self.style(codeSheet, "code_text_style", theme: "bodyMedium")
    codeFontSize = code.size
      ?? RufletThemeDefaults.markdownBodyFontSize * RufletThemeDefaults.markdownCodeFontScale
    codeForeground = theme.foreground ?? code.color

    linkColor = Self.color(sheet, "a_text_style", "color")
      ?? MaterialPalette.color(
        RufletThemeDefaults.resolvedDisplayColorToken(for: node, property: "link_color"))

    blockSpacing = sheet?["block_spacing"]?.doubleValue.map { CGFloat($0) }
      ?? RufletThemeDefaults.markdownBlockSpacing
    listIndent = sheet?["list_indent"]?.doubleValue.map { CGFloat($0) }
      ?? RufletThemeDefaults.markdownListIndent
    paragraphPadding = ControlProps.edgeInsets(sheet?["p_padding"]) ?? EdgeInsets()
    headingPaddings = (1...6).map {
      ControlProps.edgeInsets(sheet?["h\($0)_padding"]) ?? EdgeInsets()
    }
    listBulletPadding = ControlProps.edgeInsets(sheet?["list_bullet_padding"])
      ?? EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 4)
    paragraphAlignment = Self.blockAlignment(sheet?["text_alignment"]?.stringValue)
    headingAlignments = (1...6).map {
      Self.blockAlignment(sheet?["h\($0)_alignment"]?.stringValue)
    }
    blockquoteAlignment = Self.blockAlignment(sheet?["blockquote_alignment"]?.stringValue)
    codeBlockAlignment = Self.blockAlignment(sheet?["codeblock_alignment"]?.stringValue)
    orderedListAlignment = Self.blockAlignment(sheet?["ordered_list_alignment"]?.stringValue)
    unorderedListAlignment = Self.blockAlignment(sheet?["unordered_list_alignment"]?.stringValue)
    tableHeadTextAlignment = Self.textAlignment(sheet?["table_head_text_align"]?.stringValue)

    codeBlockPadding = ControlProps.edgeInsets(codeSheet?["codeblock_padding"])
      ?? RufletThemeDefaults.markdownCodeblockPadding
    codeBlockBackground = theme.background
      ?? Self.decorationColor(codeSheet, "codeblock_decoration")
      ?? MaterialPalette.color(
        RufletThemeDefaults.resolvedDisplayColorToken(for: node, property: "codeblock_color"),
        default: .clear)
    codeBlockRadius = Self.decorationRadius(codeSheet, "codeblock_decoration")
      ?? RufletThemeDefaults.markdownCodeblockRadius

    blockquotePadding = ControlProps.edgeInsets(sheet?["blockquote_padding"])
      ?? RufletThemeDefaults.markdownBlockquotePadding
    blockquoteBackground = Self.decorationColor(sheet, "blockquote_decoration")
      ?? MaterialPalette.color(
        RufletThemeDefaults.resolvedDisplayColorToken(for: node, property: "blockquote_color"),
        default: .clear)
    blockquoteRadius = Self.decorationRadius(sheet, "blockquote_decoration")
      ?? RufletThemeDefaults.markdownBlockquoteRadius

    // `horizontalRuleDecoration` is a 5pt top border in the divider colour,
    // which is the whole rule once it is drawn on its own.
    let divider = MaterialPalette.color(
      RufletThemeDefaults.resolvedDisplayColorToken(for: node, property: "divider_color"),
      default: .clear)
    ruleColor = Self.borderColor(sheet, "horizontal_rule_decoration") ?? divider
    ruleThickness = Self.borderWidth(sheet, "horizontal_rule_decoration")
      ?? RufletThemeDefaults.markdownRuleThickness

    tablePadding = ControlProps.edgeInsets(sheet?["table_padding"])
      ?? RufletThemeDefaults.markdownTablePadding
    tableCellPadding = ControlProps.edgeInsets(sheet?["table_cells_padding"])
      ?? RufletThemeDefaults.markdownTableCellPadding
    tableBorderColor = divider
  }

  func heading(_ level: Int) -> RufletTextStyle {
    headings[min(max(level, 1), headings.count) - 1]
  }

  func headingPadding(_ level: Int) -> EdgeInsets {
    headingPaddings[min(max(level, 1), headingPaddings.count) - 1]
  }

  func headingAlignment(_ level: Int) -> Alignment {
    headingAlignments[min(max(level, 1), headingAlignments.count) - 1]
  }

  private static func inlineStyle(
    _ map: [String: RufletValue]?, _ key: String, defaultStyle: RufletTextStyle
  ) -> RufletTextStyle {
    guard let value = map?[key]?.mapValue else { return defaultStyle }
    return RufletTextStyle(map: value)
  }

  private static func blockAlignment(_ raw: String?) -> Alignment {
    switch raw?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "center", "spacearound", "spacebetween", "spaceevenly": return .center
    case "end", "right": return .trailing
    default: return .leading
    }
  }

  private static func textAlignment(_ raw: String?) -> TextAlignment {
    switch raw?.lowercased() {
    case "center": return .center
    case "right", "end": return .trailing
    default: return .leading
    }
  }

  private static func style(
    _ map: [String: RufletValue]?,
    _ key: String,
    theme name: String
  ) -> RufletTextStyle {
    var resolved = RufletTextStyle(map: map?[key]?.mapValue ?? [:])
    if resolved.themeStyle == nil, resolved.size == nil {
      resolved.themeStyle = RufletTextStyle.themeTextStyle(name)
    }
    return resolved
  }

  private static func color(
    _ map: [String: RufletValue]?,
    _ key: String,
    _ field: String
  ) -> Color? {
    MaterialPalette.color(map?[key]?.mapValue?[field]?.stringValue)
  }

  private static func decorationColor(
    _ map: [String: RufletValue]?,
    _ key: String
  ) -> Color? {
    MaterialPalette.color(map?[key]?.mapValue?["bgcolor"]?.stringValue)
  }

  private static func decorationRadius(
    _ map: [String: RufletValue]?,
    _ key: String
  ) -> CGFloat? {
    ControlProps.cornerRadius(map?[key]?.mapValue?["border_radius"])
  }

  private static func borderColor(_ map: [String: RufletValue]?, _ key: String) -> Color? {
    ControlProps.border(map?[key]?.mapValue?["border"])?.color
  }

  private static func borderWidth(_ map: [String: RufletValue]?, _ key: String) -> CGFloat? {
    ControlProps.border(map?[key]?.mapValue?["border"])?.width
  }
}

/// Flutter resolves `code_theme` either from flutter_highlight's theme map by
/// name or from a map of highlight token names to text styles.
///
/// Tokenising the source would need highlight.dart's language grammars, which
/// Ruflet does not vendor, so only the theme's `root` entry — the block's own
/// foreground and background — reaches the screen.
struct RufletMarkdownCodeTheme: Equatable {
  var foreground: Color?
  var background: Color?

  init(value: RufletValue?) {
    guard let value else { return }
    if let name = value.stringValue {
      guard let root = RufletThemeDefaults.markdownCodeThemeRoot(named: name) else { return }
      foreground = MaterialPalette.color(root.foreground)
      background = MaterialPalette.color(root.background)
      return
    }
    guard let root = value["root"]?.mapValue else { return }
    foreground = MaterialPalette.color(root["color"]?.stringValue)
    background = MaterialPalette.color(root["bgcolor"]?.stringValue)
  }
}

/// Inline spans go to Foundation's Markdown parser so emphasis, code spans and
/// links come from the platform. The extension set decides what reaches it:
/// strikethrough is escaped away unless GitHub's syntaxes were asked for, and
/// bare URLs are only linkified when they were.
enum RufletMarkdownInline {
  static func attributed(
    _ source: String, extensions: RufletMarkdownExtensionSet,
    sheet: RufletMarkdownStyleSheet? = nil, baseStyle: RufletTextStyle? = nil,
    literal: Bool = false
  ) -> AttributedString {
    let prepared = literal ? source : prepare(source, extensions: extensions)
    var attributed = (try? AttributedString(
      markdown: prepared,
      options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
      ?? AttributedString(source)
    if let baseStyle { apply(baseStyle, to: &attributed, range: attributed.startIndex..<attributed.endIndex) }
    if let sheet, !literal { applyInlineStyles(sheet, to: &attributed) }
    return attributed
  }

  static func text(
    _ source: String, extensions: RufletMarkdownExtensionSet,
    sheet: RufletMarkdownStyleSheet? = nil, baseStyle: RufletTextStyle? = nil,
    literal: Bool = false
  ) -> Text {
    Text(attributed(
      source, extensions: extensions, sheet: sheet, baseStyle: baseStyle, literal: literal))
  }

  private static func applyInlineStyles(
    _ sheet: RufletMarkdownStyleSheet, to attributed: inout AttributedString
  ) {
    for run in attributed.runs {
      var style: RufletTextStyle?
      if run.link != nil {
        style = sheet.link
      } else if let intent = run.inlinePresentationIntent {
        if intent.contains(.code) { style = sheet.inlineCode }
        else if intent.contains(.strikethrough) { style = sheet.deletion }
        else if intent.contains(.stronglyEmphasized) { style = sheet.strong }
        else if intent.contains(.emphasized) { style = sheet.emphasis }
      }
      guard let style else { continue }
      apply(style, to: &attributed, range: run.range)
    }
  }

  private static func apply(
    _ style: RufletTextStyle, to attributed: inout AttributedString,
    range: Range<AttributedString.Index>
  ) {
    attributed[range].font = style.font
    if let color = style.color { attributed[range].foregroundColor = color }
    if let background = style.backgroundColor { attributed[range].backgroundColor = background }
    if let spacing = style.letterSpacing { attributed[range].kern = spacing }
    if style.decoration.contains(.underline) { attributed[range].underlineStyle = .single }
    if style.decoration.contains(.lineThrough) { attributed[range].strikethroughStyle = .single }
  }

  static func prepare(_ source: String, extensions: RufletMarkdownExtensionSet) -> String {
    guard extensions.allowsGitHubSyntaxes else {
      return source.replacingOccurrences(of: "~", with: "\\~")
    }
    return linkify(source)
  }

  /// `AutolinkExtensionSyntax` turns a bare URL into a link. Foundation only
  /// links explicit `[text](url)` spans, so the bare ones are rewritten first.
  static func linkify(_ source: String) -> String {
    guard let regex = try? NSRegularExpression(
      pattern: "(?<![(\\[])\\bhttps?://[^\\s)\\]]+")
    else { return source }
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    return regex.stringByReplacingMatches(
      in: source, range: range, withTemplate: "[$0]($0)")
  }
}

/// One parsed block, drawn with the sheet that block's element uses.
private struct MarkdownBlockView: View {
  let node: ControlNode
  let block: RufletMarkdownDocument.Block
  let sheet: RufletMarkdownStyleSheet
  let imageErrorContentID: Int?
  let imageBaseURL: URL?

  @ViewBuilder
  var body: some View {
    switch block {
    case .heading(let level, let text):
      inline(text, style: sheet.heading(level))
        .padding(sheet.headingPadding(level))
        .frame(maxWidth: .infinity, alignment: sheet.headingAlignment(level))

    case .paragraph(let text):
      inline(text, style: sheet.paragraph)
        .padding(sheet.paragraphPadding)
        .frame(maxWidth: .infinity, alignment: sheet.paragraphAlignment)

    case .code(_, let source):
      let codeStyle = markdownCodeBlockStyle
      inline(source, style: codeStyle, literal: true)
        .frame(maxWidth: .infinity, alignment: sheet.codeBlockAlignment)
        .padding(sheet.codeBlockPadding)
        .background(
          RoundedRectangle(cornerRadius: sheet.codeBlockRadius)
            .fill(sheet.codeBlockBackground))

    case .quote(let text):
      inline(text, style: sheet.blockquote)
        .frame(maxWidth: .infinity, alignment: sheet.blockquoteAlignment)
        .padding(sheet.blockquotePadding)
        .background(
          RoundedRectangle(cornerRadius: sheet.blockquoteRadius)
            .fill(sheet.blockquoteBackground))

    case .listItem(let marker, let text, let depth):
      let bulletGap = RufletThemeDefaults.markdownListBulletGap
      HStack(alignment: .firstTextBaseline, spacing: bulletGap) {
        Text(marker).rufletStyled(sheet.listBullet).padding(sheet.listBulletPadding)
        inline(text, style: sheet.paragraph)
      }
      .padding(.leading, sheet.listIndent * CGFloat(depth))
      .frame(
        maxWidth: .infinity,
        alignment: marker == "•" ? sheet.unorderedListAlignment : sheet.orderedListAlignment)

    case .taskListItem(let marker, let text, let depth, let checked):
      HStack(alignment: .firstTextBaseline, spacing: RufletThemeDefaults.markdownListBulletGap) {
        Image(systemName: checked ? "checkmark.square" : "square")
          .rufletTextStyle(sheet.checkbox)
          .accessibilityLabel(checked ? "Checked" : "Unchecked")
        inline(text, style: sheet.paragraph)
      }
      .padding(.leading, sheet.listIndent * CGFloat(depth))
      .frame(
        maxWidth: .infinity,
        alignment: marker == "•" ? sheet.unorderedListAlignment : sheet.orderedListAlignment)

    case .image(let source, let alternate):
      MarkdownImageView(
        source: source, alternate: alternate, errorContentID: imageErrorContentID,
        baseURL: imageBaseURL)

    case .latex(let source):
      // Ruflet has no maths typesetter, so the formula's own source is shown
      // in the style and at the scale Flet asked for rather than dropped.
      inline(source, style: markdownLatexStyle, literal: true)

    case .table(let rows):
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(rows.enumerated()), id: \.offset) { row in
          HStack(spacing: 0) {
            ForEach(Array(row.element.enumerated()), id: \.offset) { cell in
              inline(
                cell.element,
                style: row.offset == 0 ? sheet.tableHead : sheet.tableBody)
                .multilineTextAlignment(row.offset == 0 ? sheet.tableHeadTextAlignment : .leading)
                .padding(sheet.tableCellPadding)
                .frame(maxWidth: .infinity, alignment: row.offset == 0 ? .center : .leading)
            }
          }
          .overlay(Rectangle().stroke(sheet.tableBorderColor, lineWidth: 1))
        }
      }
      .padding(sheet.tablePadding)

    case .rule:
      Rectangle()
        .fill(sheet.ruleColor)
        .frame(maxWidth: .infinity)
        .frame(height: sheet.ruleThickness)
    }
  }

  @ViewBuilder
  private func inline(
    _ text: String, style: RufletTextStyle, literal: Bool = false
  ) -> some View {
    let attributed = RufletMarkdownInline.attributed(
      text, extensions: sheet.extensions, sheet: sheet, baseStyle: style, literal: literal)
    if node.bool("selectable") == true || selectionAreaChange != nil {
      RufletSelectableMarkdownText(
        node: node, source: text, attributed: attributed, events: events,
        selectionAreaChange: selectionAreaChange,
        activate: { openURL($0) }, tapText: { events.fire(node, "tap_text") })
    } else {
      Text(attributed)
    }
  }

  private var markdownCodeBlockStyle: RufletTextStyle {
    var style = RufletTextStyle()
    style.size = sheet.codeFontSize
    style.fontFamily = "monospace"
    style.color = sheet.codeForeground
    return style
  }

  private var markdownLatexStyle: RufletTextStyle {
    var style = sheet.latex
    style.size = sheet.latexFontSize
    return style
  }

  @Environment(\.rufletEvents) private var events
  @Environment(\.openURL) private var openURL
  @Environment(\.rufletSelectionAreaChange) private var selectionAreaChange
}

/// A block-level markdown image, which is where `image_error_content` lands.
private struct MarkdownImageView: View {
  let source: String
  let alternate: String
  let errorContentID: Int?
  let baseURL: URL?

  @ViewBuilder
  var body: some View {
    if case .binary(let data) = RufletImageSource(value: .string(source)) {
      PlatformImageView(data: data)
        .aspectRatio(contentMode: .fit)
        .accessibilityLabel(alternate)
    } else if case .remote(let url) = RufletImageSource(value: .string(source)) {
      RemoteImage(url: url, errorContentID: errorContentID)
        .aspectRatio(contentMode: .fit)
        .accessibilityLabel(alternate)
    } else if let data = RufletImageSource.packagedData(named: source) {
      PlatformImageView(data: data)
        .aspectRatio(contentMode: .fit)
        .accessibilityLabel(alternate)
    } else if let url = RufletImageAssetURL.markdownAsset(source, relativeTo: baseURL) {
      RemoteImage(url: url, errorContentID: errorContentID)
        .aspectRatio(contentMode: .fit)
        .accessibilityLabel(alternate)
    } else {
      Image(source)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .accessibilityLabel(alternate)
    }
  }
}

/// `TextSpan` — only ever composed into a parent `Text`, never standalone.
struct TextSpanControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @Environment(\.openURL) private var openURL

  var body: some View {
    Text(node.string("text") ?? "")
      .rufletTextStyle(RufletTextStyle(node: node))
      .accessibilityLabel(node.string("semantics_label") ?? node.string("text") ?? "")
      .modifier(
        SpellOutCharacters(
          enabled: node.bool("spell_out") == true,
          label: node.string("semantics_label") ?? node.string("text") ?? ""))
      .onTapGesture {
        guard node.bool("disabled") != true else { return }
        if let raw = node.string("url"), let url = URL(string: raw) { openURL(url) }
        events.fire(node, "click")
      }
      .onHover { entered in
        guard node.bool("disabled") != true else { return }
        events.fire(node, entered ? "enter" : "exit")
      }
  }
}

private struct SpellOutCharacters: ViewModifier {
  let enabled: Bool
  let label: String
  func body(content: Content) -> some View {
    // SwiftUI's speech-spelling attribute is newer than this package's iOS
    // 15 floor. A space-separated accessibility label produces the same
    // VoiceOver character-by-character reading on supported Apple releases.
    if enabled {
      content.accessibilityLabel(label.map(String.init).joined(separator: " "))
    } else {
      content
    }
  }
}
