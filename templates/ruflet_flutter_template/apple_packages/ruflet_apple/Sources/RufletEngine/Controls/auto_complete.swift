import RufletProtocol
import SwiftUI

/// Apple-native port of pinned Flet `AutoCompleteControl`.
@MainActor
public struct AutoCompleteControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var coordinator: RufletAutoCompleteCoordinator

  public init(control: RufletControl) {
    self.control = control
    _coordinator = StateObject(wrappedValue: RufletAutoCompleteCoordinator(control: control))
  }

  public var body: some View {
    LayoutControl(control: control) {
      input
        .frame(width: control.number("width") == nil ? 300 : nil)
        .overlay(alignment: .topLeading) {
          if coordinator.showsSuggestions {
            suggestions
              .offset(y: 38)
              .zIndex(10)
          }
        }
        .zIndex(coordinator.showsSuggestions ? 10 : 0)
    }
    .onAppear { coordinator.synchronizeFromControl() }
    .onChange(of: control.properties) { _ in coordinator.synchronizeFromControl() }
  }

  private var input: some View {
    RufletNativeTextInput(
      configuration: RufletNativeTextInputConfiguration(
        value: coordinator.value,
        selection: nil,
        multiline: false,
        minLines: 1,
        maxLines: 1,
        fitParentSize: false,
        readOnly: false,
        password: false,
        enabled: !control.disabled,
        autofocus: false,
        showCursor: nil,
        canRequestFocus: true,
        enableInteractiveSelection: true,
        keyboardType: "text",
        capitalization: .none,
        autocorrect: true,
        enableSuggestions: true,
        smartDashes: true,
        smartQuotes: true,
        maxLength: nil,
        inputFilter: nil,
        textAlignment: .leading,
        fontSize: nil,
        fontFamily: nil,
        fontWeight: nil,
        italic: false,
        textColor: nil,
        cursorColor: nil,
        selectionColor: nil,
        placeholder: nil,
        placeholderColor: nil,
        obscuringCharacter: "•",
        clearButtonMode: .never,
        autofillHints: [],
        shiftEnter: false,
        ignoreUpDownKeys: false,
        keyboardBrightness: nil,
        alwaysCallOnTap: false,
        reportsTapOutside: false,
        focusRequest: 0,
        blurRequest: 0),
      callbacks: RufletNativeTextInputCallbacks(
        onChange: coordinator.textChanged,
        onSubmit: { _ in coordinator.submit() },
        onFocusChange: coordinator.focusChanged,
        onSelectionChange: { _ in },
        onTap: {},
        onTapOutside: {}))
      .frame(minHeight: 34)
      .padding(.horizontal, 8)
      .background(Color.rufletSystemFieldBackground)
      .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .stroke(Color.rufletSystemFieldBorder, lineWidth: 0.5)
      }
      .opacity(control.disabled ? 0.55 : 1)
  }

  private var suggestions: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(Array(coordinator.filteredSuggestions.enumerated()), id: \.offset) { index, item in
          Button {
            coordinator.select(item, originalIndex: coordinator.index(of: item))
          } label: {
            Text(item.value)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 12)
              .padding(.vertical, 9)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .background(index == 0 ? Color.accentColor.opacity(0.08) : Color.clear)
          if index + 1 < coordinator.filteredSuggestions.count { Divider() }
        }
      }
    }
    .frame(maxHeight: coordinator.suggestionsMaxHeight)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .stroke(Color.rufletSystemFieldBorder, lineWidth: 0.5)
    }
    .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
  }
}

@MainActor
final class RufletAutoCompleteCoordinator: ObservableObject {
  @Published private(set) var value: String
  @Published private(set) var focused = false
  private let control: RufletControl

  init(control: RufletControl) {
    self.control = control
    value = control.string("value", default: "") ?? ""
  }

  var suggestions: [AutoCompleteSuggestion] {
    parseAutoCompleteSuggestions(control.dynamicValue("suggestions"), []) ?? []
  }

  var filteredSuggestions: [AutoCompleteSuggestion] {
    guard !value.isEmpty else { return [] }
    return suggestions.filter {
      $0.selectionString.range(of: value, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
  }

  var showsSuggestions: Bool { focused && !filteredSuggestions.isEmpty }
  var suggestionsMaxHeight: CGFloat { CGFloat(control.number("suggestions_max_height", default: 200) ?? 200) }

  func index(of suggestion: AutoCompleteSuggestion) -> Int {
    suggestions.firstIndex(of: suggestion) ?? -1
  }

  func synchronizeFromControl() {
    let next = control.string("value", default: "") ?? ""
    if value != next { value = next }
  }

  func textChanged(_ next: String) {
    guard value != next else { return }
    value = next
    control.updateProperties(["value": .string(next)])
    control.triggerEvent("change", data: .string(next))
  }

  func focusChanged(_ next: Bool) {
    if focused != next { focused = next }
  }

  func submit() {
    guard let first = filteredSuggestions.first else { return }
    select(first, originalIndex: index(of: first))
  }

  func select(_ suggestion: AutoCompleteSuggestion, originalIndex: Int) {
    // Flutter Autocomplete writes displayStringForOption (toString/value) to
    // its controller before invoking onSelected. The controller listener then
    // emits change, followed by the select payload.
    textChanged(suggestion.value)
    control.updateProperties(["_selected_index": .int(Int64(originalIndex))])
    control.triggerEvent("select", data: [
      "index": .int(Int64(originalIndex)),
      "selection": [
        "key": .string(suggestion.key),
        "value": .string(suggestion.value),
      ],
    ])
  }
}

private extension Color {
  static var rufletSystemFieldBackground: Color {
    #if os(iOS)
    Color(uiColor: .secondarySystemBackground)
    #else
    Color(nsColor: .controlBackgroundColor)
    #endif
  }

  static var rufletSystemFieldBorder: Color {
    #if os(iOS)
    Color(uiColor: .separator)
    #else
    Color(nsColor: .separatorColor)
    #endif
  }
}
