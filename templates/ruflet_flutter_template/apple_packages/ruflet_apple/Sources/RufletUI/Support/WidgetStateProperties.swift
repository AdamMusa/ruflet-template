import RufletEngine
import RufletProtocol
import SwiftUI

/// The states Flutter resolves a `WidgetStateProperty` against.
///
/// Flet serializes these properties as either a bare value or a map keyed by
/// the names of Flutter's `WidgetState` enum, so the names here are the wire
/// spelling and must not be renamed.
enum RufletWidgetState: String, CaseIterable {
  case disabled
  case error
  case pressed
  case dragged
  case hovered
  case focused
  case selected
  case scrolledUnder
}

/// Flutter's `WidgetStateProperty`, as `getWidgetStateProperty` parses it.
///
/// Two of Flet's rules are worth stating because they are easy to get wrong.
/// First, a bare value is the *default* state rather than an error: `Switch`
/// takes `thumb_color: "red"` and `thumb_color: {selected: "red"}` alike.
/// Second, a map whose keys are not all state names is itself the value —
/// that is what keeps `border_side: {width: 2, color: "red"}` from being read
/// as a state table with the states `width` and `color`.
///
/// One rule cannot be carried over. Flet resolves in the order the keys were
/// written, because Dart preserves a JSON map's order; a Swift dictionary does
/// not, and the order is already gone by the time a `RufletValue.map` exists.
/// `resolutionOrder` stands in for it, from the most specific state to the
/// least, so a value naming both `disabled` and `hovered` resolves the way a
/// reader would expect rather than the way the hash happened to iterate.
enum RufletWidgetStateProperty {
  /// Most specific first. `disabled` wins outright because Flutter never
  /// combines it with a pressed or hovered appearance.
  static let resolutionOrder: [RufletWidgetState] = [
    .disabled, .error, .dragged, .pressed, .hovered, .focused, .scrolledUnder, .selected,
  ]

  /// The value for `states`, or the default when no named state applies.
  static func resolve(_ value: RufletValue?, in states: Set<RufletWidgetState>) -> RufletValue? {
    guard let value else { return nil }
    guard let table = stateTable(value) else { return value }

    for state in resolutionOrder where states.contains(state) {
      if let named = table[state.rawValue] { return named }
    }
    return table["default"]
  }

  /// The state table, or nil when the value is a plain one.
  ///
  /// `""` is Flet's deprecated spelling of `default` and is accepted for it.
  private static func stateTable(_ value: RufletValue) -> [String: RufletValue]? {
    guard let map = value.mapValue else { return nil }
    let names = Set(RufletWidgetState.allCases.map(\.rawValue) + ["default", ""])
    guard !map.isEmpty, map.keys.allSatisfy({ names.contains($0) }) else { return nil }

    var table = map
    if let deprecated = table.removeValue(forKey: ""), table["default"] == nil {
      table["default"] = deprecated
    }
    return table
  }
}

extension ControlNode {
  /// The states this control is in, as far as the wire describes them.
  ///
  /// SwiftUI keeps hover, focus and press inside a view's own body, so a
  /// caller that knows it is being pressed passes the extra states in rather
  /// than expecting them to be read off the node.
  func widgetStates(selected: Bool? = nil, extra: Set<RufletWidgetState> = []) -> Set<
    RufletWidgetState
  > {
    var states = extra
    if bool("disabled") == true { states.insert(.disabled) }
    if bool("error") == true { states.insert(.error) }
    if selected ?? (bool("value") == true) { states.insert(.selected) }
    return states
  }
}

extension MaterialPalette {
  /// A colour that may have been given per widget state.
  static func color(
    stateful value: RufletValue?,
    in states: Set<RufletWidgetState>
  ) -> Color? {
    color(RufletWidgetStateProperty.resolve(value, in: states)?.stringValue)
  }
}

/// Material's state layer: the tinted halo a control shows while it is
/// hovered, focused or pressed, which Flet spells `overlay_color`.
///
/// SwiftUI keeps these states inside a view, so the layer tracks them itself
/// rather than reading them off the node. It sits *behind* the control it
/// decorates, the way Flutter's ink does.
struct MaterialStateLayer: ViewModifier {
  let node: ControlNode
  /// The control's own selected state, which `overlay_color` may key on.
  let selected: Bool
  /// Half the halo's width. Material's is larger than the control it rings.
  let radius: CGFloat

  @State private var hovering = false
  @State private var pressing = false

  func body(content: Content) -> some View {
    content
      .background {
        Circle()
          .fill(color ?? .clear)
          .frame(width: radius * 2, height: radius * 2)
      }
      .onHover { hovering = $0 }
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in pressing = true }
          .onEnded { _ in pressing = false })
  }

  private var color: Color? {
    var active: Set<RufletWidgetState> = []
    if pressing { active.insert(.pressed) }
    if hovering { active.insert(.hovered) }
    guard !active.isEmpty else { return nil }
    return MaterialPalette.color(
      stateful: node.props["overlay_color"],
      in: node.widgetStates(selected: selected, extra: active))
  }
}

extension ControlProps {
  /// A number that may have been given per widget state, such as a switch's
  /// `track_outline_width`.
  static func statefulDouble(
    _ value: RufletValue?,
    in states: Set<RufletWidgetState>
  ) -> CGFloat? {
    RufletWidgetStateProperty.resolve(value, in: states)?.doubleValue.map { CGFloat($0) }
  }

  /// A `BorderSide` that may have been given per widget state, which is how
  /// Checkbox takes its outline.
  static func statefulBorderSide(
    _ value: RufletValue?,
    in states: Set<RufletWidgetState>
  ) -> (color: Color?, width: CGFloat)? {
    guard let side = RufletWidgetStateProperty.resolve(value, in: states)?.mapValue
    else { return nil }
    return (
      color: MaterialPalette.color(side["color"]?.stringValue),
      width: side["width"]?.doubleValue.map { CGFloat($0) } ?? 1
    )
  }
}
