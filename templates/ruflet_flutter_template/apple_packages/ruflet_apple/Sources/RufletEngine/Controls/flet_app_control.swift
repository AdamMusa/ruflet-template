import RufletProtocol
import SwiftUI

/// Apple-native port of Flet's nested `flet_app_control.dart`.
@MainActor
public struct FletAppControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      RufletApp(
        pageURL: control.string("url", default: "")!,
        assetsDirectory: "",
        showAppStartupScreen: control.boolean("show_app_startup_screen"),
        appStartupScreenMessage: control.string("app_startup_screen_message"),
        appErrorMessage: control.string("app_error_message"),
        controlID: control.id,
        reconnectIntervalMilliseconds: control.integer("reconnect_interval_ms"),
        reconnectTimeoutMilliseconds: control.integer("reconnect_timeout_ms"),
        extensions: control.backend.extensionRegistry.extensions,
        arguments: nestedArguments,
        parentBackend: control.backend as? RufletBackend)
    }
  }

  private var nestedArguments: [String: RufletValue] {
    control.value("args")?.map ?? [:]
  }
}
