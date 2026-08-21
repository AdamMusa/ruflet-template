@preconcurrency import AVFoundation
import RufletEngine
import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

struct QRScannerControl: View {
  @ObservedObject var control: RufletControl
  @ObservedObject var controller: QRScannerController

  var body: some View {
    LayoutControl(control: control) {
      GeometryReader { proxy in
        QRScannerPreview(
          controller: controller,
          configuration: controller.configuration
        )
        .frame(
          width: proxy.size.width,
          height: proxy.size.height,
          alignment: .center)
      }
    }
    .onAppear { controller.mount() }
    .onDisappear { controller.unmount() }
  }
}

#if os(iOS)
private struct QRScannerPreview: UIViewRepresentable {
  let controller: QRScannerController
  let configuration: QRScannerConfiguration

  func makeUIView(context: Context) -> QRScannerPreviewView {
    QRScannerPreviewView(controller: controller, configuration: configuration)
  }

  func updateUIView(_ view: QRScannerPreviewView, context: Context) {
    view.configuration = configuration
    view.updateLayout()
  }
}

private final class QRScannerPreviewView: UIView {
  let controller: QRScannerController
  let previewLayer: AVCaptureVideoPreviewLayer
  var configuration: QRScannerConfiguration

  init(controller: QRScannerController, configuration: QRScannerConfiguration) {
    self.controller = controller
    self.configuration = configuration
    previewLayer = AVCaptureVideoPreviewLayer(session: controller.session)
    super.init(frame: .zero)
    layer.addSublayer(previewLayer)
    addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focus(_:))))
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateLayout()
  }

  func updateLayout() {
    previewLayer.frame = bounds
    previewLayer.videoGravity = configuration.videoGravity
    let scanRect = configuration.scanWindow.map {
      CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height)
    }
    controller.updateScanWindow(scanRect.map(previewLayer.metadataOutputRectConverted))
  }

  @objc private func focus(_ recognizer: UITapGestureRecognizer) {
    guard configuration.tapToFocus,
      let device = controller.session.inputs
        .compactMap({ ($0 as? AVCaptureDeviceInput)?.device }).first,
      device.isFocusPointOfInterestSupported
    else { return }
    do {
      try device.lockForConfiguration()
      device.focusPointOfInterest = previewLayer.captureDevicePointConverted(
        fromLayerPoint: recognizer.location(in: self))
      device.focusMode = .autoFocus
      device.unlockForConfiguration()
    } catch { return }
  }
}
#elseif os(macOS)
private struct QRScannerPreview: NSViewRepresentable {
  let controller: QRScannerController
  let configuration: QRScannerConfiguration

  func makeNSView(context: Context) -> QRScannerPreviewView {
    QRScannerPreviewView(controller: controller, configuration: configuration)
  }

  func updateNSView(_ view: QRScannerPreviewView, context: Context) {
    view.configuration = configuration
    view.updateLayout()
  }
}

private final class QRScannerPreviewView: NSView {
  let controller: QRScannerController
  let previewLayer: AVCaptureVideoPreviewLayer
  var configuration: QRScannerConfiguration

  init(controller: QRScannerController, configuration: QRScannerConfiguration) {
    self.controller = controller
    self.configuration = configuration
    previewLayer = AVCaptureVideoPreviewLayer(session: controller.session)
    super.init(frame: .zero)
    wantsLayer = true
    layer?.addSublayer(previewLayer)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layout() {
    super.layout()
    updateLayout()
  }

  func updateLayout() {
    previewLayer.frame = bounds
    previewLayer.videoGravity = configuration.videoGravity
    let scanRect = configuration.scanWindow.map {
      CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height)
    }
    controller.updateScanWindow(scanRect.map(previewLayer.metadataOutputRectConverted))
  }
}
#endif

private extension QRScannerConfiguration {
  var videoGravity: AVLayerVideoGravity {
    switch fit.lowercased() {
    case "fill": return .resize
    case "contain", "fit_width", "fit_height", "scale_down", "none": return .resizeAspect
    default: return .resizeAspectFill
    }
  }
}
