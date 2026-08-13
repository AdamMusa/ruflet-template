import RufletEngine
import SwiftUI

struct WebViewControl: View {
  @ObservedObject var control: RufletControl
  @StateObject private var controller: RufletWebViewController

  init(control: RufletControl) {
    self.control = control
    _controller = StateObject(wrappedValue: RufletWebViewController(control: control))
  }

  var body: some View {
    WebViewMobileAndMac(controller: controller)
      .onAppear { controller.attach() }
      .onDisappear { controller.detach() }
  }
}
