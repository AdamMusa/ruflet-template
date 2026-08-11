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

  var body: some View {
    let style = RufletTextStyle(node: node)

    text.rufletStyled(style)
      .multilineTextAlignment(alignment)
      .lineLimit(lineLimit)
      .truncationMode(.tail)
      .lineSpacing(style.lineHeight ?? 0)
      .fixedSize(horizontal: node.bool("no_wrap") == true, vertical: false)
      .background(style.backgroundColor)
      .modifier(SelectableText(enabled: node.bool("selectable") == true))
      .modifier(TapReporter(node: node, events: events))
  }

  /// Spans compose into one run so styling stays inline, matching Flutter's
  /// `Text.rich`.
  private var text: Text {
    let spans = node.controlIDs(forKey: "spans").compactMap { store.node($0) }
    guard !spans.isEmpty else {
      return Text(node.string("value") ?? "")
    }
    var composed = Text(node.string("value") ?? "")
    for span in spans {
      composed = composed + Text(span.string("text") ?? "").rufletStyled(RufletTextStyle(node: span))
    }
    return composed
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
struct IconControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    RufletIcon(
      value: node.props["name"] ?? node.props["icon"],
      size: node.double("size").map { CGFloat($0) } ?? 24,
      color: MaterialPalette.color(node.string("color")))
      .modifier(TapReporter(node: node, events: events))
  }
}

/// `Image` — a local bundle resource, a data URI, or a remote URL.
struct ImageControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    content
      .modifier(ImageFit(node: node))
      .clipShape(RoundedRectangle(cornerRadius: ControlProps.cornerRadius(node.props["border_radius"]) ?? 0))
      .modifier(TapReporter(node: node, events: events))
  }

  @ViewBuilder
  private var content: some View {
    if let source = node.string("src"), let url = URL(string: source), url.scheme != nil {
      RemoteImage(
        url: url,
        errorContentID: node.controlID(forKey: "error_content"),
        onLoad: { events.fire(node, "load") },
        onError: { message in events.fire(node, "error", data: .string(message)) })
    } else if let base64 = node.string("src_base64"), let data = Data(base64Encoded: base64) {
      PlatformImageView(data: data)
    } else if let name = node.string("src") {
      // A bundle resource, the way a packaged Ruby project ships its assets.
      Image(name)
        .resizable()
    } else {
      Color.clear
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

/// `ProgressBar` — determinate when `value` is set, indeterminate otherwise.
struct ProgressBarControlView: View {
  let node: ControlNode

  var body: some View {
    Group {
      if let value = node.double("value") {
        ProgressView(value: max(0, min(value, 1)))
      } else {
        ProgressView()
          .progressViewStyle(.linear)
      }
    }
    .tint(MaterialPalette.color(for: node, property: "color"))
    .frame(width: node.double("width").map { CGFloat($0) })
  }
}

/// `ProgressRing` — the circular counterpart.
struct ProgressRingControlView: View {
  let node: ControlNode
  @State private var rotation = Angle.zero

  var body: some View {
    ZStack {
      Circle()
        .stroke(trackColor, lineWidth: strokeWidth)

      if let value = node.double("value") {
        Circle()
          .trim(from: 0, to: max(0, min(value, 1)))
          .stroke(progressColor, style: strokeStyle)
          .rotationEffect(.degrees(-90))
      } else {
        Circle()
          .trim(from: 0.12, to: 0.72)
          .stroke(progressColor, style: strokeStyle)
          .rotationEffect(rotation)
          .onAppear {
            rotation = .degrees(360)
          }
          .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: rotation)
      }
    }
    .frame(width: diameter, height: diameter)
    .padding(strokeWidth / 2)
  }

  private var diameter: CGFloat {
    CGFloat(node.double("width") ?? node.double("height")
      ?? Double(FletThemeDefaults.progressRingDiameter))
  }

  private var strokeWidth: CGFloat {
    CGFloat(node.double("stroke_width") ?? Double(FletThemeDefaults.progressStrokeWidth))
  }

  private var strokeStyle: StrokeStyle {
    StrokeStyle(lineWidth: strokeWidth, lineCap: node.bool("stroke_align") == false ? .butt : .round)
  }

  private var progressColor: Color {
    MaterialPalette.color(for: node, property: "color", default: .primary)
  }

  private var trackColor: Color {
    MaterialPalette.color(for: node, property: "bgcolor", default: .clear)
  }
}

/// `CircleAvatar` — an image, initials, or a coloured circle.
struct CircleAvatarControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let radius = CGFloat(node.double("radius") ?? 20)

    ZStack {
      Circle().fill(MaterialPalette.color(node.string("bgcolor"), default: .gray.opacity(0.3)))
      if let source = node.string("foreground_image_src") ?? node.string("background_image_src"),
        let url = URL(string: source), url.scheme != nil
      {
        RemoteImage(
          url: url,
          errorContentID: nil,
          onError: { message in events.fire(node, "image_error", data: .string(message)) })
          .aspectRatio(contentMode: .fill)
          .clipShape(Circle())
      } else if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    .frame(width: radius * 2, height: radius * 2)
    .foregroundColor(MaterialPalette.color(node.string("color")))
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

/// `Markdown` — rendered with the platform's own Markdown support.
struct MarkdownControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let source = node.string("value") ?? ""
    if #available(iOS 15.0, macOS 12.0, *),
      let attributed = try? AttributedString(
        markdown: source,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
    {
      Text(attributed)
        .modifier(SelectableText(enabled: node.fletBool("selectable")))
        .onTapGesture {
          if node.handlesEvent("tap_text") {
            events.fire(node, "tap_text", data: .string(source))
          }
        }
    } else {
      Text(source)
        .modifier(SelectableText(enabled: node.fletBool("selectable")))
        .onTapGesture {
          if node.handlesEvent("tap_text") {
            events.fire(node, "tap_text", data: .string(source))
          }
        }
    }
  }
}

/// `TextSpan` — only ever composed into a parent `Text`, never standalone.
struct TextSpanControlView: View {
  let node: ControlNode

  var body: some View {
    Text(node.string("text") ?? "")
      .rufletTextStyle(RufletTextStyle(node: node))
  }
}
