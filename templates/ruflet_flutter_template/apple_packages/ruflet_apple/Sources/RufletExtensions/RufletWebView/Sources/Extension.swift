import RufletEngine
import SwiftUI

@MainActor
public struct RufletWebViewExtension: RufletExtension {
  public init() {}

  public func createView(for control: RufletControl) -> AnyView? {
    control.type == "WebView" ? AnyView(WebViewControl(control: control)) : nil
  }
}
