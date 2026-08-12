import RufletEngine
import RufletProtocol
import SwiftUI
#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// Flet's value controls do two distinct wire operations for every user edit:
/// first `updateProperties(..., notify: true)`, then `triggerEvent(...)`.
/// Keeping that contract explicit matters for unlistened controls (Ruby must
/// still receive the new property) and for controls whose event deliberately
/// carries no data, such as RangeSlider and adaptive CupertinoSlider.
enum RufletValueControlEvents {
  enum Payload {
    case value
    case none
  }

  static func commit(
    _ node: ControlNode,
    key: String = "value",
    value: RufletValue,
    payload: Payload,
    event: String = "change",
    to sink: RufletEventSink
  ) {
    sink.setLocal(node.id, key, value)
    sink.update(node.id, [key: value])
    sink.fire(node, event, data: payload == .value ? value : .null)
  }

  static func commitRange(
    _ node: ControlNode,
    start: Double,
    end: Double,
    to sink: RufletEventSink
  ) {
    let properties: [String: RufletValue] = [
      "start_value": .double(start),
      "end_value": .double(end),
    ]
    for (key, value) in properties { sink.setLocal(node.id, key, value) }
    sink.update(node.id, properties)
    sink.fire(node, "change")
  }
}

/// `Switch` — Flet's Material contract through Apple's native switch.
///
/// Material constructor values remain available through `SwitchPresentation`,
/// while the visible chrome and interaction belong to SwiftUI/UIKit/AppKit.
struct SwitchControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @Environment(\.rufletListTileClicks) private var listTileClicks
  @State private var currentValue: Bool

  init(node: ControlNode) {
    self.node = node
    _currentValue = State(initialValue: node.bool("value") ?? false)
  }

  var body: some View {
    let disabled = node.bool("disabled") ?? false
    let presentation = SwitchPresentation(
      node: node, labelNode: node.controlID(forKey: "label").flatMap(store.node))

    HStack(spacing: 0) {
      if presentation.labelPosition == .left { label(presentation) }
      nativeSwitch(tint: presentation.explicitTrackColor)
        .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets())
      if presentation.labelPosition == .right { label(presentation) }
    }
    .modifier(
      SelectionScaling(
        node: node,
        natural: CGSize(
          width: RufletThemeDefaults.switchTrackWidth,
          height: RufletThemeDefaults.switchTrackHeight)))
    .modifier(ListTileToggleListener(notifier: listTileClicks, action: toggle))
    .modifier(FocusReporter(node: node, events: events))
    .disabled(disabled)
    .onAppear { currentValue = node.bool("value") ?? false }
    .onChange(of: node.bool("value")) { currentValue = $0 ?? false }
  }

  private var binding: Binding<Bool> {
    Binding(get: { currentValue }, set: { commit($0) })
  }

  @ViewBuilder
  private func nativeSwitch(tint: Color?) -> some View {
    #if canImport(UIKit)
      RufletNativeSwitch(isOn: binding, tint: tint, enabled: node.bool("disabled") != true)
    #else
      Toggle("", isOn: binding)
        .labelsHidden()
        .toggleStyle(.switch)
        .modifier(OptionalTint(color: tint))
    #endif
  }

  @ViewBuilder
  private func label(_ presentation: SwitchPresentation) -> some View {
    if let labelID = presentation.labelControlID {
      ControlView(id: labelID, axis: .none)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
    } else if let value = presentation.labelText {
      Text(value)
        .rufletTextStyle(RufletTextStyle(map: node.map("label_text_style") ?? [:]))
        // Flutter recolours a disabled label with the theme's disabled colour
        // rather than leaving the style's own colour in place.
        .foregroundColor(
          node.bool("disabled") == true && node.map("label_text_style") != nil
            ? Color.secondary : nil)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
    }
  }

  private func toggle() {
    guard node.bool("disabled") != true else { return }
    commit(!currentValue)
  }

  private func commit(_ value: Bool) {
    guard node.bool("disabled") != true else { return }
    currentValue = value
    RufletValueControlEvents.commit(
      node, value: .bool(value), payload: .value, to: events)
  }
}

struct SwitchPresentation {
  enum LabelPlacement { case left, right }

  let node: ControlNode
  let labelNode: ControlNode?

  var labelPosition: LabelPlacement {
    node.string("label_position")?.lowercased() == "left" ? .left : .right
  }

  var labelControlID: Int? {
    guard case .controlRef(let id)? = node.props["label"], labelNode?.id == id,
      labelNode?.bool("visible") != false
    else { return nil }
    return id
  }

  var labelText: String? {
    guard case .string(let text)? = node.props["label"] else { return nil }
    return text
  }

  /// Apple exposes the enabled-track tint but not Material's per-state thumb,
  /// outline, overlay, or thumb-icon APIs. Apply tint only when the DSL
  /// explicitly asks for a representable color; omissions stay native.
  var explicitTrackColor: Color? {
    let states = node.widgetStates(selected: node.bool("value") == true)
    if node.props["track_color"] != nil {
      return MaterialPalette.color(stateful: node.props["track_color"], in: states)
    }
    guard node.bool("value") == true, node.props["active_track_color"] != nil else { return nil }
    return MaterialPalette.color(node.string("active_track_color"))
  }
}

/// `Checkbox` — a tri-state box when `tristate` is set, matching Flutter.
struct CheckboxControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @Environment(\.rufletListTileClicks) private var listTileClicks
  @State private var currentValue: Bool?

  init(node: ControlNode) {
    self.node = node
    _currentValue = State(initialValue: RufletCheckboxState.resting(node))
  }

  var body: some View {
    let disabled = node.bool("disabled") ?? false
    let presentation = CheckboxPresentation(node: node, value: .some(currentValue))

    HStack(spacing: 0) {
      if presentation.labelPosition == .left { label }
      Button(action: advance) {
        Image(systemName: presentation.systemImageName)
      }
      .buttonStyle(.borderless)
      .foregroundColor(presentation.explicitTint)
      if presentation.labelPosition == .right { label }
    }
    .modifier(SelectionScaling(node: node, natural: RufletThemeDefaults.checkboxTargetSize))
    .modifier(ListTileToggleListener(notifier: listTileClicks, action: advance))
    .modifier(FocusReporter(node: node, events: events))
    .modifier(SelectionAccessibilityLabel(label: RufletAccessibilitySemantics.label(node)))
    .disabled(disabled)
    .onAppear { currentValue = RufletCheckboxState.resting(node) }
    .onChange(of: node.props["value"]) { value in
      // `node` is the immutable value captured for this render pass. Re-reading
      // it here restores the pre-change value and makes a checkbox appear to
      // need two taps. Consume the value delivered by SwiftUI instead.
      currentValue = RufletCheckboxState.resting(value, tristate: node.bool("tristate") == true)
    }
  }

  private var visibleLabelID: Int? {
    RufletCheckboxLabel.visibleControlID(
      node.controlID(forKey: "label"), visibilityForID: { id in
        store.node(id).map { $0.bool("visible") != false }
      })
  }

  @ViewBuilder
  private var label: some View {
    if let labelID = visibleLabelID {
      ControlView(id: labelID, axis: .none)
        .contentShape(Rectangle())
        .onTapGesture { if node.bool("disabled") != true { advance() } }
    } else if let value = node.string("label") {
      Text(value)
        .rufletTextStyle(RufletTextStyle(map: node.map("label_style") ?? [:]))
        .foregroundColor(
          node.bool("disabled") == true && node.map("label_style") != nil
            ? Color.secondary : nil)
        .contentShape(Rectangle())
        .onTapGesture { if node.bool("disabled") != true { advance() } }
    }
  }

  private func advance() {
    let next = RufletCheckboxState.next(
      after: currentValue, tristate: node.bool("tristate") == true)
    currentValue = next.boolValue
    RufletValueControlEvents.commit(
      node,
      value: next,
      payload: .value,
      to: events)
  }
}

enum RufletCheckboxLabel {
  static func visibleControlID(
    _ id: Int?, visibilityForID: (Int) -> Bool?
  ) -> Int? {
    guard let id, visibilityForID(id) == true else { return nil }
    return id
  }
}

struct CheckboxPresentation {
  enum LabelPlacement { case left, right }

  let node: ControlNode
  let value: Bool?

  init(node: ControlNode, value: Bool?? = nil) {
    self.node = node
    self.value = value ?? RufletCheckboxState.resting(node)
  }

  var labelPosition: LabelPlacement {
    node.string("label_position")?.lowercased() == "left" ? .left : .right
  }

  var systemImageName: String {
    switch value {
    case .some(true): return "checkmark.square.fill"
    case .some(false): return "square"
    case .none: return "minus.square.fill"
    }
  }

  /// SF Symbols own the omitted appearance. Explicit active/fill/check colors
  /// can be represented as the native symbol tint; Material border geometry,
  /// splash, and state overlays remain semantic values only.
  var explicitTint: Color? {
    let selected = value != false
    let states = node.widgetStates(selected: selected)
    if node.props["fill_color"] != nil {
      return MaterialPalette.color(stateful: node.props["fill_color"], in: states)
    }
    if selected, node.props["active_color"] != nil {
      return MaterialPalette.color(node.string("active_color"))
    }
    if !selected, node.props["inactive_color"] != nil {
      return MaterialPalette.color(node.string("inactive_color"))
    }
    return nil
  }
}

/// Omission preserves the native control's inferred accessibility label;
/// an explicit empty value is still forwarded exactly as the DSL requested.
enum RufletAccessibilitySemantics {
  static func label(_ node: ControlNode) -> String? {
    guard node.props["semantics_label"] != nil else { return nil }
    return node.string("semantics_label") ?? ""
  }
}

struct SelectionAccessibilityLabel: ViewModifier {
  let label: String?

  func body(content: Content) -> some View {
    if let label {
      content.accessibilityLabel(Text(label))
    } else {
      content
    }
  }
}

/// The checkbox's `bool?` value, which is where Flutter and a naive Bool part
/// company.
enum RufletCheckboxState {
  /// Flutter's value is `bool?`, and Flet defaults it to nil when the box is
  /// tristate: a tristate checkbox that was never given a value rests
  /// *indeterminate*, not unchecked, so absence and `false` differ here.
  static func resting(_ node: ControlNode) -> Bool? {
    resting(node.props["value"], tristate: node.bool("tristate") == true)
  }

  static func resting(_ value: RufletValue?, tristate: Bool) -> Bool? {
    guard let value, !value.isNull else { return tristate ? nil : false }
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

#if canImport(UIKit)
  /// UIKit's switch owns the complete touch sequence. This avoids SwiftUI
  /// gesture arbitration with surrounding Flet rows and produces exactly one
  /// value change for one physical tap.
  struct RufletNativeSwitch: UIViewRepresentable {
    @Binding var isOn: Bool
    let tint: Color?
    let enabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UISwitch {
      let control = UISwitch(frame: .zero)
      control.addTarget(
        context.coordinator, action: #selector(Coordinator.changed(_:)),
        for: .valueChanged)
      configure(control)
      return control
    }

    func updateUIView(_ control: UISwitch, context: Context) {
      context.coordinator.parent = self
      configure(control)
    }

    private func configure(_ control: UISwitch) {
      if control.isOn != isOn { control.setOn(isOn, animated: false) }
      control.onTintColor = tint.map(UIColor.init)
      control.isEnabled = enabled
    }

    final class Coordinator: NSObject {
      var parent: RufletNativeSwitch
      init(parent: RufletNativeSwitch) { self.parent = parent }

      @objc func changed(_ sender: UISwitch) {
        parent.isOn = sender.isOn
      }
    }
  }
#endif

/// `Radio` — one option of a `RadioGroup`.
///
/// The group owns the value: a radio reports `change` on the group control, the
/// way Flet's RadioGroup does, so a group-level Ruby handler fires once.
struct RadioControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @Environment(\.rufletListTileClicks) private var listTileClicks

  @ViewBuilder
  var body: some View {
    if group == nil {
      Text("Radio must be enclosed within RadioGroup")
        .foregroundColor(.red)
    } else {
      radio
    }
  }

  private var radio: some View {
    let disabled = node.bool("disabled") ?? false
    let presentation = RadioPresentation(node: node, selected: isSelected)

    return HStack(spacing: 0) {
      if presentation.labelPosition == .left { label }
      Button { select(toggleIfSelected: true) } label: {
        Image(systemName: presentation.systemImageName)
      }
      .buttonStyle(.borderless)
      .foregroundColor(presentation.explicitTint)
      if presentation.labelPosition == .right { label }
    }
    .modifier(ListTileToggleListener(notifier: listTileClicks, action: selectFromListTile))
    .modifier(FocusReporter(node: node, events: events))
    .disabled(disabled)
  }

  @ViewBuilder
  private var label: some View {
    if let value = node.string("label"), !value.isEmpty {
      Text(value)
        .rufletTextStyle(RufletTextStyle(map: node.map("label_style") ?? [:]))
        .foregroundColor(
          node.bool("disabled") == true && node.map("label_style") != nil
            ? Color.secondary : nil)
        .contentShape(Rectangle())
        .onTapGesture {
          if node.bool("disabled") != true { select(toggleIfSelected: false) }
        }
    }
  }

  private var group: ControlNode? {
    RufletRadioGroupResolver.nearestGroup(containing: node.id, in: store.nodes)
  }

  private var isSelected: Bool {
    guard let value = node.string("value") else { return false }
    return group?.string("value") == value
  }

  private func select(toggleIfSelected: Bool) {
    guard let group, group.bool("disabled") != true else { return }
    let value = node.string("value") ?? ""
    let next: RufletValue = toggleIfSelected && isSelected && node.bool("toggleable") == true
      ? .null
      : .string(value)
    RufletValueControlEvents.commit(group, value: next, payload: .value, to: events)
  }

  /// Flet's Radio is the one inherited selection control that explicitly
  /// ignores a ListTile click while the radio itself is disabled.
  private func selectFromListTile() {
    guard node.bool("disabled") != true else { return }
    select(toggleIfSelected: false)
  }
}

struct RadioPresentation {
  enum LabelPlacement { case left, right }

  let node: ControlNode
  let selected: Bool

  var labelPosition: LabelPlacement {
    node.string("label_position")?.lowercased() == "left" ? .left : .right
  }

  var systemImageName: String {
    selected ? "circle.inset.filled" : "circle"
  }

  /// Material state colors remain part of the Flet semantic model. Apple can
  /// represent an explicit radio tint, but omitted values retain the native
  /// accent/secondary treatment rather than painting Material circles.
  var explicitTint: Color? {
    let states = node.widgetStates(selected: selected)
    if node.props["fill_color"] != nil {
      return MaterialPalette.color(stateful: node.props["fill_color"], in: states)
    }
    guard selected, node.props["active_color"] != nil else { return nil }
    return MaterialPalette.color(node.string("active_color"))
  }
}

/// Resolves the inherited `RadioGroup` context. A dictionary's iteration
/// order cannot stand in for ancestry: nested groups must win exactly as
/// Flutter's `RadioGroup.maybeOf(context)` selects the nearest provider.
enum RufletRadioGroupResolver {
  static let missingContentError = "RadioGroup.content must be provided and visible"

  static func visibleContentID(
    of group: ControlNode, in nodes: [Int: ControlNode]
  ) -> Int? {
    guard let id = group.controlID(forKey: "content"),
      let content = nodes[id], content.bool("visible") != false
    else { return nil }
    return id
  }

  static func nearestGroup(
    containing radioID: Int,
    in nodes: [Int: ControlNode]
  ) -> ControlNode? {
    nodes.values
      .filter { $0.type == "RadioGroup" }
      .compactMap { group -> (ControlNode, Int)? in
        distance(from: group.id, to: radioID, in: nodes).map { (group, $0) }
      }
      .min {
        $0.1 == $1.1 ? $0.0.id < $1.0.id : $0.1 < $1.1
      }?.0
  }

  private static func distance(
    from rootID: Int,
    to targetID: Int,
    in nodes: [Int: ControlNode]
  ) -> Int? {
    var queue: [(Int, Int)] = directControlIDs(of: nodes[rootID]).map { ($0, 1) }
    var cursor = 0
    var seen: Set<Int> = [rootID]
    while cursor < queue.count {
      let (id, depth) = queue[cursor]
      cursor += 1
      guard seen.insert(id).inserted else { continue }
      if id == targetID { return depth }
      queue.append(contentsOf: directControlIDs(of: nodes[id]).map { ($0, depth + 1) })
    }
    return nil
  }

  private static func directControlIDs(of node: ControlNode?) -> [Int] {
    guard let node else { return [] }
    var result = node.childIDs
    for value in node.props.values { collectControlIDs(value, into: &result) }
    return Array(Set(result))
  }

  private static func collectControlIDs(_ value: RufletValue, into result: inout [Int]) {
    switch value {
    case .controlRef(let id): result.append(id)
    case .array(let values):
      for value in values { collectControlIDs(value, into: &result) }
    case .map(let values):
      if let id = value.controlID { result.append(id) }
      for value in values.values { collectControlIDs(value, into: &result) }
    default: break
    }
  }
}

/// `RadioGroup` — holds the selected value; the radios inside it render.
struct RadioGroupControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore

  var body: some View {
    if let contentID = RufletRadioGroupResolver.visibleContentID(
      of: node, in: store.nodes) {
      ControlView(id: contentID, axis: .vertical)
    } else {
      Text(RufletRadioGroupResolver.missingContentError)
        .foregroundColor(.red)
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
  /// Flutter resolves slider direction from the ambient text direction. In
  /// RTL the minimum is on the right and every pointer delta is mirrored.
  let reversed: Bool
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
    thumbWidth: CGFloat,
    reversed: Bool = false
  ) {
    self.minimum = minimum
    self.maximum = maximum
    self.divisions = (divisions ?? 0) > 0 ? divisions : nil
    self.reversed = reversed
    self.inset = thumbWidth / 2
    self.travel = max(width - thumbWidth, 1)
  }

  var span: Double { max(maximum - minimum, .ulpOfOne) }

  /// Where a value's thumb centre sits, measured from the track's left edge.
  func position(of value: Double) -> CGFloat {
    let clamped = min(max(value, minimum), maximum)
    let logicalFraction = (clamped - minimum) / span
    let visualFraction = reversed ? 1 - logicalFraction : logicalFraction
    return inset + travel * CGFloat(visualFraction)
  }

  /// The value under a point, snapped to `divisions` when there are any.
  func value(at x: CGFloat) -> Double {
    let visualFraction = min(max(Double((x - inset) / travel), 0), 1)
    let fraction = reversed ? 1 - visualFraction : visualFraction
    let raw = minimum + fraction * span
    guard let divisions else { return raw }
    let step = span / Double(divisions)
    return min(max(minimum + ((raw - minimum) / step).rounded() * step, minimum), maximum)
  }

  /// The slide-only modes preserve the thumb's pointer-down value and apply
  /// the drag delta instead of jumping the thumb to the pointer.
  func value(startingAt value: Double, translation: CGFloat) -> Double {
    let direction = reversed ? -1.0 : 1.0
    let raw = min(
      max(value + direction * Double(translation / travel) * span, minimum), maximum)
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
  var jumpsOnContact: Bool { self == .tapAndSlide || self == .tapOnly }
}

/// `Slider` — Flet value/event semantics through Apple's native Slider.
struct SliderControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    nativeSlider
      .padding(ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets())
      .modifier(OptionalTint(color: SliderPresentation(node: node).explicitTint))
      .modifier(FocusReporter(node: node, events: events))
      .disabled(node.bool("disabled") ?? false)
  }

  @ViewBuilder
  private var nativeSlider: some View {
    let presentation = SliderPresentation(node: node)
    if let step = presentation.step {
      Slider(
        value: binding, in: presentation.minimum...presentation.maximum, step: step,
        onEditingChanged: editingChanged)
    } else {
      Slider(
        value: binding, in: presentation.minimum...presentation.maximum,
        onEditingChanged: editingChanged)
    }
  }

  private var binding: Binding<Double> {
    Binding(
      get: { SliderPresentation(node: node).value },
      set: {
        RufletValueControlEvents.commit(
          node, value: .double($0), payload: .value, to: events)
      })
  }

  private func editingChanged(_ editing: Bool) {
    events.fire(
      node, editing ? "change_start" : "change_end",
      data: .double(SliderPresentation(node: node).value))
  }
}

struct SliderPresentation {
  let node: ControlNode

  var minimum: Double { node.double("min") ?? 0 }
  var requestedMaximum: Double { node.double("max") ?? 1 }
  var maximum: Double { max(requestedMaximum, minimum + .ulpOfOne) }
  var value: Double {
    min(max(node.double("value") ?? minimum, minimum), maximum)
  }
  var step: Double? {
    guard let divisions = node.int("divisions"), divisions > 0,
      requestedMaximum > minimum
    else { return nil }
    return (requestedMaximum - minimum) / Double(divisions)
  }
  var explicitTint: Color? {
    guard node.props["active_color"] != nil else { return nil }
    return MaterialPalette.color(node.string("active_color"))
  }
  func label(for value: Double) -> String? {
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

  var body: some View {
    let presentation = RangeSliderPresentation(node: node)
    VStack(spacing: 0) {
      nativeSlider(value: startBinding, upperBound: presentation.end)
        .accessibilityLabel(Text(presentation.labels[0] ?? "Range start"))
      nativeSlider(value: endBinding, lowerBound: presentation.start)
        .accessibilityLabel(Text(presentation.labels[1] ?? "Range end"))
    }
      .modifier(OptionalTint(color: presentation.explicitTint))
      .disabled(node.bool("disabled") ?? false)
  }

  @ViewBuilder
  private func nativeSlider(
    value: Binding<Double>, lowerBound: Double? = nil, upperBound: Double? = nil
  ) -> some View {
    let presentation = RangeSliderPresentation(node: node)
    let bounds = (lowerBound ?? presentation.minimum)...(upperBound ?? presentation.maximum)
    if let step = presentation.step {
      Slider(value: value, in: bounds, step: step, onEditingChanged: editingChanged)
    } else {
      Slider(value: value, in: bounds, onEditingChanged: editingChanged)
    }
  }

  private var startBinding: Binding<Double> {
    Binding(
      get: { RangeSliderPresentation(node: node).start },
      set: { value in
        let presentation = RangeSliderPresentation(node: node)
        commit(start: min(value, presentation.end), end: presentation.end)
      })
  }

  private var endBinding: Binding<Double> {
    Binding(
      get: { RangeSliderPresentation(node: node).end },
      set: { value in
        let presentation = RangeSliderPresentation(node: node)
        commit(start: presentation.start, end: max(value, presentation.start))
      })
  }

  private func editingChanged(_ editing: Bool) {
    events.fire(node, editing ? "change_start" : "change_end")
  }

  /// `Page#apply_event_value_to_control` looks for a `start_value`/`end_value`
  /// pair in the event data and writes both back, so send them together.
  private func commit(start: Double, end: Double) {
    RufletValueControlEvents.commitRange(node, start: start, end: end, to: events)
  }
}

struct RangeSliderPresentation {
  let node: ControlNode

  var minimum: Double { node.double("min") ?? 0 }
  var requestedMaximum: Double { node.double("max") ?? 1 }
  var maximum: Double { max(requestedMaximum, minimum + .ulpOfOne) }
  private var values: (start: Double, end: Double) {
    RufletThemeDefaults.rangeSliderValues(node)
  }
  var start: Double { min(max(values.start, minimum), maximum) }
  var end: Double { min(max(values.end, start), maximum) }
  var step: Double? {
    guard let divisions = node.int("divisions"), divisions > 0,
      requestedMaximum > minimum
    else { return nil }
    return (requestedMaximum - minimum) / Double(divisions)
  }
  var labels: [String?] {
    RufletRangeSliderLabels.resolve(
      template: node.string("label") ?? "", start: start, end: end,
      digits: node.int("round") ?? 0)
  }
  var explicitTint: Color? {
    guard node.props["active_color"] != nil else { return nil }
    return MaterialPalette.color(node.string("active_color"))
  }
}

enum RufletRangeSliderLabels {
  static func resolve(template: String, start: Double, end: Double, digits: Int) -> [String?] {
    let format = "%.\(max(digits, 0))f"
    return [start, end].map { value in
      template.replacingOccurrences(
        of: RufletThemeDefaults.sliderLabelValueToken,
        with: String(format: format, value))
    }
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
  @EnvironmentObject private var store: ControlStore
  @State private var focused = false
  @State private var hovering = false
  @State private var selection = NSRange(location: 0, length: 0)
  @State private var revealsPassword = false
  /// UIKit/AppKit owns the live editing buffer. Reading every keystroke back
  /// through the remotely-backed ControlNode makes a fast delete sequence
  /// wait for SwiftUI/store reconciliation and can visibly restore old text.
  @State private var localValue = ""

  var body: some View {
    HStack(alignment: verticalAlignment, spacing: 8) {
      if !embedsNativePrefix {
        formIcon("prefix_icon")
          .modifier(SlotSizeConstraints(value: node.props["prefix_icon_constraints"]))
      }
      RufletFormFieldSlot(node: node, key: "prefix", styleKey: "prefix_style")
      field
      RufletFormFieldSlot(node: node, key: "suffix", styleKey: "suffix_style")
      suffixIcon
        .modifier(SlotSizeConstraints(value: node.props["suffix_icon_constraints"]))
    }
    .textFieldStyle(.plain)
    .padding(usesNativeChrome ? EdgeInsets() : contentPadding)
    .frame(width: RufletTextFieldDefaults.defaultWidth(node))
    .frame(maxWidth: fitsParent ? .infinity : nil, maxHeight: fitsParent ? .infinity : nil)
    .background {
      if !usesNativeChrome {
        RoundedRectangle(cornerRadius: fieldRadius).fill(fieldBackground)
      }
    }
    .overlay(borderStroke)
    // Flutter clips a decorated field to its border; hardEdge is the default.
    .modifier(
      ChromeClipModifier(behavior: node.string("clip_behavior") ?? "hardEdge"))
    .modifier(FieldHoverTracker(hovering: $hovering))
    .modifier(RufletFormFieldDecoration(node: node))
    .disabled(node.bool("disabled") == true)
    .onAppear {
      localValue = node.string("value") ?? ""
      focused = node.string("blur") == nil
        && (node.bool("autofocus") == true || node.string("focus") != nil)
      selection = initialSelection
    }
    .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
    .onChange(of: selection) { reportSelection($0) }
    .onChange(of: node.string("focus")) { if $0 != nil { focused = true } }
    .onChange(of: node.string("blur")) { if $0 != nil { focused = false } }
    .onChange(of: node.string("value")) { value in
      let external = value ?? ""
      if localValue != external { localValue = external }
    }
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "focus": focused = true; completion(.success(.null))
      default: completion(.failure(rufletUnsupported(node.type, call)))
      }
    }
  }

  /// `shift_enter` implies multiline, exactly as Flet's textfield.dart reads
  /// it. `min_lines` only constrains the field after that decision; it does
  /// not itself change the keyboard or submit semantics.
  private var isMultiline: Bool { RufletTextFieldDefaults.isMultiline(node) }

  /// Flutter defaults max_lines to one for a single-line field and leaves a
  /// multiline one unbounded.
  private var maxLines: Int? { RufletTextFieldDefaults.maxLines(node) }

  @ViewBuilder
  private var field: some View {
    // A Material label rests inside an empty field and floats only while
    // editing. Native TextField's prompt is the closest Apple equivalent and
    // keeps fixed-height fields from clipping a separate label row.
    let prompt = node.string("hint_text") ?? node.string("label") ?? ""
    if isMultiline {
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeMultilineTextInput(
          text: binding,
          focused: $focused,
          selection: $selection,
          traits: traits,
          submitOnReturn: node.bool("shift_enter") == true,
          onTap: { events.fire(node, "click") },
          onTapOutside: { events.fire(node, "tap_outside") },
          onSubmit: { events.fire(node, "submit") })
          .frame(minHeight: minimumHeight, maxHeight: maximumHeight)
          .overlay(alignment: .topLeading) {
            if binding.wrappedValue.isEmpty, !prompt.isEmpty {
              Text(prompt)
                .lineLimit(node.int("hint_max_lines"))
                .rufletTextStyle(RufletTextStyle(node: node, styleKey: "hint_style"))
                .allowsHitTesting(false)
            }
          }
      #else
        TextEditor(text: binding)
          .rufletTextStyle(fieldTextStyle)
          .lineLimit(maxLines)
          .frame(minHeight: minimumHeight, maxHeight: maximumHeight)
          .modifier(ScrollInset(insets: scrollPadding))
      #endif
    } else {
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeTextInput(
          text: binding,
          focused: $focused,
          selection: $selection,
          placeholder: prompt,
          secure: node.bool("password") == true && !revealsPassword,
          nativeChrome: usesNativeChrome,
          searchAppearance: usesNativeSearchAppearance,
          leadingSymbol: nativePrefixSymbol,
          traits: traits,
          onTap: { events.fire(node, "click") },
          onTapOutside: { events.fire(node, "tap_outside") },
          onSubmit: { events.fire(node, "submit", data: .string($0)) })
          .modifier(PlaceholderStyle(node: node, showing: binding.wrappedValue.isEmpty))
          // UIViewRepresentable otherwise accepts a loose vertical proposal
          // from a Column and can expand a one-line UITextField to the entire
          // preview. UIKit's ordinary field owns a compact intrinsic height.
          .frame(height: RufletTextFieldDefaults.nativeSingleLineHeight)
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
    if isMultiline { traits.keyboardType = "multiline" }
    let style = fieldTextStyle
    // The field's own style wins over the traits' colour and size, so the two
    // cannot disagree about which one painted the text.
    traits.textColor = style.color ?? MaterialPalette.color("onsurface")
    let resolvedSize = style.size ?? style.materialThemeMetric?.size
      ?? RufletTextFieldDefaults.defaultTextSize
    traits.fontSize = resolvedSize
    traits.fontWeight = RufletTextFieldDefaults.fontWeight(node)
    traits.lineHeight = style.lineHeight.map { $0 * resolvedSize }
      ?? style.materialThemeMetric?.lineHeight
      ?? RufletTextFieldDefaults.defaultTextLineHeight
    traits.caretScrollPadding = scrollPadding
    return traits
  }

  private var scrollPadding: EdgeInsets {
    ControlProps.edgeInsets(node.props["scroll_padding"])
      ?? EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
  }

  private var fitsParent: Bool { node.bool("fit_parent_size") == true }

  private var minimumHeight: CGFloat? {
    guard !fitsParent else { return nil }
    return CGFloat(RufletTextFieldDefaults.minLines(node)) * nativeLineHeight
  }

  private var nativeLineHeight: CGFloat {
    traits.lineHeight ?? RufletTextFieldDefaults.defaultTextLineHeight
  }

  private var maximumHeight: CGFloat? {
    guard !fitsParent, let maxLines else { return nil }
    return CGFloat(maxLines) * nativeLineHeight
  }

  /// `text_vertical_align` runs -1 (top) to 1 (bottom) the way Flutter's
  /// alignment axes do.
  private var verticalAlignment: VerticalAlignment {
    switch node.double("text_vertical_align") {
    case .some(let value) where value <= -0.5: return .top
    case .some(let value) where value >= 0.5: return .bottom
    default: return .center
    }
  }

  /// The resolved InputDecoration padding from Flutter 3.41.2. Flet defaults
  /// the decoration to an OutlineInputBorder, so omission is the Material 3
  /// outline inset rather than zero or a platform-text-field inset.
  private var contentPadding: EdgeInsets {
    RufletTextFieldDefaults.contentPadding(node)
  }

  private var hasError: Bool {
    node.controlID(forKey: "error") != nil || !(node.string("error") ?? "").isEmpty
  }

  @ViewBuilder
  private var borderStroke: some View {
    let radius = fieldRadius
    if !usesNativeChrome,
      RufletTextFieldDefaults.borderKind(node) != .none, borderWidth > 0
    {
      if RufletTextFieldDefaults.borderKind(node) == .underline {
        VStack(spacing: 0) {
          Spacer(minLength: 0)
          Rectangle().fill(borderColor).frame(height: borderWidth)
        }
      } else {
        RoundedRectangle(cornerRadius: radius)
          .strokeBorder(borderColor, lineWidth: borderWidth)
      }
    }
  }

  private var fieldRadius: CGFloat {
    RufletTextFieldDefaults.fieldCornerRadius(node)
  }

  private var usesNativeChrome: Bool {
    RufletTextFieldDefaults.usesNativeApplePresentation(node)
  }

  private var usesNativeSearchAppearance: Bool {
    usesNativeChrome && RufletTextFieldDefaults.hasSearchPrefix(node)
  }

  private var nativePrefixSymbol: String? {
    guard usesNativeChrome, let value = node.props["prefix_icon"] else { return nil }
    return RufletNativeTextFieldPrefix.symbol(
      value: value,
      referencedNode: value.controlID.flatMap(store.node))
  }

  private var embedsNativePrefix: Bool {
    #if canImport(UIKit)
      return nativePrefixSymbol != nil
    #else
      // NSSearchField owns its magnifying glass; arbitrary AppKit field icons
      // remain ordinary Flet slots because NSTextField has no public leftView.
      return usesNativeSearchAppearance
    #endif
  }

  private var borderWidth: CGFloat {
    if hasError { return focused ? 2 : 1 }
    return RufletTextFieldDefaults.borderWidth(node, focused: focused)
  }

  private var borderColor: Color {
    if hasError {
      return MaterialPalette.color(
        node.string("error_border_color") ?? "error", default: .red)
    }
    return MaterialPalette.color(
      RufletTextFieldDefaults.borderColorToken(node, focused: focused), default: .black)
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
    if node.bool("filled") == true {
      if let explicit = MaterialPalette.color(node.props["bgcolor"]?.stringValue) {
        return explicit
      }
      if let fill = MaterialPalette.color(node.string("fill_color")) { return fill }
      return MaterialPalette.color(RufletThemeDefaults.backgroundToken(for: node)) ?? .clear
    }
    return .clear
  }

  private var binding: Binding<String> {
    Binding(
      get: { localValue },
      set: {
        // Update the native editing buffer before publishing to Ruby. This is
        // the same controller-first ordering used by Flutter's TextField.
        localValue = $0
        RufletTextFieldEvents.change($0, on: node, to: events)
      })
  }

  private var initialSelection: NSRange {
    guard node.map("selection") != nil else {
      return NSRange(location: (node.string("value") ?? "").utf16.count, length: 0)
    }
    return RufletTextSelection.explicit(on: node)
  }

  private func reportSelection(_ range: NSRange) {
    guard node.bool("on_selection_change") == true || node.handlesEvent("selection_change") else {
      return
    }
    RufletTextSelection.report(range, on: node, to: events)
  }

  @ViewBuilder
  private func formIcon(_ key: String) -> some View {
    if let id = node.controlID(forKey: key) {
      ControlView(id: id, axis: .none)
    } else if let value = node.props[key] {
      RufletIcon(value: value)
    }
  }

  @ViewBuilder
  private var suffixIcon: some View {
    if node.controlID(forKey: "suffix_icon") != nil || node.props["suffix_icon"] != nil {
      formIcon("suffix_icon")
    } else if node.bool("password") == true && node.bool("can_reveal_password") == true {
      Button {
        revealsPassword.toggle()
      } label: {
        RufletIcon(value: .string(revealsPassword ? "visibility_off" : "visibility"))
      }
      .buttonStyle(.plain)
    }
  }
}

enum RufletNativeTextFieldPrefix {
  static func symbol(value: RufletValue, referencedNode: ControlNode?) -> String? {
    let iconValue: RufletValue?
    if let referencedNode {
      guard referencedNode.bool("visible") != false, referencedNode.type == "Icon" else {
        return nil
      }
      iconValue = referencedNode.props["name"] ?? referencedNode.props["icon"]
    } else {
      iconValue = value
    }
    guard let symbol = IconMapping.symbol(for: iconValue),
      symbol != IconMapping.placeholderSymbol
    else { return nil }
    return symbol
  }
}

/// Flet 0.80.5's constructor/build defaults, kept separate from the view so
/// omission has one source of truth and can be tested without snapshots.
enum RufletTextFieldDefaults {
  enum BorderKind: String { case outline, underline, none }

  static let nativeSingleLineHeight: CGFloat = 36

  /// Omitted decoration is a semantic Flet outline, but its Apple
  /// presentation belongs to UITextField/NSTextField. Any explicit DSL
  /// decoration keeps the translated path so Ruby remains authoritative.
  static func usesNativeApplePresentation(_ node: ControlNode) -> Bool {
    let visualOverrides = [
      "border", "border_color", "border_width", "focused_border_color",
      "focused_border_width", "error_border_color", "border_radius",
      "content_padding", "bgcolor", "fill_color", "focused_bgcolor",
      "hover_color", "filled", "collapsed", "dense", "suffix_icon",
      "prefix", "suffix", "prefix_icon_constraints", "suffix_icon_constraints",
    ]
    return !isMultiline(node) && visualOverrides.allSatisfy { node.props[$0] == nil }
  }

  static func hasSearchPrefix(_ node: ControlNode) -> Bool {
    guard let value = node.props["prefix_icon"] else { return false }
    return IconMapping.materialName(for: value)?.lowercased() == "search"
  }

  /// Flet's buildInputDecoration() chooses outline even when the wire omits
  /// `border`; this is independent of the native editor used on Apple.
  static func borderKind(_ node: ControlNode) -> BorderKind {
    BorderKind(rawValue: node.string("border")?.lowercased() ?? "outline") ?? .outline
  }

  static func fieldCornerRadius(_ node: ControlNode) -> CGFloat {
    guard borderKind(node) == .outline else { return 0 }
    return ControlProps.cornerRadius(node.props["border_radius"]) ?? 4
  }

  /// InputDecorator's Material 3 default contentPadding. ThemeData defaults
  /// to Material 3 in the pinned Flutter used by Flet 0.80.5.
  static func contentPadding(_ node: ControlNode) -> EdgeInsets {
    if let explicit = ControlProps.edgeInsets(node.props["content_padding"]) { return explicit }
    if node.bool("collapsed") == true { return EdgeInsets() }
    let dense = node.bool("dense") == true
    switch borderKind(node) {
    case .outline:
      return EdgeInsets(
        top: dense ? 16 : 20, leading: 12,
        bottom: dense ? 8 : 12, trailing: 12)
    case .underline, .none:
      if node.bool("filled") == true {
        return EdgeInsets(
          top: dense ? 4 : 8, leading: 12,
          bottom: dense ? 4 : 8, trailing: 12)
      }
      return EdgeInsets(
        top: dense ? 4 : 8, leading: 0,
        bottom: dense ? 4 : 8, trailing: 0)
    }
  }

  /// Flet only constructs a focusedBorder when any border override exists.
  /// Without one, Flutter resolves the active M3 outline token; with one,
  /// Flet's copied border uses the supplied values and exact fallbacks.
  static func hasFocusedBorder(_ node: ControlNode) -> Bool {
    node.props["border_color"] != nil || node.props["border_width"] != nil
      || node.props["focused_border_color"] != nil
      || node.props["focused_border_width"] != nil
  }

  static func borderWidth(_ node: ControlNode, focused: Bool) -> CGFloat {
    // InputDecorator's Material 3 disabled default replaces the border side,
    // including an explicitly configured enabledBorder width.
    if node.bool("disabled") == true { return 1 }
    let resting = CGFloat(node.double("border_width") ?? 1)
    guard focused else { return resting }
    guard hasFocusedBorder(node) else { return 2 }
    return CGFloat(node.double("focused_border_width") ?? node.double("border_width") ?? 2)
  }

  static func borderColorToken(_ node: ControlNode, focused: Bool) -> String {
    // `_getDefaultBorder` checks disabled before focused/error and resolves
    // onSurface at 12% opacity for the outline variant.
    if node.bool("disabled") == true { return "onsurface,0.12" }
    if focused {
      if hasFocusedBorder(node) {
        return node.string("focused_border_color")
          ?? node.string("border_color")
          ?? "primary"
      }
      return "primary"
    }
    if let explicit = node.string("border_color") { return explicit }
    // buildInputDecoration's bare outline/underline constructor uses black.
    // Supplying only width takes its separate onSurface/38% fallback branch.
    return node.props["border_width"] != nil ? "onsurface,0.38" : "black"
  }

  static let defaultTextSize: CGFloat = 16
  static let defaultTextLineHeight: CGFloat = 24

  /// TextField falls back to TextTheme.titleMedium (w500). An explicit style
  /// retains its own weight, with Material theme roles resolved before the
  /// native UIKit/AppKit font is created.
  static func fontWeight(_ node: ControlNode) -> String {
    let style = node.map("text_style")
    if let explicit = style?["weight"]?.stringValue { return explicit }
    switch style?["theme_style"]?.stringValue?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "titlemedium", "titlesmall", "labellarge", "labelmedium", "labelsmall":
      return "w500"
    case .some:
      return "w400"
    case nil:
      return "w500"
    }
  }

  static func isMultiline(_ node: ControlNode) -> Bool {
    node.bool("multiline") == true || node.bool("shift_enter") == true
  }

  static func minLines(_ node: ControlNode) -> Int { node.int("min_lines") ?? 1 }

  static func maxLines(_ node: ControlNode) -> Int? {
    node.int("max_lines") ?? (isMultiline(node) ? nil : 1)
  }

  static func defaultWidth(_ node: ControlNode) -> CGFloat? {
    guard node.double("width") == nil,
      node.bool("fit_parent_size") != true,
      !hasExpand(node)
    else { return nil }
    return 300
  }

  static func counterText(_ template: String?, value: String, maxLength: Int?) -> String? {
    // Dart String.length and TextSelection offsets are UTF-16 code units,
    // even though maxLength enforcement counts grapheme clusters.
    let valueLength = value.utf16.count
    if let template {
      return template
        .replacingOccurrences(of: "{value_length}", with: String(valueLength))
        .replacingOccurrences(of: "{max_length}", with: maxLength.map(String.init) ?? "None")
        .replacingOccurrences(
          of: "{symbols_left}",
          with: maxLength.map { String($0 - valueLength) } ?? "None")
    }
    // Flutter's default counter counts extended grapheme clusters, unlike
    // Dart String.length used by Flet's explicit interpolation tokens.
    guard let maxLength else { return nil }
    let currentLength = value.count
    return maxLength > 0 ? "\(currentLength)/\(maxLength)" : String(currentLength)
  }

  static func hasDefaultCounter(_ node: ControlNode) -> Bool {
    node.int("max_length") != nil
  }

  private static func hasExpand(_ node: ControlNode) -> Bool {
    guard let value = node.props["expand"] else { return false }
    if value.boolValue == true { return true }
    return (value.intValue ?? 0) > 0
  }
}

enum RufletTextFieldEvents {
  static func change(_ value: String, on node: ControlNode, to events: RufletEventSink) {
    let wire = RufletValue.string(value)
    events.setLocal(node.id, "value", wire)
    events.update(node.id, ["value": wire])
    if node.bool("on_change") == true || node.handlesEvent("change") {
      events.fire(node, "change", data: wire)
    }
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

/// `SearchBar` — a text field that reports `change`, `submit` and `tap`, and
/// answers Ruby's `focus`, `open_view` and `close_view`.
struct SearchBarControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var nativeFocused = false
  @State private var viewOpen = false
  @State private var selection = NSRange(location: 0, length: 0)
  @State private var lastFocusValue: String?
  @State private var lastBlurValue: String?

  var body: some View {
    Group {
      if node.bool("full_screen") == true {
        #if os(macOS)
          bar.sheet(isPresented: $viewOpen) { suggestions }
        #else
          bar.fullScreenCover(isPresented: $viewOpen) { suggestions }
        #endif
      } else {
        bar.popover(isPresented: $viewOpen, attachmentAnchor: .rect(.bounds)) {
          suggestions
        }
      }
    }
    .frame(maxWidth: node.bool("full_screen") == true ? .infinity : nil)
    .onAppear {
      nativeFocused = node.bool("autofocus") == true
      consumeFocusProperties()
    }
    .onChange(of: node.string("focus")) { _ in consumeFocusProperties() }
    .onChange(of: node.string("blur")) { _ in consumeFocusProperties() }
    .rufletCommandHandler(node.id) { call, completion in
      switch call.name {
      case "focus":
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
            synchronize(value)
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
      HStack {
        if let leading = visibleSlotID("view_leading") {
          ControlView(id: leading, axis: .none)
        }
        #if canImport(UIKit) || canImport(AppKit)
          RufletNativeTextInput(
            text: searchValue,
            focused: $nativeFocused,
            selection: $selection,
            placeholder: "",
            secure: false,
            nativeChrome: false,
            searchAppearance: visibleSlotID("view_leading") == nil,
            traits: viewTraits,
            onTap: {},
            onTapOutside: {},
            onSubmit: { submit($0) })
            .modifier(SearchHint(
              node: node, textKey: "view_hint_text", fallbackTextKey: "bar_hint_text",
              styleKey: "view_hint_text_style", fallbackStyleKey: "view_header_text_style",
              showing: (node.string("value") ?? "").isEmpty))
        #else
          TextField(node.string("view_hint_text") ?? "", text: searchValue)
        #endif
        let trailing = visibleSlotIDs("view_trailing")
        if !trailing.isEmpty { ControlList(ids: trailing, axis: .horizontal) }
      }
      .frame(height: CGFloat(
        node.double("view_header_height")
          ?? RufletSearchBarDefaults.viewHeaderHeight(fullScreen: node.bool("full_screen") == true)))
      .padding(RufletSearchBarDefaults.viewBarPadding(node))
      Divider().overlay(
        MaterialPalette.color(node.string("divider_color") ?? "outline"))
      ControlList(ids: visibleSlotIDs("controls"), axis: .vertical)
    }
    .padding(ControlProps.edgeInsets(node.props["view_padding"]) ?? EdgeInsets())
    .frame(maxWidth: node.bool("shrink_wrap") == true ? nil : .infinity, alignment: .leading)
    .frame(
      minWidth: RufletSearchBarDefaults.viewMinimumWidth(node),
      minHeight: RufletSearchBarDefaults.viewMinimumHeight(node))
    .modifier(SlotSizeConstraints(value: node.props["view_size_constraints"]))
    .modifier(SearchSurface(node: node, prefix: "view"))
  }

  private var bar: some View {
    HStack {
      if let leading = visibleSlotID("bar_leading") {
        ControlView(id: leading, axis: .none)
      }
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeTextInput(
            text: searchValue,
            focused: $nativeFocused,
          selection: $selection,
          placeholder: "",
          secure: false,
          nativeChrome: false,
          searchAppearance: visibleSlotID("bar_leading") == nil,
          traits: barTraits,
          onTap: {
            events.fire(node, "tap")
            viewOpen = true
          },
          onTapOutside: { events.fire(node, "tap_outside_bar") },
          onSubmit: { submit($0) })
          .modifier(SearchHint(
            node: node, textKey: "bar_hint_text", fallbackTextKey: nil,
            styleKey: "bar_hint_text_style", fallbackStyleKey: nil,
            showing: (node.string("value") ?? "").isEmpty))
      #else
        TextField(
          node.string("bar_hint_text") ?? node.string("view_hint_text") ?? "",
          text: searchValue)
        .textFieldStyle(.plain)
        .onSubmit { events.fire(node, "submit", data: .string(node.string("value") ?? "")) }
      #endif

      let trailing = visibleSlotIDs("bar_trailing")
      if !trailing.isEmpty {
        ControlList(ids: trailing, axis: .horizontal)
      }
    }
    .padding(RufletSearchBarDefaults.barPadding(node))
    // `bar_scroll_padding` is the inset used when scrolling the page to keep
    // the caret visible. It is not layout padding around the search bar.
    .frame(
      minWidth: RufletSearchBarDefaults.barMinimumWidth(node),
      maxWidth: RufletSearchBarDefaults.barMaximumWidth(node),
      minHeight: RufletSearchBarDefaults.barMinimumHeight(node))
    .modifier(SlotSizeConstraints(value: node.props["bar_size_constraints"]))
    .modifier(SearchSurface(node: node, prefix: "bar"))
    .onChange(of: nativeFocused) { events.fire(node, $0 ? "focus" : "blur") }
  }

  private func visibleSlotID(_ key: String) -> Int? {
    RufletSearchBarSlots.visibleID(
      node.controlID(forKey: key), visibilityForID: visibilityForID)
  }

  private func visibleSlotIDs(_ key: String) -> [Int] {
    RufletSearchBarSlots.visibleIDs(
      node.controlIDs(forKey: key), visibilityForID: visibilityForID)
  }

  private func visibilityForID(_ id: Int) -> Bool? {
    store.node(id).map { $0.bool("visible") != false }
  }

  /// The bar's own text styling, plus the scroll padding Flet names for it.
  private var barTraits: RufletTextInputTraits {
    var traits = RufletTextInputTraits(node: node)
    let style = RufletTextStyle(node: node, styleKey: "bar_text_style")
    traits.textColor = style.color ?? MaterialPalette.color("onsurface")
    let resolvedSize = style.size ?? style.materialThemeMetric?.size
      ?? RufletSearchBarDefaults.defaultTextSize
    traits.fontSize = resolvedSize
    traits.fontWeight = RufletSearchBarDefaults.fontWeight(
      node.map("bar_text_style"), fallback: "w400")
    traits.lineHeight = style.lineHeight.map { $0 * resolvedSize }
      ?? style.materialThemeMetric?.lineHeight
      ?? RufletSearchBarDefaults.defaultLineHeight
    if let overlay = MaterialPalette.color(node.string("bar_overlay_color")) {
      traits.selectionColor = overlay
    }
    traits.caretScrollPadding = RufletSearchBarDefaults.scrollPadding(node)
    return traits
  }

  private var viewTraits: RufletTextInputTraits {
    var traits = barTraits
    let style = RufletTextStyle(node: node, styleKey: "view_header_text_style")
    traits.textColor = style.color ?? MaterialPalette.color("onsurface")
    let resolvedSize = style.size ?? style.materialThemeMetric?.size
      ?? RufletSearchBarDefaults.defaultTextSize
    traits.fontSize = resolvedSize
    traits.fontWeight = RufletSearchBarDefaults.fontWeight(
      node.map("view_header_text_style"), fallback: "w400")
    traits.lineHeight = style.lineHeight.map { $0 * resolvedSize }
      ?? style.materialThemeMetric?.lineHeight
      ?? RufletSearchBarDefaults.defaultLineHeight
    return traits
  }

  private var searchValue: Binding<String> {
    Binding(
      get: { node.string("value") ?? "" },
      set: {
        let value = RufletSearchBarDefaults.capitalized(
          $0, mode: node.string("capitalization"))
        RufletSearchBarEvents.change(value, on: node, to: events)
      })
  }

  /// SearchController updates its backing property even when Ruby did not
  /// attach `on_change`. Event registration only gates the event itself.
  private func synchronize(_ value: String) {
    let transformed = RufletSearchBarDefaults.capitalized(
      value, mode: node.string("capitalization"))
    events.setLocal(node.id, "value", .string(transformed))
    events.update(node.id, ["value": .string(transformed)])
  }

  private func submit(_ value: String) {
    let transformed = RufletSearchBarDefaults.capitalized(
      value, mode: node.string("capitalization"))
    synchronize(transformed)
    events.fire(node, "submit", data: .string(transformed))
  }

  private func consumeFocusProperties() {
    let focus = node.string("focus")
    if let focus, focus != lastFocusValue {
      lastFocusValue = focus
      nativeFocused = true
    }
    let blur = node.string("blur")
    if let blur, blur != lastBlurValue {
      lastBlurValue = blur
      nativeFocused = false
    }
  }
}

enum RufletSearchBarSlots {
  static func visibleID(
    _ id: Int?, visibilityForID: (Int) -> Bool?
  ) -> Int? {
    guard let id, visibilityForID(id) == true else { return nil }
    return id
  }

  static func visibleIDs(
    _ ids: [Int], visibilityForID: (Int) -> Bool?
  ) -> [Int] {
    var seen = Set<Int>()
    return ids.filter { id in
      visibilityForID(id) == true && seen.insert(id).inserted
    }
  }
}

/// Resolves SearchBar/SearchView's constructor → theme → generated-default
/// chain while the editable text itself remains UIKit/AppKit native.
private struct SearchSurface: ViewModifier {
  let node: ControlNode
  let prefix: String

  func body(content: Content) -> some View {
    let shapeKey = prefix == "bar" ? "bar_shape" : "view_shape"
    let sideKey = prefix == "bar" ? "bar_border_side" : "view_side"
    let radius = ControlProps.cornerRadius(node.map(shapeKey)?["radius"])
      ?? RufletSearchBarDefaults.cornerRadius(prefix: prefix, fullScreen: node.bool("full_screen") == true)
    let side = node.map(sideKey)
    return AnyView(
      content
        .background(
          RoundedRectangle(cornerRadius: radius)
            .fill(MaterialPalette.color(
              stateful: node.props["\(prefix)_bgcolor"], in: node.widgetStates())
              ?? RufletSearchBarDefaults.backgroundColor))
        .overlay(
          RoundedRectangle(cornerRadius: radius)
            .strokeBorder(
              MaterialPalette.color(side?["color"]?.stringValue, default: .clear),
              lineWidth: CGFloat(side?["width"]?.doubleValue ?? 0)))
        .modifier(SearchShadow(node: node, prefix: prefix)))
  }
}

private struct SearchShadow: ViewModifier {
  let node: ControlNode
  let prefix: String

  func body(content: Content) -> some View {
    let elevation = CGFloat(node.double("\(prefix)_elevation")
      ?? RufletSearchBarDefaults.defaultElevation)
    let color = MaterialPalette.color(
      stateful: node.props["\(prefix)_shadow_color"], in: node.widgetStates())
      ?? MaterialPalette.color("shadow", default: .black)
    return AnyView(content.shadow(color: color, radius: elevation))
  }
}

/// Source-derived SearchBar controller behavior from Flet 0.80.5.
///
/// These are controller semantics, not visual tuning: Flutter applies the
/// capitalization mode before synchronizing `value`, and SearchBar's
/// `scrollPadding` constructor keeps twenty logical pixels clear by default.
enum RufletSearchBarDefaults {
  // Flutter 3.41.2 generated Material 3 SearchBar/SearchView defaults.
  static let defaultElevation: Double = 6
  static let defaultTextSize: CGFloat = 16
  static let defaultLineHeight: CGFloat = 24
  static var backgroundColor: Color {
    MaterialPalette.color("surfacecontainerhigh", default: .clear)
  }

  static func barPadding(_ node: ControlNode) -> EdgeInsets {
    ControlProps.edgeInsets(
      RufletWidgetStateProperty.resolve(node.props["bar_padding"], in: node.widgetStates()))
      ?? EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
  }

  static func viewBarPadding(_ node: ControlNode) -> EdgeInsets {
    ControlProps.edgeInsets(node.props["view_bar_padding"])
      ?? EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
  }

  static func barMinimumWidth(_ node: ControlNode) -> CGFloat? {
    ControlProps.sizeConstraints(node.props["bar_size_constraints"]) == nil ? 360 : nil
  }

  static func barMaximumWidth(_ node: ControlNode) -> CGFloat? {
    ControlProps.sizeConstraints(node.props["bar_size_constraints"]) == nil ? 800 : nil
  }

  static func barMinimumHeight(_ node: ControlNode) -> CGFloat? {
    ControlProps.sizeConstraints(node.props["bar_size_constraints"]) == nil ? 56 : nil
  }

  static func viewMinimumWidth(_ node: ControlNode) -> CGFloat? {
    ControlProps.sizeConstraints(node.props["view_size_constraints"]) == nil ? 360 : nil
  }

  static func viewMinimumHeight(_ node: ControlNode) -> CGFloat? {
    ControlProps.sizeConstraints(node.props["view_size_constraints"]) == nil ? 240 : nil
  }

  static func viewHeaderHeight(fullScreen: Bool) -> Double {
    fullScreen ? 72 : 56
  }

  static func cornerRadius(prefix: String, fullScreen: Bool) -> CGFloat {
    if prefix == "bar" { return 28 }
    return fullScreen ? 0 : 28
  }

  static func fontWeight(_ style: [String: RufletValue]?, fallback: String) -> String {
    if let explicit = style?["weight"]?.stringValue { return explicit }
    switch style?["theme_style"]?.stringValue?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "titlemedium", "titlesmall", "labellarge", "labelmedium", "labelsmall":
      return "w500"
    default:
      return fallback
    }
  }

  static func scrollPadding(_ node: ControlNode) -> EdgeInsets {
    ControlProps.edgeInsets(node.props["bar_scroll_padding"])
      ?? EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
  }

  static func capitalized(_ text: String, mode: String?) -> String {
    switch mode?.lowercased() {
    case "characters":
      return text.uppercased()
    case "words":
      return text.split(whereSeparator: { $0.isWhitespace }).map { substring in
        let word = String(substring)
        guard let first = word.first else { return word }
        return String(first).uppercased() + word.dropFirst().lowercased()
      }.joined(separator: " ")
    case "sentences":
      // The pinned Dart client splits at `. ` and lowercases the remainder of
      // each sentence. Preserve the separator instead of normalizing spaces.
      return text.components(separatedBy: ". ").map { sentence in
        guard let first = sentence.drop(while: { $0.isWhitespace }).first else {
          return sentence
        }
        return String(first).uppercased() + sentence.dropFirst().lowercased()
      }.joined(separator: ". ")
    default:
      return text
    }
  }
}

enum RufletSearchBarEvents {
  static func change(_ value: String, on node: ControlNode, to events: RufletEventSink) {
    let wire = RufletValue.string(value)
    events.setLocal(node.id, "value", wire)
    events.update(node.id, ["value": wire])
    events.fire(node, "change", data: wire)
  }
}

/// `bar_hint_text_style` and `view_hint_text_style` style the placeholder,
/// which neither platform field does directly.
private struct SearchHint: ViewModifier {
  let node: ControlNode
  let textKey: String
  let fallbackTextKey: String?
  let styleKey: String
  let fallbackStyleKey: String?
  let showing: Bool

  func body(content: Content) -> some View {
    let text = node.string(textKey) ?? fallbackTextKey.flatMap(node.string) ?? ""
    guard !text.isEmpty else { return AnyView(content) }
    let resolvedStyleKey = node.map(styleKey) != nil ? styleKey : (fallbackStyleKey ?? styleKey)
    var style = RufletTextStyle(node: node, styleKey: resolvedStyleKey)
    if style.color == nil { style.color = MaterialPalette.color("onsurfacevariant") }
    if style.size == nil, style.materialThemeMetric == nil {
      style.size = RufletSearchBarDefaults.defaultTextSize
    }
    return AnyView(
      content.overlay(alignment: .leading) {
        Text(text)
          .rufletTextStyle(style)
          .opacity(showing ? 1 : 0)
          .allowsHitTesting(false)
      })
  }
}

/// Flet's Material `DropdownMenu` contract, rendered with Apple text and
/// popover primitives. The numeric/theme values below remain Flutter's: using
/// a native primitive does not make omitted wire values mean Apple defaults.
struct DropdownControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var focused = false
  @State private var selection = NSRange(location: 0, length: 0)
  @State private var menuPresented = false
  @State private var localValue = ""
  @State private var localText = ""

  init(node: ControlNode) {
    self.node = node
    _localValue = State(initialValue: node.string("value") ?? "")
    _localText = State(initialValue: node.string("text") ?? "")
  }

  var body: some View {
    let options = optionNodes

    fieldContent(options)
    .modifier(DropdownFieldAppearance(node: node, focused: focused))
    // DropdownMenu.width sizes the field. `menu_width` belongs only to the
    // popup surface and must never resize the field itself.
    .modifier(DropdownFieldWidth(node: node))
    .modifier(RufletFormFieldDecoration(node: node))
    .disabled(node.bool("disabled") == true)
    .popover(isPresented: $menuPresented, attachmentAnchor: .rect(.bounds)) {
      dropdownPopup(options)
    }
    .onAppear {
      focused = node.bool("autofocus") == true && isEditable
      localValue = node.string("value") ?? ""
      localText = node.string("text") ?? validatedLabel(for: localValue)
      synchronizeSelectionFromWire(initial: true)
    }
    .onChange(of: node.string("value")) { value in
      localValue = value ?? ""
      synchronizeSelectionFromWire(initial: false)
    }
    .onChange(of: node.string("text")) { text in
      localText = text ?? validatedLabel(for: localValue)
    }
    .onChange(of: optionSignature) { _ in synchronizeSelectionFromWire(initial: false) }
    .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
    .rufletCommandHandler(node.id) { call, completion in
      guard call.name == "focus" else {
        completion(.failure(rufletUnsupported(node.type, call))); return
      }
      if isEditable { focused = true }
      completion(.success(.null))
    }
  }

  @ViewBuilder
  private func fieldContent(_ options: [ControlNode]) -> some View {
    if isEditable {
      HStack {
        RufletFormFieldSlot(node: node, key: "leading_icon")
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeTextInput(
          text: dropdownText,
          focused: $focused,
          selection: $selection,
          placeholder: node.string("hint_text") ?? "",
          secure: false,
          nativeChrome: false,
          traits: dropdownTraits,
          onTap: {
            // DropdownMenu opens from its field even when it is editable; the
            // editable switch only controls whether keyboard input is accepted.
            menuPresented = true
          },
          onTapOutside: {},
          onSubmit: { _ in })
      #else
        TextField(node.string("hint_text") ?? "", text: dropdownText)
      #endif
        Button {
          menuPresented.toggle()
        } label: {
          trailingIcon
        }
        .buttonStyle(.plain)
      }
    } else {
      Menu {
        ForEach(matching(options), id: \.id) { option in
          Button {
            select(option)
          } label: {
            optionMenuLabel(option)
          }
          .disabled((node.bool("disabled") ?? false) || (option.bool("disabled") ?? false))
        }
      } label: {
        HStack {
          RufletFormFieldSlot(node: node, key: "leading_icon")
          Text(selectedText).rufletTextStyle(fieldTextStyle)
          Spacer(minLength: 8)
          trailingIcon
        }
      }
      .buttonStyle(.plain)
    }
  }

  /// Flutter's `DropdownMenu.menuWidth` sizes the popup surface independently
  /// of the field. SwiftUI's `Menu` has no such contract, so the native port
  /// uses a popover whose content width and maximum height come from the same
  /// Flet constructor values.
  private func dropdownPopup(_ options: [ControlNode]) -> some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(matching(options), id: \.id) { option in
          Button {
            select(option)
            menuPresented = false
          } label: {
            HStack(spacing: 8) {
              if let leadingID = option.controlID(forKey: "leading_icon") {
                ControlView(id: leadingID, axis: .none)
              }
              optionLabel(option)
              Spacer(minLength: 8)
              if let trailingID = option.controlID(forKey: "trailing_icon") {
                ControlView(id: trailingID, axis: .none)
              }
            }
            .padding(.horizontal, DropdownMenuDefaults.optionHorizontalPadding)
            .frame(minHeight: DropdownMenuDefaults.optionMinimumHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .rufletTextStyle(DropdownMenuDefaults.optionTextStyle(option, parent: node))
          }
          .buttonStyle(.plain)
          .disabled((node.bool("disabled") ?? false) || (option.bool("disabled") ?? false))
          .modifier(MaterialOptionButtonStyle(value: option.props["style"]))
        }
      }
    }
    .padding(.vertical, DropdownMenuDefaults.menuVerticalPadding(node))
    .modifier(DropdownPopupGeometry(node: node))
    .background(
      RoundedRectangle(cornerRadius: DropdownMenuDefaults.menuCornerRadius(node))
        .fill(DropdownMenuDefaults.menuBackground(node)))
    .overlay(
      RoundedRectangle(cornerRadius: DropdownMenuDefaults.menuCornerRadius(node))
        .strokeBorder(
          DropdownMenuDefaults.menuBorderColor(node),
          lineWidth: DropdownMenuDefaults.menuBorderWidth(node)))
    .shadow(
      color: DropdownMenuDefaults.menuShadowColor(node),
      radius: DropdownMenuDefaults.menuElevation(node))
  }

  /// Flet shows `selected_trailing_icon` while the menu is open and
  /// `trailing_icon` while it is closed.
  @ViewBuilder
  private var trailingIcon: some View {
    let key = menuPresented ? "selected_trailing_icon" : "trailing_icon"
    if let id = node.controlID(forKey: key) ?? node.controlID(forKey: "trailing_icon") {
      ControlView(id: id, axis: .none)
    } else {
      Image(systemName: "chevron.down").foregroundColor(.secondary)
    }
  }

  /// A Material 3 dropdown can be typed into. `editable` opens the field,
  /// and the search and filter switches decide what typing does to the list.
  private var isEditable: Bool { node.bool("editable") == true }

  /// A non-editable dropdown's field is read-only; typing is only accepted
  /// when Ruby asked for it.
  private var dropdownTraits: RufletTextInputTraits {
    var traits = RufletTextInputTraits(node: node)
    let style = DropdownMenuDefaults.textStyle(node, disabled: node.bool("disabled") == true)
    traits.fontSize = style.size
    traits.textColor = style.color
    traits.readOnly = !isEditable
    traits.canRequestFocus = isEditable && node.bool("can_request_focus") != false
    return traits
  }

  /// `enable_filter` and `enable_search` both narrow the list as the field is
  /// typed into; Flutter distinguishes them by whether the match is
  /// highlighted, which is not a distinction SwiftUI's menu draws.
  private var filtersOptions: Bool {
    DropdownMenuDefaults.filtersOptions(node)
  }

  private func matching(_ options: [ControlNode]) -> [ControlNode] {
    let query = node.string("text") ?? ""
    guard filtersOptions, !query.isEmpty else { return options }
    return options.filter { option in
      let label = option.string("text") ?? option.string("key") ?? ""
      return label.localizedCaseInsensitiveContains(query)
    }
  }

  private var fieldTextStyle: RufletTextStyle {
    DropdownMenuDefaults.textStyle(node, disabled: node.bool("disabled") == true)
  }

  private var dropdownText: Binding<String> {
    Binding(
      get: { localText },
      set: {
        localText = $0
        events.setLocal(node.id, "text", .string($0))
        events.update(node.id, ["text": .string($0)])
        events.fire(node, "text_change", data: .string($0))
      })
  }

  private func select(_ option: ControlNode) {
    let key = option.string("key") ?? option.string("text") ?? ""
    let text = option.string("text") ?? key
    // Apple controls must acknowledge the tap in the same frame. The local
    // state is then reconciled with the authoritative wire patch below; it is
    // never held hostage by the backend/event round trip.
    localValue = key
    localText = text
    RufletDropdownEvents.select(key: key, text: text, on: node, to: events)
  }

  private func label(for key: String) -> String {
    optionNodes.first(where: { ($0.string("key") ?? $0.string("text") ?? "") == key })?
      .string("text") ?? key
  }

  private func validatedLabel(for key: String) -> String {
    guard optionNodes.contains(where: {
      ($0.string("key") ?? $0.string("text") ?? "") == key
    }) else { return "" }
    return label(for: key)
  }

  private var selectedText: String {
    if !localText.isEmpty { return localText }
    let label = validatedLabel(for: localValue)
    return label.isEmpty ? (node.string("hint_text") ?? "") : label
  }

  /// `DropdownOption` is structural and therefore filtered here rather than
  /// by a standalone ControlView.
  private var optionNodes: [ControlNode] {
    DropdownMenuDefaults.visibleOptions(
      node.controlIDs(forKey: "options").compactMap { store.node($0) })
  }

  private var optionSignature: String {
    optionNodes.map {
      "\($0.id):\($0.string("key") ?? ""): \($0.string("text") ?? "")"
    }.joined(separator: "|")
  }

  /// A backend value change updates the controller without a `text_change`
  /// event. The initial explicit text is retained for a valid initial value,
  /// matching Dropdown's `text ?? value` controller construction; an invalid
  /// value is cleared on the first build.
  private func synchronizeSelectionFromWire(initial: Bool) {
    guard let value = node.string("value"), !value.isEmpty else {
      if !initial {
        localValue = ""
        localText = ""
        events.setLocal(node.id, "text", .string(""))
      }
      return
    }
    let label = validatedLabel(for: value)
    localValue = value
    if label.isEmpty || !initial || node.string("text") == nil {
      localText = label
      events.setLocal(node.id, "text", .string(label))
    }
  }

  @ViewBuilder
  private func optionLabel(_ option: ControlNode) -> some View {
    if let contentID = option.controlID(forKey: "content") {
      ControlView(id: contentID, axis: .none)
    } else {
      Text(option.string("text") ?? option.string("key") ?? "")
    }
  }

  @ViewBuilder
  private func optionMenuLabel(_ option: ControlNode) -> some View {
    // Menu is an Apple-owned primitive. Its semantic title must remain
    // available even when the Flet option supplies custom control slots.
    HStack {
      if let leadingID = option.controlID(forKey: "leading_icon") {
        ControlView(id: leadingID, axis: .none)
      }
      optionLabel(option)
      if let trailingID = option.controlID(forKey: "trailing_icon") {
        ControlView(id: trailingID, axis: .none)
      }
    }
    .accessibilityLabel(option.string("text") ?? option.string("key") ?? "")
  }
}

/// Source-derived `DropdownMenu` geometry. Keeping popup geometry separate
/// from field geometry is important: Flet forwards `width` to DropdownMenu's
/// field and `menu_width` to MenuStyle.fixedSize.
enum DropdownMenuDefaults {
  enum BorderKind: String { case outline, underline, none }

  static let minimumMenuWidth: CGFloat = 112
  static let optionHorizontalPadding: CGFloat = 12
  static let optionMinimumHeight: CGFloat = 48
  static let defaultTextSize: CGFloat = 16
  static let defaultMenuElevation: CGFloat = 3
  static let defaultMenuCornerRadius: CGFloat = 4
  static let defaultMenuVerticalPadding: CGFloat = 8
  static let defaultOptionTextSize: CGFloat = 14

  /// Constructor defaults remain available to the semantic model, but an
  /// omitted decoration must not paint an Android/Material text-field shell
  /// around Apple's native Menu. Only an appearance explicitly supplied by
  /// the application is translated into SwiftUI decoration.
  static func hasExplicitFieldAppearance(_ node: ControlNode) -> Bool {
    [
      "border", "border_color", "border_width", "border_radius",
      "focused_border_color", "focused_border_width", "filled", "fill_color",
      "content_padding", "dense", "collapsed",
    ].contains { node.props[$0] != nil }
  }

  /// DropdownOption is structural, so its parent owns both visibility and
  /// validity filtering. This mirrors Dart's visible `children("options")`
  /// followed by its null-entry removal.
  static func visibleOptions(_ options: [ControlNode]) -> [ControlNode] {
    options.filter {
      $0.bool("visible") != false
        && ($0.string("key") != nil || $0.string("text") != nil)
    }
  }

  static func filtersOptions(_ node: ControlNode) -> Bool {
    node.bool("enable_filter") == true
  }

  static func searchesOptions(_ node: ControlNode) -> Bool {
    node.bool("enable_search") ?? true
  }

  static func fieldWidth(_ node: ControlNode) -> CGFloat? {
    node.double("width").map { CGFloat($0) }
  }

  static func menuWidth(_ node: ControlNode) -> CGFloat? {
    node.double("menu_width").map { CGFloat($0) }
  }

  static func menuHeight(_ node: ControlNode) -> CGFloat? {
    node.double("menu_height").map { CGFloat($0) }
  }

  static func effectiveMenuWidth(_ node: ControlNode) -> CGFloat? {
    if let menuWidth = menuWidth(node) { return menuWidth }
    if let fixed = menuStyleSize(node, key: "fixed_size")?.width { return fixed }
    return fieldWidth(node)
  }

  static func effectiveMenuHeight(_ node: ControlNode) -> CGFloat? {
    if let height = menuHeight(node) { return height }
    return menuStyleSize(node, key: "fixed_size")?.height
      ?? menuStyleSize(node, key: "max_size")?.height
  }

  static func minimumStyledWidth(_ node: ControlNode) -> CGFloat {
    menuStyleSize(node, key: "min_size")?.width ?? minimumMenuWidth
  }

  static func maximumStyledWidth(_ node: ControlNode) -> CGFloat? {
    menuStyleSize(node, key: "max_size")?.width
  }

  static func borderKind(_ node: ControlNode) -> BorderKind {
    BorderKind(rawValue: node.string("border")?.lowercased() ?? "outline") ?? .outline
  }

  static func fieldCornerRadius(_ node: ControlNode) -> CGFloat {
    guard borderKind(node) == .outline else { return 0 }
    return ControlProps.cornerRadius(node.props["border_radius"]) ?? 4
  }

  static func borderWidth(_ node: ControlNode, focused: Bool) -> CGFloat {
    if node.double("border_width") == 0 { return 0 }
    if focused {
      return CGFloat(node.double("focused_border_width") ?? node.double("border_width") ?? 2)
    }
    return CGFloat(node.double("border_width") ?? 1)
  }

  static func borderColor(_ node: ControlNode, focused: Bool) -> Color {
    if focused {
      return MaterialPalette.color(
        node.string("focused_border_color") ?? node.string("border_color") ?? "primary",
        default: .primary)
    }
    // Flet constructs a literal black BorderSide when all border props are omitted.
    return MaterialPalette.color(node.string("border_color") ?? "#000000", default: .black)
  }

  static func contentPadding(_ node: ControlNode) -> EdgeInsets {
    if let explicit = ControlProps.edgeInsets(node.props["content_padding"]) { return explicit }
    let dense = node.bool("dense") == true
    switch borderKind(node) {
    case .outline:
      return dense
        ? EdgeInsets(top: 16, leading: 12, bottom: 8, trailing: 12)
        : EdgeInsets(top: 20, leading: 12, bottom: 12, trailing: 12)
    case .underline, .none:
      if node.bool("filled") == true {
        return dense
          ? EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
          : EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
      }
      return dense
        ? EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        : EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
    }
  }

  static func textStyle(_ node: ControlNode, disabled: Bool) -> RufletTextStyle {
    var style = RufletTextStyle(node: node, styleKey: "text_style")
    if style.size == nil { style.size = CGFloat(node.double("text_size") ?? 16) }
    if style.color == nil {
      style.color = MaterialPalette.color(disabled ? "onsurface,0.38" : "onsurface")
    }
    return style
  }

  static func optionTextStyle(_ option: ControlNode, parent: ControlNode) -> RufletTextStyle {
    var style = RufletTextStyle(node: option, styleKey: "text_style")
    if style.size == nil { style.size = defaultOptionTextSize }
    if style.color == nil {
      style.color = MaterialPalette.color(
        option.bool("disabled") == true || parent.bool("disabled") == true
          ? "onsurface,0.38" : "onsurface")
    }
    return style
  }

  static func menuBackground(_ node: ControlNode) -> Color {
    let states = node.widgetStates()
    if let explicit = MaterialPalette.color(stateful: node.props["bgcolor"], in: states) {
      return explicit
    }
    if let style = node.map("menu_style"),
      let explicit = MaterialPalette.color(stateful: style["bgcolor"], in: states)
    {
      return explicit
    }
    return MaterialPalette.color("surfacecontainer", default: .clear)
  }

  static func menuElevation(_ node: ControlNode) -> CGFloat {
    let states = node.widgetStates()
    if let explicit = ControlProps.statefulDouble(node.props["elevation"], in: states) {
      return explicit
    }
    if let style = node.map("menu_style"),
      let explicit = ControlProps.statefulDouble(style["elevation"], in: states)
    {
      return explicit
    }
    return defaultMenuElevation
  }

  static func menuCornerRadius(_ node: ControlNode) -> CGFloat {
    guard let style = node.map("menu_style") else { return defaultMenuCornerRadius }
    return ControlProps.cornerRadius(style["shape"]?.mapValue?["radius"])
      ?? defaultMenuCornerRadius
  }

  static func menuVerticalPadding(_ node: ControlNode) -> CGFloat {
    guard let style = node.map("menu_style"),
      let padding = ControlProps.edgeInsets(
        RufletWidgetStateProperty.resolve(style["padding"], in: node.widgetStates()))
    else { return defaultMenuVerticalPadding }
    return max(padding.top, padding.bottom)
  }

  static func menuShadowColor(_ node: ControlNode) -> Color {
    guard let style = node.map("menu_style") else {
      return MaterialPalette.color("shadow", default: .black).opacity(0.2)
    }
    return MaterialPalette.color(
      stateful: style["shadow_color"], in: node.widgetStates())
      ?? MaterialPalette.color("shadow", default: .black).opacity(0.2)
  }

  static func menuBorderWidth(_ node: ControlNode) -> CGFloat {
    guard let side = node.map("menu_style")?["side"] else { return 0 }
    let resolved = RufletWidgetStateProperty.resolve(side, in: node.widgetStates())
    return CGFloat(resolved?.mapValue?["width"]?.doubleValue ?? 0)
  }

  static func menuBorderColor(_ node: ControlNode) -> Color {
    guard let side = node.map("menu_style")?["side"] else { return .clear }
    let resolved = RufletWidgetStateProperty.resolve(side, in: node.widgetStates())
    return MaterialPalette.color(resolved?.mapValue?["color"]?.stringValue, default: .clear)
  }

  private static func menuStyleSize(_ node: ControlNode, key: String) -> CGSize? {
    guard let value = node.map("menu_style")?[key],
      let resolved = RufletWidgetStateProperty.resolve(value, in: node.widgetStates()),
      let map = resolved.mapValue,
      let width = map["width"]?.doubleValue,
      let height = map["height"]?.doubleValue
    else { return nil }
    return CGSize(width: width, height: height)
  }
}

private struct DropdownFieldAppearance: ViewModifier {
  let node: ControlNode
  let focused: Bool

  func body(content: Content) -> some View {
    guard DropdownMenuDefaults.hasExplicitFieldAppearance(node) else {
      return AnyView(
        content
          .frame(minHeight: 44)
          .contentShape(Rectangle()))
    }

    let radius = DropdownMenuDefaults.fieldCornerRadius(node)
    let background = node.bool("filled") == true
      ? MaterialPalette.color(
        node.string("fill_color") ?? "surfacecontainerhighest", default: .clear)
      : Color.clear
    return AnyView(
      content
        .padding(DropdownMenuDefaults.contentPadding(node))
        .background(RoundedRectangle(cornerRadius: radius).fill(background))
        .overlay(alignment: .bottom) {
          if DropdownMenuDefaults.borderKind(node) == .outline {
            RoundedRectangle(cornerRadius: radius)
              .strokeBorder(
                DropdownMenuDefaults.borderColor(node, focused: focused),
                lineWidth: DropdownMenuDefaults.borderWidth(node, focused: focused))
          } else if DropdownMenuDefaults.borderKind(node) == .underline {
            Rectangle()
              .fill(DropdownMenuDefaults.borderColor(node, focused: focused))
              .frame(height: DropdownMenuDefaults.borderWidth(node, focused: focused))
          }
        })
  }
}

private struct DropdownFieldWidth: ViewModifier {
  let node: ControlNode
  func body(content: Content) -> some View {
    if let width = DropdownMenuDefaults.fieldWidth(node) {
      content.frame(width: width)
    } else if (node.int("expand") ?? 0) > 0 {
      content.frame(maxWidth: .infinity)
    } else {
      content.frame(minWidth: DropdownMenuDefaults.minimumMenuWidth)
    }
  }
}

private struct DropdownPopupGeometry: ViewModifier {
  let node: ControlNode
  func body(content: Content) -> some View {
    let width = DropdownMenuDefaults.effectiveMenuWidth(node)
    let height = DropdownMenuDefaults.effectiveMenuHeight(node)
    if let width {
      content.frame(width: width).frame(
        maxWidth: DropdownMenuDefaults.maximumStyledWidth(node), maxHeight: height)
    } else {
      content.frame(
        minWidth: DropdownMenuDefaults.minimumStyledWidth(node),
        maxWidth: DropdownMenuDefaults.maximumStyledWidth(node), maxHeight: height)
    }
  }
}

enum RufletDropdownEvents {
  static func select(
    key: String, text: String, on node: ControlNode, to events: RufletEventSink
  ) {
    // Flutter's DropdownMenu writes its entry label through the controller
    // before calling onSelected, so Flet's controller listener reports the
    // ordinary text-change path first.
    let textValue = RufletValue.string(text)
    events.setLocal(node.id, "text", textValue)
    events.update(node.id, ["text": textValue])
    events.fire(node, "text_change", data: textValue)

    let selection = RufletValue.string(key)
    events.setLocal(node.id, "value", selection)
    events.update(node.id, ["value": selection])
    events.fire(node, "select", data: selection)
  }
}

/// A DropdownOption carries a Material ButtonStyle in the same way as Flet's
/// DropdownMenuEntry. Apply the visible subset without changing popup layout.
private struct MaterialOptionButtonStyle: ViewModifier {
  let value: RufletValue?

  func body(content: Content) -> some View {
    guard let style = value?.mapValue else { return AnyView(content) }
    return AnyView(
      content
        .foregroundColor(MaterialPalette.color(style["color"]?.stringValue))
        .background(MaterialPalette.color(style["bgcolor"]?.stringValue)))
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
  @Environment(\.colorScheme) private var colorScheme
  @FocusState private var focused: Bool
  @State private var menuPresented = false
  @State private var localValue = ""

  init(node: ControlNode) {
    self.node = node
    _localValue = State(initialValue: node.string("value") ?? "")
  }

  var body: some View {
    Button {
      focused = true
      events.fire(node, "click")
      menuPresented = true
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
      .rufletTextStyle(DropdownM2Defaults.textStyle(node, focused: focused))
      .contentShape(Rectangle())
      .padding(DropdownM2Defaults.buttonPadding(node))
      .padding(DropdownM2Defaults.decorationContentPadding(node))
      .background(
        RoundedRectangle(cornerRadius: cornerRadius).fill(fieldBackground))
      .overlay(borderStroke)
    }
    .buttonStyle(.plain)
    .modifier(DropdownM2FieldWidth(node: node))
    .focused($focused)
    .modifier(TapFeedback(enabled: node.bool("enable_feedback") != false))
    .modifier(RufletFormFieldDecoration(node: node))
    .disabled(node.bool("disabled") ?? false)
    .popover(isPresented: $menuPresented, attachmentAnchor: .rect(.bounds)) {
      dropdownPopup
    }
    .onAppear {
      focused = node.bool("autofocus") == true
      localValue = node.string("value") ?? ""
    }
    .onChange(of: node.string("value")) { localValue = $0 ?? "" }
    .onChange(of: focused) { events.fire(node, $0 ? "focus" : "blur") }
    .rufletCommandHandler(node.id) { call, completion in
      guard call.name == "focus" else {
        completion(.failure(rufletUnsupported(node.type, call))); return
      }
      focused = true
      completion(.success(.null))
    }
  }

  private var dropdownPopup: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(optionNodes, id: \.id) { option in
          Button {
            select(option)
            menuPresented = false
          } label: {
            optionLabel(option)
              .frame(
                maxWidth: DropdownM2Defaults.optionsFillHorizontally(node) ? .infinity : nil,
                alignment: DropdownM2Defaults.alignment(option))
              .padding(.horizontal, DropdownM2Defaults.optionHorizontalPadding)
              .frame(minHeight: DropdownM2Defaults.itemHeight(node))
              .frame(maxWidth: .infinity, alignment: DropdownM2Defaults.alignment(option))
              .rufletTextStyle(DropdownM2Defaults.optionTextStyle(
                option, parent: node, focused: focused))
          }
          .buttonStyle(.plain)
          .disabled(option.bool("disabled") ?? false)
        }
      }
    }
    .modifier(DropdownM2PopupGeometry(node: node))
    .background(
      RoundedRectangle(cornerRadius: DropdownM2Defaults.popupCornerRadius(node))
        .fill(DropdownM2Defaults.popupBackground(node)))
    .shadow(
      color: MaterialPalette.color("shadow", default: .black).opacity(0.2),
      radius: DropdownM2Defaults.elevation(node))
  }

  @ViewBuilder
  private var selectIcon: some View {
    let disabled = node.bool("disabled") == true
    if let iconID = node.controlID(forKey: "select_icon") {
      ControlView(id: iconID, axis: .none)
    } else {
      Image(systemName: "chevron.down")
        .font(.system(size: DropdownM2Defaults.selectIconSize(node)))
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
    if disabled {
      if let explicit = MaterialPalette.color(node.string("select_icon_disabled_color")) {
        return explicit
      }
      return colorScheme == .dark
        ? MaterialPalette.color("white10", default: .secondary.opacity(0.1))
        : MaterialPalette.color("grey400", default: .secondary)
    }
    if let explicit = MaterialPalette.color(node.string("select_icon_enabled_color")) {
      return explicit
    }
    return colorScheme == .dark
      ? MaterialPalette.color("white70", default: .secondary.opacity(0.7))
      : MaterialPalette.color("grey700", default: .secondary)
  }

  private var hintStyle: RufletTextStyle {
    var style = RufletTextStyle(node: node, styleKey: "hint_style")
    if style.color == nil { style.color = .secondary }
    return style
  }

  private var cornerRadius: CGFloat {
    DropdownM2Defaults.fieldCornerRadius(node)
  }

  private var fieldBackground: Color {
    DropdownM2Defaults.fieldBackground(node, focused: focused)
  }

  @ViewBuilder
  private var borderStroke: some View {
    if DropdownM2Defaults.borderKind(node) == .outline {
      RoundedRectangle(cornerRadius: cornerRadius)
        .strokeBorder(
          DropdownM2Defaults.borderColor(node, focused: focused),
          lineWidth: DropdownM2Defaults.borderWidth(node, focused: focused))
    } else if DropdownM2Defaults.borderKind(node) == .underline {
      Rectangle()
        .fill(DropdownM2Defaults.borderColor(node, focused: focused))
        .frame(height: DropdownM2Defaults.borderWidth(node, focused: focused))
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
  }

  private func select(_ option: ControlNode) {
    let value = option.string("key") ?? option.string("text") ?? String(option.id)
    localValue = value
    RufletDropdownM2Events.select(value: value, option: option, on: node, to: events)
  }

  private var optionNodes: [ControlNode] {
    DropdownM2Defaults.visibleOptions(
      node.controlIDs(forKey: "options").compactMap { store.node($0) })
  }

  @ViewBuilder
  private var selectedLabel: some View {
    if !localValue.isEmpty,
      let option = optionNodes.first(where: {
        ($0.string("key") ?? $0.string("text") ?? String($0.id)) == localValue
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

/// Source-derived defaults for Flet's legacy `DropdownM2`, which wraps
/// Flutter's `DropdownButtonFormField`. These values remain the Material
/// constructor contract even though the visible popup is an Apple popover.
enum DropdownM2Defaults {
  enum BorderKind: String { case outline, underline, none }

  static let defaultWidth: CGFloat = 300
  static let optionHorizontalPadding: CGFloat = 16
  static let minimumItemHeight: CGFloat = 48
  static let defaultSelectIconSize: CGFloat = 24
  static let defaultElevation: CGFloat = 8

  /// `DropdownOption` is structural, so its parent owns visibility filtering.
  /// This matches Dart's default-visible `children("options")` lookup before
  /// each remaining entry is converted into a `DropdownMenuItem`.
  static func visibleOptions(_ options: [ControlNode]) -> [ControlNode] {
    options.filter {
      $0.bool("visible") != false
        && ($0.string("key") != nil || $0.string("text") != nil)
    }
  }

  static func optionsFillHorizontally(_ node: ControlNode) -> Bool {
    node.bool("options_fill_horizontally") ?? true
  }

  static func itemHeight(_ node: ControlNode) -> CGFloat {
    CGFloat(node.double("item_height") ?? Double(minimumItemHeight))
  }

  static func selectIconSize(_ node: ControlNode) -> CGFloat {
    CGFloat(node.double("select_icon_size") ?? Double(defaultSelectIconSize))
  }

  static func elevation(_ node: ControlNode) -> CGFloat {
    CGFloat(node.double("elevation") ?? Double(defaultElevation))
  }

  static func optionsFillWidth(_ node: ControlNode) -> CGFloat? {
    node.double("width").map { CGFloat($0) }
  }

  static func popupMaxHeight(_ node: ControlNode) -> CGFloat? {
    node.double("max_menu_height").map { CGFloat($0) }
  }

  static func popupCornerRadius(_ node: ControlNode) -> CGFloat {
    ControlProps.cornerRadius(node.props["border_radius"]) ?? 0
  }

  static func popupBackground(_ node: ControlNode) -> Color {
    MaterialPalette.color(node.string("bgcolor") ?? "surface", default: .clear)
  }

  static func buttonPadding(_ node: ControlNode) -> EdgeInsets {
    ControlProps.edgeInsets(node.props["padding"]) ?? EdgeInsets()
  }

  static func borderKind(_ node: ControlNode) -> BorderKind {
    BorderKind(rawValue: node.string("border")?.lowercased() ?? "outline") ?? .outline
  }

  static func decorationContentPadding(_ node: ControlNode) -> EdgeInsets {
    if node.bool("collapsed") == true { return EdgeInsets() }
    if let explicit = ControlProps.edgeInsets(node.props["content_padding"]) { return explicit }
    let dense = node.bool("dense") == true
    switch borderKind(node) {
    case .outline:
      return dense
        ? EdgeInsets(top: 16, leading: 12, bottom: 8, trailing: 12)
        : EdgeInsets(top: 20, leading: 12, bottom: 12, trailing: 12)
    case .underline, .none:
      if node.bool("filled") == true {
        return dense
          ? EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
          : EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
      }
      return dense
        ? EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        : EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
    }
  }

  static func fieldCornerRadius(_ node: ControlNode) -> CGFloat {
    guard borderKind(node) == .outline else { return 0 }
    return ControlProps.cornerRadius(node.props["border_radius"]) ?? 4
  }

  static func borderWidth(_ node: ControlNode, focused: Bool) -> CGFloat {
    if node.double("border_width") == 0 { return 0 }
    if focused {
      return CGFloat(node.double("focused_border_width") ?? node.double("border_width") ?? 2)
    }
    return CGFloat(node.double("border_width") ?? 1)
  }

  static func borderColor(_ node: ControlNode, focused: Bool) -> Color {
    if focused {
      return MaterialPalette.color(
        node.string("focused_border_color") ?? node.string("border_color") ?? "primary",
        default: .primary)
    }
    return MaterialPalette.color(node.string("border_color") ?? "#000000", default: .black)
  }

  static func fieldBackground(_ node: ControlNode, focused: Bool) -> Color {
    guard node.bool("filled") == true else { return .clear }
    let name = node.string("fill_color")
      ?? (focused ? node.string("focused_bgcolor") : nil)
      ?? node.string("bgcolor")
      ?? "surfacecontainerhighest"
    return MaterialPalette.color(name, default: .clear)
  }

  static func textStyle(_ node: ControlNode, focused: Bool) -> RufletTextStyle {
    var style = RufletTextStyle(node: node, styleKey: "text_style")
    if let size = node.double("text_size") { style.size = CGFloat(size) }
    if let explicit = node.string("color") {
      style.color = MaterialPalette.color(explicit)
    } else if focused, let explicit = node.string("focused_color") {
      style.color = MaterialPalette.color(explicit)
    }
    if style.color == nil { style.color = MaterialPalette.color("onsurface") }
    return style
  }

  static func optionTextStyle(
    _ option: ControlNode, parent: ControlNode, focused: Bool
  ) -> RufletTextStyle {
    var style = RufletTextStyle(node: option, styleKey: "text_style")
    let parentStyle = textStyle(parent, focused: focused)
    if style.size == nil { style.size = parentStyle.size }
    if style.color == nil {
      style.color = option.bool("disabled") == true
        ? MaterialPalette.color("onsurface,0.38") : parentStyle.color
    }
    return style
  }

  static func alignment(_ option: ControlNode) -> Alignment {
    ControlProps.alignment(option.props["alignment"]) ?? .leading
  }
}

private struct DropdownM2FieldWidth: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    if let width = node.double("width") {
      content.frame(width: CGFloat(width))
    } else if (node.int("expand") ?? 0) > 0 {
      content.frame(maxWidth: .infinity)
    } else {
      content.frame(idealWidth: DropdownM2Defaults.defaultWidth)
    }
  }
}

private struct DropdownM2PopupGeometry: ViewModifier {
  let node: ControlNode

  func body(content: Content) -> some View {
    let width = DropdownM2Defaults.optionsFillWidth(node)
      ?? ((node.int("expand") ?? 0) > 0 ? nil : DropdownM2Defaults.defaultWidth)
    if let width {
      content.frame(width: width).frame(maxHeight: DropdownM2Defaults.popupMaxHeight(node))
    } else {
      content.frame(maxHeight: DropdownM2Defaults.popupMaxHeight(node))
    }
  }
}

enum RufletDropdownM2Events {
  static func select(
    value: String, option: ControlNode, on node: ControlNode, to events: RufletEventSink
  ) {
    // DropdownMenuItem.onTap runs before DropdownButton.onChanged.
    events.fire(option, "click")
    let wire = RufletValue.string(value)
    events.setLocal(node.id, "value", wire)
    events.update(node.id, ["value": wire])
    events.fire(node, "change", data: wire)
  }
}

/// `AutoComplete` — a field with a filtered suggestion list underneath.
struct AutoCompleteControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events
  @State private var query = ""
  @State private var focused = false
  @State private var selection = NSRange(location: 0, length: 0)
  @State private var suggestionsPresented = false

  var body: some View {
    Group {
      #if canImport(UIKit) || canImport(AppKit)
        RufletNativeTextInput(
          text: queryBinding,
          focused: $focused,
          selection: $selection,
          placeholder: "",
          secure: false,
          nativeChrome: false,
          traits: inputTraits,
          onTap: { suggestionsPresented = !query.isEmpty && !matches.isEmpty },
          onTapOutside: {},
          onSubmit: { _ in
            if let match = matches.first { select(match) }
          })
      #else
        TextField("", text: queryBinding)
      #endif
    }
    .padding(RufletAutoCompleteDefaults.fieldContentPadding)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(RufletAutoCompleteDefaults.fieldBorderColor(focused: focused))
        .frame(height: RufletAutoCompleteDefaults.fieldBorderWidth(focused: focused))
    }
    .popover(isPresented: $suggestionsPresented, attachmentAnchor: .rect(.bounds)) {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(matches) { match in
            Button {
              select(match)
            } label: {
              Text(match.suggestion.value)
                .rufletTextStyle(RufletAutoCompleteDefaults.optionTextStyle)
                .padding(RufletAutoCompleteDefaults.optionPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
      }
      .frame(maxHeight: RufletAutoCompleteDefaults.suggestionsMaxHeight(node))
      .background(RufletAutoCompleteDefaults.popupBackground)
      .shadow(
        color: RufletAutoCompleteDefaults.popupShadowColor,
        radius: RufletAutoCompleteDefaults.popupElevation)
    }
    .onAppear { synchronizeFromWire() }
    .onChange(of: node.string("value")) { _ in synchronizeFromWire() }
  }

  private var queryBinding: Binding<String> {
    Binding(
      get: { query },
      set: { value in
        guard value != query else { return }
        query = value
        RufletAutoCompleteEvents.change(value, on: node, to: events)
        suggestionsPresented = !value.isEmpty && !matches.isEmpty
      })
  }

  private var inputTraits: RufletTextInputTraits {
    var traits = RufletTextInputTraits(node: node)
    traits.fontSize = RufletAutoCompleteDefaults.fieldTextSize
    traits.textColor = MaterialPalette.color("onsurface")
    return traits
  }

  private var suggestions: [RufletAutoCompleteSuggestion] {
    RufletAutoCompleteSuggestion.parse(node.props["suggestions"], store: store)
  }

  private var matches: [RufletAutoCompleteMatch] {
    suggestions.enumerated().compactMap { index, suggestion in
      // Flet filters on `selectionString()`, which is the key, while it
      // displays `toString()`, which is the value.
      suggestion.matches(query)
        ? RufletAutoCompleteMatch(index: index, suggestion: suggestion) : nil
    }
  }

  private func select(_ match: RufletAutoCompleteMatch) {
    // Flutter Autocomplete writes displayStringForOption (`value`) into the
    // field (which first follows the ordinary change path), then reports the
    // original key/value pair and source index.
    query = match.suggestion.value
    RufletAutoCompleteEvents.change(query, on: node, to: events)
    suggestionsPresented = false
    let index = Int64(match.index)
    events.setLocal(node.id, "_selected_index", .int(index))
    events.update(node.id, ["_selected_index": .int(index)])
    events.fire(node, "select", data: .map([
      "index": .int(index),
      "selection": match.suggestion.wireValue,
    ]))
  }

  private func synchronizeFromWire() {
    let value = node.string("value") ?? ""
    guard value != query else { return }
    query = value
    selection = NSRange(location: value.utf16.count, length: 0)
  }
}

/// Exact defaults used by Flutter's Material `Autocomplete`. The editable
/// primitive remains UIKit/AppKit, while its constructor-level field and
/// popup semantics stay identical to the Flet engine.
enum RufletAutoCompleteDefaults {
  static let defaultSuggestionsMaxHeight: CGFloat = 200
  static let popupElevation: CGFloat = 4
  static let fieldTextSize: CGFloat = 16
  static let optionTextSize: CGFloat = 14
  static let optionPadding = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
  static let fieldContentPadding = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)

  static func suggestionsMaxHeight(_ node: ControlNode) -> CGFloat {
    CGFloat(node.double("suggestions_max_height") ?? Double(defaultSuggestionsMaxHeight))
  }

  static func fieldBorderWidth(focused: Bool) -> CGFloat { focused ? 2 : 1 }

  static func fieldBorderColor(focused: Bool) -> Color {
    MaterialPalette.color(focused ? "primary" : "onsurfacevariant", default: .secondary)
  }

  static var popupBackground: Color {
    MaterialPalette.color("surface", default: .clear)
  }

  static var popupShadowColor: Color {
    MaterialPalette.color("shadow", default: .black).opacity(0.2)
  }

  static var optionTextStyle: RufletTextStyle {
    var style = RufletTextStyle()
    style.size = optionTextSize
    style.color = MaterialPalette.color("onsurface")
    return style
  }
}

enum RufletAutoCompleteEvents {
  static func change(_ value: String, on node: ControlNode, to events: RufletEventSink) {
    let wire = RufletValue.string(value)
    events.setLocal(node.id, "value", wire)
    events.update(node.id, ["value": wire])
    events.fire(node, "change", data: wire)
  }
}

struct RufletAutoCompleteSuggestion: Equatable {
  let key: String
  let value: String

  var wireValue: RufletValue {
    .map(["key": .string(key), "value": .string(value)])
  }

  /// Pinned Dart calls `toLowerCase()` on both strings before `contains`.
  /// Foundation's localized case-insensitive comparison performs broader
  /// locale/case folding (for example `ß` can match `SS`), which changes the
  /// suggestion set and therefore the selected source index.
  func matches(_ query: String) -> Bool {
    guard !query.isEmpty else { return false }
    return key.lowercased().contains(query.lowercased())
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
/// Ruflet drives these by flipping `open`. The picker primitives and buttons
/// are native Apple controls; the surrounding state machine mirrors Flet's
/// service-style dialogs without recreating Material dialog chrome.
struct DateTimePickerControlView: View {
  enum Kind: Equatable { case date, time, dateRange }

  let node: ControlNode
  let kind: Kind
  @Environment(\.rufletEvents) private var events
  @State private var selection = Date()
  @State private var rangeStart = Date()
  @State private var rangeEnd = Date()
  @State private var entryMode = ""

  @ViewBuilder
  var body: some View {
    // Flet's picker widget itself is always zero-sized. It presents exactly
    // once when `open` changes from false to true. DialogPresenter normally
    // performs that host transition, but retaining the same guard here is
    // important when a picker is mounted directly and makes `open` a real
    // renderer contract rather than presenter-only bookkeeping.
    if node.bool("open") == true {
      picker
        .environment(\.locale, pickerLocale)
        .onAppear {
          // These props influence the Flutter dialog host. Apple keeps their
          // wire contract while delegating the visual primitive to DatePicker.
          _ = node.bool("adaptive")
          _ = node.string("orientation")
          _ = node.bool("modal")
          _ = node.string("barrier_color")
          _ = node.string("keyboard_type")
          _ = node.string("date_picker_mode")
          events.setLocal(node.id, "_open", .bool(true))
        }
    }
  }

  /// `locale` is the calendar and month names the picker draws with.
  private var pickerLocale: Locale {
    let base = node.string("locale") ?? Locale.current.identifier
    guard kind == .time else { return Locale(identifier: base) }
    switch node.string("hour_format")?.lowercased() {
    case "h12": return Locale(identifier: "\(base)@hours=h12")
    case "h24": return Locale(identifier: "\(base)@hours=h23")
    default: return Locale(identifier: base)
    }
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
    RufletPickerSemantics.switchIcon(node, kind: kind, entryMode: entryMode)
  }

  @ViewBuilder
  private var picker: some View {
    let text = RufletPickerSemantics.text(node, kind: kind)
    VStack {
      if let help = text.helpText, !help.isEmpty {
        Text(help).frame(maxWidth: .infinity, alignment: .leading)
      }

      switch kind {
      case .date:
        if entryMode == "input" {
          VStack(alignment: .leading, spacing: 4) {
            if let label = text.fieldLabelText { Text(label).font(.caption) }
            DatePicker("", selection: $selection, in: allowedDates, displayedComponents: [.date])
              .datePickerStyle(.compact)
              .labelsHidden()
              .accessibilityHint(text.fieldHintText ?? "")
          }
        } else {
          DatePicker("", selection: $selection, in: allowedDates, displayedComponents: [.date])
            .datePickerStyle(.graphical)
            .labelsHidden()
        }
      case .time:
        #if os(iOS)
        if entryMode == "input" {
          VStack(alignment: .leading, spacing: 4) {
            DatePicker("", selection: $selection, displayedComponents: [.hourAndMinute])
              .datePickerStyle(.compact)
              .labelsHidden()
              .accessibilityLabel(timeFieldAccessibilityLabel(text))
          }
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
        VStack {
          DatePicker(
            entryMode == "input" ? (text.fieldStartLabelText ?? "Start date") : "Start date",
            selection: $rangeStart,
            in: allowedDates,
            displayedComponents: [.date]
          )
          .accessibilityHint(entryMode == "input" ? (text.fieldStartHintText ?? "") : "")
          DatePicker(
            entryMode == "input" ? (text.fieldEndLabelText ?? "End date") : "End date",
            selection: $rangeEnd,
            in: rangeStart...allowedDates.upperBound,
            displayedComponents: [.date]
          )
          .accessibilityHint(entryMode == "input" ? (text.fieldEndHintText ?? "") : "")
        }
        .datePickerStyle(.compact)
      }

      // DateRangePickerDialog also switches between calendar and input, but
      // unlike the other two Flet does not expose an entry-mode-change event.
      if supportsEntryModeSwitch {
        Button(action: toggleEntryMode) {
          HStack {
            if entryModeIconValue != nil {
              entryModeIcon
            } else {
              Image(systemName: nativeEntryModeIcon)
            }
            Text(nativeEntryModeLabel)
          }
        }
        .accessibilityLabel(entryMode == "input" ? "Switch to picker mode" : "Switch to input mode")
      }

      HStack {
        Button(text.cancelText ?? "Cancel", role: .cancel) { cancel() }
        Spacer()
        Button(RufletPickerSemantics.confirmationText(
          text, kind: kind, entryMode: entryMode)) { confirm() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(RufletPickerSemantics.contentInsets(node, kind: kind))
    .onAppear {
      let current = parsedValue(node.string("current_date")) ?? selection
      selection = parsedValue(node.string("value")) ?? current
      rangeStart = parsedValue(node.string("start_value")) ?? current
      rangeEnd = max(parsedValue(node.string("end_value")) ?? rangeStart, rangeStart)
      entryMode = RufletPickerSemantics.initialEntryMode(node, kind: kind)
    }
  }

  private var supportsEntryModeSwitch: Bool { true }

  private func timeFieldAccessibilityLabel(_ text: RufletPickerTextSemantics) -> String {
    [text.hourLabelText, text.minuteLabelText]
      .compactMap { $0 }.joined(separator: ", ")
  }

  private var nativeEntryModeIcon: String {
    guard entryMode != "input" else { return kind == .time ? "clock" : "calendar" }
    return "keyboard"
  }

  private var nativeEntryModeLabel: String {
    guard entryMode != "input" else { return kind == .time ? "Clock" : "Calendar" }
    return "Keyboard"
  }

  private func toggleEntryMode() {
    let next = entryMode == "input" ? (kind == .time ? "dial" : "calendar") : "input"
    entryMode = next
    guard kind != .dateRange else { return }
    RufletPickerEvents.entryModeChanged(next, on: node, to: events)
  }

  private func confirm() {
    if kind == .dateRange {
      let start = formattedDate(rangeStart)
      let end = formattedDate(rangeEnd)
      RufletPickerEvents.confirmRange(start: start, end: end, on: node, to: events)
    } else {
      let value = kind == .time ? formattedTime(selection) : formattedDate(selection)
      RufletPickerEvents.confirm(value: value, on: node, to: events)
    }
  }

  private func cancel() {
    RufletPickerEvents.cancel(node, to: events)
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

/// The picker dialogs are service controls: closing them always clears both
/// the public `open` bit and Flet's private `_open` edge-trigger bit. A
/// successful selection reports `change` before `dismiss(false)`. Date and
/// date-range cancellation preserve their prior values; Flet's TimePicker
/// intentionally writes a null value. All cancellations report only
/// `dismiss(true)`.
enum RufletPickerEvents {
  static func confirm(value: String, on node: ControlNode, to events: RufletEventSink) {
    let wire = RufletValue.string(value)
    beginClose(node, to: events)
    events.setLocal(node.id, "value", wire)
    events.setLocal(node.id, "open", .bool(false))
    events.update(node.id, ["value": wire, "open": .bool(false)])
    events.fire(node, "change", data: .map(["value": wire]))
    events.fire(node, "dismiss", data: .bool(false))
  }

  static func confirmRange(
    start: String, end: String, on node: ControlNode, to events: RufletEventSink
  ) {
    let startValue = RufletValue.string(start)
    let endValue = RufletValue.string(end)
    beginClose(node, to: events)
    events.setLocal(node.id, "start_value", startValue)
    events.setLocal(node.id, "end_value", endValue)
    events.setLocal(node.id, "open", .bool(false))
    events.update(node.id, [
      "start_value": startValue, "end_value": endValue, "open": .bool(false),
    ])
    events.fire(node, "change", data: .map([
      "start_value": startValue, "end_value": endValue,
    ]))
    events.fire(node, "dismiss", data: .bool(false))
  }

  static func cancel(_ node: ControlNode, to events: RufletEventSink) {
    beginClose(node, to: events)
    var values: [String: RufletValue] = ["open": .bool(false)]
    switch node.type {
    case "DateRangePicker":
      values["start_value"] = node.props["start_value"] ?? .null
      values["end_value"] = node.props["end_value"] ?? .null
      events.setLocal(node.id, "start_value", values["start_value"]!)
      events.setLocal(node.id, "end_value", values["end_value"]!)
    case "DatePicker":
      values["value"] = node.props["value"] ?? .null
      events.setLocal(node.id, "value", values["value"]!)
    case "TimePicker":
      // `TimePickerControl.onClosed()` forwards the nullable dialog result
      // directly, unlike DatePicker's `dateValue ?? value` behavior.
      values["value"] = .null
      events.setLocal(node.id, "value", .null)
    default:
      break
    }
    events.setLocal(node.id, "open", .bool(false))
    events.update(node.id, values)
    events.fire(node, "dismiss", data: .bool(true))
  }

  static func entryModeChanged(
    _ mode: String, on node: ControlNode, to events: RufletEventSink
  ) {
    let wire = RufletValue.string(mode)
    events.setLocal(node.id, "entry_mode", wire)
    events.update(node.id, ["entry_mode": wire])
    events.fire(node, "entry_mode_change", data: .map(["entry_mode": wire]))
  }

  private static func beginClose(_ node: ControlNode, to events: RufletEventSink) {
    // Flet uses `python: false` for this private edge-trigger property.
    events.setLocal(node.id, "_open", .bool(false))
  }
}

enum RufletPickerSemantics {
  static let defaultFirstDate = date(year: 1900, month: 1, day: 1)
  static let defaultLastDate = date(year: 2050, month: 1, day: 1)

  /// Mirrors Flet's `control.getBool("open", false)` gate. Pickers are dialog
  /// services with no persistent visual body, so a missing value is closed.
  static func isPresented(_ node: ControlNode) -> Bool {
    node.bool("open") == true
  }

  /// Only DatePicker forwards an inset to its Flutter dialog constructor.
  /// DateRangePicker and TimePicker expose no such property. Preserve the
  /// exact 16×24 default while leaving the native controls themselves native.
  static func contentInsets(_ node: ControlNode, kind: DateTimePickerControlView.Kind)
    -> EdgeInsets
  {
    guard kind == .date else { return EdgeInsets() }
    return ControlProps.edgeInsets(node.props["inset_padding"])
      ?? EdgeInsets(top: 24, leading: 16, bottom: 24, trailing: 16)
  }

  static func initialEntryMode(
    _ node: ControlNode, kind: DateTimePickerControlView.Kind
  ) -> String {
    node.string("entry_mode") ?? (kind == .time ? "dial" : "calendar")
  }

  /// Exact optional text forwarded to each pinned Flutter picker constructor.
  /// Error strings are metadata for a validation failure, not persistent help
  /// text: Apple's native DatePicker never exposes malformed typed text, so it
  /// must not paint configured errors before a failure has occurred.
  static func text(
    _ node: ControlNode, kind: DateTimePickerControlView.Kind
  ) -> RufletPickerTextSemantics {
    switch kind {
    case .date:
      return RufletPickerTextSemantics(
        helpText: node.string("help_text"),
        cancelText: node.string("cancel_text"),
        confirmText: node.string("confirm_text"),
        errorFormatText: node.string("error_format_text"),
        errorInvalidText: node.string("error_invalid_text"),
        fieldHintText: node.string("field_hint_text"),
        fieldLabelText: node.string("field_label_text"))
    case .dateRange:
      return RufletPickerTextSemantics(
        helpText: node.string("help_text"),
        cancelText: node.string("cancel_text"),
        confirmText: node.string("confirm_text"),
        saveText: node.string("save_text"),
        errorFormatText: node.string("error_format_text"),
        errorInvalidText: node.string("error_invalid_text"),
        errorInvalidRangeText: node.string("error_invalid_range_text"),
        fieldStartHintText: node.string("field_start_hint_text"),
        fieldEndHintText: node.string("field_end_hint_text"),
        fieldStartLabelText: node.string("field_start_label_text"),
        fieldEndLabelText: node.string("field_end_label_text"))
    case .time:
      return RufletPickerTextSemantics(
        helpText: node.string("help_text"),
        cancelText: node.string("cancel_text"),
        confirmText: node.string("confirm_text"),
        errorInvalidText: node.string("error_invalid_text"),
        hourLabelText: node.string("hour_label_text"),
        minuteLabelText: node.string("minute_label_text"))
    }
  }

  static func validationMessage(
    _ failure: RufletPickerValidationFailure,
    text: RufletPickerTextSemantics
  ) -> String? {
    switch failure {
    case .format: return text.errorFormatText
    case .invalid: return text.errorInvalidText
    case .invalidRange: return text.errorInvalidRangeText
    }
  }

  static func switchIcon(
    _ node: ControlNode,
    kind: DateTimePickerControlView.Kind,
    entryMode: String
  ) -> RufletValue? {
    guard entryMode == "input" else { return node.props["switch_to_input_icon"] }
    switch kind {
    case .date, .dateRange: return node.props["switch_to_calendar_icon"]
    case .time: return node.props["switch_to_timer_icon"]
    }
  }

  static func confirmationText(
    _ text: RufletPickerTextSemantics,
    kind: DateTimePickerControlView.Kind,
    entryMode: String
  ) -> String {
    guard kind == .dateRange else { return text.confirmText ?? "OK" }
    return entryMode == "input" ? (text.confirmText ?? "OK") : (text.saveText ?? "Save")
  }

  private static func date(year: Int, month: Int, day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: DateComponents(year: year, month: month, day: day))!
  }
}

enum RufletPickerValidationFailure: Equatable {
  case format
  case invalid
  case invalidRange
}

struct RufletPickerTextSemantics: Equatable {
  var helpText: String? = nil
  var cancelText: String? = nil
  var confirmText: String? = nil
  var saveText: String? = nil
  var errorFormatText: String? = nil
  var errorInvalidText: String? = nil
  var errorInvalidRangeText: String? = nil
  var fieldHintText: String? = nil
  var fieldLabelText: String? = nil
  var fieldStartHintText: String? = nil
  var fieldEndHintText: String? = nil
  var fieldStartLabelText: String? = nil
  var fieldEndLabelText: String? = nil
  var hourLabelText: String? = nil
  var minuteLabelText: String? = nil
}
