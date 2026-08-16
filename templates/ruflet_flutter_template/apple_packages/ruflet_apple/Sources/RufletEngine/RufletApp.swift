import SwiftUI
import RufletProtocol

/// Top-level Apple host mirroring FletApp.
///
/// The same host is used by server-driven and self-contained builds. Both
/// modes feed the Flet protocol into the native control tree; neither embeds
/// or switches to Flutter's renderer on Apple.
@MainActor
public struct RufletApp: View {
  @StateObject private var backend: RufletBackend
  @StateObject private var routeState = RufletRouteState()
  private let title: String?

  public init(
    pageURL: String,
    assetsDirectory: String,
    showAppStartupScreen: Bool? = nil,
    appStartupScreenMessage: String? = nil,
    appErrorMessage: String? = nil,
    controlID: Int? = nil,
    forcePyodide: Bool? = nil,
    title: String? = nil,
    errorsHandler: RufletAppErrorsHandler? = nil,
    reconnectIntervalMilliseconds: Int? = nil,
    reconnectTimeoutMilliseconds: Int? = nil,
    extensions: [any RufletExtension] = [],
    arguments: [String: RufletValue] = [:],
    multiView: Bool = false,
    parentBackend: RufletBackend? = nil
  ) {
    guard let url = URL(string: pageURL) else {
      preconditionFailure("Invalid Ruflet page URL: \(pageURL)")
    }
    self.title = title
    _backend = StateObject(wrappedValue: RufletBackend(
      pageURL: url,
      assetsDirectory: assetsDirectory,
      multiView: multiView,
      reconnectIntervalMilliseconds: reconnectIntervalMilliseconds,
      reconnectTimeoutMilliseconds: reconnectTimeoutMilliseconds,
      errorsHandler: errorsHandler,
      showAppStartupScreen: showAppStartupScreen,
      appStartupScreenMessage: appStartupScreenMessage,
      appErrorMessage: appErrorMessage,
      controlID: controlID,
      forcePyodide: forcePyodide,
      arguments: arguments,
      extensions: extensions,
      parentBackend: parentBackend))
  }

  public var body: some View {
    RufletHeroScope {
      ZStack {
        // Page must remain mounted throughout startup and error states. It is
        // the owner of Flet services, invoke listeners, and the first native
        // geometry report which releases backend registration.
        ControlWidget(control: backend.page)

        if backend.isLoading && shouldShowStartupScreen {
          LoadingPage(isLoading: true, message: backend.appStartupScreenMessage ?? "Loading...")
        } else if !backend.error.isEmpty {
          ErrorControl(
            title ?? "Ruflet",
            description: backend.formatAppErrorMessage(backend.error))
        }
      }
    }
    .environmentObject(backend.extensionRegistry)
    .environmentObject(backend)
    .onChange(of: routeState.route) { route in
      backend.onRouteUpdated(route)
    }
    .task {
      if routeState.route.isEmpty {
        let initial = RufletDeepLinkingBootstrap.takePendingInitialURL()?.absoluteString ?? "/"
        routeState.go(initial)
      }
    }
    .onOpenURL { routeState.go($0.absoluteString) }
    .onDisappear { backend.dispose() }
  }

  private var shouldShowStartupScreen: Bool {
    backend.showAppStartupScreen ?? true
  }
}
