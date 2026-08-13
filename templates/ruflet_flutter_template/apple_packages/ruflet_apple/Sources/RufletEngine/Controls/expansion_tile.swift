import RufletProtocol
import SwiftUI

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
    LayoutControl(control: control) {
      if control.buildTextOrWidget("title") == nil {
        ErrorControl("ExpansionTile.title must be provided and visible")
      } else if expandedCrossAxisAlignment == .baseline {
        ErrorControl(
          "CrossAxisAlignment.BASELINE is not supported since expanded controls use a column")
      } else {
        tile
      }
    }
    .onAppear(perform: synchronize)
    .onChange(of: control.properties) { _ in synchronize() }
  }

  private var tile: some View {
    VStack(spacing: 0) {
      Button(action: toggle) {
        HStack(spacing: 12) {
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
        .padding(tilePadding)
        .frame(minHeight: minimumTileHeight)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(control.disabled)

      expandedControls
    }
    .background(currentBackgroundColor)
    .clipShape(RufletCornerShape(radius: currentRadius))
    .overlay { currentBorder }
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

  @ViewBuilder
  private var currentBorder: some View {
    if let side = currentSide {
      RufletCornerShape(radius: currentRadius).stroke(side.color, lineWidth: side.width)
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

  private var tilePadding: EdgeInsets {
    parseEdgeInsets(control.dynamicValue("tile_padding"))
      ?? EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
  }

  private var controlsPadding: EdgeInsets {
    parsePadding(control.dynamicValue("controls_padding")) ?? EdgeInsets()
  }

  private var minimumTileHeight: CGFloat {
    CGFloat(control.number("min_tile_height") ?? (control.boolean("dense") == true ? 44 : 48))
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
    parseColor(control.string(expanded ? "text_color" : "collapsed_text_color")) ?? .primary
  }

  private var currentIconColor: Color {
    parseColor(control.string(expanded ? "icon_color" : "collapsed_icon_color"))
      ?? .secondary
  }

  private var currentBackgroundColor: Color {
    parseColor(control.string(expanded ? "bgcolor" : "collapsed_bgcolor")) ?? .clear
  }

  private var currentShape: [String: Any]? {
    rufletDictionary(control.dynamicValue(expanded ? "shape" : "collapsed_shape"))
  }

  private var currentRadius: RufletBorderRadius {
    parseBorderRadius(
      currentShape?["radius"] ?? currentShape?["border_radius"],
      RufletBorderRadius(topLeft: 10, topRight: 10, bottomLeft: 10, bottomRight: 10))!
  }

  private var currentSide: RufletBorderSide? {
    parseBorderSide(currentShape?["side"])
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
