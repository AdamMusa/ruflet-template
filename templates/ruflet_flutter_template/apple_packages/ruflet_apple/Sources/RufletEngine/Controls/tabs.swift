import RufletProtocol
import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

let rufletDefaultTabAnimationDuration: TimeInterval = 0.1

private struct RufletTabsStateKey: EnvironmentKey {
  static let defaultValue: RufletTabsState? = nil
}

extension EnvironmentValues {
  fileprivate var rufletTabsState: RufletTabsState? {
    get { self[RufletTabsStateKey.self] }
    set { self[RufletTabsStateKey.self] = newValue }
  }
}

@MainActor
final class RufletTabsState: ObservableObject {
  @Published private(set) var selectedIndex: Int
  private(set) var length: Int

  private weak var control: RufletControl?
  private var invokeToken: UUID?
  private var pendingMove: Task<Void, Never>?

  init(control: RufletControl) {
    self.control = control
    length = max(control.integer("length", default: 0) ?? 0, 0)
    selectedIndex =
      resolveRufletSelectionIndex(
        control.integer("selected_index", default: 0), count: length) ?? 0
  }

  func mount() {
    guard invokeToken == nil, let control else { return }
    invokeToken = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { return .null }
      return try await self.invoke(name, arguments: arguments)
    }
    synchronizeFromControl()
  }

  func unmount() {
    pendingMove?.cancel()
    pendingMove = nil
    if let invokeToken, let control { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
  }

  func synchronizeFromControl() {
    guard let control else { return }
    let nextLength = max(control.integer("length", default: 0) ?? 0, 0)
    if nextLength != length {
      let preserved = resolveRufletSelectionIndex(selectedIndex, count: nextLength) ?? 0
      length = nextLength
      selectedIndex = preserved
      control.updateProperties(["selected_index": .int(Int64(preserved))])
      return
    }
    let requested = control.integer("selected_index", default: 0) ?? 0
    let resolved = resolveRufletSelectionIndex(requested, count: length) ?? 0
    guard selectedIndex != resolved else { return }
    let duration = parseDuration(
      control.dynamicValue("animation_duration"), rufletDefaultTabAnimationDuration)!
    withAnimation(.easeInOut(duration: duration)) { selectedIndex = resolved }
  }

  func select(_ requested: Int, emitChange: Bool = true) {
    guard let control,
      let resolved = resolveRufletSelectionIndex(requested, count: length),
      resolved != selectedIndex
    else { return }
    selectedIndex = resolved
    if emitChange {
      commitSelection(control: control, index: resolved)
    }
  }

  private func invoke(_ name: String, arguments: RufletValue) async throws -> RufletValue {
    guard name == "move_to" else { throw RufletTabsError.unknownMethod(name) }
    let values = arguments.map ?? [:]
    guard let requested = values["index"]?.integer,
      let resolved = resolveRufletSelectionIndex(requested, count: length),
      let control,
      resolved != selectedIndex
    else { return .null }

    let duration = parseDuration(
      values["duration"].map(rufletAny), rufletDefaultTabAnimationDuration)!
    let curve = parseCurve(values["curve"]?.text, .ease)!
    pendingMove?.cancel()
    withAnimation(curve.animation(duration: duration)) {
      selectedIndex = resolved
    }
    pendingMove = Task { @MainActor [weak self, weak control] in
      try? await Task.sleep(nanoseconds: rufletSleepNanoseconds(duration))
      guard !Task.isCancelled, self?.selectedIndex == resolved, let control else { return }
      self?.commitSelection(control: control, index: resolved)
    }
    return .null
  }

  private func commitSelection(control: RufletControl, index: Int) {
    control.updateProperties(
      ["selected_index": .int(Int64(index))],
      notify: false)
    control.triggerEvent("change", data: .int(Int64(index)))
  }
}

/// Apple-native port of pinned Flet `TabsControl`.
@MainActor
public struct TabsControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var tabsState: RufletTabsState

  public init(control: RufletControl) {
    self.control = control
    _tabsState = StateObject(wrappedValue: RufletTabsState(control: control))
  }

  public var body: some View {
    Group {
      if let content = control.buildWidget("content") {
        LayoutControl(control: control, child: content)
          .environment(\.rufletTabsState, tabsState)
      } else {
        ErrorControl("Tabs.content must be provided and visible")
      }
    }
    .onAppear(perform: tabsState.mount)
    .onDisappear(perform: tabsState.unmount)
    .onChange(of: control.properties) { _ in tabsState.synchronizeFromControl() }
  }
}

/// Apple-native port of pinned Flet `TabBarViewControl`.
@MainActor
public struct TabBarViewControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.rufletTabsState) private var tabsState

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    Group {
      if let tabsState {
        RufletTabsObserver(state: tabsState) { state in
          LayoutControl(control: control) {
            GeometryReader { proxy in
              TabView(
                selection: Binding(
                  get: { state.selectedIndex },
                  set: { state.select($0) })
              ) {
                ForEach(Array(control.children("controls").enumerated()), id: \.element.id) {
                  index, child in
                  ControlWidget(control: child)
                    .frame(
                      width: proxy.size.width * viewportFraction,
                      height: proxy.size.height
                    )
                    .tag(index)
                }
              }
              .modifier(RufletApplePagingTabStyle())
              .modifier(RufletTabBarViewClipModifier(behavior: clipBehavior))
            }
          }
        }
      } else {
        ErrorControl("TabBarView must be used within a Tabs control")
      }
    }
  }

  private var viewportFraction: CGFloat {
    let value = CGFloat(control.number("viewport_fraction", default: 1) ?? 1)
    precondition(value > 0, "TabBarView.viewport_fraction must be greater than zero")
    return value
  }

  private var clipBehavior: String {
    control.string("clip_behavior", default: "hardEdge")!.lowercased()
  }
}

/// Apple-native port of pinned Flet `TabControl`.
@MainActor
public struct TabControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    BaseControl(control: control) {
      RufletTabLabel(control: control)
        .frame(height: control.number("height").map { CGFloat($0) })
    }
  }
}

@MainActor
private struct RufletTabLabel: View {
  @ObservedObject var control: RufletControl

  var body: some View {
    VStack(spacing: 0) {
      if let icon = control.buildIconOrWidget("icon") {
        icon.padding(
          parseMargin(control.dynamicValue("icon_margin"))
            ?? RufletLayoutDefaults.primaryTabIcon)
      }
      if let label = control.buildTextOrWidget("label") {
        label
      }
    }
  }
}

@MainActor
private struct RufletAppleSegmentLabel: View {
  @ObservedObject var control: RufletControl

  var body: some View {
    HStack(spacing: 6) {
      if let icon = control.buildIconOrWidget("icon") {
        icon.padding(parseMargin(control.dynamicValue("icon_margin")) ?? EdgeInsets())
      }
      if let label = control.buildTextOrWidget("label") {
        label
      }
    }
  }
}

/// Apple-native port of pinned Flet `TabBarControl`.
@MainActor
public struct TabBarControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.rufletTabsState) private var tabsState
  @State private var hoveredIndex: Int?
  @Namespace private var appleSegmentSelection

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    Group {
      if let tabsState {
        RufletTabsObserver(state: tabsState) { state in
          BaseControl(control: control) {
            VStack(spacing: 0) {
              tabStrip(state: state)
              if dividerHeight > 0 {
                Rectangle().fill(dividerColor).frame(height: dividerHeight)
              }
            }
          }
        }
      } else {
        ErrorControl("TabBar must be used within a Tabs control")
      }
    }
  }

  @ViewBuilder
  private func tabStrip(state: RufletTabsState) -> some View {
    if rufletTabBarUsesAppleSegmentedPresentation(
      tabCount: tabControls.count,
      isIOS: rufletIsIOS)
    {
      appleSegmentedTabs(state: state)
    } else if scrollable {
      ScrollView(.horizontal, showsIndicators: false) {
        tabs(state: state, fill: false)
          .frame(maxWidth: .infinity, alignment: tabAlignment)
      }
    } else {
      tabs(state: state, fill: true)
    }
  }

  private func appleSegmentedTabs(state: RufletTabsState) -> some View {
    HStack(spacing: 0) {
      ForEach(Array(tabControls.enumerated()), id: \.element.id) { index, tab in
        let selected = state.selectedIndex == index
        Button {
          selectTab(index, tab: tab, state: state)
        } label: {
          Group {
            if tab.type == "Tab" {
              RufletAppleSegmentLabel(control: tab)
            } else {
              ControlWidget(control: tab)
            }
          }
          .modifier(
            RufletTextStyleModifier(style: selected ? selectedTextStyle : unselectedTextStyle)
          )
          .foregroundStyle(selected ? labelColor : unselectedLabelColor)
          .lineLimit(1)
          .frame(maxWidth: .infinity, minHeight: 32)
          .padding(.horizontal, 8)
          .background {
            if selected {
              RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(appleSelectedSegmentColor)
                .shadow(color: .black.opacity(0.14), radius: 1, y: 1)
                .matchedGeometryEffect(id: "selected-tab", in: appleSegmentSelection)
            }
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(control.disabled || tab.disabled)
        .opacity(control.disabled || tab.disabled ? 0.38 : 1)
        .accessibilityAddTraits(selected ? .isSelected : [])
      }
    }
    .padding(2)
    .background(
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(appleSegmentTrackColor)
    )
    .padding(
      parsePadding(control.dynamicValue("padding"))
        ?? EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
    )
    .frame(minHeight: 44)
    .accessibilityLabel(control.string("semantics_label") ?? "Tabs")
    .animation(.easeInOut(duration: 0.18), value: state.selectedIndex)
  }

  private func selectTab(_ index: Int, tab: RufletControl, state: RufletTabsState) {
    guard !control.disabled, !tab.disabled, index != state.selectedIndex else { return }
    let presentation = RufletTabBarPresentation(control: control)
    if presentation.enableFeedback { performTabBarFeedback() }
    state.select(index)
    control.triggerEvent("click", data: .int(Int64(index)))
  }

  private var appleSegmentTrackColor: Color {
    #if os(iOS)
      Color(uiColor: .tertiarySystemFill)
    #else
      Color.secondary.opacity(0.16)
    #endif
  }

  private var appleSelectedSegmentColor: Color {
    #if os(iOS)
      Color(uiColor: .secondarySystemBackground)
    #else
      Color.rufletSystemBackground
    #endif
  }

  private func tabs(state: RufletTabsState, fill: Bool) -> some View {
    HStack(spacing: 0) {
      ForEach(Array(tabControls.enumerated()), id: \.element.id) { index, tab in
        tabButton(tab, index: index, state: state)
          .frame(maxWidth: fill ? .infinity : nil)
      }
    }
    .padding(parsePadding(control.dynamicValue("padding")) ?? EdgeInsets())
  }

  private func tabButton(_ tab: RufletControl, index: Int, state: RufletTabsState) -> some View {
    let selected = state.selectedIndex == index
    let presentation = RufletTabBarPresentation(control: control)
    let states = presentation.states(
      selected: selected,
      hovered: hoveredIndex == index,
      pressed: false,
      disabled: control.disabled || tab.disabled)
    return Button {
      guard !control.disabled, !tab.disabled else { return }
      if presentation.enableFeedback { performTabBarFeedback() }
      state.select(index)
      control.triggerEvent("click", data: .int(Int64(index)))
    } label: {
      Group {
        if tab.type == "Tab" {
          RufletTabLabel(control: tab)
        } else {
          ControlWidget(control: tab)
        }
      }
      .modifier(RufletTextStyleModifier(style: selected ? selectedTextStyle : unselectedTextStyle))
      .foregroundStyle(selected ? labelColor : unselectedLabelColor)
      .padding(labelPadding)
      .frame(minHeight: presentation.minimumHeight)
      .contentShape(Rectangle())
      .background(presentation.overlay(states))
      .clipShape(RufletCornerShape(radius: presentation.splashBorderRadius))
      .overlay(alignment: .bottom) {
        if selected { indicator }
      }
    }
    .buttonStyle(
      RufletTabBarButtonStyle(
        presentation: presentation,
        selected: selected,
        disabled: control.disabled || tab.disabled)
    )
    .disabled(control.disabled || tab.disabled)
    .modifier(RufletMouseCursorModifier(cursor: presentation.mouseCursor))
    .onHover { hovering in
      hoveredIndex = hovering ? index : (hoveredIndex == index ? nil : hoveredIndex)
      control.triggerEvent(
        "hover",
        data: [
          "hovering": .bool(hovering),
          "index": .int(Int64(index)),
        ])
    }
    .animation(tabIndicatorAnimation, value: state.selectedIndex)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var indicator: some View {
    let presentation = RufletTabBarPresentation(control: control)
    let custom = control.underlineTabIndicator("indicator")
    let color =
      custom?.borderSide.color
      ?? parseColor(control.string("indicator_color"))
      ?? .accentColor
    let thickness = CGFloat(
      custom?.borderSide.width
        ?? control.number("indicator_thickness", default: 2) ?? 2)
    let radius = custom?.borderRadius?.uniform ?? thickness / 2
    return Rectangle()
      .fill(color)
      .frame(height: thickness)
      .clipShape(RoundedRectangle(cornerRadius: radius))
      .padding(
        custom?.insets ?? parsePadding(control.dynamicValue("indicator_padding")) ?? EdgeInsets()
      )
      .padding(.horizontal, presentation.indicatorHorizontalInset(labelPadding: labelPadding))
  }

  private var tabControls: [RufletControl] {
    control.children("tabs").map { tab in
      tab.notifyParent = true
      return tab
    }
  }

  private var scrollable: Bool { control.boolean("scrollable", default: true) }
  private var labelPadding: EdgeInsets {
    parsePadding(control.dynamicValue("label_padding"))
      ?? RufletLayoutDefaults.tabLabel
  }
  private var labelColor: Color {
    parseColor(control.string("label_color")) ?? .accentColor
  }
  private var unselectedLabelColor: Color {
    parseColor(control.string("unselected_label_color")) ?? .secondary
  }
  private var selectedTextStyle: RufletTextStyle? {
    parseTextStyle(control.dynamicValue("label_text_style"))
  }
  private var unselectedTextStyle: RufletTextStyle? {
    parseTextStyle(control.dynamicValue("unselected_label_text_style"))
  }
  private var dividerHeight: CGFloat {
    CGFloat(max(control.number("divider_height") ?? 0, 0))
  }
  private var dividerColor: Color {
    parseColor(control.string("divider_color")) ?? Color.secondary.opacity(0.25)
  }
  private var tabAlignment: Alignment {
    switch control.string("tab_alignment")?.lowercased() {
    case "center": .center
    case "end": .trailing
    default: .leading
    }
  }
  private var tabIndicatorAnimation: Animation {
    switch control.tabIndicatorAnimation("indicator_animation", default: .linear)! {
    case .linear: .linear(duration: rufletDefaultTabAnimationDuration)
    case .elastic: .spring(response: 0.25, dampingFraction: 0.72)
    }
  }
}

struct RufletTabBarPresentation {
  let enableFeedback: Bool
  let indicatorSize: RufletTabBarIndicatorSize
  let mouseCursor: String?
  let overlayColor: RufletWidgetStateProperty<Color>
  let secondary: Bool
  let splashBorderRadius: RufletBorderRadius

  @MainActor
  init(control: RufletControl) {
    enableFeedback = control.boolean("enable_feedback") ?? true
    indicatorSize = control.tabBarIndicatorSize("indicator_size", default: .tab)!
    mouseCursor = control.string("mouse_cursor")
    overlayColor = RufletWidgetStateProperty(
      control.dynamicValue("overlay_color"),
      converter: rufletTabBarColor)
    secondary = control.boolean("secondary", default: false)
    splashBorderRadius = parseBorderRadius(
      control.dynamicValue("splash_border_radius"),
      .zero)!
  }

  var minimumHeight: CGFloat { secondary ? 40 : 44 }

  func indicatorHorizontalInset(labelPadding: EdgeInsets) -> CGFloat {
    indicatorSize == .label ? min(labelPadding.leading, labelPadding.trailing) : 0
  }

  func states(
    selected: Bool,
    hovered: Bool,
    pressed: Bool,
    disabled: Bool
  ) -> Set<RufletWidgetState> {
    var result = Set<RufletWidgetState>()
    if selected { result.insert(.selected) }
    if hovered { result.insert(.hovered) }
    if pressed { result.insert(.pressed) }
    if disabled { result.insert(.disabled) }
    return result
  }

  func overlay(_ states: Set<RufletWidgetState>) -> Color {
    if let explicit = overlayColor.resolve(states) { return explicit }
    if states.contains(.pressed) { return Color.accentColor.opacity(0.16) }
    if states.contains(.hovered) { return Color.accentColor.opacity(0.08) }
    return .clear
  }
}

private struct RufletTabBarButtonStyle: ButtonStyle {
  let presentation: RufletTabBarPresentation
  let selected: Bool
  let disabled: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        presentation.overlay(
          presentation.states(
            selected: selected,
            hovered: false,
            pressed: configuration.isPressed,
            disabled: disabled))
      )
      .clipShape(RufletCornerShape(radius: presentation.splashBorderRadius))
  }
}

private func rufletTabBarColor(_ raw: Any?) -> Color? {
  if let string = raw as? String { return parseColor(string) }
  if let value = raw as? RufletValue { return parseColor(value.text) }
  return nil
}

private func performTabBarFeedback() {
  #if os(iOS)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  #elseif os(macOS)
    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
  #endif
}

func rufletTabBarUsesAppleSegmentedPresentation(
  tabCount: Int,
  isIOS: Bool
) -> Bool {
  isIOS && (1...5).contains(tabCount)
}

private enum RufletTabsError: Error {
  case unknownMethod(String)
}

private struct RufletTabBarViewClipModifier: ViewModifier {
  let behavior: String

  @ViewBuilder
  func body(content: Content) -> some View {
    if behavior == "none" {
      content
    } else {
      content.clipped(antialiased: behavior.contains("antialias"))
    }
  }
}

private struct RufletApplePagingTabStyle: ViewModifier {
  @ViewBuilder
  func body(content: Content) -> some View {
    #if os(iOS)
      content.tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    #elseif os(macOS)
      content.tabViewStyle(DefaultTabViewStyle())
    #endif
  }
}

@MainActor
private struct RufletTabsObserver<Content: View>: View {
  @ObservedObject var state: RufletTabsState
  @ViewBuilder let content: (RufletTabsState) -> Content

  var body: some View {
    content(state)
  }
}
