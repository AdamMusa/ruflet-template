import RufletProtocol
import SwiftUI

#if os(iOS)
  import UIKit
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
      if !rufletIsIOS {
        ErrorControl("The native Tabs renderer requires iOS.")
      } else if let content = control.buildWidget("content") {
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
      if !rufletIsIOS {
        ErrorControl("The native TabBarView renderer requires iOS.")
      } else if let tabsState {
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
  @Environment(\.rufletPageTheme) private var pageTheme
  @State private var hoveredIndex: Int?
  @Namespace private var appleSegmentSelection

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    let presentation = RufletTabBarPresentation(control: control, theme: pageTheme)
    Group {
      if let tabsState {
        RufletTabsObserver(state: tabsState) { state in
          BaseControl(control: control) {
            VStack(spacing: 0) {
              tabStrip(state: state, presentation: presentation)
              if presentation.dividerHeight > 0 {
                Rectangle()
                  .fill(presentation.dividerColor)
                  .frame(height: presentation.dividerHeight)
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
  private func tabStrip(
    state: RufletTabsState,
    presentation: RufletTabBarPresentation
  ) -> some View {
    if tabControls.isEmpty {
      ErrorControl("TabBar.tabs must contain at least one visible Tab.")
    } else if !rufletIsIOS {
      ErrorControl("The native TabBar renderer requires iOS.")
    } else if !rufletTabBarUsesAppleSegmentedPresentation(
      isIOS: rufletIsIOS,
      scrollable: presentation.scrollable)
    {
      appleScrollableTabs(state: state, presentation: presentation)
    } else {
      appleSegmentedTabs(state: state, presentation: presentation)
    }
  }

  private func appleSegmentedTabs(
    state: RufletTabsState,
    presentation: RufletTabBarPresentation
  ) -> some View {
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
            RufletTextStyleModifier(
              style: selected
                ? presentation.selectedTextStyle : presentation.unselectedTextStyle)
          )
          .environment(\.rufletInheritsTextColor, true)
          .foregroundStyle(
            selected ? presentation.labelColor : presentation.unselectedLabelColor)
          .lineLimit(1)
          .padding(presentation.labelPadding)
          .frame(
            maxWidth: presentation.tabAlignment == .fill ? .infinity : nil,
            minHeight: 32)
          .background {
            if selected {
              appleSelectionIndicator(presentation)
                .matchedGeometryEffect(id: "selected-tab", in: appleSegmentSelection)
            }
          }
          .background(
            presentation.overlay(presentation.states(
              selected: selected,
              hovered: hoveredIndex == index,
              pressed: false,
              disabled: control.disabled || tab.disabled)))
          .contentShape(Rectangle())
        }
        .buttonStyle(RufletTabBarButtonStyle(
          presentation: presentation,
          selected: selected,
          disabled: control.disabled || tab.disabled))
        .disabled(control.disabled || tab.disabled)
        .opacity(control.disabled || tab.disabled ? 0.38 : 1)
        .modifier(RufletMouseCursorModifier(cursor: presentation.mouseCursor))
        .onHover { hovering in updateHover(hovering, index: index) }
        .accessibilityAddTraits(selected ? .isSelected : [])
      }
    }
    .padding(2)
    .background(
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(appleSegmentTrackColor)
    )
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(presentation.padding)
    .frame(minHeight: presentation.minimumHeight)
    .accessibilityLabel(control.string("semantics_label") ?? "Tabs")
    .animation(presentation.selectionAnimation, value: state.selectedIndex)
  }

  private func selectTab(_ index: Int, tab: RufletControl, state: RufletTabsState) {
    guard !control.disabled, !tab.disabled, index != state.selectedIndex else { return }
    let presentation = RufletTabBarPresentation(control: control)
    if presentation.enableFeedback { performTabBarFeedback() }
    state.select(index)
    control.triggerEvent("click", data: .int(Int64(index)))
  }

  private func appleScrollableTabs(
    state: RufletTabsState,
    presentation: RufletTabBarPresentation
  ) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
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
              RufletTextStyleModifier(
                style: selected
                  ? presentation.selectedTextStyle : presentation.unselectedTextStyle)
            )
            .environment(\.rufletInheritsTextColor, true)
            .foregroundStyle(
              selected ? presentation.labelColor : presentation.unselectedLabelColor)
            .lineLimit(1)
            .padding(presentation.labelPadding)
            .frame(minHeight: 36)
            .background {
              if selected {
                appleSelectionIndicator(presentation)
              }
            }
            .background(
              presentation.overlay(presentation.states(
                selected: selected,
                hovered: hoveredIndex == index,
                pressed: false,
                disabled: control.disabled || tab.disabled)))
            .contentShape(Capsule(style: .continuous))
          }
          .buttonStyle(RufletTabBarButtonStyle(
            presentation: presentation,
            selected: selected,
            disabled: control.disabled || tab.disabled))
          .disabled(control.disabled || tab.disabled)
          .opacity(control.disabled || tab.disabled ? 0.38 : 1)
          .modifier(RufletMouseCursorModifier(cursor: presentation.mouseCursor))
          .onHover { hovering in updateHover(hovering, index: index) }
          .accessibilityAddTraits(selected ? .isSelected : [])
        }
      }
      .padding(.leading, presentation.tabAlignment == .startOffset ? 52 : 0)
      .padding(presentation.padding)
    }
    .frame(minHeight: presentation.minimumHeight)
    .animation(presentation.selectionAnimation, value: state.selectedIndex)
  }

  @ViewBuilder
  private func appleSelectionIndicator(_ presentation: RufletTabBarPresentation) -> some View {
    if let indicator = presentation.indicator {
      VStack(spacing: 0) {
        Spacer(minLength: 0)
        RoundedRectangle(
          cornerRadius: indicator.borderRadius?.uniform ?? 0,
          style: .continuous
        )
        .fill(indicator.borderSide.color)
        .frame(height: indicator.borderSide.width)
      }
      .padding(indicator.insets)
      .padding(
        .horizontal,
        presentation.indicatorHorizontalInset(labelPadding: presentation.labelPadding))
      .padding(presentation.indicatorPadding)
    } else {
      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .fill(presentation.indicatorColor ?? defaultSelectionColor(presentation))
        .overlay {
          if presentation.hasExplicitIndicatorThickness {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
              .stroke(
                presentation.indicatorColor ?? presentation.labelColor,
                lineWidth: presentation.indicatorThickness)
          }
        }
        .padding(
          .horizontal,
          presentation.indicatorHorizontalInset(labelPadding: presentation.labelPadding))
        .padding(presentation.indicatorPadding)
        .shadow(color: .black.opacity(0.14), radius: 1, y: 1)
    }
  }

  private func defaultSelectionColor(_ presentation: RufletTabBarPresentation) -> Color {
    switch presentation.defaultSelectionSurface {
    case .segmented:
      appleSelectedSegmentColor
    case .scrollable:
      // A scrollable iOS tab bar is a row of independent choices, not one
      // filled segmented-control track. Tint only the active choice so the
      // selected state cannot appear visually inverted in dark appearance.
      presentation.labelColor.opacity(0.16)
    }
  }

  private func updateHover(_ hovering: Bool, index: Int) {
    hoveredIndex = hovering ? index : (hoveredIndex == index ? nil : hoveredIndex)
    guard control.hasEventHandler("hover") else { return }
    control.triggerEvent("hover", data: .map([
      "hovering": .bool(hovering),
      "index": .int(Int64(index)),
    ]))
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
      Color(uiColor: .secondarySystemFill)
    #else
      Color.secondary.opacity(0.24)
    #endif
  }

  private var tabControls: [RufletControl] {
    control.children("tabs").map { tab in
      tab.notifyParent = true
      return tab
    }
  }

}

enum RufletAppleTabSelectionSurface: Equatable {
  case segmented
  case scrollable
}

private struct RufletTabBarButtonStyle: ButtonStyle {
  let presentation: RufletTabBarPresentation
  let selected: Bool
  let disabled: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        presentation.overlay(presentation.states(
          selected: selected,
          hovered: false,
          pressed: configuration.isPressed,
          disabled: disabled)))
      .clipShape(RufletCornerShape(radius: presentation.splashBorderRadius))
  }
}

struct RufletTabBarPresentation {
  let enableFeedback: Bool
  let indicatorSize: RufletTabBarIndicatorSize
  let indicator: RufletUnderlineTabIndicator?
  let indicatorAnimation: RufletTabIndicatorAnimation
  let indicatorColor: Color?
  let indicatorPadding: EdgeInsets
  let indicatorThickness: CGFloat
  let hasExplicitIndicatorThickness: Bool
  let labelPadding: EdgeInsets
  let labelColor: Color
  let unselectedLabelColor: Color
  let selectedTextStyle: RufletTextStyle?
  let unselectedTextStyle: RufletTextStyle?
  let dividerHeight: CGFloat
  let dividerColor: Color
  let padding: EdgeInsets
  let scrollable: Bool
  let tabAlignment: RufletTabAlignment
  let mouseCursor: String?
  let overlayColor: RufletWidgetStateProperty<Color>
  let secondary: Bool
  let splashBorderRadius: RufletBorderRadius
  let selectionAnimation: Animation

  @MainActor
  init(control: RufletControl, theme: RufletTheme? = nil) {
    let componentTheme = theme?.componentTheme("tab_bar_theme")
    enableFeedback = control.boolean("enable_feedback") ?? true
    indicatorSize =
      control.tabBarIndicatorSize("indicator_size")
      ?? parseTabBarIndicatorSize(rufletTabBarString(componentTheme?["indicator_size"]))
      ?? .tab
    indicator =
      control.underlineTabIndicator("indicator")
      ?? parseUnderlineTabIndicator(componentTheme?["indicator"])
    indicatorAnimation =
      control.tabIndicatorAnimation("indicator_animation")
      ?? parseTabIndicatorAnimation(rufletTabBarString(componentTheme?["indicator_animation"]))
      ?? .linear
    if control.dynamicValue("indicator_color") != nil {
      indicatorColor = parseColor(control.string("indicator_color"))
    } else if componentTheme != nil {
      indicatorColor =
        rufletTabBarColor(componentTheme?["indicator_color"])
        ?? theme?.colorScheme?["primary"]
        ?? theme?.appleAccentColor
    } else {
      indicatorColor = nil
    }
    indicatorPadding =
      parsePadding(control.dynamicValue("indicator_padding"))
      ?? EdgeInsets()
    hasExplicitIndicatorThickness = control.dynamicValue("indicator_thickness") != nil
    indicatorThickness = CGFloat(max(
      control.number("indicator_thickness", default: 2) ?? 2,
      0))
    labelPadding =
      parsePadding(control.dynamicValue("label_padding"))
      ?? parsePadding(componentTheme?["label_padding"])
      ?? RufletLayoutDefaults.tabLabel
    labelColor =
      parseColor(control.string("label_color"))
      ?? rufletTabBarColor(componentTheme?["label_color"])
      ?? theme?.colorScheme?["primary"]
      ?? theme?.appleAccentColor
      ?? .accentColor
    unselectedLabelColor =
      parseColor(control.string("unselected_label_color"))
      ?? rufletTabBarColor(componentTheme?["unselected_label_color"])
      ?? theme?.colorScheme?["on_surface_variant"]
      ?? theme?.appleContentColor
      ?? .secondary
    selectedTextStyle =
      parseTextStyle(control.dynamicValue("label_text_style"))
      ?? parseTextStyle(componentTheme?["label_text_style"])
    unselectedTextStyle =
      parseTextStyle(control.dynamicValue("unselected_label_text_style"))
      ?? parseTextStyle(componentTheme?["unselected_label_text_style"])
    dividerHeight = CGFloat(max(
      control.number("divider_height")
        ?? parseDouble(componentTheme?["divider_height"])
        ?? 0,
      0))
    dividerColor =
      parseColor(control.string("divider_color"))
      ?? rufletTabBarColor(componentTheme?["divider_color"])
      ?? Color.secondary.opacity(0.25)
    padding = parsePadding(control.dynamicValue("padding")) ?? EdgeInsets()
    let resolvedScrollable = control.boolean("scrollable", default: true)
    scrollable = resolvedScrollable
    tabAlignment =
      control.tabAlignment("tab_alignment")
      ?? (resolvedScrollable ? .start : .fill)
    mouseCursor =
      control.string("mouse_cursor")
      ?? rufletTabBarString(componentTheme?["mouse_cursor"])
    overlayColor = RufletWidgetStateProperty(
      control.dynamicValue("overlay_color") ?? componentTheme?["overlay_color"],
      converter: rufletTabBarColor)
    secondary = control.boolean("secondary", default: false)
    splashBorderRadius = parseBorderRadius(
      control.dynamicValue("splash_border_radius")
        ?? componentTheme?["splash_border_radius"],
      .zero)!
    switch indicatorAnimation {
    case .linear:
      selectionAnimation = .linear(duration: 0.18)
    case .elastic:
      selectionAnimation = .spring(response: 0.25, dampingFraction: 0.82)
    }
  }

  var minimumHeight: CGFloat { secondary ? 40 : 44 }

  var defaultSelectionSurface: RufletAppleTabSelectionSurface {
    scrollable ? .scrollable : .segmented
  }

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

private func rufletTabBarColor(_ raw: Any?) -> Color? {
  if let string = raw as? String { return parseColor(string) }
  if let value = raw as? RufletValue { return parseColor(value.text) }
  return nil
}

private func rufletTabBarString(_ raw: Any?) -> String? {
  if let string = raw as? String { return string }
  if let value = raw as? RufletValue { return value.text }
  return nil
}

private func performTabBarFeedback() {
  #if os(iOS)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  #endif
}

func rufletTabBarUsesAppleSegmentedPresentation(
  isIOS: Bool,
  scrollable: Bool
) -> Bool {
  isIOS && !scrollable
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
    #else
      ErrorControl("The native paging TabBarView renderer requires iOS.")
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
