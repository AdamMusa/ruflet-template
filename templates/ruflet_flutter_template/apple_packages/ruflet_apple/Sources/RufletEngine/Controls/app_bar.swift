import SwiftUI

/// Apple-native port of Flet's `AppBarControl`.
@MainActor
public struct AppBarControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    RufletAppleAppBar(control: control, kind: .appBar)
  }
}

@MainActor
struct RufletAppleAppBar: View {
  enum Kind {
    case appBar
    case cupertino
  }

  @ObservedObject var control: RufletControl
  @Environment(\.rufletViewScrolledUnder) private var scrolledUnder
  @Environment(\.rufletPageTheme) private var pageTheme
  @Environment(\.rufletBarBackgroundColor) private var pageBarBackgroundColor
  @Environment(\.rufletSafeAreaInsets) private var safeAreaInsets
  let kind: Kind

  var body: some View {
    let presentation = RufletAppBarPresentation(control: control, isMaterial: kind == .appBar)
    BaseControl(control: control) {
      VStack(spacing: 0) {
        if extendsIntoTop, safeAreaInsets.top > 0 {
          Color.clear.frame(height: safeAreaInsets.top)
        }
        barContent
          .padding(kind == .cupertino ? cupertinoPadding : EdgeInsets())
          .frame(height: toolbarHeight)
        if isLarge, let title {
          title
            .modifier(
              RufletAppBarTitleTextModifier(
                style: resolvedTitleStyle, nestedControl: control.child("title") != nil)
            )
            .environment(\.rufletInheritedTextStyle, resolvedTitleStyle)
            .environment(\.rufletInheritsTextColor, true)
            .font(.largeTitle.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, titleSpacing)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
        }
      }
      .foregroundStyle(foregroundColor ?? pageTheme?.appleContentColor ?? .primary)
      .opacity(toolbarOpacity)
      .background {
        background(presentation)
          .allowsHitTesting(false)
      }
      .overlay { borderOverlay }
      .modifier(RufletAppBarClipModifier(shape: barShape, presentation: presentation))
      .shadow(
        color: shadowColor.opacity(presentation.forceTransparency ? 0 : (elevation > 0 ? 0.3 : 0)),
        radius: presentation.forceTransparency ? 0 : elevation,
        y: presentation.forceTransparency ? 0 : elevation / 2
      )
      .modifier(RufletBarBrightnessModifier(value: control.string("brightness")))
      .animation(
        control.boolean("transition_between_routes", default: true)
          ? .easeInOut(duration: 0.25) : nil,
        value: control.string("title") ?? String(control.child("title")?.id ?? 0))
    }
  }

  @ViewBuilder
  private var barContent: some View {
    if centerTitle && !isLarge {
      // Flutter's `NavigationToolbar` lays the middle out *between* the
      // leading and trailing slots and clamps it so it can never overlap them.
      // Stacking the title over the row instead painted it on top of the back
      // button whenever the two occupied the same pixels.
      HStack(spacing: 0) {
        leading
        if let title {
          title
            .modifier(
              RufletAppBarTitleTextModifier(
                style: resolvedTitleStyle, nestedControl: control.child("title") != nil)
            )
            .environment(\.rufletInheritedTextStyle, resolvedTitleStyle)
            .environment(\.rufletInheritsTextColor, true)
            .modifier(RufletHeaderSemantics(excluded: excludeHeaderSemantics))
            .padding(.horizontal, titleSpacing)
            .frame(maxWidth: .infinity)
        } else {
          Spacer(minLength: 0)
        }
        actions
      }
    } else {
      HStack(spacing: 0) {
        leading
        if !isLarge, let title {
          title
            .modifier(
              RufletAppBarTitleTextModifier(
                style: resolvedTitleStyle, nestedControl: control.child("title") != nil)
            )
            .environment(\.rufletInheritedTextStyle, resolvedTitleStyle)
            .environment(\.rufletInheritsTextColor, true)
            .modifier(RufletHeaderSemantics(excluded: excludeHeaderSemantics))
            // Flutter applies AppBar.titleSpacing around the title even when
            // the leading or actions slot is absent. HStack spacing alone
            // drops the edge inset when either adjacent view is EmptyView.
            .padding(.horizontal, titleSpacing)
        }
        Spacer(minLength: 0)
        actions
      }
    }
  }

  @ViewBuilder
  private var leading: some View {
    if let leading = control.buildWidget("leading") {
      leading.frame(width: leadingWidth)
    } else if control.boolean("automatically_imply_leading", default: true), canNavigateBack {
      Button(action: requestPop) {
        HStack(spacing: 4) {
          Image(systemName: "chevron.backward")
            // Flutter's implicit BackButton uses the default IconTheme size
            // of 24 logical pixels. Do not inherit the Apple toolbar font,
            // which makes this protocol-generated icon vary by platform.
            .font(.system(size: RufletLayoutDefaults.appBarBackIconSize))
          if kind == .cupertino, let previous = control.string("previous_page_title"),
            !previous.isEmpty
          {
            Text(previous)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .frame(width: leadingWidth, height: toolbarHeight)
      .accessibilityLabel(Text("Back"))
    }
  }

  private var actions: some View {
    HStack(spacing: 8) {
      if let trailing = control.child("trailing") {
        ControlWidget(control: trailing)
          .fixedSize(horizontal: true, vertical: false)
      } else {
        ForEach(control.children("actions")) { action in
          ControlWidget(control: action)
            // Flutter's NavigationToolbar measures each action at its own
            // width. A Row used as a button label must not consume all toolbar
            // slack and push later actions off screen.
            .fixedSize(horizontal: true, vertical: false)
        }
      }
    }
    .modifier(RufletTextStyleModifier(style: toolbarStyle))
    .padding(actionsPadding)
  }

  @ViewBuilder
  private func background(_ presentation: RufletAppBarPresentation) -> some View {
    if presentation.forceTransparency {
      Color.clear
    } else if kind == .cupertino,
      control.boolean("automatic_background_visibility", default: true),
      !scrolledUnder
    {
      Color.clear
    } else if let backgroundColor = backgroundColor ?? pageBarBackgroundColor {
      backgroundColor
    } else if kind == .cupertino && control.boolean("background_filter_blur", default: true) {
      Rectangle().fill(.bar)
    } else {
      Color.rufletSystemBackground
    }
  }

  @ViewBuilder
  private var borderOverlay: some View {
    if let border {
      RufletBorderOverlay(border: border, radius: shapeRadius)
    } else if kind == .cupertino {
      Rectangle()
        .fill(Color.secondary.opacity(0.28))
        .frame(height: 0.5)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
    if let side = shapeSide {
      barShape.stroke(side.color, lineWidth: side.width)
    }
  }

  private var title: AnyView? {
    guard kind == .appBar || control.boolean("automatically_imply_title", default: true) else {
      return control.buildTextOrWidget("title")
    }
    return control.buildTextOrWidget("title")
  }

  private var toolbarHeight: CGFloat {
    CGFloat(kind == .appBar ? control.number("toolbar_height") ?? 56 : 44)
  }

  private var toolbarOpacity: Double {
    kind == .appBar ? control.number("toolbar_opacity") ?? 1 : 1
  }

  private var centerTitle: Bool {
    if kind == .cupertino { return true }
    #if os(iOS)
      let centersByPlatformDefault = true
    #else
      let centersByPlatformDefault = false
    #endif
    return rufletMaterialAppBarCenterTitle(
      explicit: control.boolean("center_title"),
      themed: parseBool(pageTheme?.componentTheme("appbar_theme")?["center_title"]),
      centersByPlatformDefault: centersByPlatformDefault,
      actionCount: control.children("actions").count)
  }

  private var titleSpacing: CGFloat {
    rufletAppBarTitleSpacing(
      explicit: control.number("title_spacing"),
      themed: parseDouble(pageTheme?.componentTheme("appbar_theme")?["title_spacing"]),
      defaultValue: kind == .appBar ? RufletLayoutDefaults.appBarTitleSpacing : 12)
  }
  private var leadingWidth: CGFloat? {
    control.number("leading_width").map { CGFloat($0) }
      ?? (kind == .appBar ? CGFloat(RufletLayoutDefaults.appBarLeadingWidth) : nil)
  }

  private var actionsPadding: EdgeInsets {
    parsePadding(control.dynamicValue("actions_padding"))
      ?? RufletLayoutDefaults.appBarActions
  }
  private var cupertinoPadding: EdgeInsets {
    parsePadding(control.dynamicValue("padding"))
      ?? RufletLayoutDefaults.cupertinoNavigationBar
  }

  private var foregroundColor: Color? { parseColor(control.string("color")) }
  private var backgroundColor: Color? { parseColor(control.string("bgcolor")) }
  private var shadowColor: Color { parseColor(control.string("shadow_color")) ?? .black }
  private var elevation: Double {
    max(
      scrolledUnder
        ? control.number("elevation_on_scroll") ?? control.number("elevation") ?? 0
        : control.number("elevation") ?? 0, 0)
  }
  private var excludeHeaderSemantics: Bool {
    control.boolean("exclude_header_semantics", default: false)
  }
  private var titleStyle: RufletTextStyle? {
    parseTextStyle(control.dynamicValue("title_text_style"))
  }
  private var resolvedTitleStyle: RufletTextStyle? {
    mergeTextStyles(pageTheme?.textTheme?["title_large"], titleStyle)
  }
  private var toolbarStyle: RufletTextStyle? {
    parseTextStyle(control.dynamicValue("toolbar_text_style"))
  }
  private var isLarge: Bool { kind == .cupertino && control.boolean("large", default: false) }
  private var extendsIntoTop: Bool {
    kind == .cupertino || !control.boolean("secondary", default: false)
  }
  private var border: RufletBorder? { parseBorder(control.dynamicValue("border")) }

  private var view: RufletControl? { control.parentControl }
  private var page: RufletControl? { view?.parentControl }
  private var canNavigateBack: Bool {
    guard let page, let view else { return false }
    return rufletAppBarCanNavigateBack(
      currentViewID: view.id,
      orderedViewIDs: page.children("views").map(\.id))
  }

  private func requestPop() {
    guard let page, let view else { return }
    RufletPagePopRegistry.requestPop(page: page, view: view)
  }

  private var shapeDetails: [String: Any]? { rufletDictionary(control.dynamicValue("shape")) }
  private var shapeRadius: RufletBorderRadius {
    parseBorderRadius(shapeDetails?["radius"], .zero)!
  }
  private var shapeSide: RufletBorderSide? { parseBorderSide(shapeDetails?["side"]) }
  private var barShape: RufletAppBarShape {
    RufletAppBarShape(type: shapeDetails?["_type"] as? String, radius: shapeRadius)
  }
}

/// Mirrors Navigator.canPop using the ordered wire stack instead of Swift
/// object identity. Protocol patches may rebuild the same control ID as a new
/// Swift object, so reference comparisons can leave Back visible on the root.
func rufletAppBarCanNavigateBack(
  currentViewID: Int?,
  orderedViewIDs: [Int]
) -> Bool {
  guard orderedViewIDs.count > 1, let currentViewID else { return false }
  return orderedViewIDs.last == currentViewID
}

func rufletMaterialAppBarCenterTitle(
  explicit: Bool?,
  themed: Bool?,
  centersByPlatformDefault: Bool,
  actionCount: Int
) -> Bool {
  explicit ?? themed ?? (centersByPlatformDefault && actionCount < 2)
}

func rufletAppBarTitleSpacing(
  explicit: Double?, themed: Double?, defaultValue: Double = RufletLayoutDefaults.appBarTitleSpacing
) -> CGFloat {
  CGFloat(explicit ?? themed ?? defaultValue)
}

private struct RufletAppBarTitleTextModifier: ViewModifier {
  let style: RufletTextStyle?
  let nestedControl: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if nestedControl {
      content
    } else {
      content.modifier(RufletTextStyleModifier(style: style))
    }
  }
}

@MainActor
struct RufletAppBarPresentation {
  let clipBehavior: String
  let forceTransparency: Bool

  init(control: RufletControl, isMaterial: Bool = true) {
    clipBehavior = control.string("clip_behavior", default: "none")!.lowercased()
    let forced = control.boolean("force_material_transparency", default: false)
    forceTransparency = isMaterial && forced
  }

  var clipsContent: Bool { clipBehavior != "none" }
  var antialiasedClip: Bool { clipBehavior.contains("antialias") }
}

private struct RufletViewScrolledUnderKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  var rufletViewScrolledUnder: Bool {
    get { self[RufletViewScrolledUnderKey.self] }
    set { self[RufletViewScrolledUnderKey.self] = newValue }
  }
}

private struct RufletHeaderSemantics: ViewModifier {
  let excluded: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if excluded { content } else { content.accessibilityAddTraits(.isHeader) }
  }
}

private struct RufletBarBrightnessModifier: ViewModifier {
  let value: String?

  @ViewBuilder
  func body(content: Content) -> some View {
    switch value?.lowercased() {
    case "light": content.environment(\.colorScheme, .light)
    case "dark": content.environment(\.colorScheme, .dark)
    default: content
    }
  }
}

private struct RufletAppBarClipModifier: ViewModifier {
  let shape: RufletAppBarShape
  let presentation: RufletAppBarPresentation

  @ViewBuilder
  func body(content: Content) -> some View {
    if presentation.clipsContent {
      content.clipShape(shape, style: FillStyle(antialiased: presentation.antialiasedClip))
    } else {
      content
    }
  }
}

private struct RufletAppBarShape: Shape {
  let type: String?
  let radius: RufletBorderRadius

  func path(in rect: CGRect) -> Path {
    switch type?.lowercased() {
    case "stadium": return Capsule().path(in: rect)
    case "circle": return Circle().path(in: rect)
    case "beveledrectangle":
      let amount = min(radius.topLeft, min(rect.width, rect.height) / 2)
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
    default:
      return RufletCornerShape(radius: radius).path(in: rect)
    }
  }
}
