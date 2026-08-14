import RufletProtocol
import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// Apple-native port of pinned `expansion_tile.dart`.
@MainActor
public struct ExpansionTileControl: View {
  @ObservedObject public var control: RufletControl
  @State private var expanded: Bool

  public init(control: RufletControl) {
    self.control = control
    _expanded = State(initialValue: control.boolean("expanded", default: false))
  }

  public var body: some View {
    let presentation = RufletExpansionTilePresentation(control: control)
    LayoutControl(control: control) {
      if control.buildTextOrWidget("title") == nil {
        ErrorControl("ExpansionTile.title must be provided and visible")
      } else if expandedCrossAxisAlignment == .baseline {
        ErrorControl(
          "CrossAxisAlignment.BASELINE is not supported since expanded controls use a column")
      } else {
        tile(presentation)
      }
    }
    .onAppear(perform: synchronize)
    .onChange(of: control.properties) { _ in synchronize() }
  }

  private func tile(_ presentation: RufletExpansionTilePresentation) -> some View {
    VStack(spacing: 0) {
      Button(action: toggle) {
        HStack(spacing: presentation.horizontalTitleGap) {
          if affinity == .leading, showTrailingIcon { disclosureIcon }
          if let leading = control.buildIconOrWidget("leading", color: currentIconColor) { leading }

          VStack(alignment: .leading, spacing: 2) {
            if let title = control.buildTextOrWidget("title") {
              title
                .foregroundStyle(currentTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let subtitle = control.buildTextOrWidget("subtitle") {
              subtitle
                .font(.subheadline)
                .foregroundStyle(currentTextColor.opacity(0.68))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }

          if let trailing = control.buildIconOrWidget("trailing", color: currentIconColor) {
            trailing
          }
          if affinity != .leading, showTrailingIcon { disclosureIcon }
        }
        .padding(presentation.tilePadding)
        .frame(minHeight: presentation.minimumTileHeight)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(control.disabled)

      expandedControls
    }
    .background(presentation.resolvedBackgroundColor(expanded: expanded))
    .clipShape(RufletExpansionTileShape(description: presentation.shape(expanded: expanded)))
    .overlay {
      let shape = presentation.shape(expanded: expanded)
      if let side = shape.side {
        RufletExpansionTileShape(description: shape)
          .stroke(side.color, lineWidth: side.width)
      }
    }
    .modifier(RufletExpansionClipModifier(behavior: control.string("clip_behavior")))
    .animation(expansionAnimation(opening: expanded), value: expanded)
    .accessibilityElement(children: .contain)
    .accessibilityValue(expanded ? "expanded" : "collapsed")
  }

  private var disclosureIcon: some View {
    Image(systemName: "chevron.down")
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(currentIconColor)
      .rotationEffect(expanded ? .degrees(180) : .zero)
  }

  @ViewBuilder
  private var expandedControls: some View {
    if expanded || maintainState {
      VStack(alignment: childrenAlignment, spacing: 0) {
        ForEach(control.children("controls")) { child in
          ControlWidget(control: child)
        }
      }
      .frame(maxWidth: childrenStretch ? .infinity : nil, alignment: expandedAlignment)
      .padding(controlsPadding)
      .opacity(expanded ? 1 : 0)
      .frame(height: expanded ? nil : 0, alignment: .top)
      .clipped()
      .allowsHitTesting(expanded)
      .accessibilityHidden(!expanded)
    }
  }

  private enum RufletExpansionAffinity: String {
    case leading, trailing, platform
  }

  private var affinity: RufletExpansionAffinity {
    RufletExpansionAffinity(rawValue: control.string("affinity")?.lowercased() ?? "platform")
      ?? .platform
  }

  private var showTrailingIcon: Bool {
    control.boolean("show_trailing_icon", default: true)
  }

  private var maintainState: Bool {
    control.boolean("maintain_state", default: false)
  }

  private var controlsPadding: EdgeInsets {
    parsePadding(control.dynamicValue("controls_padding")) ?? EdgeInsets()
  }

  private var expandedAlignment: Alignment {
    parseAlignment(control.dynamicValue("expanded_alignment"), .center)!.swiftUI
  }

  private var expandedCrossAxisAlignment: RufletCrossAxisAlignment {
    parseEnum(
      RufletCrossAxisAlignment.self,
      control.string("expanded_cross_axis_alignment"),
      .center)!
  }

  private var childrenAlignment: HorizontalAlignment {
    switch expandedCrossAxisAlignment {
    case .start: return .leading
    case .end: return .trailing
    default: return .center
    }
  }

  private var childrenStretch: Bool {
    expandedCrossAxisAlignment == .stretch
  }

  private var currentTextColor: Color {
    let presentation = RufletExpansionTilePresentation(control: control)
    return presentation.resolvedTextColor(expanded: expanded)
  }

  private var currentIconColor: Color {
    let presentation = RufletExpansionTilePresentation(control: control)
    return presentation.resolvedIconColor(expanded: expanded)
  }

  private func expansionAnimation(opening: Bool) -> Animation {
    guard let details = rufletDictionary(control.dynamicValue("animation_style")) else {
      return .easeInOut(duration: 0.2)
    }
    let durationName = opening ? "duration" : "reverse_duration"
    let curveName = opening ? "curve" : "reverse_curve"
    let duration = parseDuration(details[durationName], 0.2)!
    return parseCurve(details[curveName] as? String, .easeinout)!.animation(duration: duration)
  }

  private func synchronize() {
    let requested = control.boolean("expanded", default: false)
    guard requested != expanded else { return }
    withAnimation(expansionAnimation(opening: requested)) { expanded = requested }
  }

  private func toggle() {
    guard !control.disabled else { return }
    let presentation = RufletExpansionTilePresentation(control: control)
    if presentation.enableFeedback { performExpansionTileFeedback() }
    let next = !expanded
    withAnimation(expansionAnimation(opening: next)) { expanded = next }
    rufletCommitExpansion(
      target: control,
      expanded: next,
      notify: false,
      eventControl: control,
      eventData: .bool(next))
  }
}

enum RufletExpansionTileShapeKind: String, Equatable {
  case roundedRectangle
  case stadium
  case circle
  case beveledRectangle
  case continuousRectangle
}

struct RufletExpansionTileShapeDescription: @unchecked Sendable {
  let kind: RufletExpansionTileShapeKind
  let radius: RufletBorderRadius
  let eccentricity: Double
  let side: RufletBorderSide?

  init(_ value: Any?) {
    let details = rufletDictionary(value)
    switch (details?["_type"] as? String)?.lowercased() {
    case "stadium": kind = .stadium
    case "circle": kind = .circle
    case "beveledrectangle": kind = .beveledRectangle
    case "continuousrectangle": kind = .continuousRectangle
    default: kind = .roundedRectangle
    }
    radius = parseBorderRadius(
      details?["radius"] ?? details?["border_radius"],
      RufletBorderRadius(topLeft: 10, topRight: 10, bottomLeft: 10, bottomRight: 10))!
    eccentricity = parseDouble(details?["eccentricity"], 0)!
    side = parseBorderSide(details?["side"])
  }
}

@MainActor
struct RufletExpansionTilePresentation {
  let backgroundColor: Color?
  let iconColor: Color?
  let textColor: Color?
  let collapsedBackgroundColor: Color?
  let collapsedIconColor: Color?
  let collapsedTextColor: Color?
  let expandedShape: RufletExpansionTileShapeDescription
  let collapsedShape: RufletExpansionTileShapeDescription
  let visualDensity: RufletVisualDensity?
  let enableFeedback: Bool
  let dense: Bool
  let explicitMinimumTileHeight: CGFloat?
  let tilePadding: EdgeInsets

  init(control: RufletControl) {
    backgroundColor = parseColor(control.string("bgcolor"))
    iconColor = parseColor(control.string("icon_color"))
    textColor = parseColor(control.string("text_color"))
    collapsedBackgroundColor = parseColor(control.string("collapsed_bgcolor"))
    collapsedIconColor = parseColor(control.string("collapsed_icon_color"))
    collapsedTextColor = parseColor(control.string("collapsed_text_color"))
    expandedShape = RufletExpansionTileShapeDescription(control.dynamicValue("shape"))
    collapsedShape = RufletExpansionTileShapeDescription(control.dynamicValue("collapsed_shape"))
    visualDensity = parseVisualDensity(control.string("visual_density"))
    enableFeedback = control.boolean("enable_feedback") ?? true
    dense = control.boolean("dense", default: false)
    explicitMinimumTileHeight = control.number("min_tile_height").map { CGFloat($0) }
    tilePadding =
      parseEdgeInsets(control.dynamicValue("tile_padding"))
      ?? RufletLayoutDefaults.listTile
  }

  var horizontalTitleGap: CGFloat {
    switch visualDensity {
    case .compact: 8
    case .comfortable: 12
    case .adaptivePlatformDensity, .standard, nil: 16
    }
  }

  var minimumTileHeight: CGFloat {
    if let explicitMinimumTileHeight { return explicitMinimumTileHeight }
    let base: CGFloat = dense ? 48 : 56
    switch visualDensity {
    case .compact: return base - 8
    case .comfortable: return base - 4
    case .adaptivePlatformDensity, .standard, nil: return base
    }
  }

  func resolvedBackgroundColor(expanded: Bool) -> Color {
    (expanded ? backgroundColor : collapsedBackgroundColor) ?? .clear
  }

  func resolvedIconColor(expanded: Bool) -> Color {
    (expanded ? iconColor : collapsedIconColor) ?? .secondary
  }

  func resolvedTextColor(expanded: Bool) -> Color {
    (expanded ? textColor : collapsedTextColor) ?? .primary
  }

  func shape(expanded: Bool) -> RufletExpansionTileShapeDescription {
    expanded ? expandedShape : collapsedShape
  }
}

private struct RufletExpansionTileShape: Shape {
  let description: RufletExpansionTileShapeDescription

  func path(in rect: CGRect) -> Path {
    switch description.kind {
    case .circle:
      let eccentricity = CGFloat(min(max(description.eccentricity, 0), 1))
      if rect.width < rect.height {
        let delta = (1 - eccentricity) * (rect.height - rect.width) / 2
        return Ellipse().path(in: rect.insetBy(dx: 0, dy: delta))
      }
      let delta = (1 - eccentricity) * (rect.width - rect.height) / 2
      return Ellipse().path(in: rect.insetBy(dx: delta, dy: 0))
    case .stadium:
      return Capsule().path(in: rect)
    case .beveledRectangle:
      let amount = min(description.radius.topLeft, min(rect.width, rect.height) / 2)
      var path = Path()
      path.move(to: CGPoint(x: rect.minX + amount, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX - amount, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + amount))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - amount))
      path.addLine(to: CGPoint(x: rect.maxX - amount, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX + amount, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - amount))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + amount))
      path.closeSubpath()
      return path
    case .roundedRectangle, .continuousRectangle:
      return RufletCornerShape(radius: description.radius).path(in: rect)
    }
  }
}

private func performExpansionTileFeedback() {
  #if os(iOS)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  #elseif os(macOS)
    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
  #endif
}

@MainActor
func rufletCommitExpansion(
  target: RufletControl,
  expanded: Bool,
  notify: Bool,
  eventControl: RufletControl,
  eventData: RufletValue
) {
  target.updateProperties(["expanded": .bool(expanded)], notify: notify)
  eventControl.triggerEvent("change", data: eventData)
}

private struct RufletExpansionClipModifier: ViewModifier {
  let behavior: String?

  @ViewBuilder
  func body(content: Content) -> some View {
    switch behavior?.lowercased() {
    case "none": content
    case "antialias", "antialiaswithsavelayer": content.clipped(antialiased: true)
    default: content.clipped()
    }
  }
}
