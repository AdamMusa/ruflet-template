import RufletEngine
import RufletProtocol
import SwiftUI

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

  var body: some View {
    let style = RufletTextStyle.forText(node: node)

    renderedText(style: style)
      .multilineTextAlignment(alignment)
      .lineLimit(lineLimit)
      .truncationMode(truncation)
      .lineSpacing(style.lineHeight ?? 0)
      .fixedSize(horizontal: node.bool("no_wrap") == true, vertical: false)
      .frame(maxWidth: node.double("max_width").map { CGFloat($0) })
      .background(style.backgroundColor)
      .modifier(TextSelectionCursor(node: node))
      .modifier(TapReporter(node: node, events: events))
  }

  /// Flutter's `TextOverflow`. `ellipsis` is also carried as its own boolean,
  /// which Flet treats as the same request.
  private var truncation: Text.TruncationMode {
    if node.bool("ellipsis") == true { return .tail }
    switch node.string("overflow")?.lowercased() {
    case "ellipsis": return .tail
    case "fade", "clip", "visible": return .tail
    default: return .tail
    }
  }

  @ViewBuilder
  private func renderedText(style: RufletTextStyle) -> some View {
    let document = RufletRichTextDocument(
      value: node.string("value") ?? "",
      spanIDs: node.controlIDs(forKey: "spans"),
      resolve: store.node)
    let attributed = document.attributedString(rootStyle: style)
    if node.bool("selectable") == true || document.runs.contains(where: \.tracksPointer) {
      RufletSelectableRichText(
        node: node, document: document, attributed: attributed, events: events,
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

  /// `max_lines` caps the run; `no_wrap` is Flutter's single-line shorthand.
  private var lineLimit: Int? {
    if node.bool("no_wrap") == true { return 1 }
    return node.int("max_lines")
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
    guard node.bool("show_selection_cursor") == true else { return AnyView(content) }
    let width = CGFloat(node.double("selection_cursor_width") ?? 2)
    return AnyView(
      content
        .tint(MaterialPalette.color(node.string("selection_cursor_color")))
        .frame(minHeight: node.double("selection_cursor_height").map { CGFloat($0) })
        .padding(.trailing, width))
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
      .modifier(IconFillAxis(filled: glyph.isFilled))
      // Material's opsz axis; SF Symbols express the same idea as the glyph's
      // own point size, so it scales the resolved symbol.
      .modifier(IconOpticalSize(value: node.double("optical_size")))
      .modifier(IconShadows(value: node.props["shadows"]))
      .modifier(IconBlendMode(name: node.string("blend_mode")))
      .modifier(TapReporter(node: node, events: events))
  }

  /// `RufletIcon` builds its font from the size alone, and SwiftUI's
  /// `fontWeight` cannot reach an image whose font is already set further in,
  /// so an icon carrying the wght or GRAD axis is drawn from the same resolved
  /// SF Symbol with the weight folded into its font.
  @ViewBuilder
  private func symbol(_ glyph: RufletIconGlyph) -> some View {
    let value = node.props["name"] ?? node.props["icon"]
    let color = MaterialPalette.color(node.string("color"))
    if let weight = glyph.symbolWeight, let name = IconMapping.symbol(for: value) {
      Image(systemName: name)
        .font(.system(size: glyph.scaledSize(textScale: textScale), weight: weight))
        .modifier(IconGlyphColor(color: color))
    } else {
      RufletIcon(value: value, size: glyph.scaledSize(textScale: textScale), color: color)
    }
  }
}

/// The Material Symbols axes an `Icon` carries, resolved onto what SF Symbols
/// can express.
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

/// Material's FILL axis picks between the outlined and filled cuts of a glyph,
/// which is exactly SF Symbols' fill variant. An icon that asked for neither
/// keeps the platform's own outlined rendering.
private struct IconFillAxis: ViewModifier {
  let filled: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if filled {
      content.symbolVariant(.fill)
    } else {
      content
    }
  }
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
  @Environment(\.rufletEvents) private var events

  var body: some View {
    content
      .modifier(ImageFit(node: node))
      .modifier(ImageColorFilter(node: node))
      .clipShape(RoundedRectangle(cornerRadius: ControlProps.cornerRadius(node.props["border_radius"]) ?? 0))
      .modifier(ImageSemantics(node: node))
      .modifier(TapReporter(node: node, events: events))
  }

  @ViewBuilder
  private var content: some View {
    if case .binary(let data) = RufletImageSource(node: node) {
      PlatformImageView(data: data)
    } else if case .remote(let url) = RufletImageSource(node: node) {
      if url.isFileURL, let data = try? Data(contentsOf: url) {
        PlatformImageView(data: data)
      } else {
        RemoteImage(
          url: url,
          errorContentID: node.controlID(forKey: "error_content"),
          onLoad: { events.fire(node, "load") },
          onError: { message in events.fire(node, "error", data: .string(message)) })
      }
    } else if case .asset(let name) = RufletImageSource(node: node) {
      // A bundle resource, the way a packaged Ruby project ships its assets.
      Image(name)
        .resizable()
    } else {
      Text("Image must have \"src\" specified.")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }
}

/// The forms accepted by Flet's `getSrc`: bytes, data URIs, network/file URLs,
/// and packaged assets. Resolution is deliberately separate from SwiftUI so
/// byte/data-URI behavior is covered without a network or snapshot test.
enum RufletImageSource: Equatable {
  case binary(Data)
  case remote(URL)
  case asset(String)
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
    if case .binary(let bytes) = value {
      self = .binary(Data(bytes))
      return
    }
    guard let rawSource = value?.stringValue else {
      self = .missing
      return
    }
    let source = rawSource.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !source.isEmpty else {
      self = .missing
      return
    }
    if let data = Self.dataURI(source) {
      self = .binary(data)
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
}

private struct ImageColorFilter: ViewModifier {
  let node: ControlNode

  @ViewBuilder
  func body(content: Content) -> some View {
    if let color = MaterialPalette.color(node.string("color")) {
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
  let node: ControlNode

  func body(content: Content) -> some View {
    // Flet's BoxFit; `contain` is Flutter's default for Image.
    switch node.string("fit")?.lowercased() {
    case "cover", "fitwidth", "fitheight":
      return AnyView(content.aspectRatio(contentMode: .fill).clipped())
    case "fill":
      return AnyView(content)
    case "none", "scaledown":
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
  var onLoad: () -> Void = {}
  var onError: (String) -> Void = { _ in }

  @State private var data: Data?
  @State private var failed = false

  var body: some View {
    Group {
      if let data {
        PlatformImageView(data: data)
      } else if failed {
        if let errorContentID {
          ControlView(id: errorContentID, axis: .none)
        } else {
          Image(systemName: "photo").foregroundColor(.secondary)
        }
      } else {
        ProgressView()
      }
    }
    .task(id: url) { await load() }
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

  var body: some View {
    #if canImport(UIKit)
      if let image = UIImage(data: data) {
        Image(uiImage: image).resizable()
      }
    #elseif canImport(AppKit)
      if let image = NSImage(data: data) {
        Image(nsImage: image).resizable()
      }
    #endif
  }
}

/// Flutter's `LinearProgressIndicator` geometry.
///
/// `year2023` still defaults to true upstream, so an unconfigured bar is the
/// original Material 3 shape: square ends, a track that runs the full width and
/// no stop indicator. `year_2023: false` opts into the 2024 revision, which
/// rounds the ends, leaves a gap before the remaining track and puts a dot at
/// the far end.
struct RufletLinearProgressMetrics: Equatable {
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
    guard let value, value < 1 else { return 0 }
    return trackGap ?? 0
  }

  func activeWidth(in width: CGFloat) -> CGFloat {
    guard let value else { return 0 }
    return width * CGFloat(value)
  }

  /// The leading edge of the remaining track, which the gap pushes right.
  func trackOrigin(in width: CGFloat) -> CGFloat {
    guard value != nil, effectiveTrackGap > 0 else { return 0 }
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

/// `ProgressBar` — Flutter's `LinearProgressIndicator`.
///
/// Drawn rather than delegated to SwiftUI's linear `ProgressView`, which
/// exposes neither the bar's height nor the 2024 track gap and stop indicator.
struct ProgressBarControlView: View {
  let node: ControlNode
  @State private var sweep: CGFloat = 0

  var body: some View {
    let metrics = RufletLinearProgressMetrics(node: node)

    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        bar(metrics, width: proxy.size.width)
      }
    }
    .frame(height: metrics.height)
    .modifier(ProgressSemanticsValue(node: node))
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
  let diameter: CGFloat
  let strokeWidth: CGFloat
  let strokeAlign: CGFloat
  let trackGap: CGFloat?
  let strokeCap: CGLineCap
  let trackCap: CGLineCap
  let drawsTrack: Bool
  let padding: EdgeInsets?

  init(node: ControlNode) {
    let year2023 = node.bool("year_2023") != false
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
    let minimum = constraints?.minWidth ?? constraints?.minHeight
      ?? (year2023
        ? RufletThemeDefaults.circularProgressLegacyDiameter
        : RufletThemeDefaults.circularProgressDiameter)
    // Flet wraps the indicator in a SizedBox, whose tight constraint wins over
    // the ConstrainedBox minimum the widget carries.
    let requested = node.double("width") ?? node.double("height")
    let base = requested.map { CGFloat($0) } ?? minimum
    if let ceiling = constraints?.maxWidth ?? constraints?.maxHeight {
      diameter = min(base, ceiling)
    } else {
      diameter = base
    }

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

  var body: some View {
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
    .frame(width: metrics.diameter, height: metrics.diameter)
    .padding(metrics.padding ?? EdgeInsets())
    .modifier(ProgressSemanticsValue(node: node))
  }

  private func arc(
    _ metrics: RufletCircularProgressMetrics,
    from: CGFloat,
    to: CGFloat
  ) -> some Shape {
    Circle()
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
  static func spokenValue(_ node: ControlNode) -> String? {
    if let explicit = node.double("semantics_value") { return String(explicit) }
    guard let value = node.double("value") else { return nil }
    return "\(Int((value * 100).rounded()))%"
  }
}

private struct ProgressSemanticsValue: ViewModifier {
  let node: ControlNode

  @ViewBuilder
  func body(content: Content) -> some View {
    if let spoken = RufletProgressSemantics.spokenValue(node) {
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

    ZStack {
      Circle().fill(backgroundColor)

      avatarImage(source: sources.background, slot: "background")

      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }

      avatarImage(source: sources.foreground, slot: "foreground")
    }
    .frame(
      minWidth: diameter.minimum, maxWidth: diameter.maximum,
      minHeight: diameter.minimum, maxHeight: diameter.maximum)
    // Flutter wraps the child in a `titleMedium` DefaultTextStyle and an
    // IconTheme of the same colour, so initials and glyphs both pick it up.
    .font(.headline)
    .foregroundColor(foregroundColor)
  }

  @ViewBuilder
  private func avatarImage(source: RufletImageSource, slot: String) -> some View {
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
      Image(name)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .clipShape(Circle())
    case .missing:
      EmptyView()
    }
  }

  private func reportImageError(_ slot: String) {
    events.fire(node, "image_error", data: .string(slot))
  }

  private var backgroundColor: Color {
    MaterialPalette.color(
      RufletThemeDefaults.resolvedDisplayColorToken(for: node, property: "bgcolor"),
      default: .clear)
  }

  private var foregroundColor: Color? {
    MaterialPalette.color(
      RufletThemeDefaults.resolvedDisplayColorToken(for: node, property: "color"))
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

  var body: some View {
    Group {
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    .overlay(alignment: .topTrailing) {
      if node.bool("visible") != false {
        label
      }
    }
  }

  @ViewBuilder
  private var label: some View {
    let text = node.string("text") ?? node.string("label")
    if let text, !text.isEmpty {
      Text(text)
        .font(.caption2)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule().fill(MaterialPalette.color(node.string("bgcolor"), default: .red)))
        .foregroundColor(MaterialPalette.color(node.string("text_color"), default: .white))
        .offset(x: 6, y: -6)
    } else {
      Circle()
        .fill(MaterialPalette.color(node.string("bgcolor"), default: .red))
        .frame(width: 8, height: 8)
        .offset(x: 3, y: -3)
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

  var body: some View {
    let sheet = RufletMarkdownStyleSheet(node: node)
    let document = RufletMarkdownDocument(node: node)

    VStack(alignment: .leading, spacing: sheet.blockSpacing) {
      ForEach(Array(document.blocks.enumerated()), id: \.offset) { entry in
        MarkdownBlockView(
          block: entry.element,
          sheet: sheet,
          imageErrorContentID: node.controlID(forKey: "image_error_content"))
      }
    }
    // MarkdownBody stretches its children when `fitContent` is off and sizes
    // its column to the content when `shrinkWrap` is on.
    .frame(maxWidth: document.fitsContent ? nil : CGFloat.infinity, alignment: .leading)
    .frame(maxHeight: document.shrinksWrap ? nil : CGFloat.infinity, alignment: .top)
    .modifier(SelectableText(enabled: node.bool("selectable") == true))
    .tint(sheet.linkColor)
    .environment(\.openURL, markdownURLAction)
    .onTapGesture {
      if node.handlesEvent("tap_text") {
        events.fire(node, "tap_text")
      }
    }
  }

  /// Flet reports every link tap and additionally opens the link itself only
  /// when `auto_follow_links` is set.
  private var markdownURLAction: OpenURLAction {
    OpenURLAction { url in
      events.fire(node, "tap_link", data: .string(url.absoluteString))
      guard node.bool("auto_follow_links") == true else { return .handled }
      // `auto_follow_links_target` is Flutter's UrlLauncher mode. A link asked
      // to stay inside the app has no in-app browser here, so only an external
      // target hands off to the system; the rest are reported and left.
      switch node.string("auto_follow_links_target")?.lowercased() {
      case "self", "in_app_web_view", "inappwebview": return .handled
      default: return .systemAction
      }
    }
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

      if let item = listItem(line) {
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
  static func listItem(_ line: String) -> Block? {
    let indent = line.prefix { $0 == " " }.count
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    for marker in ["- ", "* ", "+ "] where trimmed.hasPrefix(marker) {
      return .listItem(
        marker: "\u{2022}",
        text: String(trimmed.dropFirst(marker.count)),
        depth: indent / 2)
    }
    let digits = trimmed.prefix { $0.isNumber }
    guard !digits.isEmpty, trimmed.dropFirst(digits.count).hasPrefix(". ") else { return nil }
    return .listItem(
      marker: "\(digits).",
      text: String(trimmed.dropFirst(digits.count + 2)),
      depth: indent / 2)
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
  let latex: RufletTextStyle
  let latexFontSize: CGFloat
  let codeFontSize: CGFloat
  let codeForeground: Color?
  let linkColor: Color?
  let blockSpacing: CGFloat
  let listIndent: CGFloat
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
  static func text(_ source: String, extensions: RufletMarkdownExtensionSet) -> Text {
    let prepared = prepare(source, extensions: extensions)
    guard let attributed = try? AttributedString(
      markdown: prepared,
      options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
    else {
      return Text(source)
    }
    return Text(attributed)
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
  let block: RufletMarkdownDocument.Block
  let sheet: RufletMarkdownStyleSheet
  let imageErrorContentID: Int?

  @ViewBuilder
  var body: some View {
    switch block {
    case .heading(let level, let text):
      inline(text).rufletStyled(sheet.heading(level))

    case .paragraph(let text):
      inline(text).rufletStyled(sheet.paragraph)

    case .code(_, let source):
      Text(source)
        .font(.system(size: sheet.codeFontSize, design: .monospaced))
        .foregroundColor(sheet.codeForeground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(sheet.codeBlockPadding)
        .background(
          RoundedRectangle(cornerRadius: sheet.codeBlockRadius)
            .fill(sheet.codeBlockBackground))

    case .quote(let text):
      inline(text)
        .rufletStyled(sheet.blockquote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(sheet.blockquotePadding)
        .background(
          RoundedRectangle(cornerRadius: sheet.blockquoteRadius)
            .fill(sheet.blockquoteBackground))

    case .listItem(let marker, let text, let depth):
      let bulletGap = RufletThemeDefaults.markdownListBulletGap
      HStack(alignment: .firstTextBaseline, spacing: bulletGap) {
        Text(marker).rufletStyled(sheet.listBullet)
        inline(text).rufletStyled(sheet.paragraph)
      }
      .padding(.leading, sheet.listIndent * CGFloat(depth))

    case .image(let source, let alternate):
      MarkdownImageView(
        source: source, alternate: alternate, errorContentID: imageErrorContentID)

    case .latex(let source):
      // Ruflet has no maths typesetter, so the formula's own source is shown
      // in the style and at the scale Flet asked for rather than dropped.
      Text(source)
        .font(.system(size: sheet.latexFontSize, design: .serif))
        .foregroundColor(sheet.latex.color)

    case .table(let rows):
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(rows.enumerated()), id: \.offset) { row in
          HStack(spacing: 0) {
            ForEach(Array(row.element.enumerated()), id: \.offset) { cell in
              inline(cell.element)
                .rufletStyled(row.offset == 0 ? sheet.tableHead : sheet.tableBody)
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

  private func inline(_ text: String) -> Text {
    RufletMarkdownInline.text(text, extensions: sheet.extensions)
  }
}

/// A block-level markdown image, which is where `image_error_content` lands.
private struct MarkdownImageView: View {
  let source: String
  let alternate: String
  let errorContentID: Int?

  @ViewBuilder
  var body: some View {
    if let url = URL(string: source), url.scheme != nil {
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
