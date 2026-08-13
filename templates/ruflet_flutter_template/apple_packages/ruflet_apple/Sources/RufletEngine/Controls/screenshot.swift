import RufletProtocol
import SwiftUI

struct RufletScreenshotCaptureRequest: Equatable {
  let delay: TimeInterval
  let pixelRatio: Double?

  init(arguments: RufletValue) throws {
    let values = arguments.map ?? [:]
    delay = parseRufletWireDuration(values["delay"], 0.02)!
    pixelRatio = values["pixel_ratio"]?.number
    if let pixelRatio, pixelRatio <= 0 {
      throw RufletScreenshotError.invalidPixelRatio
    }
  }
}

/// Apple-native port of pinned `screenshot.dart`.
@MainActor
public struct ScreenshotControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var captureCoordinator = RufletScreenshotCaptureCoordinator()
  @State private var invokeToken: UUID?

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    BaseControl(control: control) {
      if let content = control.buildWidget("content") {
        RufletScreenshotCaptureHost(
          content: content,
          captureCoordinator: captureCoordinator)
      } else {
        ErrorControl("Screenshot.content must be provided and visible")
      }
    }
    .onAppear(perform: attach)
    .onDisappear(perform: detach)
  }

  private func attach() {
    guard invokeToken == nil else { return }
    invokeToken = control.addInvokeMethodListener { name, arguments in
      guard name == "capture" else { throw RufletScreenshotError.unknownMethod(name) }
      let request = try RufletScreenshotCaptureRequest(arguments: arguments)
      if request.delay > 0 {
        try await Task.sleep(nanoseconds: rufletSleepNanoseconds(request.delay))
      }
      let ratio = request.pixelRatio ?? defaultApplePixelRatio()
      return captureCoordinator.capture(pixelRatio: CGFloat(ratio))
        .map(RufletValue.binary) ?? .null
    }
  }

  private func detach() {
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
    captureCoordinator.uninstall()
  }
}

enum RufletScreenshotError: Error {
  case invalidPixelRatio
  case unknownMethod(String)
}
