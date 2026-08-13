import RufletProtocol
import SwiftUI

/// Apple-native port of pinned Flet `page_view.dart`.
@MainActor
public struct PageViewControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var coordinator: RufletPageViewCoordinator
  @GestureState private var dragTranslation: CGFloat = 0

  public init(control: RufletControl) {
    self.control = control
    _coordinator = StateObject(
      wrappedValue: RufletPageViewCoordinator(
        selectedIndex: control.integer("selected_index", default: 0) ?? 0))
  }

  public var body: some View {
    let configuration = RufletPageViewConfiguration(control: control)

    LayoutControl(control: control) {
      GeometryReader { proxy in
        pages(in: proxy.size, configuration: configuration)
      }
    }
    .onAppear {
      coordinator.mount(
        control: control,
        pageCount: pageControls.count,
        configuration: configuration)
    }
    .onDisappear(perform: coordinator.unmount)
    .onChange(of: control.properties) { _ in
      coordinator.synchronize(
        pageCount: pageControls.count,
        configuration: RufletPageViewConfiguration(control: control))
    }
  }

  private func pages(
    in size: CGSize,
    configuration: RufletPageViewConfiguration
  ) -> some View {
    let availableLength = configuration.horizontal ? size.width : size.height
    let pageLength = max(availableLength * configuration.viewportFraction, 1)
    let leadingInset = configuration.padEnds ? (availableLength - pageLength) / 2 : 0
    let direction: CGFloat = configuration.reverse ? -1 : 1

    return ZStack(alignment: configuration.horizontal ? .leading : .top) {
      ForEach(Array(pageControls.enumerated()), id: \.element.id) { index, child in
        ControlWidget(control: child)
          .frame(
            width: configuration.horizontal ? pageLength : size.width,
            height: configuration.horizontal ? size.height : pageLength
          )
          .offset(
            x: configuration.horizontal
              ? (CGFloat(index) - coordinator.continuousPage) * pageLength * direction
                + dragTranslation + leadingInset
              : 0,
            y: configuration.horizontal
              ? 0
              : (CGFloat(index) - coordinator.continuousPage) * pageLength * direction
                + dragTranslation + leadingInset
          )
          // Flutter's allowImplicitScrolling=false prevents off-screen pages
          // from responding to accessibility show-on-screen requests.
          .accessibilityHidden(
            !configuration.implicitScrolling && index != coordinator.selectedIndex)
      }
    }
    .contentShape(Rectangle())
    .gesture(
      dragGesture(
        pageLength: pageLength,
        direction: direction,
        configuration: configuration))
    .modifier(RufletPageViewClipModifier(behavior: configuration.clipBehavior))
    .onAppear { coordinator.setPageLength(pageLength) }
    .onChange(of: pageLength) { coordinator.setPageLength($0) }
  }

  private func dragGesture(
    pageLength: CGFloat,
    direction: CGFloat,
    configuration: RufletPageViewConfiguration
  ) -> some Gesture {
    DragGesture(minimumDistance: control.disabled ? .greatestFiniteMagnitude : 10)
      .updating($dragTranslation) { value, state, _ in
        state = configuration.horizontal ? value.translation.width : value.translation.height
      }
      .onEnded { value in
        coordinator.endDrag(
          translation: configuration.horizontal
            ? value.translation.width : value.translation.height,
          predictedTranslation: configuration.horizontal
            ? value.predictedEndTranslation.width : value.predictedEndTranslation.height,
          direction: direction,
          configuration: configuration)
      }
  }

  private var pageControls: [RufletControl] { control.children("controls") }
}

struct RufletPageViewConfiguration: Equatable {
  let horizontal: Bool
  let reverse: Bool
  let clipBehavior: String
  let padEnds: Bool
  let implicitScrolling: Bool
  let snap: Bool
  let keepPage: Bool
  let viewportFraction: CGFloat
  let animationDuration: TimeInterval
  let animationCurve: RufletCurve

  @MainActor
  init(control: RufletControl) {
    horizontal = control.boolean("horizontal", default: true)
    reverse = control.boolean("reverse", default: false)
    clipBehavior = control.string("clip_behavior", default: "hardEdge")!.lowercased()
    padEnds = control.boolean("pad_ends", default: true)
    implicitScrolling = control.boolean("implicit_scrolling", default: false)
    snap = control.boolean("snap", default: true)
    keepPage = control.boolean("keep_page", default: true)
    viewportFraction = CGFloat(control.number("viewport_fraction", default: 1) ?? 1)
    animationDuration = parseDuration(control.dynamicValue("animation_duration"), 1)!
    animationCurve = parseCurve(control.string("animation_curve"), .linear)!

    precondition(viewportFraction > 0, "PageView.viewport_fraction must be greater than zero")
  }

  var controllerIdentity: ControllerIdentity {
    ControllerIdentity(keepPage: keepPage, viewportFraction: viewportFraction)
  }

  struct ControllerIdentity: Equatable {
    let keepPage: Bool
    let viewportFraction: CGFloat
  }
}

private struct RufletPageViewStorageKey: Hashable {
  let backend: ObjectIdentifier
  let controlID: Int
}

@MainActor
private enum RufletPageViewPositionStore {
  static var pages: [RufletPageViewStorageKey: Double] = [:]
}

@MainActor
final class RufletPageViewCoordinator: ObservableObject {
  @Published private(set) var selectedIndex: Int
  @Published private(set) var continuousPage: CGFloat

  private weak var control: RufletControl?
  private var pageCount = 0
  private var pageLength: CGFloat = 1
  private var configuration: RufletPageViewConfiguration?
  private var invokeToken: UUID?
  private var storageKey: RufletPageViewStorageKey?

  init(selectedIndex: Int) {
    self.selectedIndex = selectedIndex
    continuousPage = CGFloat(selectedIndex)
  }

  func mount(
    control: RufletControl,
    pageCount: Int,
    configuration: RufletPageViewConfiguration
  ) {
    self.control = control
    self.pageCount = pageCount
    self.configuration = configuration
    storageKey = RufletPageViewStorageKey(
      backend: ObjectIdentifier(control.backend),
      controlID: control.id)

    let requested = bounded(control.integer("selected_index", default: 0) ?? 0)
    if configuration.keepPage,
       let storageKey,
       let stored = RufletPageViewPositionStore.pages[storageKey] {
      continuousPage = bounded(stored)
      selectedIndex = bounded(Int(stored.rounded()))
    } else {
      selectedIndex = requested
      continuousPage = CGFloat(requested)
      if let storageKey { RufletPageViewPositionStore.pages.removeValue(forKey: storageKey) }
    }

    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { return .null }
      return try await self.invoke(name, arguments: arguments)
    }
  }

  func unmount() {
    persistPage()
    if let invokeToken { control?.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
    control = nil
  }

  func synchronize(
    pageCount: Int,
    configuration newConfiguration: RufletPageViewConfiguration
  ) {
    guard let control else { return }
    let oldIdentity = configuration?.controllerIdentity
    self.pageCount = pageCount
    configuration = newConfiguration
    let requested = bounded(control.integer("selected_index", default: 0) ?? 0)

    // Pinned didUpdateWidget recreates PageController when either field changes.
    if oldIdentity != newConfiguration.controllerIdentity {
      selectedIndex = requested
      continuousPage = CGFloat(requested)
      if !newConfiguration.keepPage, let storageKey {
        RufletPageViewPositionStore.pages.removeValue(forKey: storageKey)
      }
      persistPage()
      return
    }

    if selectedIndex != requested {
      selectedIndex = requested
      continuousPage = CGFloat(requested)
      persistPage()
    } else {
      continuousPage = bounded(Double(continuousPage))
    }
  }

  func setPageLength(_ length: CGFloat) {
    pageLength = max(length, 1)
  }

  func endDrag(
    translation: CGFloat,
    predictedTranslation: CGFloat,
    direction: CGFloat,
    configuration: RufletPageViewConfiguration
  ) {
    guard pageCount > 0 else { return }
    if configuration.snap {
      let target = Double(selectedIndex) - Double(predictedTranslation * direction / pageLength)
      commitPage(Int(target.rounded()), animated: true, notify: true)
    } else {
      let page = Double(continuousPage) - Double(translation * direction / pageLength)
      continuousPage = CGFloat(bounded(page))
      commitPage(
        Int(Double(continuousPage).rounded()),
        animated: false,
        notify: true,
        preserveOffset: true)
    }
  }

  @discardableResult
  func commitPage(
    _ requestedIndex: Int,
    animated: Bool,
    notify: Bool,
    preserveOffset: Bool = false,
    animation: Animation? = nil
  ) -> Bool {
    guard pageCount > 0 else { return false }
    let index = bounded(requestedIndex)
    let changed = selectedIndex != index
    let update = {
      self.selectedIndex = index
      if !preserveOffset { self.continuousPage = CGFloat(index) }
    }
    if animated {
      withAnimation(animation ?? defaultAnimation) { update() }
    } else {
      update()
    }
    persistPage()

    // PageView.onPageChanged only runs after a distinct logical page is reached.
    guard changed, notify, let control else { return changed }
    control.updateProperties(["selected_index": .int(Int64(index))])
    control.triggerEvent("change", data: .int(Int64(index)))
    return true
  }

  func invoke(_ name: String, arguments: RufletValue) async throws -> RufletValue {
    let values = arguments.map ?? [:]
    let duration = parseDuration(
      values["duration"].map(rufletAny),
      configuration?.animationDuration ?? 1)!
    let curve = parseCurve(
      values["curve"]?.text,
      configuration?.animationCurve ?? .linear)!
    let animation = curve.animation(duration: duration)

    switch name {
    case "go_to_page":
      if let index = parseInt(values["index"].map(rufletAny)) {
        commitPage(index, animated: true, notify: true, animation: animation)
      }
    case "jump_to_page":
      if let index = parseInt(values["index"].map(rufletAny)) {
        commitPage(index, animated: false, notify: true)
      }
    case "jump_to":
      if let offset = parseDouble(values["value"].map(rufletAny)) {
        continuousPage = CGFloat(bounded(offset / Double(pageLength)))
        commitPage(
          Int(Double(continuousPage).rounded()),
          animated: false,
          notify: true,
          preserveOffset: true)
      }
    case "next_page":
      commitPage(
        selectedIndex + 1,
        animated: true,
        notify: true,
        animation: animation)
    case "previous_page":
      commitPage(
        selectedIndex - 1,
        animated: true,
        notify: true,
        animation: animation)
    default:
      throw RufletPageViewError.unknownMethod(name)
    }
    return .null
  }

  private func persistPage() {
    guard let storageKey, configuration?.keepPage == true else { return }
    RufletPageViewPositionStore.pages[storageKey] = Double(continuousPage)
  }

  private func bounded(_ index: Int) -> Int {
    min(max(index, 0), max(pageCount - 1, 0))
  }

  private func bounded(_ page: Double) -> Double {
    min(max(page, 0), Double(max(pageCount - 1, 0)))
  }

  private var defaultAnimation: Animation {
    let configuration = configuration
    return (configuration?.animationCurve ?? .linear)
      .animation(duration: configuration?.animationDuration ?? 1)
  }
}

enum RufletPageViewError: Error {
  case unknownMethod(String)
}

private struct RufletPageViewClipModifier: ViewModifier {
  let behavior: String

  @ViewBuilder
  func body(content: Content) -> some View {
    if behavior == "none" {
      content
    } else {
      content.clipped(
        antialiased: behavior == "antialias" || behavior == "antialiaswithsavelayer")
    }
  }
}
