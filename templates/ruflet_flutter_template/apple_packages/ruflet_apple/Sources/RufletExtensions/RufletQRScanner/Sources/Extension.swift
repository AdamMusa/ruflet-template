import RufletEngine
import SwiftUI

@MainActor
public final class RufletQRScannerExtension: RufletExtension {
  private struct ControllerEntry {
    weak var control: RufletControl?
    let controller: QRScannerController
  }

  private var controllers: [Int: ControllerEntry] = [:]

  public init() {}

  public var renderedControlTypes: Set<String> { RufletQRScanner.controlTypes }

  public func createView(for control: RufletControl) -> AnyView? {
    guard RufletQRScanner.controlTypes.contains(control.type) else { return nil }
    let controller: QRScannerController
    if let existing = controllers[control.id], existing.control === control {
      controller = existing.controller
    } else {
      controllers[control.id]?.controller.dispose()
      controller = QRScannerController(control: control)
      controllers[control.id] = ControllerEntry(control: control, controller: controller)
    }
    return AnyView(QRScannerControl(control: control, controller: controller))
  }
}
