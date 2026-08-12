import CoreImage
import Foundation
import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

#if canImport(AVFoundation)
  @preconcurrency import AVFoundation
#endif
#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

enum QRScannerCameraFacing: String, Equatable {
  case front
  case back
}

enum QRScannerDetectionSpeed: String, Equatable {
  case noDuplicates = "no_duplicates"
  case normal
  case unrestricted
}

/// Names are intentionally identical to `mobile_scanner` 7.4.0. The parser
/// normalizes punctuation/case exactly like the pinned Dart plug-in.
enum QRScannerBarcodeFormat: String, CaseIterable, Equatable {
  case unknown, all, code128, code39, code93, codabar, dataMatrix, ean13, ean8
  case itf2of5, itf2of5WithChecksum, itf, itf14, qrCode, upcA, upcE, pdf417
  case aztec, maxiCode, microQrCode, dataBar, dataBarExpanded, dataBarLimited
}

struct QRScannerRect: Equatable {
  let x: Double
  let y: Double
  let width: Double
  let height: Double
}

struct QRScannerConfiguration: Equatable {
  let autoStart: Bool
  let autoZoom: Bool
  let cameraFacing: QRScannerCameraFacing
  let detectionSpeed: QRScannerDetectionSpeed
  let detectionTimeoutMilliseconds: Int
  let fit: String
  let formats: [QRScannerBarcodeFormat]
  let invertImage: Bool
  let returnImage: Bool
  let scanWindow: QRScannerRect?
  let tapToFocus: Bool
  let torchEnabled: Bool
  let zoomScale: Double

  init(
    autoStart: Bool, autoZoom: Bool, cameraFacing: QRScannerCameraFacing,
    detectionSpeed: QRScannerDetectionSpeed, detectionTimeoutMilliseconds: Int,
    fit: String, formats: [QRScannerBarcodeFormat], invertImage: Bool,
    returnImage: Bool, scanWindow: QRScannerRect?, tapToFocus: Bool,
    torchEnabled: Bool, zoomScale: Double
  ) {
    self.autoStart = autoStart
    self.autoZoom = autoZoom
    self.cameraFacing = cameraFacing
    self.detectionSpeed = detectionSpeed
    self.detectionTimeoutMilliseconds = detectionTimeoutMilliseconds
    self.fit = fit
    self.formats = formats
    self.invertImage = invertImage
    self.returnImage = returnImage
    self.scanWindow = scanWindow
    self.tapToFocus = tapToFocus
    self.torchEnabled = torchEnabled
    self.zoomScale = zoomScale
  }

  init(node: ControlNode) {
    autoStart = node.bool("auto_start") ?? true
    autoZoom = node.bool("auto_zoom") ?? false
    cameraFacing = Self.parseCameraFacing(node.string("camera_facing"))
    detectionSpeed = Self.parseDetectionSpeed(node.string("detection_speed"))
    detectionTimeoutMilliseconds = node.int("detection_timeout") ?? 250
    fit = node.string("fit") ?? "cover"
    formats = Self.parseFormats(node.array("formats"))
    invertImage = node.bool("invert_image") ?? false
    returnImage = node.bool("return_image") ?? false
    scanWindow = Self.parseScanWindow(node.props["scan_window"])
    tapToFocus = node.bool("tap_to_focus") ?? false
    torchEnabled = node.bool("torch_enabled") ?? false
    zoomScale = node.double("zoom_scale") ?? 1
  }

  static func parseCameraFacing(_ value: String?) -> QRScannerCameraFacing {
    value?.lowercased() == "front" ? .front : .back
  }

  static func parseDetectionSpeed(_ value: String?) -> QRScannerDetectionSpeed {
    switch normalized(value) {
    case "noduplicates": return .noDuplicates
    case "unrestricted": return .unrestricted
    default: return .normal
    }
  }

  static func parseFormats(_ values: [RufletValue]?) -> [QRScannerBarcodeFormat] {
    guard let values, !values.isEmpty else { return [] }
    var result: [QRScannerBarcodeFormat] = []
    for value in values {
      let name = normalized(value.stringValue)
      guard let format = QRScannerBarcodeFormat.allCases.first(where: {
        normalized($0.rawValue) == name
      }), !result.contains(format) else { continue }
      result.append(format)
    }
    return result
  }

  static func parseScanWindow(_ value: RufletValue?) -> QRScannerRect? {
    guard let map = value?.mapValue,
      let left = (map["left"] ?? map["x"])?.doubleValue,
      let top = (map["top"] ?? map["y"])?.doubleValue
    else { return nil }
    if let right = map["right"]?.doubleValue,
      let bottom = map["bottom"]?.doubleValue
    {
      return QRScannerRect(x: left, y: top, width: right - left, height: bottom - top)
    }
    if let width = map["width"]?.doubleValue,
      let height = map["height"]?.doubleValue
    {
      return QRScannerRect(x: left, y: top, width: width, height: height)
    }
    return nil
  }

  private static func normalized(_ value: String?) -> String {
    (value ?? "")
      .unicodeScalars
      .filter { CharacterSet.alphanumerics.contains($0) }
      .map(String.init)
      .joined()
      .lowercased()
  }
}

/// The stateful native equivalent of the pinned `MobileScanner` control.
public struct QRScannerControlView: View {
  let node: ControlNode
  @StateObject private var model = QRScannerModel()
  @Environment(\.rufletEvents) private var events

  public init(node: ControlNode) { self.node = node }

  public var body: some View {
    Group {
      #if canImport(AVFoundation) && !targetEnvironment(simulator)
        QRScannerPreview(model: model, configuration: QRScannerConfiguration(node: node))
      #else
        EmptyView()
      #endif
    }
    .onAppear { model.attach(node: node, events: events) }
    .onChange(of: node) { model.attach(node: $0, events: events) }
    .onDisappear { model.dispose() }
    .rufletCommandHandler(node.id) { call, completion in
      model.handle(call, completion: completion)
    }
  }
}

@MainActor
final class QRScannerModel: NSObject, ObservableObject {
  #if canImport(AVFoundation)
    let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let captureQueue = DispatchQueue(label: "com.izeesoft.ruflet.qrcode-scanner")
    private var input: AVCaptureDeviceInput?
    private var configured = false
    private var starting = false
    private var disposed = false
    private var shouldRun = false
    private var configuration: QRScannerConfiguration?
    private var control: ControlNode?
    private var events = RufletEventSink()
    private var lastImage: Data?
    private var lastDetection = Date.distantPast
    private var detectedValues = Set<String>()
  #endif

  func attach(node: ControlNode, events: RufletEventSink) {
    #if canImport(AVFoundation)
      let next = QRScannerConfiguration(node: node)
      control = node
      self.events = events
      disposed = false
      if configuration == nil { shouldRun = next.autoStart }
      if configuration != next {
        if let previous = configuration, previous.autoStart != next.autoStart {
          shouldRun = next.autoStart
        }
        configuration = next
        replaceController()
      }
      if shouldRun { start(completion: nil) }
    #endif
  }

  func dispose() {
    #if canImport(AVFoundation)
      disposed = true
      shouldRun = false
      stopSession()
      configured = false
      session.inputs.forEach(session.removeInput)
      session.outputs.forEach(session.removeOutput)
    #endif
  }

  func handle(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
    #if canImport(AVFoundation)
      switch call.name {
      case "start":
        shouldRun = true
        start(completion: completion)
      case "stop":
        shouldRun = false
        stopSession()
        completion(.success(.bool(true)))
      case "switch_camera":
        guard configuration != nil else {
          return fail(RufletServiceError.unavailable("QR scanner is not configured"), completion)
        }
        let facing: QRScannerCameraFacing = input?.device.position == .front ? .back : .front
        replaceInput(facing: facing)
        completion(.success(.bool(true)))
      case "toggle_torch":
        do {
          guard let device = input?.device, device.hasTorch else {
            throw RufletServiceError.unavailable("The selected camera has no torch")
          }
          try device.lockForConfiguration()
          device.torchMode = device.torchMode == .on ? .off : .on
          device.unlockForConfiguration()
          completion(.success(.bool(true)))
        } catch { fail(error, completion) }
      case "set_zoom_scale":
        guard let value = call.argument("value")?.doubleValue else {
          return fail(RufletServiceError.invalidArguments("value is required"), completion)
        }
        setZoom(value, completion: completion)
      case "reset_zoom_scale":
        setZoom(1, completion: completion)
      default:
        fail(rufletUnsupported(control?.type ?? "qrcode_scanner", call), completion)
      }
    #else
      completion(.failure(RufletServiceError.unavailable("AVFoundation is unavailable")))
    #endif
  }

  #if canImport(AVFoundation)
    private func start(completion: RufletMethodCompletion?) {
      guard !disposed else {
        completion?(.success(.bool(true)))
        return
      }
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
          Task { @MainActor in
            guard let self else { return }
            if granted { self.start(completion: completion) }
            else { self.fail(RufletServiceError.unavailable("Camera permission was denied"), completion) }
          }
        }
      case .authorized:
        guard !starting else {
          completion?(.success(.bool(true)))
          return
        }
        do {
          try ensureConfigured()
          guard !session.isRunning else {
            completion?(.success(.bool(true)))
            return
          }
          let session = session
          starting = true
          Task {
            await Task.detached { session.startRunning() }.value
            self.starting = false
            completion?(.success(.bool(true)))
          }
        } catch { fail(error, completion) }
      default:
        fail(RufletServiceError.unavailable("Camera permission was denied"), completion)
      }
    }

    private func ensureConfigured() throws {
      guard !configured, let configuration else { return }
      session.beginConfiguration()
      defer { session.commitConfiguration() }
      session.sessionPreset = .high
      try addInput(facing: configuration.cameraFacing)
      guard session.canAddOutput(metadataOutput) else {
        throw RufletServiceError.unavailable("Barcode metadata output is unavailable")
      }
      session.addOutput(metadataOutput)
      metadataOutput.setMetadataObjectsDelegate(self, queue: captureQueue)
      let requested = Self.metadataTypes(configuration.formats)
      metadataOutput.metadataObjectTypes = requested.isEmpty
        ? metadataOutput.availableMetadataObjectTypes
        : requested.filter(metadataOutput.availableMetadataObjectTypes.contains)
      if configuration.returnImage, session.canAddOutput(videoOutput) {
        session.addOutput(videoOutput)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
          kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
      }
      configured = true
      apply(configuration)
    }

    private func replaceController() {
      let wasRunning = session.isRunning
      stopSession()
      configured = false
      detectedValues.removeAll()
      session.inputs.forEach(session.removeInput)
      session.outputs.forEach(session.removeOutput)
      if wasRunning { shouldRun = true }
    }

    private func stopSession() {
      guard session.isRunning else { return }
      let session = session
      Task { await Task.detached { session.stopRunning() }.value }
    }

    private func addInput(facing: QRScannerCameraFacing) throws {
      let position: AVCaptureDevice.Position = facing == .front ? .front : .back
      guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
        ?? AVCaptureDevice.default(for: .video)
      else { throw RufletServiceError.unavailable("No camera is available") }
      let next = try AVCaptureDeviceInput(device: device)
      guard session.canAddInput(next) else {
        throw RufletServiceError.unavailable("The selected camera cannot be attached")
      }
      session.addInput(next)
      input = next
    }

    private func replaceInput(facing: QRScannerCameraFacing) {
      let wasRunning = session.isRunning
      session.beginConfiguration()
      if let input { session.removeInput(input) }
      do { try addInput(facing: facing) }
      catch { report(error) }
      session.commitConfiguration()
      if wasRunning && !session.isRunning { start(completion: nil) }
    }

    private func apply(_ configuration: QRScannerConfiguration) {
      setZoom(configuration.zoomScale, completion: nil)
      guard configuration.torchEnabled, let device = input?.device, device.hasTorch else { return }
      do {
        try device.lockForConfiguration()
        try device.setTorchModeOn(level: 1)
        device.unlockForConfiguration()
      } catch { report(error) }
    }

    private func setZoom(_ value: Double, completion: RufletMethodCompletion?) {
      #if os(iOS)
      do {
        guard let device = input?.device else {
          throw RufletServiceError.unavailable("QR scanner is not running")
        }
        try device.lockForConfiguration()
        device.videoZoomFactor = min(max(CGFloat(value), 1), device.activeFormat.videoMaxZoomFactor)
        device.unlockForConfiguration()
        completion?(.success(.bool(true)))
      } catch { fail(error, completion) }
      #else
      completion?(.failure(
        RufletServiceError.platformUnsupported(
          type: control?.type ?? "qrcode_scanner", method: "set_zoom_scale",
          platform: "macOS")))
      #endif
    }

    private func fail(_ error: Error, _ completion: RufletMethodCompletion?) {
      report(error)
      completion?(.failure(error))
    }

    private func report(_ error: Error) {
      guard let control else { return }
      events.fire(control, "error", data: .map([
        "message": .string(String(describing: error)),
        "type": .string(String(describing: type(of: error)))
      ]))
    }

    private static func metadataTypes(_ formats: [QRScannerBarcodeFormat]) -> [AVMetadataObject.ObjectType] {
      if formats.isEmpty || formats.contains(.all) { return [] }
      return formats.compactMap { format in
        switch format {
        case .qrCode: return .qr
        case .code128: return .code128
        case .code39: return .code39
        case .code93: return .code93
        case .codabar:
          if #available(iOS 15.4, macOS 12.3, *) { return .codabar }
          return nil
        case .dataMatrix: return .dataMatrix
        case .ean13: return .ean13
        case .ean8: return .ean8
        case .itf, .itf14, .itf2of5, .itf2of5WithChecksum: return .interleaved2of5
        case .upcE: return .upce
        case .pdf417: return .pdf417
        case .aztec: return .aztec
        case .dataBar, .dataBarExpanded, .dataBarLimited:
          if #available(iOS 15.4, macOS 12.3, *) { return .gs1DataBar }
          return nil
        case .upcA, .maxiCode, .microQrCode, .unknown, .all: return nil
        }
      }
    }

    fileprivate func updateScanWindow(_ rect: CGRect?) {
      metadataOutput.rectOfInterest = rect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
    }
  #endif
}

#if canImport(AVFoundation)
extension QRScannerModel: AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
  nonisolated func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    let codes = metadataObjects.compactMap { $0 as? AVMetadataMachineReadableCodeObject }
    Task { @MainActor in self.consume(codes) }
  }

  nonisolated func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let image = CIImage(cvPixelBuffer: buffer)
    guard let data = CIContext().jpegRepresentation(
      of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:])
    else { return }
    Task { @MainActor in self.lastImage = data }
  }

  private func consume(_ codes: [AVMetadataMachineReadableCodeObject]) {
    guard let configuration, let control, control.handlesEvent("detect") else { return }
    let now = Date()
    if configuration.detectionSpeed == .normal,
      now.timeIntervalSince(lastDetection) * 1_000 < Double(configuration.detectionTimeoutMilliseconds)
    { return }
    let fresh = codes.filter { code in
      guard configuration.detectionSpeed == .noDuplicates else { return true }
      let value = code.stringValue ?? ""
      return detectedValues.insert(value).inserted
    }
    guard !fresh.isEmpty || codes.isEmpty else { return }
    lastDetection = now
    if configuration.autoZoom, let first = fresh.first ?? codes.first {
      let area = first.bounds.width * first.bounds.height
      if area > 0, area < 0.1 { setZoom(2, completion: nil) }
    }
    let values = fresh.isEmpty ? codes : fresh
    var payload: [String: RufletValue] = [
      "value": values.first?.stringValue.map(RufletValue.string) ?? .null,
      "barcodes": .array(values.map(Self.serialize))
    ]
    if configuration.returnImage, let lastImage {
      payload["image"] = .string(lastImage.base64EncodedString())
    }
    events.fire(control, "detect", data: .map(payload))
  }

  private static func serialize(_ code: AVMetadataMachineReadableCodeObject) -> RufletValue {
    .map([
      "raw_value": code.stringValue.map(RufletValue.string) ?? .null,
      "display_value": code.stringValue.map(RufletValue.string) ?? .null,
      "format": .string(formatName(code.type)),
      "type": .string("text"),
      "corners": .array(code.corners.map { point in
        .map(["x": .double(point.x), "y": .double(point.y)])
      })
    ])
  }

  private static func formatName(_ type: AVMetadataObject.ObjectType) -> String {
    switch type {
    case .qr: return "qrCode"
    case .code128: return "code128"
    case .code39: return "code39"
    case .code93: return "code93"
    case .dataMatrix: return "dataMatrix"
    case .ean13: return "ean13"
    case .ean8: return "ean8"
    case .interleaved2of5: return "itf"
    case .upce: return "upcE"
    case .pdf417: return "pdf417"
    case .aztec: return "aztec"
    default: return "unknown"
    }
  }
}
#endif

#if canImport(UIKit) && canImport(AVFoundation)
private struct QRScannerPreview: UIViewRepresentable {
  let model: QRScannerModel
  let configuration: QRScannerConfiguration

  func makeUIView(context: Context) -> QRScannerPreviewUIView {
    QRScannerPreviewUIView(model: model, configuration: configuration)
  }

  func updateUIView(_ view: QRScannerPreviewUIView, context: Context) {
    view.configuration = configuration
    view.updateLayout()
  }
}

private final class QRScannerPreviewUIView: UIView {
  let previewLayer: AVCaptureVideoPreviewLayer
  let model: QRScannerModel
  var configuration: QRScannerConfiguration

  init(model: QRScannerModel, configuration: QRScannerConfiguration) {
    self.model = model
    self.configuration = configuration
    previewLayer = AVCaptureVideoPreviewLayer(session: model.session)
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
    model.updateScanWindow(scanRect.map(previewLayer.metadataOutputRectConverted))
  }

  @objc private func focus(_ recognizer: UITapGestureRecognizer) {
    guard configuration.tapToFocus,
      let device = model.session.inputs.compactMap({ ($0 as? AVCaptureDeviceInput)?.device }).first,
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
#elseif canImport(AppKit) && canImport(AVFoundation)
private struct QRScannerPreview: NSViewRepresentable {
  let model: QRScannerModel
  let configuration: QRScannerConfiguration

  func makeNSView(context: Context) -> QRScannerPreviewNSView {
    QRScannerPreviewNSView(model: model, configuration: configuration)
  }

  func updateNSView(_ view: QRScannerPreviewNSView, context: Context) {
    view.configuration = configuration
    view.updateLayout()
  }
}

private final class QRScannerPreviewNSView: NSView {
  let previewLayer: AVCaptureVideoPreviewLayer
  let model: QRScannerModel
  var configuration: QRScannerConfiguration

  init(model: QRScannerModel, configuration: QRScannerConfiguration) {
    self.model = model
    self.configuration = configuration
    previewLayer = AVCaptureVideoPreviewLayer(session: model.session)
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
    model.updateScanWindow(scanRect.map(previewLayer.metadataOutputRectConverted))
  }
}
#endif

#if canImport(AVFoundation)
private extension QRScannerConfiguration {
  var videoGravity: AVLayerVideoGravity {
    switch fit.lowercased() {
    case "fill": return .resize
    case "contain", "fit_width", "fit_height", "scale_down", "none": return .resizeAspect
    default: return .resizeAspectFill
    }
  }
}
#endif
