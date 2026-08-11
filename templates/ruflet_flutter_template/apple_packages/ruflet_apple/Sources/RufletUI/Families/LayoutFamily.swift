import RufletEngine
import RufletProtocol
import SwiftUI

extension ControlRegistry {
  /// Structure: the containers, spacers and wrappers that arrange other
  /// controls rather than drawing anything themselves.
  static func layout(_ node: ControlNode, _ axis: LayoutAxis) -> AnyView? {
    switch node.type {
    case "Page":
      return AnyView(PageControlView(node: node))
    case "View", "BasePage":
      return AnyView(ViewControlView(node: node))
    case "Row":
      return AnyView(RowControlView(node: node))
    case "Column":
      return AnyView(ColumnControlView(node: node))
    case "ResponsiveRow":
      return AnyView(ResponsiveRowControlView(node: node))
    case "Stack":
      return AnyView(StackControlView(node: node))
    case "Container":
      return AnyView(ContainerControlView(node: node, axis: axis))
    case "Card":
      return AnyView(CardControlView(node: node))
    case "SafeArea":
      return AnyView(SafeAreaControlView(node: node))
    case "Divider":
      return AnyView(DividerControlView(node: node, isVertical: false))
    case "VerticalDivider":
      return AnyView(DividerControlView(node: node, isVertical: true))
    case "Placeholder":
      return AnyView(PlaceholderControlView(node: node))
    case "RotatedBox":
      return AnyView(RotatedBoxControlView(node: node))
    case "Pagelet":
      return AnyView(PageletControlView(node: node))
    case "AnimatedSwitcher":
      return AnyView(AnimatedSwitcherControlView(node: node))
    case "RufletApp":
      return AnyView(RufletAppControlView(node: node))
    case "Hero":
      return AnyView(HeroControlView(node: node))
    case "Semantics":
      return AnyView(SemanticsControlView(node: node))
    case "MergeSemantics":
      return AnyView(MergeSemanticsControlView(node: node))
    case "SelectionArea":
      return AnyView(SelectionAreaControlView(node: node))
    case "TransparentPointer":
      return AnyView(TransparentPointerControlView(node: node))
    case "Shimmer":
      return AnyView(ShimmerControlView(node: node))
    case "ShaderMask":
      return AnyView(ShaderMaskControlView(node: node))
    case "Screenshot":
      return AnyView(ScreenshotControlView(node: node))
    case "WindowDragArea":
      return AnyView(WindowDragAreaControlView(node: node))
    case "AutofillGroup", "BrowserContextMenu":
      // Autofill is managed by the platform and the browser context menu is
      // web-only; both simply render their content here.
      return AnyView(InertWrapperControlView(node: node))
    case "Overlay", "Dialogs", "ServiceRegistry", "Window":
      // Not part of the visible tree: overlays and dialogs are presented by the
      // view that owns them, services have no body, and the window is handled
      // by the app shell.
      return AnyView(EmptyView())
    default:
      return nil
    }
  }
}
