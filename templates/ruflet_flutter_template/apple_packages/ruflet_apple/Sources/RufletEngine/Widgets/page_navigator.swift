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
  @Environment(\.rufletSafeAreaInsets) private var safeAreaInsets
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
      safeAreaInsets: safeAreaInsets,
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
  let safeAreaInsets: RufletSafeAreaInsets
  let heroNamespace: Namespace.ID?
  let heroTransitionState: RufletHeroTransitionState

  var body: some View {
    PageContext(themeMode: themeMode, theme: theme, design: design) {
      ControlWidget(control: control)
        .environment(\.rufletTopViewID, topViewID)
        .environment(\.rufletSafeAreaInsets, safeAreaInsets)
    }
    .environment(\.locale, locale)
    .environment(\.layoutDirection, layoutDirection)
    .environmentObject(backend)
    .environmentObject(backend.extensionRegistry)
    .modifier(RufletHostedPageTint(color: tint))
    .environment(\.rufletHeroNamespace, heroNamespace)
    .environmentObject(heroTransitionState)
    // Apply the full-viewport contract at the hosting root, before SwiftUI
    // proposes a safe-area-reduced width to the route's View/ScrollView tree.
    // Physical insets remain available through `rufletSafeAreaInsets` for
    // explicit SafeArea, app bar, and bottom bar controls.
    .ignoresSafeArea(.container)
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

enum RufletPageNavigationUpdateDisposition: Equatable {
  case activate
  case stage
}

func rufletPageNavigationUpdateDisposition(
  for identity: RufletPageNavigationIdentity,
  topIdentity: RufletPageNavigationIdentity?
) -> RufletPageNavigationUpdateDisposition {
  identity == topIdentity ? .activate : .stage
}

/// Interaction ownership for a native route stack.
///
/// UIKit normally keeps covered view controllers out of hit testing, but a
/// queued burst of pointer events can overlap an interactive navigation
/// transition. SwiftUI gesture recognizers hosted by the covered controller
/// may then receive a late tap. Keep the invariant explicit: only the
/// controller UIKit has actually shown is interactive.
func rufletPageNavigationInteractionStates(
  count: Int,
  activeIndex: Int?
) -> [Bool] {
  guard count > 0 else { return [] }
  guard let activeIndex, (0..<count).contains(activeIndex) else {
    return Array(repeating: false, count: count)
  }
  return (0..<count).map { $0 == activeIndex }
}

/// Reports a native route removal only when it was initiated by UIKit's
/// interactive-pop recognizer. A representable rebuild or programmatic stack
/// reconciliation can also produce `didShow` callbacks with a temporarily
/// shorter controller array; those callbacks are renderer bookkeeping, not
/// user intent, and must never become Flet `view_pop` events.
func rufletShouldReportNativeViewRemoval(
  interactivePopStarted: Bool,
  synchronizing: Bool,
  expected: [RufletPageNavigationIdentity],
  actual: [RufletPageNavigationIdentity]
) -> Bool {
  interactivePopStarted && !synchronizing && actual != expected
    && expected.starts(with: actual)
}

/// Geometry for the pinned Flet route transition.
///
/// Flutter's iOS page transition moves the new route across a flat,
/// full-screen surface while the covered route shifts by one third of the
/// width. UIKit's latest default navigation transition instead rounds and
/// scales the route like a card. Keep the protocol renderer independent of
/// that changing UIKit default so the same Flet `Page.views` mutation retains
/// Flet's route geometry on every iOS release.
enum RufletPageTransitionOperation: Equatable {
  case push
  case pop
}

enum RufletPageTransitionStyle: Equatable {
  case standard
  case fullscreenDialog
}

struct RufletPageTransitionOffsets: Equatable {
  let fromStart: CGSize
  let fromEnd: CGSize
  let toStart: CGSize
  let toEnd: CGSize
}

let rufletPageTransitionDuration: TimeInterval = 0.3

func rufletPageTransitionOffsets(
  operation: RufletPageTransitionOperation,
  style: RufletPageTransitionStyle,
  width: CGFloat,
  height: CGFloat,
  rightToLeft: Bool
) -> RufletPageTransitionOffsets {
  if style == .fullscreenDialog {
    switch operation {
    case .push:
      return RufletPageTransitionOffsets(
        fromStart: .zero,
        fromEnd: .zero,
        toStart: CGSize(width: 0, height: height),
        toEnd: .zero)
    case .pop:
      return RufletPageTransitionOffsets(
        fromStart: .zero,
        fromEnd: CGSize(width: 0, height: height),
        toStart: .zero,
        toEnd: .zero)
    }
  }

  let direction: CGFloat = rightToLeft ? -1 : 1
  switch operation {
  case .push:
    return RufletPageTransitionOffsets(
      fromStart: .zero,
      fromEnd: CGSize(width: -direction * width / 3, height: 0),
      toStart: CGSize(width: direction * width, height: 0),
      toEnd: .zero)
  case .pop:
    return RufletPageTransitionOffsets(
      fromStart: .zero,
      fromEnd: CGSize(width: direction * width, height: 0),
      toStart: CGSize(width: -direction * width / 3, height: 0),
      toEnd: .zero)
  }
}

#if os(iOS)
  @MainActor
  private final class RufletFletPageTransitionAnimator: NSObject,
    UIViewControllerAnimatedTransitioning
  {
    let operation: RufletPageTransitionOperation
    let style: RufletPageTransitionStyle
    let rightToLeft: Bool
    private var animator: UIViewPropertyAnimator?

    init(
      operation: RufletPageTransitionOperation,
      style: RufletPageTransitionStyle,
      rightToLeft: Bool
    ) {
      self.operation = operation
      self.style = style
      self.rightToLeft = rightToLeft
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
      rufletPageTransitionDuration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
      interruptibleAnimator(using: transitionContext).startAnimation()
    }

    func interruptibleAnimator(
      using transitionContext: UIViewControllerContextTransitioning
    ) -> UIViewImplicitlyAnimating {
      if let animator { return animator }
      guard
        let fromViewController = transitionContext.viewController(forKey: .from),
        let toViewController = transitionContext.viewController(forKey: .to),
        let fromView = transitionContext.view(forKey: .from) ?? fromViewController.view,
        let toView = transitionContext.view(forKey: .to) ?? toViewController.view
      else {
        let empty = UIViewPropertyAnimator(duration: 0, curve: .linear)
        empty.addCompletion { _ in transitionContext.completeTransition(false) }
        animator = empty
        return empty
      }

      let container = transitionContext.containerView
      let bounds = container.bounds
      let finalToFrame = transitionContext.finalFrame(for: toViewController)
      toView.frame = finalToFrame.isEmpty ? bounds : finalToFrame
      if fromView.frame.isEmpty { fromView.frame = bounds }

      // Route views are always rectangular protocol surfaces. In particular,
      // never inherit the rounded-card mask introduced by newer UIKit's
      // default UINavigationController animator.
      for routeView in [fromView, toView] {
        routeView.layer.cornerRadius = 0
        routeView.layer.mask = nil
        routeView.clipsToBounds = false
      }

      switch operation {
      case .push:
        container.addSubview(toView)
      case .pop:
        container.insertSubview(toView, belowSubview: fromView)
      }

      let offsets = rufletPageTransitionOffsets(
        operation: operation,
        style: style,
        width: max(bounds.width, 1),
        height: max(bounds.height, 1),
        rightToLeft: rightToLeft)
      fromView.transform = CGAffineTransform(
        translationX: offsets.fromStart.width,
        y: offsets.fromStart.height)
      toView.transform = CGAffineTransform(
        translationX: offsets.toStart.width,
        y: offsets.toStart.height)

      let foregroundView = operation == .push ? toView : fromView
      let edgeShadow = makeEdgeShadow(
        for: foregroundView,
        rightToLeft: rightToLeft,
        visible: style == .standard)

      let propertyAnimator = UIViewPropertyAnimator(
        duration: transitionDuration(using: transitionContext),
        curve: .easeInOut)
      propertyAnimator.addAnimations {
        fromView.transform = CGAffineTransform(
          translationX: offsets.fromEnd.width,
          y: offsets.fromEnd.height)
        toView.transform = CGAffineTransform(
          translationX: offsets.toEnd.width,
          y: offsets.toEnd.height)
      }
      propertyAnimator.addCompletion { [weak self] _ in
        let completed = !transitionContext.transitionWasCancelled
        fromView.transform = .identity
        toView.transform = .identity
        edgeShadow?.removeFromSuperview()
        transitionContext.completeTransition(completed)
        self?.animator = nil
      }
      animator = propertyAnimator
      return propertyAnimator
    }

    private func makeEdgeShadow(
      for foregroundView: UIView,
      rightToLeft: Bool,
      visible: Bool
    ) -> UIView? {
      guard visible else { return nil }
      let shadow = UIView(
        frame: CGRect(
          x: rightToLeft ? max(foregroundView.bounds.width - 1, 0) : 0,
          y: 0,
          width: 1,
          height: foregroundView.bounds.height))
      shadow.isUserInteractionEnabled = false
      shadow.backgroundColor = UIColor.black.withAlphaComponent(0.12)
      shadow.layer.shadowColor = UIColor.black.cgColor
      shadow.layer.shadowOpacity = 0.22
      shadow.layer.shadowRadius = 5
      shadow.layer.shadowOffset = CGSize(width: rightToLeft ? -3 : 3, height: 0)
      shadow.autoresizingMask = [
        .flexibleHeight, rightToLeft ? .flexibleLeftMargin : .flexibleRightMargin,
      ]
      foregroundView.addSubview(shadow)
      return shadow
    }
  }

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
    let safeAreaInsets: RufletSafeAreaInsets
    let heroNamespace: Namespace.ID?
    let heroTransitionState: RufletHeroTransitionState
    let onRequestPop: (RufletControl) -> Void
    let onDidRemove: (RufletControl) -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
      let navigationController = UINavigationController()
      navigationController.view.backgroundColor = .clear
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
      private var interactivePopStarted = false

      init(parent: RufletNativePageNavigator) {
        self.parent = parent
      }

      func synchronize(with parent: RufletNativePageNavigator, animated: Bool) {
        let started = RufletProtocolDiagnostics.now()
        self.parent = parent
        guard let navigationController,
          let backend = parent.page.backend as? RufletBackend
        else { return }
        navigationController.view.backgroundColor = UIColor(
          parent.views.last.flatMap { parseColor($0.string("bgcolor")) }
            ?? parent.theme.applePageBackgroundColor!)

        let currentControllers = navigationController.viewControllers.compactMap {
          $0 as? RufletHostingController
        }
        let currentIdentities = identities(for: currentControllers.map(\.control))
        let mountedControllers = Dictionary(
          uniqueKeysWithValues: zip(currentIdentities, currentControllers))
        let requestedIdentities = identities(for: parent.views)
        let topIdentity = requestedIdentities.last
        let topViewID = parent.views.last?.id
        var activated = 0
        var staged = 0
        var created = 0
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
              safeAreaInsets: parent.safeAreaInsets,
              heroNamespace: parent.heroNamespace,
              heroTransitionState: parent.heroTransitionState))
          if let controller = mountedControllers[identity] ?? controllers[identity] {
            switch rufletPageNavigationUpdateDisposition(
              for: identity, topIdentity: topIdentity)
            {
            case .activate:
              controller.activate(control: control, rootView: root)
              activated += 1
            case .stage:
              // Keep hidden routes current without asking SwiftUI to lay out
              // every off-screen tree for each Flet patch. The staged root is
              // activated in `willShow`, before a native pop reveals it.
              controller.stage(control: control, rootView: root)
              staged += 1
            }
            return controller
          }
          let controller = RufletHostingController(control: control, rootView: root)
          created += 1
          return controller
        }

        expectedIdentities = requestedIdentities
        controllers = Dictionary(
          uniqueKeysWithValues: zip(requestedIdentities, requestedControllers))
        var interactionControllers = currentControllers
        interactionControllers.append(
          contentsOf: requestedControllers.filter { requested in
            !currentControllers.contains { $0 === requested }
          })
        setInteractiveController(
          requestedControllers.last,
          among: interactionControllers)
        guard currentIdentities != requestedIdentities else {
          reportSynchronization(
            started: started,
            views: requestedIdentities.count,
            activated: activated,
            staged: staged,
            created: created)
          return
        }

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
          // Build the destination's first native frame before UIKit starts
          // the push. Large Ruby-driven views (notably the code editor) then
          // animate a ready surface instead of laying out during the gesture.
          last.prepareForNavigation()
          push(last, animated: animated)
        } else if isPop {
          // UIKit captures the destination controller at the start of an
          // animated pop. Flush the newly activated SwiftUI root first so the
          // transition cannot reveal the previously staged (or blank) frame.
          // Only the destination is laid out; deeper hidden routes stay staged.
          requestedControllers.last?.prepareForNavigation()
          navigationController.setViewControllers(requestedControllers, animated: animated)
        } else {
          navigationController.setViewControllers(
            requestedControllers, animated: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
          self?.synchronizing = false
        }
        reportSynchronization(
          started: started,
          views: requestedIdentities.count,
          activated: activated,
          staged: staged,
          created: created)
      }

      private func reportSynchronization(
        started: TimeInterval,
        views: Int,
        activated: Int,
        staged: Int,
        created: Int
      ) {
        RufletProtocolDiagnostics.timing(
          "ios_navigator_sync",
          milliseconds: (RufletProtocolDiagnostics.now() - started) * 1_000,
          details:
            "views=\(views) activated=\(activated) staged=\(staged) created=\(created)")
      }

      private func push(
        _ controller: RufletHostingController,
        animated: Bool
      ) {
        guard let navigationController else { return }
        navigationController.pushViewController(controller, animated: animated)
      }

      func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromViewController: UIViewController,
        to toViewController: UIViewController
      ) -> UIViewControllerAnimatedTransitioning? {
        let transitionOperation: RufletPageTransitionOperation
        let fullscreenControl: RufletControl?
        switch operation {
        case .push:
          transitionOperation = .push
          fullscreenControl = (toViewController as? RufletHostingController)?.control
        case .pop:
          transitionOperation = .pop
          fullscreenControl = (fromViewController as? RufletHostingController)?.control
        case .none:
          return nil
        @unknown default:
          return nil
        }
        let style: RufletPageTransitionStyle =
          fullscreenControl?.boolean("fullscreen_dialog", default: false) == true
          ? .fullscreenDialog : .standard
        return RufletFletPageTransitionAnimator(
          operation: transitionOperation,
          style: style,
          rightToLeft: parent.layoutDirection == .rightToLeft)
      }

      func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
      ) {
        (viewController as? RufletHostingController)?.activateStagedRoot()
      }

      func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
      ) {
        let hostedControllers = navigationController.viewControllers.compactMap {
          $0 as? RufletHostingController
        }
        setInteractiveController(
          viewController as? RufletHostingController,
          among: hostedControllers)
        let actualControls = navigationController.viewControllers.compactMap {
          ($0 as? RufletHostingController)?.control
        }
        let actualIdentities = identities(for: actualControls)
        let shouldReportRemoval = rufletShouldReportNativeViewRemoval(
          interactivePopStarted: interactivePopStarted,
          synchronizing: synchronizing,
          expected: expectedIdentities,
          actual: actualIdentities)
        interactivePopStarted = false
        guard shouldReportRemoval,
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

      private func setInteractiveController(
        _ activeController: RufletHostingController?,
        among controllers: [RufletHostingController]
      ) {
        let activeIndex = controllers.firstIndex { $0 === activeController }
        let states = rufletPageNavigationInteractionStates(
          count: controllers.count,
          activeIndex: activeIndex)
        for (controller, isInteractive) in zip(controllers, states) {
          if isInteractive {
            controller.view.isUserInteractionEnabled = true
          } else {
            controller.viewIfLoaded?.isUserInteractionEnabled = false
          }
        }
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
        case .began:
          interactivePopStarted = true
          parent.heroTransitionState.updateInteractiveNavigation(true)
        case .changed:
          parent.heroTransitionState.updateInteractiveNavigation(true)
        case .ended:
          parent.heroTransitionState.updateInteractiveNavigation(false)
        case .cancelled, .failed:
          interactivePopStarted = false
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
    private var stagedControl: RufletControl?
    private var stagedRootView: AnyView?

    init(control: RufletControl, rootView: AnyView) {
      self.control = control
      super.init(rootView: rootView)
      if #available(iOS 16.4, *) {
        // The nested route controller must expose its complete viewport to the
        // Flet View. Physical insets are already carried through
        // `rufletSafeAreaInsets` and consumed by bars/SafeArea controls when
        // Ruby asks for them. Letting UIHostingController apply the same
        // system insets again narrows and leading-aligns the entire route.
        safeAreaRegions = []
      }
    }

    func activate(control: RufletControl, rootView: AnyView) {
      stagedControl = nil
      stagedRootView = nil
      self.control = control
      self.rootView = rootView
    }

    func stage(control: RufletControl, rootView: AnyView) {
      stagedControl = control
      stagedRootView = rootView
    }

    func activateStagedRoot() {
      guard let stagedControl, let stagedRootView else { return }
      activate(control: stagedControl, rootView: stagedRootView)
    }

    func prepareForNavigation() {
      loadViewIfNeeded()
      view.setNeedsLayout()
      view.layoutIfNeeded()
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
    let safeAreaInsets: RufletSafeAreaInsets
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
            safeAreaInsets: safeAreaInsets,
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

    func synchronize(control nextControl: RufletControl?, rootView: AnyView?, index nextIndex: Int)
    {
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
