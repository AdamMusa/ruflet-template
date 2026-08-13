import RufletProtocol
import SwiftUI

@MainActor
public struct SemanticsControl: View {
  @ObservedObject public var control: RufletControl
  @AccessibilityFocusState private var accessibilityFocused: Bool

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    let descriptor = RufletSemanticsDescriptor(control: control)
    LayoutControl(control: control) {
      control.buildWidget("content")
        .modifier(RufletSemanticsIdentityModifier(descriptor: descriptor))
        .modifier(RufletSemanticsStateModifier(descriptor: descriptor))
        .modifier(RufletSemanticsActionModifier(control: control, descriptor: descriptor))
        .accessibilityFocused($accessibilityFocused)
        .onAppear {
          if descriptor.focused == true { accessibilityFocused = true }
        }
        .onChange(of: descriptor.focused) { focused in
          guard let focused, focused != accessibilityFocused else { return }
          accessibilityFocused = focused
        }
        .onChange(of: accessibilityFocused) { focused in
          RufletSemanticsEventRouter(control: control).trigger(
            focused ? .didGainAccessibilityFocus : .didLoseAccessibilityFocus)
        }
    }
  }
}

@MainActor
struct RufletSemanticsDescriptor {
  let label: String?
  let value: String?
  let hint: String?
  let hidden: Bool
  let disabled: Bool
  let excludeSemantics: Bool
  let container: Bool
  let focusable: Bool?
  let focused: Bool?
  let longPressHint: String?
  let headingLevel: AccessibilityHeadingLevel
  let traits: AccessibilityTraits

  init(control: RufletControl) {
    label = control.string("label")
    hidden = control.boolean("hidden", default: false)
    disabled = control.boolean("disabled", default: false) || (control.parent?.disabled ?? false)
    excludeSemantics = control.boolean("exclude_semantics", default: false)
    container = control.boolean("container", default: false)
    focusable = control.boolean("focusable")
    focused = control.boolean("focused") ?? control.boolean("focus")
    let tapHint = control.string("on_tap_hint") ?? control.string("on_tap_hint_text")
    longPressHint = control.string("on_long_press_hint")
      ?? control.string("on_long_press_hint_text")
    headingLevel = Self.heading(control.integer("heading_level"))

    let checked = control.boolean("checked")
    let expanded = control.boolean("expanded")
    let toggled = control.boolean("toggled")
    let mixed = control.boolean("mixed", default: false)
    let slider = control.boolean("slider", default: false)
    let textField = control.boolean("text_field") ?? control.boolean("textfield", default: false)
    let liveRegion = control.boolean("live_region", default: false)
    let obscured = control.boolean("obscured", default: false)
    let multiline = control.boolean("multiline", default: false)
    let readOnly = control.boolean("read_only", default: false)
    let currentValueLength = control.integer("current_value_length")
    let maxValueLength = control.integer("max_value_length")

    value = Self.accessibilityValue(
      base: control.string("value"),
      checked: checked,
      expanded: expanded,
      toggled: toggled,
      mixed: mixed,
      slider: slider,
      textField: textField,
      obscured: obscured,
      multiline: multiline,
      readOnly: readOnly,
      disabled: disabled,
      currentValueLength: currentValueLength,
      maxValueLength: maxValueLength)
    hint = Self.accessibilityHint(
      base: control.string("hint") ?? control.string("hint_text") ?? control.string("tooltip"),
      tapHint: tapHint,
      increasedValue: control.string("increased_value"),
      decreasedValue: control.string("decreased_value"))

    var parsedTraits: AccessibilityTraits = []
    if control.boolean("button", default: false) { parsedTraits.formUnion(.isButton) }
    if control.boolean("link", default: false) { parsedTraits.formUnion(.isLink) }
    if control.boolean("image", default: false) { parsedTraits.formUnion(.isImage) }
    if control.boolean("header", default: false) || headingLevel != .unspecified {
      parsedTraits.formUnion(.isHeader)
    }
    if control.boolean("selected", default: false) { parsedTraits.formUnion(.isSelected) }
    if textField || slider { parsedTraits.formUnion(.allowsDirectInteraction) }
    if readOnly { parsedTraits.formUnion(.isStaticText) }
    if liveRegion { parsedTraits.formUnion(.updatesFrequently) }
    traits = parsedTraits
  }

  var childBehavior: AccessibilityChildBehavior {
    if excludeSemantics { return .ignore }
    return container ? .contain : .combine
  }

  private static func heading(_ level: Int?) -> AccessibilityHeadingLevel {
    switch level {
    case 1: .h1
    case 2: .h2
    case 3: .h3
    case 4: .h4
    case 5: .h5
    case 6: .h6
    default: .unspecified
    }
  }

  private static func accessibilityValue(
    base: String?,
    checked: Bool?,
    expanded: Bool?,
    toggled: Bool?,
    mixed: Bool,
    slider: Bool,
    textField: Bool,
    obscured: Bool,
    multiline: Bool,
    readOnly: Bool,
    disabled: Bool,
    currentValueLength: Int?,
    maxValueLength: Int?
  ) -> String? {
    var parts = base.map { [$0] } ?? []
    if mixed {
      parts.append("mixed")
    } else if let checked {
      parts.append(checked ? "checked" : "unchecked")
    }
    if let toggled { parts.append(toggled ? "on" : "off") }
    if let expanded { parts.append(expanded ? "expanded" : "collapsed") }
    if slider { parts.append("adjustable") }
    if textField { parts.append("text field") }
    if obscured { parts.append("secure") }
    if multiline { parts.append("multiline") }
    if readOnly { parts.append("read only") }
    if disabled { parts.append("disabled") }
    if let currentValueLength {
      if let maxValueLength {
        parts.append("\(currentValueLength) of \(maxValueLength) characters")
      } else {
        parts.append("\(currentValueLength) characters")
      }
    } else if let maxValueLength {
      parts.append("maximum \(maxValueLength) characters")
    }
    return parts.isEmpty ? nil : parts.joined(separator: ", ")
  }

  private static func accessibilityHint(
    base: String?,
    tapHint: String?,
    increasedValue: String?,
    decreasedValue: String?
  ) -> String? {
    var parts = base.map { [$0] } ?? []
    if let tapHint { parts.append(tapHint) }
    if let increasedValue { parts.append("Increase: \(increasedValue)") }
    if let decreasedValue { parts.append("Decrease: \(decreasedValue)") }
    return parts.isEmpty ? nil : parts.joined(separator: ". ")
  }
}

@MainActor
private struct RufletSemanticsIdentityModifier: ViewModifier {
  let descriptor: RufletSemanticsDescriptor

  func body(content: Content) -> some View {
    var result = AnyView(
      content
        .accessibilityElement(children: descriptor.childBehavior)
        .accessibilityHidden(descriptor.hidden)
        .accessibilityAddTraits(descriptor.traits)
        .accessibilityHeading(descriptor.headingLevel)
        .disabled(descriptor.disabled))
    if let label = descriptor.label {
      result = AnyView(result.accessibilityLabel(Text(label)))
    }
    if let focusable = descriptor.focusable {
      result = AnyView(result.accessibilityRespondsToUserInteraction(focusable))
    }
    return result
  }
}

@MainActor
private struct RufletSemanticsStateModifier: ViewModifier {
  let descriptor: RufletSemanticsDescriptor

  func body(content: Content) -> some View {
    var result = AnyView(content)
    if let value = descriptor.value {
      result = AnyView(result.accessibilityValue(Text(value)))
    }
    if let hint = descriptor.hint {
      result = AnyView(result.accessibilityHint(Text(hint)))
    }
    return result
  }
}

enum RufletSemanticsAction: Equatable {
  case tap
  case doubleTap
  case longPress
  case increase
  case decrease
  case dismiss
  case scrollLeft
  case scrollRight
  case scrollUp
  case scrollDown
  case copy
  case cut
  case paste
  case moveCursorForwardByCharacter(extendSelection: Bool)
  case moveCursorBackwardByCharacter(extendSelection: Bool)
  case didGainAccessibilityFocus
  case didLoseAccessibilityFocus
  case setText(String)
}

@MainActor
struct RufletSemanticsEventRouter {
  let control: RufletControl

  func isAvailable(_ action: RufletSemanticsAction) -> Bool {
    eventName(for: action) != nil
  }

  func trigger(_ action: RufletSemanticsAction) {
    guard let name = eventName(for: action) else { return }
    control.triggerEvent(name, data: data(for: action))
  }

  private func eventName(for action: RufletSemanticsAction) -> String? {
    switch action {
    case .tap:
      if control.hasEventHandler("tap") { return "tap" }
      if control.hasEventHandler("click") { return "click" }
      return nil
    case .doubleTap:
      return control.hasEventHandler("double_tap") ? "double_tap" : nil
    case .longPress:
      if control.hasEventHandler("long_press") { return "long_press" }
      if control.hasEventHandler("dismiss") { return "dismiss" }
      return nil
    case .increase:
      return control.hasEventHandler("increase") ? "increase" : nil
    case .decrease:
      return control.hasEventHandler("decrease") ? "decrease" : nil
    case .dismiss:
      return control.hasEventHandler("dismiss") ? "dismiss" : nil
    case .scrollLeft:
      return control.hasEventHandler("scroll_left") ? "scroll_left" : nil
    case .scrollRight:
      return control.hasEventHandler("scroll_right") ? "scroll_right" : nil
    case .scrollUp:
      return control.hasEventHandler("scroll_up") ? "scroll_up" : nil
    case .scrollDown:
      return control.hasEventHandler("scroll_down") ? "scroll_down" : nil
    case .copy:
      return control.hasEventHandler("copy") ? "copy" : nil
    case .cut:
      return control.hasEventHandler("cut") ? "cut" : nil
    case .paste:
      return control.hasEventHandler("paste") ? "paste" : nil
    case .moveCursorForwardByCharacter:
      return control.hasEventHandler("move_cursor_forward_by_character")
        ? "move_cursor_forward_by_character" : nil
    case .moveCursorBackwardByCharacter:
      return control.hasEventHandler("move_cursor_backward_by_character")
        ? "move_cursor_backward_by_character" : nil
    case .didGainAccessibilityFocus:
      return control.hasEventHandler("did_gain_accessibility_focus")
        ? "did_gain_accessibility_focus" : nil
    case .didLoseAccessibilityFocus:
      return control.hasEventHandler("did_lose_accessibility_focus")
        ? "did_lose_accessibility_focus" : nil
    case .setText:
      return control.hasEventHandler("set_text") ? "set_text" : nil
    }
  }

  private func data(for action: RufletSemanticsAction) -> RufletValue {
    switch action {
    case .moveCursorForwardByCharacter(let extendSelection),
         .moveCursorBackwardByCharacter(let extendSelection):
      .bool(extendSelection)
    case .setText(let text): .string(text)
    default: .null
    }
  }
}

@MainActor
private struct RufletSemanticsActionModifier: ViewModifier {
  @ObservedObject var control: RufletControl
  let descriptor: RufletSemanticsDescriptor

  func body(content: Content) -> some View {
    let router = RufletSemanticsEventRouter(control: control)
    var result = AnyView(content)
    if router.isAvailable(.tap) {
      result = AnyView(result.accessibilityAction(.default) { router.trigger(.tap) })
    }
    if router.isAvailable(.increase) || router.isAvailable(.decrease) {
      result = AnyView(result.accessibilityAdjustableAction { direction in
        switch direction {
        case .increment: router.trigger(.increase)
        case .decrement: router.trigger(.decrease)
        @unknown default: break
        }
      })
    }
    if router.isAvailable(.dismiss) {
      result = AnyView(result.accessibilityAction(.escape) { router.trigger(.dismiss) })
    }
    result = namedAction(
      result, title: descriptor.longPressHint ?? "Long press",
      action: .longPress, router: router)
    result = namedAction(result, title: "Double tap", action: .doubleTap, router: router)
    result = namedAction(result, title: "Scroll left", action: .scrollLeft, router: router)
    result = namedAction(result, title: "Scroll right", action: .scrollRight, router: router)
    result = namedAction(result, title: "Scroll up", action: .scrollUp, router: router)
    result = namedAction(result, title: "Scroll down", action: .scrollDown, router: router)
    result = namedAction(result, title: "Copy", action: .copy, router: router)
    result = namedAction(result, title: "Cut", action: .cut, router: router)
    result = namedAction(result, title: "Paste", action: .paste, router: router)
    result = namedAction(
      result, title: "Move cursor forward", action: .moveCursorForwardByCharacter(extendSelection: false),
      router: router)
    result = namedAction(
      result, title: "Move cursor backward", action: .moveCursorBackwardByCharacter(extendSelection: false),
      router: router)
    result = namedAction(
      result, title: "Set text", action: .setText(control.string("value") ?? ""), router: router)
    return result
  }

  private func namedAction(
    _ content: AnyView,
    title: String,
    action: RufletSemanticsAction,
    router: RufletSemanticsEventRouter
  ) -> AnyView {
    guard router.isAvailable(action) else { return content }
    return AnyView(content.accessibilityAction(named: Text(title)) { router.trigger(action) })
  }
}
