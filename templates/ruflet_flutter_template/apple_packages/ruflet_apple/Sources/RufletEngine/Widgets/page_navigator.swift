import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

/// Apple navigation host for the ordered Flet `Page.views` collection.
///
/// Page mutation remains owned by the Flet protocol. The platform navigator
/// owns transitions, interactive back gestures, and native view-controller
/// lifetime, then reports a native removal back to `PageControl`.
@MainActor
struct RufletPageNavigator: View {
  @ObservedObject var page: RufletControl
  let views: [RufletControl]
  let locale: Locale
  let layoutDirection: LayoutDirection
  let themeMode: RufletThemeMode
  let theme: RufletTheme
  let design: RufletPageDesign
  let tint: Color?
  let onRequestPop: (RufletControl) -> Void
  let onDidRemove: (RufletControl) -> Void
  @Environment(\.rufletHeroNamespace) private var heroNamespace
  @EnvironmentObject private var heroTransitionState: RufletHeroTransitionState

  var body: some View {
    RufletNativePageNavigator(
      page: page,
      views: views,
      locale: locale,
      layoutDirection: layoutDirection,
      themeMode: themeMode,
      theme: theme,
      design: design,
      tint: tint,
      heroNamespace: heroNamespace,
      heroTransitionState: heroTransitionState,
      onRequestPop: onRequestPop,
      onDidRemove: onDidRemove)
  }
}

@MainActor
private struct RufletHostedPage: View {
  @ObservedObject var control: RufletControl
  @ObservedObject var backend: RufletBackend
  let topViewID: Int?
  let locale: Locale
  let layoutDirection: LayoutDirection
  let themeMode: RufletThemeMode
  let theme: RufletTheme
  let design: RufletPageDesign
  let tint: Color?
  let heroNamespace: Namespace.ID?
  let heroTransitionState: RufletHeroTransitionState

  var body: some View {
    PageContext(themeMode: themeMode, theme: theme, design: design) {
      ControlWidget(control: control)
        .environment(\.rufletTopViewID, topViewID)
    }
    .environment(\.locale, locale)
    .environment(\.layoutDirection, layoutDirection)
    .environmentObject(backend)
    .environmentObject(backend.extensionRegistry)
    .modifier(RufletHostedPageTint(color: tint))
    .environment(\.rufletHeroNamespace, heroNamespace)
    .environmentObject(heroTransitionState)
  }
}

private struct RufletHostedPageTint: ViewModifier {
  let color: Color?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let color { content.tint(color) } else { content }
  }
}

/// Stable identity for one position in Flet's `Page.views` route stack.
///
/// Ruflet applications can rebuild the same logical views with fresh wire
/// control IDs on every route update. UIKit navigation identity follows the
/// route stack instead, matching Flet's Navigator semantics and allowing an
/// ordinary back update to reuse the already-rendered destination controller.
struct RufletPageNavigationIdentity: Hashable, Equatable {
  let route: String
  let occurrence: Int
}

func rufletPageNavigationIdentities(_ routes: [String]) -> [RufletPageNavigationIdentity] {
  var occurrences: [String: Int] = [:]
  return routes.map { route in
    let occurrence = occurrences[route, default: 0]
    occurrences[route] = occurrence + 1
    return RufletPageNavigationIdentity(route: route, occurrence: occurrence)
  }
}

#if os(iOS)
  @MainActor
  private struct RufletNativePageNavigator: UIViewControllerRepresentable {
    let page: RufletControl
    let views: [RufletControl]
    let locale: Locale
    let layoutDirection: LayoutDirection
    let themeMode: RufletThemeMode
    let theme: RufletTheme
    let design: RufletPageDesign
    let tint: Color?
    let heroNamespace: Namespace.ID?
    let heroTransitionState: RufletHeroTransitionState
    let onRequestPop: (RufletControl) -> Void
    let onDidRemove: (RufletControl) -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
      let navigationController = UINavigationController()
      navigationController.view.backgroundColor = .systemBackground
      navigationController.setNavigationBarHidden(true, animated: false)
      navigationController.delegate = context.coordinator
      navigationController.interactivePopGestureRecognizer?.delegate = context.coordinator
      navigationController.interactivePopGestureRecognizer?.addTarget(
        context.coordinator,
        action: #selector(Coordinator.interactivePopChanged(_:)))
      context.coordinator.navigationController = navigationController
      context.coordinator.synchronize(with: self, animated: false)
      return navigationController
    }

    func updateUIViewController(_ navigationController: UINavigationController, context: Context) {
      context.coordinator.navigationController = navigationController
      context.coordinator.synchronize(with: self, animated: true)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIGestureRecognizerDelegate {
      var parent: RufletNativePageNavigator
      weak var navigationController: UINavigationController?
      private var controllers: [RufletPageNavigationIdentity: RufletHostingController] = [:]
      private var expectedIdentities: [RufletPageNavigationIdentity] = []
      private var synchronizing = false

      init(parent: RufletNativePageNavigator) {
        self.parent = parent
      }

      func synchronize(with parent: RufletNativePageNavigator, animated: Bool) {
        self.parent = parent
        guard let navigationController,
          let backend = parent.page.backend as? RufletBackend
        else { return }

        let currentControllers = navigationController.viewControllers.compactMap {
          $0 as? RufletHostingController
        }
        let currentIdentities = identities(for: currentControllers.map(\.control))
        let mountedControllers = Dictionary(
          uniqueKeysWithValues: zip(currentIdentities, currentControllers))
        let requestedIdentities = identities(for: parent.views)
        let topViewID = parent.views.last?.id
        let requestedControllers = zip(requestedIdentities, parent.views).map { identity, control in
          let root = AnyView(
            RufletHostedPage(
              control: control,
              backend: backend,
              topViewID: topViewID,
              locale: parent.locale,
              layoutDirection: parent.layoutDirection,
              themeMode: parent.themeMode,
              theme: parent.theme,
              design: parent.design,
              tint: parent.tint,
              heroNamespace: parent.heroNamespace,
              heroTransitionState: parent.heroTransitionState))
          if let controller = mountedControllers[identity] ?? controllers[identity] {
            controller.rootView = root
            controller.control = control
            return controller
          }
          let controller = RufletHostingController(control: control, rootView: root)
          return controller
        }

        expectedIdentities = requestedIdentities
        controllers = Dictionary(uniqueKeysWithValues: zip(requestedIdentities, requestedControllers))
        guard currentIdentities != requestedIdentities else { return }

        synchronizing = true
        let isPush =
          currentIdentities.count < requestedIdentities.count
          && requestedIdentities.starts(with: currentIdentities)
        let isPop =
          requestedIdentities.count < currentIdentities.count
          && currentIdentities.starts(with: requestedIdentities)

        if isPush, let last = requestedControllers.last {
          let preceding = Array(requestedControllers.dropLast())
          if navigationController.viewControllers.map({
            ($0 as? RufletHostingController)?.control.id
          })
            != preceding.map({ Optional($0.control.id) })
          {
            navigationController.setViewControllers(preceding, animated: false)
          }
          push(
            last, animated: animated,
            fullscreen: last.control.boolean("fullscreen_dialog", default: false))
        } else if isPop {
          navigationController.setViewControllers(requestedControllers, animated: animated)
        } else {
          navigationController.setViewControllers(
            requestedControllers, animated: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
          self?.synchronizing = false
        }
      }

      private func push(
        _ controller: RufletHostingController,
        animated: Bool,
        fullscreen: Bool
      ) {
        guard let navigationController else { return }
        if fullscreen && animated {
          let transition = CATransition()
          transition.duration = 0.35
          transition.type = .moveIn
          transition.subtype = .fromBottom
          transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
          navigationController.view.layer.add(transition, forKey: "ruflet_fullscreen_dialog")
          navigationController.pushViewController(controller, animated: false)
        } else {
          navigationController.pushViewController(controller, animated: animated)
        }
      }

      func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
      ) {
        guard !synchronizing else { return }
        let actualControls = navigationController.viewControllers.compactMap {
          ($0 as? RufletHostingController)?.control
        }
        let actualIdentities = identities(for: actualControls)
        guard actualIdentities != expectedIdentities,
          expectedIdentities.starts(with: actualIdentities),
          let removedIdentity = expectedIdentities.dropFirst(actualIdentities.count).first,
          let removedIndex = expectedIdentities.firstIndex(of: removedIdentity),
          parent.views.indices.contains(removedIndex)
        else { return }
        parent.onDidRemove(parent.views[removedIndex])
      }

      private func identities(for controls: [RufletControl]) -> [RufletPageNavigationIdentity] {
        rufletPageNavigationIdentities(
          controls.map { $0.string("route", default: "")! })
      }

      func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationController,
          navigationController.viewControllers.count > 1,
          let top = parent.views.last
        else { return false }
        if top.boolean("can_pop", default: true) { return true }
        guard top.boolean("on_confirm_pop", default: false) else { return false }
        Task { @MainActor [weak self] in
          guard let self, await RufletViewPopRegistry.confirmPop(control: top) else { return }
          self.parent.onRequestPop(top)
        }
        return false
      }

      @objc func interactivePopChanged(_ gestureRecognizer: UIGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began, .changed:
          parent.heroTransitionState.updateInteractiveNavigation(true)
        case .ended, .cancelled, .failed:
          parent.heroTransitionState.updateInteractiveNavigation(false)
        default:
          break
        }
      }
    }
  }

  @MainActor
  private final class RufletHostingController: UIHostingController<AnyView> {
    var control: RufletControl

    init(control: RufletControl, rootView: AnyView) {
      self.control = control
      super.init(rootView: rootView)
    }

    @available(*, unavailable)
    @MainActor dynamic required init?(coder _: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }
#elseif os(macOS)
  @MainActor
  private struct RufletNativePageNavigator: NSViewControllerRepresentable {
    let page: RufletControl
    let views: [RufletControl]
    let locale: Locale
    let layoutDirection: LayoutDirection
    let themeMode: RufletThemeMode
    let theme: RufletTheme
    let design: RufletPageDesign
    let tint: Color?
    let heroNamespace: Namespace.ID?
    let heroTransitionState: RufletHeroTransitionState
    let onRequestPop: (RufletControl) -> Void
    let onDidRemove: (RufletControl) -> Void

    func makeNSViewController(context _: Context) -> RufletPageContainerController {
      RufletPageContainerController()
    }

    func updateNSViewController(
      _ container: RufletPageContainerController,
      context _: Context
    ) {
      let started = RufletProtocolDiagnostics.now()
      guard let backend = page.backend as? RufletBackend else { return }
      let topViewID = views.last?.id
      let topControl = views.last
      let root = topControl.map { control in
        AnyView(
          RufletHostedPage(
            control: control,
            backend: backend,
            topViewID: topViewID,
            locale: locale,
            layoutDirection: layoutDirection,
            themeMode: themeMode,
            theme: theme,
            design: design,
            tint: tint,
            heroNamespace: heroNamespace,
            heroTransitionState: heroTransitionState))
      }
      container.synchronize(control: topControl, rootView: root, index: views.count - 1)
      RufletProtocolDiagnostics.timing(
        "macos_navigator_sync",
        milliseconds: (RufletProtocolDiagnostics.now() - started) * 1_000,
        details: "views=\(views.count)")
    }
  }

  @MainActor
  private final class RufletMacHostingController: NSHostingController<AnyView>, @unchecked Sendable
  {
    var control: RufletControl

    init(control: RufletControl, rootView: AnyView) {
      self.control = control
      super.init(rootView: rootView)
    }

    @available(*, unavailable)
    @MainActor dynamic required init?(coder _: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }

  @MainActor
  private final class RufletPageContainerController: NSViewController {
    private var current: RufletMacHostingController?
    private var currentIndex = -1

    override func loadView() {
      view = NSView()
    }

    func synchronize(control nextControl: RufletControl?, rootView: AnyView?, index nextIndex: Int) {
      guard let nextControl, let rootView else {
        current?.view.removeFromSuperview()
        current?.removeFromParent()
        current = nil
        currentIndex = -1
        return
      }
      if let current {
        // AppKit only hosts Page.views.last; Page mutation and back behavior
        // remain protocol-owned. Reuse the single NSHostingController so a
        // route push does not synchronously instantiate and measure the whole
        // incoming control tree before AppKit can return to the event loop.
        current.control = nextControl
        current.rootView = rootView
        currentIndex = nextIndex
        return
      }

      let next = RufletMacHostingController(control: nextControl, rootView: rootView)
      addChild(next)
      next.view.frame = view.bounds
      next.view.autoresizingMask = [.width, .height]
      view.addSubview(next.view)
      current = next
      currentIndex = nextIndex
    }
  }
#endif
