import RufletEngine
import RufletProtocol
import SwiftUI

/// The Cupertino family.
///
/// These are the controls a Flet app uses to look iOS-native — which is what
/// SwiftUI renders by default on both platforms this engine targets. Most of
/// them therefore map onto the same native control as their Material
/// counterpart; the ones that differ genuinely (action sheets, pickers, the
/// tinted button styles) get their own treatment.

/// `CupertinoButton` / `CupertinoFilledButton` / `CupertinoTintedButton`.
struct CupertinoButtonControlView: View {
  let node: ControlNode
  let filled: Bool

  @Environment(\.rufletEvents) private var events

  var body: some View {
    Button {
      events.fire(node, "click")
    } label: {
      Group {
        if let contentID = node.controlID(forKey: "content") {
          ControlView(id: contentID, axis: .none)
        } else {
          Text(node.string("text") ?? "")
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .frame(minWidth: node.double("min_size").map { CGFloat($0) })
    }
    .buttonStyle(.plain)
    .foregroundColor(
      filled
        ? .white
        : MaterialPalette.color(node.string("color") ?? "#007aff", default: .primary))
    .background(
      RoundedRectangle(cornerRadius: ControlProps.cornerRadius(node.props["border_radius"]) ?? 8)
        .fill(background))
    .opacity(node.bool("disabled") == true ? Double(node.double("disabled_opacity") ?? 0.4) : 1)
    .disabled(node.bool("disabled") ?? false)
  }

  private var background: Color {
    if filled {
      return MaterialPalette.color(node.string("bgcolor") ?? "#007aff", default: .primary)
    }
    return MaterialPalette.color(node.string("bgcolor"), default: .clear)
  }
}

/// `CupertinoSwitch` — the same native toggle, which is already the iOS one.
struct CupertinoSwitchControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Toggle(
      isOn: Binding(
        get: { node.bool("value") ?? false },
        set: { events.commit(node, value: .bool($0)) })
    ) {
      if let label = node.string("label") { Text(label) }
    }
    .toggleStyle(.switch)
    .tint(MaterialPalette.color(node.string("active_color")))
  }
}

/// `CupertinoSlider` — the platform slider.
struct CupertinoSliderControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let minimum = node.double("min") ?? 0
    let maximum = node.double("max") ?? 1

    Slider(
      value: Binding(
        get: { node.double("value") ?? minimum },
        set: { events.commit(node, value: .double($0)) }),
      in: minimum...max(maximum, minimum + .ulpOfOne),
      onEditingChanged: { editing in
        events.fire(
          node, editing ? "change_start" : "change_end",
          data: .double(node.double("value") ?? minimum))
      }
    )
    .tint(MaterialPalette.color(node.string("active_color")))
  }
}

/// `CupertinoCheckbox` and `CupertinoRadio` — the iOS marks.
struct CupertinoSelectionControlView: View {
  enum Kind { case checkbox, radio }

  let node: ControlNode
  let kind: Kind
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Button {
      events.commit(node, value: .bool(!(node.bool("value") ?? false)))
    } label: {
      HStack(spacing: 8) {
        Image(systemName: symbol)
          .foregroundColor(
            (node.bool("value") ?? false)
              ? MaterialPalette.color(node.string("active_color") ?? "#007aff", default: .primary)
              : .secondary)
        if let label = node.string("label") { Text(label) }
      }
    }
    .buttonStyle(.plain)
  }

  private var symbol: String {
    let on = node.bool("value") ?? false
    switch kind {
    case .checkbox: return on ? "checkmark.circle.fill" : "circle"
    case .radio: return on ? "largecircle.fill.circle" : "circle"
    }
  }
}

/// `CupertinoTextField` — a rounded iOS field.
struct CupertinoTextFieldControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events

  var body: some View {
    TextField(
      node.string("placeholder_text") ?? "",
      text: Binding(
        get: { node.string("value") ?? "" },
        set: { events.commit(node, value: .string($0)) })
    )
    .textFieldStyle(.plain)
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: ControlProps.cornerRadius(node.props["border_radius"]) ?? 8)
        .fill(MaterialPalette.color(node.string("bgcolor"), default: .gray.opacity(0.12))))
    .onSubmit { events.fire(node, "submit", data: .string(node.string("value") ?? "")) }
  }
}

/// `CupertinoSegmentedButton` / `CupertinoSlidingSegmentedButton` — a native
/// segmented picker.
struct CupertinoSegmentedControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    let controls = node.childIDs.compactMap { store.node($0) }

    Picker(
      "",
      selection: Binding(
        get: { node.int("selected_index") ?? 0 },
        set: { events.commit(node, key: "selected_index", value: .int(Int64($0))) })
    ) {
      ForEach(Array(controls.enumerated()), id: \.element.id) { index, control in
        ControlView(id: control.id, axis: .none).tag(index)
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
  }
}

/// `CupertinoPicker` — the scrolling wheel.
struct CupertinoPickerControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Picker(
      "",
      selection: Binding(
        get: { node.int("selected_index") ?? 0 },
        set: { events.commit(node, key: "selected_index", value: .int(Int64($0))) })
    ) {
      ForEach(Array(node.childIDs.enumerated()), id: \.element) { index, childID in
        ControlView(id: childID, axis: .none).tag(index)
      }
    }
    .modifier(WheelPickerStyle())
    .labelsHidden()
    .frame(height: CGFloat(node.double("item_extent") ?? 32) * 5)
  }
}

/// `CupertinoDatePicker` and `CupertinoTimerPicker`.
struct CupertinoDatePickerControlView: View {
  let node: ControlNode
  let timerMode: Bool
  @Environment(\.rufletEvents) private var events
  @State private var selection = Date()

  var body: some View {
    DatePicker(
      "", selection: $selection,
      displayedComponents: components)
      .modifier(WheelDatePickerStyle())
      .labelsHidden()
      .onChange(of: selection) { value in
        events.commit(node, value: .string(ISO8601DateFormatter().string(from: value)))
      }
  }

  private var components: DatePickerComponents {
    if timerMode { return [.hourAndMinute] }
    switch node.string("date_picker_mode")?.lowercased() {
    case "time": return [.hourAndMinute]
    case "datetime": return [.date, .hourAndMinute]
    default: return [.date]
    }
  }
}

/// `CupertinoActivityIndicator` — the iOS spinner.
struct CupertinoActivityIndicatorControlView: View {
  let node: ControlNode

  var body: some View {
    ProgressView()
      .progressViewStyle(.circular)
      .scaleEffect(CGFloat(node.double("radius") ?? 10) / 10)
      .tint(MaterialPalette.color(node.string("color")))
  }
}

/// `CupertinoAppBar` / `CupertinoNavigationBar` — the iOS title bar.
struct CupertinoNavigationBarControlView: View {
  let node: ControlNode

  var body: some View {
    HStack(spacing: 8) {
      if let leadingID = node.controlID(forKey: "leading") {
        ControlView(id: leadingID, axis: .none)
      }
      Spacer(minLength: 0)
      if let middleID = node.controlID(forKey: "middle") ?? node.controlID(forKey: "title") {
        ControlView(id: middleID, axis: .none).font(.headline)
      }
      Spacer(minLength: 0)
      if let trailingID = node.controlID(forKey: "trailing") {
        ControlView(id: trailingID, axis: .none)
      }
    }
    .padding(.horizontal, 12)
    .frame(height: 44)
    .background(MaterialPalette.color(node.string("bgcolor")))
    .overlay(alignment: .bottom) { Divider() }
  }
}

/// `CupertinoActionSheet` — a titled list of actions above a cancel button.
struct CupertinoActionSheetControlView: View {
  let node: ControlNode

  var body: some View {
    VStack(spacing: 8) {
      VStack(spacing: 0) {
        if let titleID = node.controlID(forKey: "title") {
          ControlView(id: titleID, axis: .none).padding(12).font(.footnote)
        }
        if let messageID = node.controlID(forKey: "message") {
          ControlView(id: messageID, axis: .none).padding(.horizontal, 12).font(.footnote)
        }
        ForEach(node.controlIDs(forKey: "actions"), id: \.self) { actionID in
          Divider()
          ControlView(id: actionID, axis: .none)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
      }
      .background(sheetSurface, in: RoundedRectangle(cornerRadius: 12))

      if let cancelID = node.controlID(forKey: "cancel") {
        ControlView(id: cancelID, axis: .none)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(sheetSurface, in: RoundedRectangle(cornerRadius: 12))
      }
    }
    .padding(12)
  }

  private var sheetSurface: Color {
    #if canImport(UIKit)
      return Color(UIColor.secondarySystemBackground)
    #elseif canImport(AppKit)
      return Color(NSColor.controlBackgroundColor)
    #else
      return .white
    #endif
  }
}

/// The scrolling wheel exists only on iOS; macOS gets the menu picker, which is
/// what a Mac app would use for the same choice.
private struct WheelPickerStyle: ViewModifier {
  func body(content: Content) -> some View {
    #if os(iOS)
      content.pickerStyle(.wheel)
    #else
      content.pickerStyle(.menu)
    #endif
  }
}

private struct WheelDatePickerStyle: ViewModifier {
  func body(content: Content) -> some View {
    #if os(iOS)
      content.datePickerStyle(.wheel)
    #else
      content.datePickerStyle(.field)
    #endif
  }
}
