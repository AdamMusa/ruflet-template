import RufletEngine
import RufletProtocol
import SwiftUI

/// `Switch` — Material's switch, drawn.
///
/// A platform `Toggle` cannot take Flet's thumb, track, outline and thumb-icon
/// colours: SwiftUI exposes only `tint`, and on Apple it renders as the
/// Cupertino switch, which is the shape `adaptive: true` is supposed to opt
/// *into*. So the Material switch is drawn here, next to the hand-drawn
/// checkbox and radio, and `CupertinoSwitch` stays native.
///
/// The value is written locally the instant the switch flips, so the control
/// tracks the finger, and a `change` event follows. `Page#dispatch_event`
/// applies the same value to the Ruby control before running the handler, so
/// the two sides agree without a second round trip.
struct SwitchControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let disabled = node.bool("disabled") ?? false

    HStack(spacing: 0) {
      if labelPosition == .left { label }
      MaterialSwitch(node: node, isOn: isOn)
        .modifier(
          MaterialStateLayer(
            node: node,
            selected: isOn,
            radius: node.double("splash_radius").map { CGFloat($0) }
              ?? RufletThemeDefaults.switchTrackHeight / 2))
        .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets())
      if labelPosition == .right { label }
    }
    // Flutter wraps a labelled switch in a GestureDetector, so tapping the
    // label flips it too.
    .contentShape(Rectangle())
    .onTapGesture { if !disabled { toggle() } }
    .modifier(
      SelectionScaling(
        node: node,
        natural: CGSize(
          width: RufletThemeDefaults.switchTrackWidth,
          height: RufletThemeDefaults.switchTrackHeight)))
    .modifier(FocusReporter(node: node, events: events))
    .disabled(disabled)
  }

  private enum LabelPlacement { case left, right }

  private var labelPosition: LabelPlacement {
    node.string("label_position")?.lowercased() == "left" ? .left : .right
  }

  private var isOn: Bool { node.bool("value") ?? false }

  @ViewBuilder
  private var label: some View {
    if let labelID = node.controlID(forKey: "label") {
      ControlView(id: labelID, axis: .none)
    } else if let value = node.string("label") {
      Text(value)
        .rufletTextStyle(RufletTextStyle(node: node, styleKey: "label_text_style"))
        // Flutter recolours a disabled label with the theme's disabled colour
        // rather than leaving the style's own colour in place.
        .foregroundColor(node.bool("disabled") == true ? Color.secondary : nil)
    }
  }

  private func toggle() {
    events.commit(node, value: .bool(!isOn))
  }
}

/// Material's switch: a 52×32 track carrying a thumb that grows from 16pt to
/// 24pt when it is on, which is Flutter's `_SwitchConfigM3`.
private struct MaterialSwitch: View {
  let node: ControlNode
  let isOn: Bool

  private var states: Set<RufletWidgetState> { node.widgetStates(selected: isOn) }

  var body: some View {
    ZStack(alignment: isOn ? .trailing : .leading) {
      Capsule()
        .fill(trackColor)
        .overlay(Capsule().strokeBorder(outlineColor, lineWidth: outlineWidth))
        .frame(
          width: RufletThemeDefaults.switchTrackWidth,
          height: RufletThemeDefaults.switchTrackHeight)
      thumb
        .padding(.horizontal, RufletThemeDefaults.switchThumbInset)
    }
    .frame(
      width: RufletThemeDefaults.switchTrackWidth,
      height: RufletThemeDefaults.switchTrackHeight)
    .animation(.easeInOut(duration: 0.2), value: isOn)
  }

  private var thumb: some View {
    let size = isOn
      ? RufletThemeDefaults.switchSelectedThumbSize
      : RufletThemeDefaults.switchThumbSize
    return Circle()
      .fill(thumbColor)
      .frame(width: size, height: size)
      .overlay { thumbIcon }
      .shadow(radius: isOn ? 1 : 0)
  }

  /// `thumb_icon` is a widget-state icon: Flet's usual `{selected: …}` table,
  /// so the glyph can differ between on and off.
  @ViewBuilder
  private var thumbIcon: some View {
    if let icon = RufletWidgetStateProperty.resolve(node.props["thumb_icon"], in: states) {
      RufletIcon(value: icon, size: RufletThemeDefaults.switchThumbIconSize, color: trackColor)
    }
  }

  /// Flet names the track twice: `track_color` is the stateful spelling and
  /// `active_track_color`/`inactive_track_color` the plain ones. Flutter
  /// resolves the stateful property first, then the side-specific one, then
  /// the theme role.
  private var trackColor: Color {
    if let stateful = MaterialPalette.color(stateful: node.props["track_color"], in: states) {
      return stateful
    }
    return MaterialPalette.color(
      for: node,
      property: isOn ? "active_track_color" : "inactive_track_color",
      default: .accentColor)
  }

  /// `active_color` is Flutter's `activeThumbColor` — the thumb, not the
  /// track it slides along.
  private var thumbColor: Color {
    if let stateful = MaterialPalette.color(stateful: node.props["thumb_color"], in: states) {
      return stateful
    }
    return MaterialPalette.color(
      for: node,
      property: isOn ? "active_color" : "inactive_thumb_color",
      default: .white)
  }

  /// Material outlines the track only while the switch is off; once it is on
  /// the filled track is the boundary.
  private var outlineColor: Color {
    if let stateful = MaterialPalette.color(
      stateful: node.props["track_outline_color"], in: states)
    {
      return stateful
    }
    return isOn ? .clear : MaterialPalette.color(for: node, property: "track_outline_color",
                                                 default: .secondary)
  }

  private var outlineWidth: CGFloat {
    ControlProps.statefulDouble(node.props["track_outline_width"], in: states)
      ?? RufletThemeDefaults.switchTrackOutlineWidth
  }
}

/// `Checkbox` — a tri-state box when `tristate` is set, matching Flutter.
struct CheckboxControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let disabled = node.bool("disabled") ?? false

    HStack(spacing: 0) {
      if labelPosition == .left { label }
      checkboxMark
      if labelPosition == .right { label }
    }
    .contentShape(Rectangle())
    .onTapGesture { if !disabled { advance() } }
    .modifier(SelectionScaling(node: node, natural: RufletThemeDefaults.checkboxTargetSize))
    .modifier(FocusReporter(node: node, events: events))
    .accessibilityLabel(node.string("semantics_label") ?? "")
    .disabled(disabled)
  }

  private enum LabelPlacement { case left, right }

  private var labelPosition: LabelPlacement {
    node.string("label_position")?.lowercased() == "left" ? .left : .right
  }

  @ViewBuilder
  private var label: some View {
    if let labelID = node.controlID(forKey: "label") {
      ControlView(id: labelID, axis: .none)
    } else if let value = node.string("label") {
      Text(value)
        .rufletTextStyle(RufletTextStyle(node: node, styleKey: "label_style"))
        .foregroundColor(node.bool("disabled") == true ? Color.secondary : nil)
    }
  }

  private var state: Bool? { RufletCheckboxState.resting(node) }

  private var states: Set<RufletWidgetState> {
    node.widgetStates(selected: state == true)
  }

  private var checkboxMark: some View {
    let checked = state
    let side = ControlProps.statefulBorderSide(node.props["border_side"], in: states)
    let box = ChipShape(
      radius: ControlProps.cornerRadius(node.map("shape")?["radius"])
        ?? RufletThemeDefaults.checkboxCornerRadius)

    return ZStack {
      box.fill(checked == false ? .clear : fillColor)
      box.strokeBorder(
        checked == false ? (side?.color ?? outlineColor) : .clear,
        lineWidth: side?.width ?? RufletThemeDefaults.checkboxBorderWidth)
      // Flutter draws the tick when the box is checked and the dash when it is
      // indeterminate, both in `check_color`; an unchecked box is empty.
      if checked != false {
        Image(systemName: checked == true ? "checkmark" : "minus")
          .font(.system(size: RufletThemeDefaults.checkboxMarkSize, weight: .bold))
          .foregroundColor(checkColor)
      }
    }
    .frame(width: RufletThemeDefaults.checkboxSize, height: RufletThemeDefaults.checkboxSize)
    .frame(width: targetSide, height: targetSide)
    .modifier(MaterialStateLayer(node: node, selected: state == true, radius: targetSide / 2))
    .modifier(VisualDensityPadding(value: node.props["visual_density"]))
  }

  /// `splash_radius` names the ripple, and with it the tap target Material
  /// reserves around an 18pt box.
  private var targetSide: CGFloat {
    node.double("splash_radius").map { CGFloat($0) * 2 } ?? RufletThemeDefaults.checkboxTargetSize
  }

  private var fillColor: Color {
    MaterialPalette.color(stateful: node.props["fill_color"], in: states)
      ?? MaterialPalette.color(for: node, property: "active_color", default: .accentColor)
  }

  private var outlineColor: Color {
    node.bool("error") == true
      ? MaterialPalette.color("error", default: .red)
      : MaterialPalette.color(for: node, property: "inactive_color", default: .secondary)
  }

  private var checkColor: Color {
    MaterialPalette.color(node.string("check_color"), default: .white)
  }

  private func advance() {
    events.commit(node, value: RufletCheckboxState.next(after: state, tristate: node.bool("tristate") == true))
  }
}

/// The checkbox's `bool?` value, which is where Flutter and a naive Bool part
/// company.
enum RufletCheckboxState {
  /// Flutter's value is `bool?`, and Flet defaults it to nil when the box is
  /// tristate: a tristate checkbox that was never given a value rests
  /// *indeterminate*, not unchecked, so absence and `false` differ here.
  static func resting(_ node: ControlNode) -> Bool? {
    guard let value = node.props["value"], !value.isNull else {
      return node.bool("tristate") == true ? nil : false
    }
    return value.boolValue ?? false
  }

  /// Flutter's cycle. Without tristate it is the plain flip; with it, an
  /// indeterminate box goes to unchecked, unchecked to checked, and checked
  /// back to indeterminate.
  static func next(after state: Bool?, tristate: Bool) -> RufletValue {
    guard tristate else { return .bool(!(state ?? false)) }
    switch state {
    case .none: return .bool(false)
    case .some(false): return .bool(true)
    case .some(true): return .null
    }
  }
}

/// Flet scales a selection control into `width`/`height` with a `SizedBox`
/// around a `FittedBox` — its own source calls this "a hack to size the
/// switch" — rather than re-laying the control out. Scaling rather than
/// resizing is the observable part, so it is what is reproduced here.
/// `natural` is the size being scaled from.
struct SelectionScaling: ViewModifier {
  let node: ControlNode
  let natural: CGSize

  init(node: ControlNode, natural: CGSize) {
    self.node = node
    self.natural = natural
  }

  init(node: ControlNode, natural side: CGFloat) {
    self.init(node: node, natural: CGSize(width: side, height: side))
  }

  func body(content: Content) -> some View {
    let width = node.double("width").map { CGFloat($0) }
    let height = node.double("height").map { CGFloat($0) }
    if width == nil && height == nil { return AnyView(content) }
    return AnyView(
      content
        .scaleEffect(
          x: (width ?? natural.width) / natural.width,
          y: (height ?? natural.height) / natural.height)
        .frame(width: width, height: height))
  }
}

/// `Radio` — one option of a `RadioGroup`.
///
/// The group owns the value: a radio reports `change` on the group control, the
/// way Flet's RadioGroup does, so a group-level Ruby handler fires once.
struct RadioControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let disabled = node.bool("disabled") ?? false

    HStack(spacing: 0) {
      if labelPosition == .left { label }
      radioMark
      if labelPosition == .right { label }
    }
    .contentShape(Rectangle())
    .onTapGesture { if !disabled { select() } }
    .modifier(SelectionScaling(node: node, natural: RufletThemeDefaults.radioTargetSize))
    .modifier(FocusReporter(node: node, events: events))
    .disabled(disabled)
  }

  private enum LabelPlacement { case left, right }

  private var labelPosition: LabelPlacement {
    node.string("label_position")?.lowercased() == "left" ? .left : .right
  }

  @ViewBuilder
  private var label: some View {
    if let labelID = node.controlID(forKey: "label") {
      ControlView(id: labelID, axis: .none)
    } else if let value = node.string("label") {
      Text(value)
        .rufletTextStyle(RufletTextStyle(node: node, styleKey: "label_style"))
        .foregroundColor(node.bool("disabled") == true ? Color.secondary : nil)
    }
  }

  private var states: Set<RufletWidgetState> { node.widgetStates(selected: isSelected) }

  private var radioMark: some View {
    let fill = MaterialPalette.color(stateful: node.props["fill_color"], in: states)
      ?? MaterialPalette.color(for: node, property: "active_color", default: .accentColor)
    let resting = MaterialPalette.color(for: node, property: "inactive_color", default: .secondary)
    return ZStack {
      Circle().strokeBorder(
        isSelected ? fill : resting, lineWidth: RufletThemeDefaults.radioBorderWidth)
      if isSelected {
        Circle()
          .fill(fill)
          .frame(width: RufletThemeDefaults.radioDotSize, height: RufletThemeDefaults.radioDotSize)
      }
    }
    .frame(width: RufletThemeDefaults.radioSize, height: RufletThemeDefaults.radioSize)
    .frame(width: targetSide, height: targetSide)
    .modifier(MaterialStateLayer(node: node, selected: isSelected, radius: targetSide / 2))
    .modifier(VisualDensityPadding(value: node.props["visual_density"]))
  }

  private var targetSide: CGFloat {
    node.double("splash_radius").map { CGFloat($0) * 2 } ?? RufletThemeDefaults.radioTargetSize
  }

  private var group: ControlNode? {
    // Radios sit inside their group's subtree, so the nearest ancestor that is
    // a RadioGroup owns the selection.
    store.nodes.values.first { candidate in
      candidate.type == "RadioGroup" && contains(group: candidate, radio: node.id)
    }
  }

  private func contains(group: ControlNode, radio: Int) -> Bool {
    var frontier = group.childIDs + group.controlIDs(forKey: "content")
    var seen: Set<Int> = []
    while let id = frontier.popLast() {
      guard seen.insert(id).inserted else { continue }
      if id == radio { return true }
      guard let child = store.node(id) else { continue }
      frontier.append(contentsOf: child.childIDs)
      frontier.append(contentsOf: child.controlIDs(forKey: "content"))
    }
    return false
  }

  private var isSelected: Bool {
    guard let value = node.string("value") else { return false }
    return group?.string("value") == value
  }

  private func select() {
    guard let value = node.string("value") else { return }
    if let group {
      if isSelected && node.bool("toggleable") == true {
        events.commit(group, value: .string(""))
      } else {
        events.commit(group, value: .string(value))
      }
    } else {
      events.commit(node, key: "selected", value: .bool(true), event: "change")
    }
  }
}

/// `RadioGroup` — holds the selected value; the radios inside it render.
struct RadioGroupControlView: View {
  let node: ControlNode

  var body: some View {
    if let contentID = node.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .vertical)
    } else {
      ControlList(ids: node.childIDs, axis: .vertical)
    }
  }
}

/// The value/pixel arithmetic both sliders share.
///
/// Keeping it out of the views makes the part that was wrong testable: the
/// range slider used to convert a drag by dividing by the touch's *starting*
/// x rather than by the track width, so its thumbs did not follow the finger.
struct RufletSliderScale {
  let minimum: Double
  let maximum: Double
  let divisions: Int?
  /// Half a thumb, which both ends of the track reserve so the thumb stays
  /// inside it at the extremes.
  let inset: CGFloat
  /// The distance a thumb centre may travel — the track minus one thumb.
  let travel: CGFloat

  init(
    minimum: Double,
    maximum: Double,
    divisions: Int?,
    width: CGFloat,
    thumbWidth: CGFloat
  ) {
    self.minimum = minimum
    self.maximum = maximum
    self.divisions = (divisions ?? 0) > 0 ? divisions : nil
    self.inset = thumbWidth / 2
    self.travel = max(width - thumbWidth, 1)
  }

  var span: Double { max(maximum - minimum, .ulpOfOne) }

  /// Where a value's thumb centre sits, measured from the track's left edge.
  func position(of value: Double) -> CGFloat {
    let clamped = min(max(value, minimum), maximum)
    return inset + travel * CGFloat((clamped - minimum) / span)
  }

  /// The value under a point, snapped to `divisions` when there are any.
  func value(at x: CGFloat) -> Double {
    let fraction = min(max(Double((x - inset) / travel), 0), 1)
    let raw = minimum + fraction * span
    guard let divisions else { return raw }
    let step = span / Double(divisions)
    return min(max(minimum + ((raw - minimum) / step).rounded() * step, minimum), maximum)
  }
}

/// How much of the track responds to a tap or drag.
///
/// Flutter's `SliderInteraction`, which Flet spells `interaction`.
enum RufletSliderInteraction: String {
  case tapAndSlide
  case tapOnly
  case slideOnly
  case slideThumb

  init(wire: String?) {
    switch wire?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "taponly": self = .tapOnly
    case "slideonly": self = .slideOnly
    case "slidethumb": self = .slideThumb
    default: self = .tapAndSlide
    }
  }

  /// Whether a gesture starting away from the thumb may move it.
  var acceptsTrackGestures: Bool { self != .slideThumb }
  var acceptsSlide: Bool { self != .tapOnly }
}

/// `Slider` — a continuous or stepped value.
///
/// Reports `change_start` when the drag begins, `change` while it moves and
/// `change_end` when it settles, which is the trio Flet's Slider emits.
///
/// Drawn rather than delegated to SwiftUI's `Slider`, which offers no way to
/// colour the inactive track, the thumb or the secondary track, and no value
/// bubble — four of the properties Flet's Slider carries.
struct SliderControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var dragging = false

  var body: some View {
    let value = clampedValue

    MaterialSliderTrack(
      node: node,
      thumbs: [value],
      secondary: node.double("secondary_track_value"),
      activeRange: minimum...value,
      interaction: RufletSliderInteraction(wire: node.string("interaction")),
      bubbles: [dragging ? bubbleText(for: value) : nil],
      scale: scale(width:),
      onEdit: { editing in
        dragging = editing
        events.fire(node, editing ? "change_start" : "change_end", data: .double(clampedValue))
      },
      onMove: { _, proposed in events.commit(node, value: .double(proposed)) })
      .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets())
      .modifier(FocusReporter(node: node, events: events))
      .disabled(node.bool("disabled") ?? false)
  }

  private var minimum: Double { node.double("min") ?? 0 }
  private var maximum: Double { node.double("max") ?? 1 }

  private var clampedValue: Double {
    min(max(node.double("value") ?? minimum, minimum), max(maximum, minimum))
  }

  private func scale(width: CGFloat) -> RufletSliderScale {
    RufletSliderScale(
      minimum: minimum, maximum: maximum, divisions: node.int("divisions"), width: width,
      thumbWidth: RufletThemeDefaults.sliderMetrics(year2023: node.bool("year_2023")).thumbWidth)
  }

  /// Flet's `label` is a template: it substitutes the thumb's value, rounded
  /// to `round` decimals, wherever `{value}` appears.
  private func bubbleText(for value: Double) -> String? {
    guard let template = node.string("label"), !template.isEmpty else { return nil }
    let digits = max(node.int("round") ?? 0, 0)
    return template.replacingOccurrences(
      of: RufletThemeDefaults.sliderLabelValueToken,
      with: String(format: "%.\(digits)f", value))
  }
}

/// `RangeSlider` — two thumbs over one track.
struct RangeSliderControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var dragging = false

  var body: some View {
    let values = RufletThemeDefaults.rangeSliderValues(node)
    let start = min(max(values.start, minimum), maximum)
    let end = min(max(values.end, start), maximum)

    MaterialSliderTrack(
      node: node,
      thumbs: [start, end],
      secondary: nil,
      activeRange: start...end,
      interaction: RufletSliderInteraction(wire: node.string("interaction")),
      bubbles: dragging ? bubbleTexts(start: start, end: end) : [nil, nil],
      scale: scale(width:),
      onEdit: { editing in
        dragging = editing
        events.fire(node, editing ? "change_start" : "change_end")
      },
      onMove: { index, proposed in
        // Each thumb clamps against the other, so the pair stays ordered even
        // when one is dragged past its neighbour.
        if index == 0 {
          commit(start: min(proposed, end), end: end)
        } else {
          commit(start: start, end: max(proposed, start))
        }
      })
      .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets())
      .disabled(node.bool("disabled") ?? false)
  }

  private var minimum: Double { node.double("min") ?? 0 }
  private var maximum: Double { node.double("max") ?? 1 }

  private func scale(width: CGFloat) -> RufletSliderScale {
    RufletSliderScale(
      minimum: minimum, maximum: maximum, divisions: node.int("divisions"), width: width,
      thumbWidth: RufletThemeDefaults.sliderMetrics(year2023: node.bool("year_2023")).thumbWidth)
  }

  private func bubbleTexts(start: Double, end: Double) -> [String?] {
    RufletRangeSliderLabels.resolve(
      template: node.string("label") ?? "", start: start, end: end,
      digits: node.int("round") ?? 0)
  }

  /// `Page#apply_event_value_to_control` looks for a `start_value`/`end_value`
  /// pair in the event data and writes both back, so send them together.
  private func commit(start: Double, end: Double) {
    events.setLocal(node.id, "start_value", .double(start))
    events.setLocal(node.id, "end_value", .double(end))
    guard node.handlesEvent("change") else { return }
    events.send(
      node.id, "change",
      .map(["start_value": .double(start), "end_value": .double(end)]))
  }
}

enum RufletRangeSliderLabels {
  static func resolve(template: String, start: Double, end: Double, digits: Int) -> [String?] {
    guard !template.isEmpty else { return [nil, nil] }
    let format = "%.\(max(digits, 0))f"
    return [start, end].map { value in
      template.replacingOccurrences(
        of: RufletThemeDefaults.sliderLabelValueToken,
        with: String(format: format, value))
    }
  }
}

/// Material's slider track, shared by `Slider` and `RangeSlider`.
///
/// `thumbs` is one value or two; `activeRange` is the stretch drawn in the
/// active colour, which is min…value for one thumb and start…end for two.
private struct MaterialSliderTrack: View {
  let node: ControlNode
  let thumbs: [Double]
  let secondary: Double?
  let activeRange: ClosedRange<Double>
  let interaction: RufletSliderInteraction
  /// One value indicator per thumb. Flutter's `RangeSlider` creates two
  /// independent `RangeLabels`; combining them over the trailing thumb loses
  /// both the start thumb's label and the template semantics.
  let bubbles: [String?]
  let scale: (CGFloat) -> RufletSliderScale
  let onEdit: (Bool) -> Void
  let onMove: (Int, Double) -> Void

  @State private var held: Int?

  /// The 2023 or 2024 slider shape, chosen by `year_2023`.
  private var shape: RufletThemeDefaults.SliderMetrics {
    RufletThemeDefaults.sliderMetrics(year2023: node.bool("year_2023"))
  }

  var body: some View {
    GeometryReader { proxy in
      let scale = self.scale(proxy.size.width)
      ZStack(alignment: .leading) {
        Capsule()
          .fill(inactiveColor)
          .frame(height: shape.trackHeight)
        if let secondary {
          segment(from: activeRange.lowerBound, to: secondary, in: scale)
            .fill(secondaryColor)
        }
        segment(from: activeRange.lowerBound, to: activeRange.upperBound, in: scale)
          .fill(activeColor)
        ForEach(Array(thumbs.enumerated()), id: \.offset) { index, value in
          thumb(bubble: index < bubbles.count ? bubbles[index] : nil)
            .offset(x: scale.position(of: value) - shape.thumbWidth / 2)
        }
      }
      .frame(maxHeight: .infinity)
      .contentShape(Rectangle())
      .gesture(gesture(in: scale))
    }
    .frame(height: shape.height)
  }

  private func gesture(in scale: RufletSliderScale) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { drag in
        let proposed = scale.value(at: drag.location.x)
        if held == nil {
          // Which thumb a gesture owns is decided once, where it went down,
          // and the same thumb keeps it for the whole drag.
          guard let claimed = claim(at: drag.startLocation.x, in: scale) else { return }
          held = claimed
          onEdit(true)
        }
        guard interaction.acceptsSlide || drag.translation == .zero else { return }
        onMove(held ?? 0, proposed)
      }
      .onEnded { _ in
        guard held != nil else { return }
        held = nil
        onEdit(false)
      }
  }

  /// The thumb a gesture starting at `x` moves, or nil when the interaction
  /// mode refuses it.
  private func claim(at x: CGFloat, in scale: RufletSliderScale) -> Int? {
    let distances = thumbs.enumerated().map { ($0.offset, abs(scale.position(of: $0.element) - x)) }
    guard let nearest = distances.min(by: { $0.1 < $1.1 }) else { return nil }
    // Material's thumb is easier to grab than it is wide, so the hit slop is
    // the overlay radius rather than the drawn thumb.
    let onThumb = nearest.1 <= shape.overlayRadius
    guard onThumb || interaction.acceptsTrackGestures else { return nil }
    return nearest.0
  }

  private func segment(
    from lower: Double, to upper: Double, in scale: RufletSliderScale
  ) -> some Shape {
    let start = scale.position(of: min(lower, upper))
    let end = scale.position(of: max(lower, upper))
    return SliderSegment(start: start, width: max(end - start, 0), height: shape.trackHeight)
  }

  private func thumb(bubble: String?) -> some View {
    Capsule()
      .fill(thumbColor)
      .frame(width: shape.thumbWidth, height: shape.thumbHeight)
      .shadow(radius: 1)
      .modifier(
        MaterialStateLayer(node: node, selected: false, radius: shape.overlayRadius))
      .overlay(alignment: .top) {
        if let bubble {
          Text(bubble)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(activeColor))
            .foregroundColor(.white)
            .fixedSize()
            .offset(y: -shape.thumbHeight - 8)
        }
      }
  }

  private var states: Set<RufletWidgetState> { node.widgetStates(selected: false) }

  private var activeColor: Color {
    MaterialPalette.color(for: node, property: "active_color", default: .accentColor)
  }

  private var inactiveColor: Color {
    MaterialPalette.color(for: node, property: "inactive_color", default: .secondary.opacity(0.25))
  }

  private var secondaryColor: Color {
    MaterialPalette.color(for: node, property: "secondary_active_color", default: activeColor)
  }

  private var thumbColor: Color {
    MaterialPalette.color(stateful: node.props["thumb_color"], in: states)
      ?? MaterialPalette.color(for: node, property: "thumb_color", default: activeColor)
  }
}

/// A stretch of the track, positioned from its left edge.
private struct SliderSegment: Shape {
  let start: CGFloat
  let width: CGFloat
  let height: CGFloat

  func path(in rect: CGRect) -> Path {
    let bounds = CGRect(
      x: start, y: rect.midY - height / 2, width: width, height: height)
    return Capsule().path(in: bounds)
  }
}

/// `TextField` — the Material text input.
///
/// `on_change` fires per keystroke and `on_submit` on return, which is what
/// Flet's TextField reports. `password` picks a `SecureField`, and
/// `multiline`/`min_lines` a `TextEditor`.
struct TextFieldControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var focused = false
  @State private var hovering = false
  @State private var selection = NSRange(location: 0, length: 0)

  var body: some View {
    HStack(alignment: verticalAlignment, spacing: 8) {
      RufletFormFieldSlot(node: node, key: "prefix_icon")
        .modifier(SlotSizeConstraints(value: node.props["prefix_icon_size_constraints"]))
      RufletFormFieldSlot(node: node, key: "prefix", styleKey: "prefix_style")
      field
      RufletFormFieldSlot(node: node, key: "suffix", styleKey: "suffix_style")
      RufletFormFieldSlot(node: node, key: "suffix_icon")
        .modifier(SlotSizeConstraints(value: node.props["suffix_icon_size_constraints"]))
    }
    .textFieldStyle(.plain)
    .padding(contentPadding)
    .frame(maxWidth: fitsParent ? .infinity : nil, maxHeight: fitsParent ? .infinity : nil)
    .background(
      RoundedRectangle(cornerRadius: ControlProps.cornerRadius(node.props["border_radius"]) ?? 8)
        .fill(fieldBackground))
    .overlay(borderStroke)
    // Flutter clips a decorated field to its border; hardEdge is the default.
    .modifier(
      ChromeClipModifier(behavior: node.string("clip_behavior") ?? "hardEdge"))
    .modifier(FieldHoverTracker(hovering: $hovering))
    .modifier(RufletFormFieldDecoration(node: node))
    .onAppear {
      focused = node.bool("autofocus") == true
      selection = explicitSelection
    }
    .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
    .onChange(of: selection) { reportSelection($0) }
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "focus": focused = true; completion(.success(.null))
      case "blur": focused = false; completion(.success(.null))
      default: completion(.failure(rufletUnsupported(node.type, call)))
      }
    }
  }

  /// `shift_enter` implies multiline, exactly as Flet's textfield.dart reads
  /// it. `min_lines` only constrains the field after that decision; it does
  /// not itself change the keyboard or submit semantics.
  private var isMultiline: Bool {
    node.bool("multiline") == true || node.bool("shift_enter") == true
  }

  /// Flutter defaults max_lines to one for a single-line field and leaves a
  /// multiline one unbounded.
  private var maxLines: Int? {
    node.int("max_lines") ?? (isMultiline ? nil : 1)
  }

  @ViewBuilder
  private var field: some View {
    // A Material label rests inside an empty field and floats only while
    // editing. Native TextField's prompt is the closest Apple equivalent and
    // keeps fixed-height fields from clipping a separate label row.
    let prompt = node.string("hint_text") ?? node.string("label") ?? ""
    if isMultiline {
      TextEditor(text: binding)
        .rufletTextStyle(fieldTextStyle)
        .lineLimit(maxLines)
        .frame(minHeight: CGFloat((node.int("min_lines") ?? 3) * 20))
        // Flutter scrolls a multiline field with this padding held clear of
        // the caret; the inset is the closest equivalent.
        .modifier(ScrollInset(insets: scrollPadding))
    } else {
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeTextInput(
          text: binding,
          focused: $focused,
          selection: $selection,
          placeholder: prompt,
          secure: node.bool("password") == true,
          traits: traits,
          onTap: { events.fire(node, "click") },
          onTapOutside: { events.fire(node, "tap_outside") },
          onSubmit: { events.fire(node, "submit", data: .string($0)) })
          .modifier(PlaceholderStyle(node: node, showing: binding.wrappedValue.isEmpty))
      #else
        TextField(prompt, text: binding)
          .onSubmit { events.fire(node, "submit", data: .string(binding.wrappedValue)) }
          .modifier(KeyboardType(node: node))
      #endif
    }
  }

  /// Flet layers the field's text style: `text_style` first, then `text_size`,
  /// then `focused_color` while focused and `color` otherwise.
  private var fieldTextStyle: RufletTextStyle {
    var style = RufletTextStyle(node: node, styleKey: "text_style")
    if let size = node.double("text_size") { style.size = CGFloat(size) }
    let resting = MaterialPalette.color(node.string("color"))
    let active = MaterialPalette.color(node.string("focused_color"))
    if let color = focused ? (active ?? resting) : resting { style.color = color }
    return style
  }

  private var traits: RufletTextInputTraits {
    var traits = RufletTextInputTraits(node: node)
    // The field's own style wins over the traits' colour and size, so the two
    // cannot disagree about which one painted the text.
    traits.textColor = fieldTextStyle.color
    traits.fontSize = fieldTextStyle.size
    return traits
  }

  private var scrollPadding: EdgeInsets {
    ControlProps.edgeInsets(node.props["scroll_padding"])
      ?? EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
  }

  private var fitsParent: Bool { node.bool("fit_parent_size") == true }

  /// `text_vertical_align` runs -1 (top) to 1 (bottom) the way Flutter's
  /// alignment axes do.
  private var verticalAlignment: VerticalAlignment {
    switch node.double("text_vertical_align") {
    case .some(let value) where value <= -0.5: return .top
    case .some(let value) where value >= 0.5: return .bottom
    default: return .center
    }
  }

  /// `dense` and `collapsed` are Material's two tighter insets; anything else
  /// takes `content_padding` when Ruby supplies it.
  private var contentPadding: EdgeInsets {
    if let explicit = ControlProps.edgeInsets(node.props["content_padding"]) { return explicit }
    if node.bool("collapsed") == true { return EdgeInsets() }
    let inset: CGFloat = node.bool("dense") == true ? 4 : 8
    return EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
  }

  private var hasError: Bool {
    node.controlID(forKey: "error") != nil || !(node.string("error") ?? "").isEmpty
  }

  @ViewBuilder
  private var borderStroke: some View {
    let radius = ControlProps.cornerRadius(node.props["border_radius"]) ?? 8
    if node.string("border")?.lowercased() != "none" {
      RoundedRectangle(cornerRadius: radius)
        .strokeBorder(borderColor, lineWidth: borderWidth)
    }
  }

  private var borderWidth: CGFloat {
    let resting = node.double("border_width") ?? 1
    guard focused else { return CGFloat(resting) }
    return CGFloat(node.double("focused_border_width") ?? resting)
  }

  private var borderColor: Color {
    if hasError {
      return MaterialPalette.color(for: node, property: "error_border_color", default: .red)
    }
    if focused,
      let focusedColor = MaterialPalette.color(
        node.string("focused_border_color") ?? node.string("focus_color"))
    {
      return focusedColor
    }
    return MaterialPalette.color(for: node, property: "border_color", default: .clear)
  }

  /// Material resolves a field's fill from its interaction state, so the
  /// focused, hovered and resting colours are tried in that order.
  private var fieldBackground: Color {
    if focused, let focusedFill = MaterialPalette.color(node.string("focused_bgcolor")) {
      return focusedFill
    }
    if hovering, let hover = MaterialPalette.color(node.string("hover_color")) {
      return hover
    }
    if let explicit = MaterialPalette.color(node.props["bgcolor"]?.stringValue) {
      return explicit
    }
    if node.bool("filled") == true, let fill = MaterialPalette.color(node.string("fill_color")) {
      return fill
    }
    return MaterialPalette.color(RufletThemeDefaults.backgroundToken(for: node)) ?? .clear
  }

  private var binding: Binding<String> {
    Binding(
      get: { node.string("value") ?? "" },
      set: { events.commit(node, value: .string($0)) })
  }

  private var explicitSelection: NSRange { RufletTextSelection.explicit(on: node) }

  private func reportSelection(_ range: NSRange) {
    RufletTextSelection.report(range, on: node, to: events)
  }
}

/// `CodeEditor` — a native, monospaced multiline editor.
///
/// The Flutter extension uses a themed editor widget; on Apple the same wire
/// contract maps to `TextEditor`, including live value changes, read-only
/// previews, focus/blur events and the imperative `focus` command.
struct CodeEditorControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @FocusState private var focused: Bool
  @State private var nativeFocused = false
  @State private var selection = NSRange(location: 0, length: 0)
  @State private var folds: [CodeFoldRegion] = []

  var body: some View {
    #if canImport(UIKit) || canImport(AppKit)
      ZStack(alignment: .topLeading) {
        HighlightedCodeTextView(
          text: editorValue,
          focused: $nativeFocused,
          selection: $selection,
          configuration: configuration,
          editable: !configuration.readOnly && !configuration.disabled && folds.isEmpty,
          focusable: !configuration.disabled)
        if configuration.gutter.visible {
          CodeEditorGutterView(
            source: editorValue.wrappedValue,
            configuration: configuration,
            folds: folds,
            toggle: toggleFold)
        }
        if configuration.autocomplete, nativeFocused, !configuration.readOnly,
          let completion = CodeEditorCompletion.current(
            in: source, selection: selection,
            words: configuration.autocompleteWords + CodeLanguageSyntax.resolve(configuration.language).keywords)
        {
          CodeEditorCompletionBar(completion: completion) { word in
            applyCompletion(word, replacing: completion.range)
          }
        }
      }
      .onChange(of: nativeFocused) { isFocused in
        events.fire(node, isFocused ? "focus" : "blur")
      }
      .onChange(of: selection) { range in
        reportSelection(range)
      }
      .modifier(CodeEditorChrome(node: node, dark: isDark))
      .onAppear {
        selection = explicitSelection
        if configuration.autofocus, !configuration.disabled {
          nativeFocused = true
        }
      }
      .rufletCommandHandler(node.id) { call, completion in
        switch call.name {
        case "focus":
          if !configuration.disabled { nativeFocused = true }
          completion(.success(.null))
        case "fold_at":
          toggleFold(at: call.argument("line_number")?.intValue ?? 0)
          completion(.success(.null))
        case "fold_comment_at_line_zero":
          folds = CodeFoldProjection.leadingCommentRegion(in: source).map { [$0] } ?? []
          completion(.success(.null))
        case "fold_imports":
          folds = CodeFoldProjection.importRegions(in: source)
          completion(.success(.null))
        default:
          completion(.failure(rufletUnsupported("CodeEditor", call)))
        }
      }
    #else
    Group {
      if configuration.readOnly {
        ScrollView([.horizontal, .vertical]) {
          Text(node.string("value") ?? "")
            .font(editorFont)
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(configuration.padding)
        }
      } else {
        TextEditor(text: value)
          .font(editorFont)
          .foregroundColor(foreground)
          .focused($focused)
          .padding(configuration.padding)
          .colorScheme(isDark ? .dark : .light)
          .disabled(configuration.disabled || !folds.isEmpty)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(background)
    .onAppear {
      if configuration.autofocus, !configuration.disabled {
        focused = true
      }
    }
    .onChange(of: focused) { isFocused in
      events.fire(node, isFocused ? "focus" : "blur")
    }
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "focus":
        if !configuration.disabled { focused = true }
        completion(.success(.null))
      case "fold_at":
        toggleFold(at: call.argument("line_number")?.intValue ?? 0)
        completion(.success(.null))
      case "fold_comment_at_line_zero":
        folds = CodeFoldProjection.leadingCommentRegion(in: source).map { [$0] } ?? []
        completion(.success(.null))
      case "fold_imports":
        folds = CodeFoldProjection.importRegions(in: source)
        completion(.success(.null))
      default:
        completion(.failure(rufletUnsupported("CodeEditor", call)))
      }
    }
    #endif
  }

  private var value: Binding<String> {
    Binding(
      get: { node.string("value") ?? "" },
      set: { events.commit(node, value: .string($0)) })
  }

  private var source: String { node.string("value") ?? "" }

  private var configuration: CodeEditorConfiguration { CodeEditorConfiguration(node: node) }

  private var editorValue: Binding<String> {
    Binding(
      get: { CodeFoldProjection.project(source, folding: folds) },
      set: { newValue in
        guard folds.isEmpty else { return }
        events.commit(node, value: .string(newValue))
      })
  }

  private var explicitSelection: NSRange {
    CodeEditorSelection.range(from: node.props["selection"], text: source)
  }

  private func reportSelection(_ range: NSRange) {
    guard folds.isEmpty else { return }
    let length = source.utf16.count
    let location = min(max(range.location, 0), length)
    let selectedLength = min(max(range.length, 0), length - location)
    let resolved = NSRange(location: location, length: selectedLength)
    let selectionValue = CodeEditorSelection.value(resolved, text: source)
    events.setLocal(node.id, "selection", selectionValue)
    events.update(node.id, ["selection": selectionValue])
    events.fire(node, "selection_change", data: CodeEditorSelection.event(resolved, text: source))
  }

  private func toggleFold(at line: Int) {
    if let index = folds.firstIndex(where: { $0.startLine == line }) {
      folds.remove(at: index)
      return
    }
    if let region = CodeFoldProjection.blockRegion(in: source, startingAt: line) {
      folds.append(region)
    }
  }

  private func applyCompletion(_ word: String, replacing range: NSRange) {
    guard folds.isEmpty else { return }
    let next = (source as NSString).replacingCharacters(in: range, with: word)
    selection = NSRange(location: range.location + word.utf16.count, length: 0)
    events.commit(node, value: .string(next))
  }

  private var editorFont: Font {
    if let family = configuration.fontFamily {
      return .custom(family, size: configuration.fontSize)
    }
    return .system(size: configuration.fontSize, design: .monospaced)
  }

  private var isDark: Bool { configuration.dark }

  private var background: Color {
    MaterialPalette.color(node.string("bgcolor"), default: isDark ? Color(red: 0.16, green: 0.17, blue: 0.20) : .white)
  }

  private var foreground: Color {
    MaterialPalette.color(node.string("color"), default: isDark ? Color(red: 0.67, green: 0.70, blue: 0.75) : .primary)
  }
}

private struct CodeEditorGutterView: View {
  let source: String
  let configuration: CodeEditorConfiguration
  let folds: [CodeFoldRegion]
  let toggle: (Int) -> Void

  var body: some View {
    VStack(alignment: .trailing, spacing: 0) {
      ForEach(Array(source.components(separatedBy: "\n").indices), id: \.self) { line in
        HStack(spacing: 3) {
          if configuration.gutter.showFoldingHandles {
            Button { toggle(line) } label: {
              Image(systemName: folds.contains { $0.startLine == line } ? "chevron.right" : "chevron.down")
                .opacity(CodeFoldProjection.blockRegion(in: source, startingAt: line) == nil ? 0 : 1)
            }
            .buttonStyle(.plain)
          }
          if configuration.gutter.showErrors {
            Circle()
              .fill(CodeEditorDiagnostics.lines(in: source).contains(line) ? Color.red : Color.clear)
              .frame(width: 5, height: 5)
          }
          if configuration.gutter.showLineNumbers {
            Text(String(line + 1)).monospacedDigit()
          }
        }
        .font(.system(size: configuration.fontSize))
        .foregroundColor(.secondary)
        .frame(height: configuration.fontSize * 1.25)
      }
    }
    .padding(.top, configuration.padding.top)
    .padding(.leading, configuration.padding.leading)
    .frame(width: configuration.gutter.width, alignment: .trailing)
    .background(MaterialPalette.color(configuration.gutter.backgroundToken) ?? Color.clear)
  }
}

struct CodeEditorCompletion: Equatable {
  let range: NSRange
  let suggestions: [String]

  static func current(in source: String, selection: NSRange, words: [String]) -> CodeEditorCompletion? {
    guard selection.length == 0, selection.location <= source.utf16.count else { return nil }
    let prefixSource = (source as NSString).substring(to: selection.location)
    let prefix = prefixSource.components(separatedBy: CharacterSet.alphanumerics.inverted).last ?? ""
    guard !prefix.isEmpty else { return nil }
    let matches = words.filter { $0.hasPrefix(prefix) && $0 != prefix }
    guard !matches.isEmpty else { return nil }
    return CodeEditorCompletion(
      range: NSRange(location: selection.location - prefix.utf16.count, length: prefix.utf16.count),
      suggestions: Array(matches.prefix(8)))
  }
}

enum CodeEditorDiagnostics {
  /// The Flutter plugin obtains parser errors from `CodeController`. Native
  /// Apple text systems do not expose a language parser, but unmatched paired
  /// delimiters are deterministic diagnostics and belong in the same gutter.
  static func lines(in source: String) -> Set<Int> {
    let pairs: [Character: Character] = [")": "(", "]": "[", "}": "{"]
    var stack: [(Character, Int)] = []
    var errors = Set<Int>()
    var line = 0
    var quote: Character?
    var escaped = false
    for character in source {
      if character == "\n" { line += 1 }
      if escaped { escaped = false; continue }
      if character == "\\" { escaped = true; continue }
      if character == "\"" || character == "'" {
        if quote == character { quote = nil } else if quote == nil { quote = character }
        continue
      }
      guard quote == nil else { continue }
      if character == "(" || character == "[" || character == "{" {
        stack.append((character, line))
      } else if let expected = pairs[character] {
        guard stack.last?.0 == expected else { errors.insert(line); continue }
        stack.removeLast()
      }
    }
    errors.formUnion(stack.map(\.1))
    return errors
  }
}

private struct CodeEditorCompletionBar: View {
  let completion: CodeEditorCompletion
  let apply: (String) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack {
        ForEach(completion.suggestions, id: \.self) { word in
          Button(word) { apply(word) }.buttonStyle(.bordered)
        }
      }
      .padding(6)
    }
    .background(.regularMaterial)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct CodeFoldRegion: Equatable {
  let startLine: Int
  let endLine: Int
}

/// A source-preserving projection for the imperative folding API exposed by
/// Flet's CodeEditor. While a projection is folded it is read-only; invoking
/// `fold_at` for the same line expands it without ever replacing the DSL value.
enum CodeFoldProjection {
  static func project(_ source: String, folding regions: [CodeFoldRegion]) -> String {
    guard !regions.isEmpty else { return source }
    let lines = source.components(separatedBy: "\n")
    let byStart = Dictionary(uniqueKeysWithValues: regions.map { ($0.startLine, $0) })
    var output: [String] = []
    var line = 0
    while line < lines.count {
      if let region = byStart[line], region.endLine > line {
        output.append(lines[line] + "  …")
        line = min(region.endLine + 1, lines.count)
      } else {
        output.append(lines[line])
        line += 1
      }
    }
    return output.joined(separator: "\n")
  }

  static func blockRegion(in source: String, startingAt line: Int) -> CodeFoldRegion? {
    let lines = source.components(separatedBy: "\n")
    guard lines.indices.contains(line), line + 1 < lines.count else { return nil }
    let startIndent = indentation(lines[line])
    var end = line
    for index in (line + 1)..<lines.count {
      let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty { end = index; continue }
      if indentation(lines[index]) <= startIndent {
        if trimmed == "end" || trimmed.hasPrefix("}") { end = index }
        break
      }
      end = index
    }
    return end > line ? CodeFoldRegion(startLine: line, endLine: end) : nil
  }

  static func leadingCommentRegion(in source: String) -> CodeFoldRegion? {
    let lines = source.components(separatedBy: "\n")
    var end = -1
    for (index, line) in lines.enumerated() {
      let value = line.trimmingCharacters(in: .whitespaces)
      if value.hasPrefix("#") || value.hasPrefix("//") || value.hasPrefix("/*") || value.hasPrefix("*") {
        end = index
      } else if !value.isEmpty {
        break
      }
    }
    return end > 0 ? CodeFoldRegion(startLine: 0, endLine: end) : nil
  }

  static func importRegions(in source: String) -> [CodeFoldRegion] {
    let lines = source.components(separatedBy: "\n")
    let prefixes = ["import ", "from ", "require ", "require(", "use ", "using "]
    var regions: [CodeFoldRegion] = []
    var start: Int?
    for index in 0...lines.count {
      let isImport = index < lines.count && prefixes.contains {
        lines[index].trimmingCharacters(in: .whitespaces).hasPrefix($0)
      }
      if isImport, start == nil { start = index }
      if !isImport, let first = start {
        if index - 1 > first { regions.append(CodeFoldRegion(startLine: first, endLine: index - 1)) }
        start = nil
      }
    }
    return regions
  }

  private static func indentation(_ line: String) -> Int {
    line.prefix { $0 == " " || $0 == "\t" }.reduce(0) { result, character in
      result + (character == "\t" ? 2 : 1)
    }
  }
}

private struct CodeEditorChrome: ViewModifier {
  let node: ControlNode
  let dark: Bool

  func body(content: Content) -> some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(
        MaterialPalette.color(
          node.string("bgcolor"),
          default: dark ? Color(red: 0.16, green: 0.17, blue: 0.20) : .white))
  }
}

/// Flet's `KeyboardType`, where the platform has an equivalent.
/// Tracks the pointer so a field can paint its `hover_color`.
private struct FieldHoverTracker: ViewModifier {
  @Binding var hovering: Bool

  func body(content: Content) -> some View {
    content.onHover { hovering = $0 }
  }
}

/// `prefix_icon_size_constraints` and its suffix twin are Flutter
/// `BoxConstraints` on the slot rather than on the field.
struct SlotSizeConstraints: ViewModifier {
  let value: RufletValue?

  func body(content: Content) -> some View {
    if let constraints = ControlProps.sizeConstraints(value) {
      content.frame(
        minWidth: constraints.minWidth, maxWidth: constraints.maxWidth,
        minHeight: constraints.minHeight, maxHeight: constraints.maxHeight)
    } else {
      content
    }
  }
}

/// `scroll_padding` is the margin Flutter keeps between the caret and the
/// edge while a multiline field scrolls.
private struct ScrollInset: ViewModifier {
  let insets: EdgeInsets

  func body(content: Content) -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      content.contentMargins(.all, insets, for: .scrollContent)
    } else {
      content.padding(insets)
    }
  }
}

/// `hint_style`, `hint_max_lines` and `hint_fade_duration` describe the
/// placeholder, which neither platform field styles directly, so it is drawn
/// over an empty field.
private struct PlaceholderStyle: ViewModifier {
  let node: ControlNode
  let showing: Bool

  func body(content: Content) -> some View {
    guard let hint = node.string("hint_text"), !hint.isEmpty,
      node.map("hint_style") != nil || node.int("hint_max_lines") != nil
    else { return AnyView(content) }
    let duration = (node.double("hint_fade_duration") ?? 0) / 1_000
    return AnyView(
      content.overlay(alignment: .leading) {
        Text(hint)
          .lineLimit(node.int("hint_max_lines"))
          .rufletTextStyle(RufletTextStyle(node: node, styleKey: "hint_style"))
          .opacity(showing ? 1 : 0)
          .animation(.easeInOut(duration: duration), value: showing)
          .allowsHitTesting(false)
      })
  }
}

/// Flutter lists dropdown options in the order they were given, but SwiftUI
/// reverses a menu that opens upwards. `menuOrder` pins it, and arrived in
/// iOS 16 against a package that ships to iOS 15.
private struct FixedMenuOrder: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 16.0, macOS 13.0, *) {
      content.menuOrder(.fixed)
    } else {
      content
    }
  }
}

private struct KeyboardType: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    #if os(iOS)
      switch node.string("keyboard_type")?.lowercased() {
      case "number": return AnyView(content.keyboardType(.numberPad))
      case "phone": return AnyView(content.keyboardType(.phonePad))
      case "email": return AnyView(content.keyboardType(.emailAddress))
      case "url": return AnyView(content.keyboardType(.URL))
      case "datetime": return AnyView(content.keyboardType(.numbersAndPunctuation))
      default: return AnyView(content)
      }
    #else
      return AnyView(content)
    #endif
  }
}

/// `hour_label_text` and `minute_label_text` caption the two fields a Material
/// time picker shows in its typed-entry mode.
private struct TimeFieldLabels: ViewModifier {
  let node: ControlNode
  let kind: DateTimePickerControlView.Kind

  func body(content: Content) -> some View {
    guard kind == .time,
      node.string("hour_label_text") != nil || node.string("minute_label_text") != nil
    else { return AnyView(content) }
    return AnyView(
      VStack(spacing: 4) {
        content
        HStack(spacing: 24) {
          if let hour = node.string("hour_label_text") {
            Text(hour).font(.caption2).foregroundColor(.secondary)
          }
          if let minute = node.string("minute_label_text") {
            Text(minute).font(.caption2).foregroundColor(.secondary)
          }
        }
      })
  }
}

/// The validation strings a Material date picker shows under its field when
/// what was typed cannot be parsed or falls outside the allowed range.
private struct PickerValidation: ViewModifier {
  let node: ControlNode
  let kind: DateTimePickerControlView.Kind

  func body(content: Content) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      content
      if let message = message {
        Text(message).font(.caption2).foregroundColor(.red)
      }
      HStack(spacing: 12) {
        if let start = node.string("field_start_hint_text") {
          Text(start).font(.caption2).foregroundColor(.secondary)
        }
        if let end = node.string("field_end_hint_text") {
          Text(end).font(.caption2).foregroundColor(.secondary)
        }
        if let hint = node.string("field_hint_text") {
          Text(hint).font(.caption2).foregroundColor(.secondary)
        }
        if let label = node.string("field_label_text") {
          Text(label).font(.caption2).foregroundColor(.secondary)
        }
        if let save = node.string("save_text") {
          Text(save).font(.caption2).foregroundColor(.accentColor)
        }
      }
    }
  }

  /// Flutter shows one of these at a time: the format complaint first, then
  /// the out-of-range one, and for a range the invalid-range message.
  private var message: String? {
    node.string("error_format_text")
      ?? node.string("error_invalid_text")
      ?? node.string("error_invalid_range_text")
  }
}

/// `SearchBar` — a text field that reports `change`, `submit` and `tap`, and
/// answers Ruby's `focus`, `open_view` and `close_view`.
struct SearchBarControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @FocusState private var focused: Bool
  @State private var nativeFocused = false
  @State private var viewOpen = false
  @State private var selection = NSRange(location: 0, length: 0)

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      bar
      // Flet's SearchView is the sheet the bar opens onto: its own header,
      // padding and surface, with the suggestion controls beneath a divider.
      if viewOpen, !node.controlIDs(forKey: "controls").isEmpty {
        Divider().background(MaterialPalette.color(node.string("divider_color")))
        suggestions
      }
    }
    .frame(maxWidth: node.bool("full_screen") == true ? .infinity : nil)
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "focus":
        focused = true
        nativeFocused = true
        completion(.success(.null))
      case "open_view":
        viewOpen = true
        completion(.success(.null))
      case "close_view":
        // The pinned SearchController only applies close_view while its view
        // is open. Closing the view does not blur the separate bar FocusNode.
        if viewOpen {
          viewOpen = false
          if let value = call.argument("text")?.stringValue {
            events.setLocal(node.id, "value", .string(value))
            events.update(node.id, ["value": .string(value)])
          }
        }
        completion(.success(.null))
      default:
        completion(.failure(rufletUnsupported("SearchBar", call)))
      }
    }
  }

  /// The suggestion sheet. `shrink_wrap` sizes it to its content rather than
  /// letting it fill, and `view_header_height` fixes the header row.
  private var suggestions: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let header = node.string("view_hint_text") {
        Text(header)
          .rufletTextStyle(RufletTextStyle(node: node, styleKey: "view_header_text_style"))
          .frame(height: node.double("view_header_height").map { CGFloat($0) })
          .padding(ControlProps.edgeInsets(node.props["view_bar_padding"]) ?? EdgeInsets())
      }
      ControlList(ids: node.controlIDs(forKey: "controls"), axis: .vertical)
    }
    .padding(ControlProps.edgeInsets(node.props["view_padding"]) ?? EdgeInsets())
    .frame(maxWidth: node.bool("shrink_wrap") == true ? nil : .infinity, alignment: .leading)
    .modifier(SlotSizeConstraints(value: node.props["view_size_constraints"]))
    .background(
      RoundedRectangle(cornerRadius: shapeRadius(node.props["view_shape"]))
        .fill(MaterialPalette.color(node.string("view_bgcolor"), default: .clear)))
    .overlay(
      RoundedRectangle(cornerRadius: shapeRadius(node.props["view_shape"]))
        .strokeBorder(
          MaterialPalette.color(node.map("view_side")?["color"]?.stringValue, default: .clear),
          lineWidth: CGFloat(node.map("view_side")?["width"]?.doubleValue ?? 0)))
    .shadow(radius: CGFloat(node.double("view_elevation") ?? 0))
  }

  private func shapeRadius(_ value: RufletValue?) -> CGFloat {
    ControlProps.cornerRadius(value?.mapValue?["radius"]) ?? 0
  }

  private var bar: some View {
    HStack(spacing: 8) {
      if let leading = node.controlID(forKey: "bar_leading") {
        ControlView(id: leading, axis: .none)
      } else if let viewLeading = node.controlID(forKey: "view_leading") {
        ControlView(id: viewLeading, axis: .none)
      } else {
        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
      }
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeTextInput(
          text: searchValue,
          focused: $nativeFocused,
          selection: $selection,
          placeholder: node.string("bar_hint_text") ?? node.string("view_hint_text") ?? "",
          secure: false,
          traits: barTraits,
          onTap: { events.fire(node, "tap") },
          onTapOutside: { events.fire(node, "tap_outside_bar") },
          onSubmit: { events.fire(node, "submit", data: .string($0)) })
          .modifier(SearchBarHint(node: node, showing: (node.string("value") ?? "").isEmpty))
      #else
        TextField(
          node.string("bar_hint_text") ?? node.string("view_hint_text") ?? "",
          text: searchValue)
        .textFieldStyle(.plain)
        .focused($focused)
        .onSubmit { events.fire(node, "submit", data: .string(node.string("value") ?? "")) }
      #endif

      let trailing = node.controlIDs(forKey: "bar_trailing").isEmpty
        ? node.controlIDs(forKey: "view_trailing")
        : node.controlIDs(forKey: "bar_trailing")
      if !trailing.isEmpty {
        ControlList(ids: trailing, axis: .horizontal)
      }
    }
    .padding(ControlProps.edgeInsets(node.props["bar_padding"])
      ?? EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
    // `bar_scroll_padding` is the inset used when scrolling the page to keep
    // the caret visible. It is not layout padding around the search bar.
    .modifier(SlotSizeConstraints(value: node.props["bar_size_constraints"]))
    .background(
      RoundedRectangle(cornerRadius: barRadius)
        .fill(MaterialPalette.color(node.string("bar_bgcolor"), default: .gray.opacity(0.14))))
    .overlay(
      RoundedRectangle(cornerRadius: barRadius)
        .strokeBorder(
          MaterialPalette.color(
            node.map("bar_border_side")?["color"]?.stringValue, default: .clear),
          lineWidth: CGFloat(node.map("bar_border_side")?["width"]?.doubleValue ?? 0)))
    .shadow(
      color: MaterialPalette.color(node.string("bar_shadow_color"), default: .black.opacity(0.2)),
      radius: CGFloat(node.double("bar_elevation") ?? 0))
    .onAppear { nativeFocused = node.bool("autofocus") == true }
    .onChange(of: nativeFocused) { events.fire(node, $0 ? "focus" : "blur") }
  }

  /// `bar_shape` is an OutlinedBorder; a search bar is a capsule by default,
  /// so an absent radius takes half the bar's height.
  private var barRadius: CGFloat {
    ControlProps.cornerRadius(node.map("bar_shape")?["radius"]) ?? 22
  }

  /// The bar's own text styling, plus the scroll padding Flet names for it.
  private var barTraits: RufletTextInputTraits {
    var traits = RufletTextInputTraits(node: node)
    let style = RufletTextStyle(node: node, styleKey: "bar_text_style")
    traits.textColor = style.color
    traits.fontSize = style.size
    if let overlay = MaterialPalette.color(node.string("bar_overlay_color")) {
      traits.selectionColor = overlay
    }
    return traits
  }

  private var searchValue: Binding<String> {
    Binding(
      get: { node.string("value") ?? "" },
      set: { events.commit(node, value: .string($0)) })
  }
}

/// `bar_hint_text_style` and `view_hint_text_style` style the placeholder,
/// which neither platform field does directly.
private struct SearchBarHint: ViewModifier {
  let node: ControlNode
  let showing: Bool

  func body(content: Content) -> some View {
    guard node.map("bar_hint_text_style") != nil || node.map("view_hint_text_style") != nil
    else { return AnyView(content) }
    let key = node.map("bar_hint_text_style") != nil
      ? "bar_hint_text_style" : "view_hint_text_style"
    let text = node.string("bar_hint_text") ?? node.string("view_hint_text") ?? ""
    return AnyView(
      content.overlay(alignment: .leading) {
        Text(text)
          .rufletTextStyle(RufletTextStyle(node: node, styleKey: key))
          .opacity(showing ? 1 : 0)
          .allowsHitTesting(false)
      })
  }
}

/// `Dropdown` / `DropdownM2` — a native `Picker` over the control's options.
struct DropdownControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var focused = false
  @State private var selection = NSRange(location: 0, length: 0)

  var body: some View {
    let options = optionNodes

    HStack(spacing: 8) {
      RufletFormFieldSlot(node: node, key: "leading_icon")
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeTextInput(
          text: dropdownText,
          focused: $focused,
          selection: $selection,
          placeholder: node.string("hint_text") ?? "",
          secure: false,
          traits: dropdownTraits,
          onTap: { events.fire(node, "click") },
          onTapOutside: {},
          onSubmit: { _ in })
      #else
        TextField(node.string("hint_text") ?? "", text: dropdownText)
      #endif
      RufletFormFieldSlot(node: node, key: "selected_suffix", styleKey: "text_style")
      RufletFormFieldSlot(node: node, key: "selected_trailing_icon")
      RufletFormFieldSlot(node: node, key: "helper_text", styleKey: "helper_style")
      Menu {
        ForEach(matching(options), id: \.id) { option in
          Button {
            select(option)
          } label: {
            optionLabel(option)
          }
        }
      } label: {
        trailingIcon
      }
      .modifier(FixedMenuOrder())
      .frame(maxHeight: node.double("menu_height").map { CGFloat($0) })
    }
    .padding(contentPadding)
    .padding(ControlProps.edgeInsets(node.props["expanded_insets"]) ?? EdgeInsets())
    .background(RoundedRectangle(cornerRadius: fieldRadius).fill(fieldBackground))
    .overlay(borderStroke)
    // DropdownMenu.width sizes the field. `menu_width` belongs only to the
    // popup surface and must never resize the field itself.
    .frame(width: node.double("width").map { CGFloat($0) })
    .shadow(radius: CGFloat(node.double("elevation") ?? 0))
    .modifier(MenuSurfaceStyle(value: node.props["menu_style"]))
    .modifier(RufletFormFieldDecoration(node: node))
    .onAppear {
      focused = node.bool("autofocus") == true
      if node.string("text") == nil, let value = node.string("value") {
        events.setLocal(node.id, "text", .string(label(for: value)))
      }
    }
    .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
    .rufletCommandHandler(node.id) { call, completion in
      guard call.name == "focus" else {
        completion(.failure(rufletUnsupported(node.type, call))); return
      }
      focused = true
      completion(.success(.null))
    }
  }

  /// Flet shows `selected_trailing_icon` while the menu is open and
  /// `trailing_icon` while it is closed; SwiftUI's Menu does not report that
  /// state, so the selected form stands in once a value exists.
  @ViewBuilder
  private var trailingIcon: some View {
    let key = node.string("value") == nil ? "trailing_icon" : "selected_trailing_icon"
    if let id = node.controlID(forKey: key) ?? node.controlID(forKey: "trailing_icon") {
      ControlView(id: id, axis: .none)
    } else {
      Image(systemName: "chevron.down").foregroundColor(.secondary)
    }
  }

  private var contentPadding: EdgeInsets {
    if let explicit = ControlProps.edgeInsets(node.props["content_padding"]) { return explicit }
    let inset: CGFloat = node.bool("dense") == true ? 4 : 8
    return EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
  }

  /// A Material 3 dropdown can be typed into. `editable` opens the field,
  /// and the search and filter switches decide what typing does to the list.
  private var isEditable: Bool { node.bool("editable") == true }

  /// A non-editable dropdown's field is read-only; typing is only accepted
  /// when Ruby asked for it.
  private var dropdownTraits: RufletTextInputTraits {
    var traits = RufletTextInputTraits(node: node)
    traits.readOnly = !isEditable
    return traits
  }

  /// `enable_filter` and `enable_search` both narrow the list as the field is
  /// typed into; Flutter distinguishes them by whether the match is
  /// highlighted, which is not a distinction SwiftUI's menu draws.
  private var filtersOptions: Bool {
    node.bool("enable_filter") == true || node.bool("enable_search") == true
  }

  private func matching(_ options: [ControlNode]) -> [ControlNode] {
    let query = node.string("text") ?? ""
    guard filtersOptions, !query.isEmpty else { return options }
    return options.filter { option in
      let label = option.string("text") ?? option.string("key") ?? ""
      return label.localizedCaseInsensitiveContains(query)
    }
  }

  private var fieldBackground: Color {
    guard node.bool("filled") == true else { return .clear }
    return MaterialPalette.color(node.string("fill_color"), default: .gray.opacity(0.10))
  }

  private var fieldRadius: CGFloat {
    ControlProps.cornerRadius(node.props["border_radius"]) ?? 4
  }

  @ViewBuilder
  private var borderStroke: some View {
    if node.string("border")?.lowercased() != "none" {
      RoundedRectangle(cornerRadius: fieldRadius)
        .strokeBorder(
          MaterialPalette.color(
            node.string(focused ? "focused_border_color" : "border_color"),
            default: focused ? .accentColor : .primary),
          lineWidth: CGFloat(
            node.double(focused ? "focused_border_width" : "border_width")
              ?? (focused ? 2 : 1)))
    }
  }

  private var dropdownText: Binding<String> {
    Binding(
      get: { node.string("text") ?? label(for: node.string("value") ?? "") },
      set: {
        events.setLocal(node.id, "text", .string($0))
        events.update(node.id, ["text": .string($0)])
        events.fire(node, "text_change", data: .string($0))
      })
  }

  private func select(_ option: ControlNode) {
    let key = option.string("key") ?? option.string("text") ?? ""
    let text = option.string("text") ?? key
    events.setLocal(node.id, "value", .string(key))
    events.setLocal(node.id, "text", .string(text))
    events.update(node.id, ["value": .string(key), "text": .string(text)])
    events.fire(node, "select", data: .string(key))
  }

  private func label(for key: String) -> String {
    optionNodes.first(where: { ($0.string("key") ?? $0.string("text") ?? "") == key })?
      .string("text") ?? key
  }

  /// Options arrive under `options` on a Dropdown and `controls` on the M2
  /// variant, so both are accepted.
  private var optionNodes: [ControlNode] {
    let ids = node.controlIDs(forKey: "options") + node.childIDs
    return ids.compactMap { store.node($0) }
  }

  @ViewBuilder
  private func optionLabel(_ option: ControlNode) -> some View {
    if let contentID = option.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    } else {
      Text(option.string("text") ?? option.string("key") ?? "")
    }
  }
}

/// The legacy Material 2 dropdown is intentionally separate from the modern
/// editable DropdownMenu. Flet builds it with `DropdownButtonFormField`: the
/// field itself reports `click`, selecting an option reports `change`, and an
/// option can independently report its own `click` event.
struct DropdownM2ControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @FocusState private var focused: Bool

  var body: some View {
    Menu {
      ForEach(optionNodes, id: \.id) { option in
        Button {
          select(option)
        } label: {
          optionLabel(option)
            .frame(
              maxWidth: node.bool("options_fill_horizontally") == true ? .infinity : nil,
              minHeight: node.double("item_height").map { CGFloat($0) })
        }
        .disabled(option.bool("disabled") ?? false)
      }
    } label: {
      HStack(spacing: 8) {
        RufletFormFieldSlot(node: node, key: "icon")
        RufletFormFieldSlot(node: node, key: "prefix_icon")
        RufletFormFieldSlot(node: node, key: "prefix", styleKey: "prefix_style")
        selectedLabel
        Spacer(minLength: 8)
        RufletFormFieldSlot(node: node, key: "suffix", styleKey: "suffix_style")
        RufletFormFieldSlot(node: node, key: "suffix_icon")
        selectIcon
      }
      .contentShape(Rectangle())
      .padding(contentPadding)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius).fill(fieldBackground))
      .overlay(borderStroke)
    }
    .modifier(FixedMenuOrder())
    .frame(maxHeight: node.double("max_menu_height").map { CGFloat($0) })
    .focused($focused)
    .simultaneousGesture(TapGesture().onEnded { events.fire(node, "click") })
    .modifier(TapFeedback(enabled: node.bool("enable_feedback") != false))
    .modifier(RufletFormFieldDecoration(node: node))
    .shadow(radius: CGFloat(node.double("elevation") ?? 0))
    .disabled(node.bool("disabled") ?? false)
    .onAppear { focused = node.bool("autofocus") == true }
    .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "focus": focused = true; completion(.success(.null))
      case "blur": focused = false; completion(.success(.null))
      default: completion(.failure(rufletUnsupported(node.type, call)))
      }
    }
  }

  @ViewBuilder
  private var selectIcon: some View {
    let disabled = node.bool("disabled") == true
    if let iconID = node.controlID(forKey: "select_icon") {
      ControlView(id: iconID, axis: .none)
    } else {
      Image(systemName: "chevron.down")
        .font(.system(size: CGFloat(node.double("select_icon_size") ?? 13)))
        .foregroundColor(selectIconColor(disabled: disabled))
    }
  }

  /// A disabled dropdown shows its own hint control, if Ruby gave one.
  private var hintContentID: Int? {
    if node.bool("disabled") == true, let disabled = node.controlID(forKey: "disabled_hint_content") {
      return disabled
    }
    return node.controlID(forKey: "hint_content")
  }

  private func selectIconColor(disabled: Bool) -> Color {
    guard disabled else {
      return MaterialPalette.color(node.string("select_icon_enabled_color"), default: .primary)
    }
    return MaterialPalette.color(node.string("select_icon_disabled_color"), default: .secondary)
  }

  private var hintStyle: RufletTextStyle {
    var style = RufletTextStyle(node: node, styleKey: "hint_style")
    if style.color == nil { style.color = .secondary }
    return style
  }

  private var cornerRadius: CGFloat {
    ControlProps.cornerRadius(node.props["border_radius"]) ?? 8
  }

  private var contentPadding: EdgeInsets {
    if let explicit = ControlProps.edgeInsets(node.props["content_padding"]) { return explicit }
    if node.bool("collapsed") == true { return EdgeInsets() }
    let inset: CGFloat = node.bool("dense") == true ? 4 : 8
    return EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
  }

  private var fieldBackground: Color {
    if let focused = MaterialPalette.color(node.string("focused_bgcolor")) { return focused }
    if node.bool("filled") == true {
      return MaterialPalette.color(node.string("fill_color"), default: .gray.opacity(0.12))
    }
    return MaterialPalette.color(node.string("fill_color"), default: .clear)
  }

  @ViewBuilder
  private var borderStroke: some View {
    if node.string("border")?.lowercased() != "none" {
      RoundedRectangle(cornerRadius: cornerRadius)
        .strokeBorder(
          MaterialPalette.color(node.string("border_color"), default: .secondary.opacity(0.4)),
          lineWidth: CGFloat(node.double("border_width") ?? 1))
    }
  }

  private func select(_ option: ControlNode) {
    let value = option.string("key") ?? option.string("text") ?? String(option.id)
    events.setLocal(node.id, "value", .string(value))
    events.update(node.id, ["value": .string(value)])
    events.fire(option, "click")
    events.fire(node, "change", data: .string(value))
  }

  private var optionNodes: [ControlNode] {
    let ids = node.controlIDs(forKey: "options") + node.childIDs
    var seen = Set<Int>()
    return ids.filter { seen.insert($0).inserted }.compactMap { store.node($0) }
  }

  @ViewBuilder
  private var selectedLabel: some View {
    if let value = node.string("value"),
      let option = optionNodes.first(where: {
        ($0.string("key") ?? $0.string("text") ?? String($0.id)) == value
      })
    {
      optionLabel(option)
    } else if let hintID = hintContentID {
      ControlView(id: hintID, axis: .none)
    } else {
      Text(node.string("hint_text") ?? "")
        .lineLimit(node.int("hint_max_lines"))
        .rufletTextStyle(hintStyle)
    }
  }

  @ViewBuilder
  private func optionLabel(_ option: ControlNode) -> some View {
    if let contentID = option.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    } else {
      Text(option.string("text") ?? option.string("key") ?? String(option.id))
    }
  }
}

/// `AutoComplete` — a field with a filtered suggestion list underneath.
struct AutoCompleteControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var query = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      TextField("", text: $query)
        .textFieldStyle(.plain)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.12)))
        .onChange(of: query) { value in
          // Flet's controller always synchronizes `value`; `on_change` only
          // decides whether an event accompanies that synchronization.
          events.setLocal(node.id, "value", .string(value))
          events.update(node.id, ["value": .string(value)])
          events.fire(node, "change", data: .string(value))
        }

      if !query.isEmpty {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(matches) { match in
              Button {
                select(match)
              } label: {
                Text(match.suggestion.value)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.vertical, 6)
                  .padding(.horizontal, 8)
              }
              .buttonStyle(.plain)
            }
          }
        }
        // `suggestions_max_height` is a pixel constraint, not a cap on the
        // number of matches (the previous implementation always took eight).
        .frame(maxHeight: CGFloat(node.double("suggestions_max_height") ?? 200))
      }
    }
    .onAppear { query = node.string("value") ?? "" }
  }

  private var suggestions: [RufletAutoCompleteSuggestion] {
    RufletAutoCompleteSuggestion.parse(node.props["suggestions"], store: store)
  }

  private var matches: [RufletAutoCompleteMatch] {
    suggestions.enumerated().compactMap { index, suggestion in
      // Flet filters on `selectionString()`, which is the key, while it
      // displays `toString()`, which is the value.
      suggestion.key.localizedCaseInsensitiveContains(query)
        ? RufletAutoCompleteMatch(index: index, suggestion: suggestion) : nil
    }
  }

  private func select(_ match: RufletAutoCompleteMatch) {
    // Flutter Autocomplete writes displayStringForOption (`value`) into the
    // field, then reports the original key/value pair and source index.
    query = match.suggestion.value
    let index = Int64(match.index)
    events.setLocal(node.id, "_selected_index", .int(index))
    events.update(node.id, ["_selected_index": .int(index)])
    events.fire(node, "select", data: .map([
      "index": .int(index),
      "selection": match.suggestion.wireValue,
    ]))
  }
}

struct RufletAutoCompleteSuggestion: Equatable {
  let key: String
  let value: String

  var wireValue: RufletValue {
    .map(["key": .string(key), "value": .string(value)])
  }

  /// Suggestions are ordinary JSON maps in Flet 0.80.5, not child controls.
  /// Accept materialized refs too so the native store remains compatible with
  /// Ruflet's structural-child normalization.
  static func parse(_ value: RufletValue?, store: ControlStore) -> [Self] {
    guard let items = value?.arrayValue else { return [] }
    return items.compactMap { item in
      if let map = item.mapValue { return parse(map) }
      if let id = item.controlID, let child = store.node(id) {
        return parse(child.props)
      }
      return nil
    }
  }

  static func parse(_ map: [String: RufletValue]) -> Self? {
    var key = map["key"]?.stringValue
    var value = map["value"]?.stringValue
    if key?.isEmpty != false, value?.isEmpty != false { return nil }
    if key == nil { key = value }
    if value == nil { value = key }
    guard let key, let value else { return nil }
    return Self(key: key, value: value)
  }
}

private struct RufletAutoCompleteMatch: Identifiable {
  let index: Int
  let suggestion: RufletAutoCompleteSuggestion
  var id: Int { index }
}

/// `DatePicker`, `TimePicker` and `DateRangePicker`.
///
/// Ruflet drives these by flipping `open`; the native pickers are presented in
/// a sheet so the control reads the same from Ruby.
struct DateTimePickerControlView: View {
  enum Kind { case date, time, dateRange }

  let node: ControlNode
  let kind: Kind
  @Environment(\.rufletEvents) private var events
  @State private var selection = Date()
  @State private var rangeStart = Date()
  @State private var rangeEnd = Date()
  @State private var entryMode = ""

  var body: some View {
    picker
      .padding(20)
      .frame(maxWidth: 420)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(MaterialPalette.color(node.string("bgcolor"), default: pickerSurface)))
      .shadow(radius: 20)
      .padding(ControlProps.edgeInsets(node.props["inset_padding"])
        ?? EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24))
      .environment(\.locale, pickerLocale)
      .modifier(PickerValidation(node: node, kind: kind))
      .modifier(TimeFieldLabels(node: node, kind: kind))
      .onAppear {
        // `adaptive` picks the Cupertino wheel on Apple, which is what the
        // native pickers already are; `modal` and `barrier_color` belong to
        // the presenter that shows this.
        _ = node.bool("adaptive")
        // A 12- or 24-hour clock is the locale's on Apple; Flutter lets the
        // control override it, and `orientation` picks the dial's layout,
        // which the native picker decides from its own size.
        _ = node.string("hour_format")
        _ = node.string("orientation")
        _ = node.bool("modal")
        _ = node.string("barrier_color")
        _ = node.string("keyboard_type")
        _ = node.string("date_picker_mode")
        if let current = date(from: node.string("current_date")) { selection = current }
      }
  }

  /// `locale` is the calendar and month names the picker draws with.
  private var pickerLocale: Locale {
    node.string("locale").map { Locale(identifier: $0) } ?? .current
  }

  /// The icons Material puts on the button that swaps between the calendar
  /// and the typed-entry modes.
  @ViewBuilder
  var entryModeIcon: some View {
    RufletIcon(value: entryModeIconValue, size: 20, color: nil)
  }

  /// A time picker swaps to a timer dial rather than a calendar, so it names
  /// its own icon for the mode switch.
  private var entryModeIconValue: RufletValue? {
    guard entryMode == "input" else { return node.props["switch_to_input_icon"] }
    if kind == .time, let timer = node.props["switch_to_timer_icon"] { return timer }
    return node.props["switch_to_calendar_icon"]
  }

  private func date(from text: String?) -> Date? {
    guard let text else { return nil }
    return ISO8601DateFormatter().date(from: text)
  }

  @ViewBuilder
  private var picker: some View {
    VStack(spacing: 16) {
      if let help = node.string("help_text"), !help.isEmpty {
        Text(help).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
      }

      switch kind {
      case .date:
        if entryMode == "input" {
          DatePicker("", selection: $selection, in: allowedDates, displayedComponents: [.date])
            .datePickerStyle(.compact)
            .labelsHidden()
        } else {
          DatePicker("", selection: $selection, in: allowedDates, displayedComponents: [.date])
            .datePickerStyle(.graphical)
            .labelsHidden()
        }
      case .time:
        #if os(iOS)
        if entryMode == "input" {
          DatePicker("", selection: $selection, displayedComponents: [.hourAndMinute])
            .datePickerStyle(.compact)
            .labelsHidden()
        } else {
          DatePicker("", selection: $selection, displayedComponents: [.hourAndMinute])
            .datePickerStyle(.wheel)
            .labelsHidden()
        }
        #else
        DatePicker("", selection: $selection, displayedComponents: [.hourAndMinute])
          .datePickerStyle(.field)
          .labelsHidden()
        #endif
      case .dateRange:
        VStack(spacing: 14) {
          DatePicker(
            node.string("field_start_label_text") ?? "Start date",
            selection: $rangeStart,
            in: allowedDates,
            displayedComponents: [.date])
          DatePicker(
            node.string("field_end_label_text") ?? "End date",
            selection: $rangeEnd,
            in: rangeStart...allowedDates.upperBound,
            displayedComponents: [.date])
        }
        .datePickerStyle(.compact)
      }

      if kind != .dateRange {
        Button(entryMode == "input" ? "Calendar" : "Keyboard") { toggleEntryMode() }
          .buttonStyle(.plain)
          .accessibilityLabel(entryMode == "input" ? "Switch to picker mode" : "Switch to input mode")
      }

      HStack {
        Button(node.string("cancel_text") ?? "Cancel") { close(cancelled: true) }
        Spacer()
        Button(node.string("confirm_text") ?? "OK") { confirm() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding()
    .onAppear {
      selection = parsedValue(node.string("value")) ?? selection
      rangeStart = parsedValue(node.string("start_value")) ?? selection
      rangeEnd = max(parsedValue(node.string("end_value")) ?? rangeStart, rangeStart)
      entryMode = node.string("entry_mode") ?? (kind == .time ? "dial" : "calendar")
    }
  }

  private func toggleEntryMode() {
    let next = entryMode == "input" ? (kind == .time ? "dial" : "calendar") : "input"
    entryMode = next
    events.setLocal(node.id, "entry_mode", .string(next))
    events.update(node.id, ["entry_mode": .string(next)])
    events.fire(node, "entry_mode_change", data: .map(["entry_mode": .string(next)]))
  }

  private func confirm() {
    let data: RufletValue
    var updates: [String: RufletValue] = ["open": .bool(false)]
    if kind == .dateRange {
      let start = formattedDate(rangeStart)
      let end = formattedDate(rangeEnd)
      events.setLocal(node.id, "start_value", .string(start))
      events.setLocal(node.id, "end_value", .string(end))
      updates["start_value"] = .string(start)
      updates["end_value"] = .string(end)
      data = .map(["start_value": .string(start), "end_value": .string(end)])
    } else {
      let value = kind == .time ? formattedTime(selection) : formattedDate(selection)
      events.setLocal(node.id, "value", .string(value))
      updates["value"] = .string(value)
      data = .map(["value": .string(value)])
    }
    events.setLocal(node.id, "open", .bool(false))
    events.update(node.id, updates)
    events.fire(node, "change", data: data)
    // Flet always follows the successful `change` with `dismiss(false)`.
    events.fire(node, "dismiss", data: .bool(false))
  }

  private func close(cancelled: Bool) {
    events.setLocal(node.id, "open", .bool(false))
    events.update(node.id, ["open": .bool(false)])
    events.fire(node, "dismiss", data: .bool(cancelled))
  }

  private var allowedDates: ClosedRange<Date> {
    // These are DatePickerDialog's explicit Flet defaults, not rolling
    // relative dates. A rolling window changes valid input as time passes.
    let lower = parsedValue(node.string("first_date")) ?? RufletPickerSemantics.defaultFirstDate
    let upper = parsedValue(node.string("last_date")) ?? RufletPickerSemantics.defaultLastDate
    return min(lower, upper)...max(lower, upper)
  }

  private func parsedValue(_ value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }
    if kind == .time {
      return Self.timeFormatter.date(from: value)
    }
    return Self.dateFormatter.date(from: String(value.prefix(10)))
      ?? ISO8601DateFormatter().date(from: value)
  }

  private func formattedDate(_ date: Date) -> String { Self.dateFormatter.string(from: date) }
  private func formattedTime(_ date: Date) -> String { Self.timeFormatter.string(from: date) }

  private var pickerSurface: Color {
    #if canImport(UIKit)
      return Color(UIColor.systemBackground)
    #elseif canImport(AppKit)
      return Color(NSColor.windowBackgroundColor)
    #else
      return .white
    #endif
  }

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "HH:mm"
    return formatter
  }()
}

enum RufletPickerSemantics {
  static let defaultFirstDate = date(year: 1900, month: 1, day: 1)
  static let defaultLastDate = date(year: 2050, month: 1, day: 1)

  private static func date(year: Int, month: Int, day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: DateComponents(year: year, month: month, day: day))!
  }
}
