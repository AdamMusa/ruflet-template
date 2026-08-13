@preconcurrency import AVFoundation
import CoreImage
import Foundation
import ImageIO
import RufletEngine
import RufletProtocol
import Vision

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

@MainActor
final class QRScannerController: NSObject, ObservableObject,
  AVCaptureVideoDataOutputSampleBufferDelegate
{
  let session = AVCaptureSession()
  private(set) var configuration: QRScannerConfiguration

  private weak var control: RufletControl?
  private let videoOutput = AVCaptureVideoDataOutput()
  private let captureQueue = DispatchQueue(label: "com.izeesoft.ruflet.qrcode-scanner")
  private var input: AVCaptureDeviceInput?
  private var configured = false
  private var starting = false
  private var mounted = false
  private var shouldRun: Bool
  private var invokeToken: UUID?
  private var updateToken: UUID?
  private var lifecycleObservers: [NSObjectProtocol] = []
  private var lastDetection = Date.distantPast
  private var detectionState = QRScannerDetectionState()
  private var processingFrame = false
  private var visionRegionOfInterest: CGRect?

  init(control: RufletControl) {
    self.control = control
    let configuration = QRScannerConfiguration(control: control)
    self.configuration = configuration
    shouldRun = configuration.autoStart
    super.init()
    invokeToken = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { throw QRScannerError.unavailable("QR scanner was disposed") }
      do {
        return try await self.invoke(name, arguments: arguments)
      } catch {
        self.report(error, stackTrace: Thread.callStackSymbols.joined(separator: "\n"))
        throw error
      }
    }
    updateToken = control.addListener { [weak self] in self?.synchronizeConfiguration() }
    registerLifecycleObservers()
  }

  deinit {
    for observer in lifecycleObservers { NotificationCenter.default.removeObserver(observer) }
  }

  func mount() {
    mounted = true
    if shouldRun { Task { try? await start() } }
  }

  func unmount() {
    mounted = false
    pause()
  }

  func dispose() {
    mounted = false
    shouldRun = false
    pause()
    if let control, let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    if let control, let updateToken { control.removeListener(updateToken) }
    invokeToken = nil
    updateToken = nil
    teardownSession()
    self.control = nil
  }

  private func synchronizeConfiguration() {
    guard let control else { return }
    let next = QRScannerConfiguration(control: control)
    guard next != configuration else { return }
    if next.autoStart != configuration.autoStart { shouldRun = next.autoStart }
    configuration = next
    replaceController()
    if shouldRun, mounted { Task { try? await start() } }
  }

  private func invoke(_ name: String, arguments: RufletValue) async throws -> RufletValue {
    switch name {
    case "start":
      shouldRun = true
      try await start()
      return .bool(true)
    case "stop":
      shouldRun = false
      pause()
      return .bool(true)
    case "switch_camera":
      let facing: QRScannerCameraFacing = input?.device.position == .front ? .back : .front
      try replaceInput(facing: facing)
      return .bool(true)
    case "toggle_torch":
      try toggleTorch()
      return .bool(true)
    case "set_zoom_scale":
      guard let value = arguments["value"]?.number else { throw QRScannerError.missingValue }
      try setZoom(value)
      return .bool(true)
    case "reset_zoom_scale":
      try setZoom(0)
      return .bool(true)
    default:
      throw QRScannerError.unknownMethod(name)
    }
  }

  private func start() async throws {
    guard mounted || shouldRun else { return }
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .notDetermined:
      let granted = await AVCaptureDevice.requestAccess(for: .video)
      guard granted else { throw QRScannerError.unavailable("Camera permission was denied") }
      try await start()
    case .authorized:
      guard !starting else { return }
      try ensureConfigured()
      guard !session.isRunning else { return }
      starting = true
      let session = session
      await Task.detached { session.startRunning() }.value
      starting = false
    default:
      throw QRScannerError.unavailable("Camera permission was denied")
    }
  }

  private func pause() {
    guard session.isRunning else { return }
    let session = session
    Task { await Task.detached { session.stopRunning() }.value }
  }

  private func ensureConfigured() throws {
    guard !configured else { return }
    session.beginConfiguration()
    defer { session.commitConfiguration() }
    session.sessionPreset = .high
    try addInput(facing: configuration.cameraFacing)
    guard session.canAddOutput(videoOutput) else {
      throw QRScannerError.unavailable("Barcode video output is unavailable")
    }
    session.addOutput(videoOutput)
    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
    configured = true
    try apply(configuration)
  }

  private func replaceController() {
    pause()
    teardownSession()
    detectionState.reset()
    processingFrame = false
  }

  private func teardownSession() {
    configured = false
    session.beginConfiguration()
    session.inputs.forEach(session.removeInput)
    session.outputs.forEach(session.removeOutput)
    session.commitConfiguration()
    input = nil
  }

  private func addInput(facing: QRScannerCameraFacing) throws {
    let position: AVCaptureDevice.Position = facing == .front ? .front : .back
    guard let device = AVCaptureDevice.default(
      .builtInWideAngleCamera, for: .video, position: position)
      ?? AVCaptureDevice.default(for: .video)
    else { throw QRScannerError.unavailable("No camera is available") }
    let next = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(next) else {
      throw QRScannerError.unavailable("The selected camera cannot be attached")
    }
    session.addInput(next)
    input = next
  }

  private func replaceInput(facing: QRScannerCameraFacing) throws {
    guard configured else { throw QRScannerError.unavailable("QR scanner is not configured") }
    let wasRunning = session.isRunning
    let previous = input
    session.beginConfiguration()
    if let previous { session.removeInput(previous) }
    do {
      try addInput(facing: facing)
    } catch {
      if let previous, session.canAddInput(previous) {
        session.addInput(previous)
        input = previous
      }
      session.commitConfiguration()
      throw error
    }
    session.commitConfiguration()
    if wasRunning, !session.isRunning { Task { try? await start() } }
  }

  private func apply(_ configuration: QRScannerConfiguration) throws {
    try setZoom(configuration.zoomScale)
    if configuration.torchEnabled { try setTorch(enabled: true) }
  }

  private func toggleTorch() throws {
    guard let device = input?.device else {
      throw QRScannerError.unavailable("The selected camera has no torch")
    }
    guard device.hasTorch else { return }
    try setTorch(enabled: device.torchMode != .on)
  }

  private func setTorch(enabled: Bool) throws {
    guard let device = input?.device, device.hasTorch else { return }
    let mode: AVCaptureDevice.TorchMode = enabled ? .on : .off
    guard device.isTorchModeSupported(mode) else { return }
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }
    if enabled { try device.setTorchModeOn(level: 1) } else { device.torchMode = .off }
  }

  private func setZoom(_ normalizedScale: Double) throws {
    guard let device = input?.device else {
      throw QRScannerError.unavailable("QR scanner is not running")
    }
    #if os(iOS)
      let requested = CGFloat(min(max(normalizedScale, 0), 1) * 4 + 1)
      try device.lockForConfiguration()
      device.videoZoomFactor = min(5, requested, device.activeFormat.videoMaxZoomFactor)
      device.unlockForConfiguration()
    #endif
  }

  private func registerLifecycleObservers() {
    #if os(iOS)
      let inactive = UIApplication.willResignActiveNotification
      let resumed = UIApplication.didBecomeActiveNotification
    #elseif os(macOS)
      let inactive = NSApplication.didResignActiveNotification
      let resumed = NSApplication.didBecomeActiveNotification
    #endif
    lifecycleObservers.append(NotificationCenter.default.addObserver(
      forName: inactive, object: nil, queue: .main
    ) { [weak self] _ in Task { @MainActor in self?.pause() } })
    lifecycleObservers.append(NotificationCenter.default.addObserver(
      forName: resumed, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self, self.shouldRun, self.mounted else { return }
        try? await self.start()
      }
    })
  }

  private func report(_ error: Error, stackTrace: String? = nil) {
    guard let control, control.hasEventHandler("error") else { return }
    control.triggerEvent("error", data: QRScannerErrorEvent.payload(error, stackTrace: stackTrace))
  }

  static func visionSymbologies(_ formats: [QRScannerBarcodeFormat]) -> [VNBarcodeSymbology] {
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
      case .itf2of5: return .i2of5
      case .itf2of5WithChecksum: return .i2of5Checksum
      case .itf, .itf14: return .itf14
      case .upcE: return .upce
      case .pdf417: return .pdf417
      case .aztec: return .aztec
      case .dataBar:
        if #available(iOS 15, macOS 12, *) { return .gs1DataBar }
        return nil
      case .dataBarExpanded:
        if #available(iOS 15, macOS 12, *) { return .gs1DataBarExpanded }
        return nil
      case .dataBarLimited:
        if #available(iOS 15, macOS 12, *) { return .gs1DataBarLimited }
        return nil
      case .upcA, .maxiCode, .microQrCode, .unknown, .all: return nil
      }
    }
  }

  func updateScanWindow(_ rect: CGRect?) {
    guard let rect else {
      visionRegionOfInterest = nil
      return
    }
    visionRegionOfInterest = CGRect(
      x: rect.minX, y: 1 - rect.maxY, width: rect.width, height: rect.height)
  }

  nonisolated func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    Task { @MainActor in self.process(buffer) }
  }

  private func process(_ buffer: CVPixelBuffer) {
    guard let control, control.hasEventHandler("detect") else { return }
    let now = Date()
    if QRScannerDetectionState.shouldThrottle(
      speed: configuration.detectionSpeed,
      elapsedMilliseconds: now.timeIntervalSince(lastDetection) * 1_000,
      timeoutMilliseconds: configuration.detectionTimeoutMilliseconds)
    { return }
    if configuration.detectionSpeed != .unrestricted, processingFrame { return }
    lastDetection = now
    processingFrame = configuration.detectionSpeed != .unrestricted

    var image = CIImage(cvPixelBuffer: buffer)
    if configuration.invertImage { image = image.applyingFilter("CIColorInvert") }
    let extent = image.extent
    let request = VNDetectBarcodesRequest { [weak self] request, error in
      Task { @MainActor in
        guard let self else { return }
        self.processingFrame = false
        if let error { self.report(error); return }
        self.consume(
          (request.results as? [VNBarcodeObservation]) ?? [],
          image: image,
          imageWidth: Int(extent.width),
          imageHeight: Int(extent.height))
      }
    }
    let requested = Self.visionSymbologies(configuration.formats)
    if !requested.isEmpty { request.symbologies = requested }
    if let visionRegionOfInterest { request.regionOfInterest = visionRegionOfInterest }
    let controller = self
    Task.detached {
      do { try VNImageRequestHandler(ciImage: image).perform([request]) }
      catch {
        await MainActor.run {
          controller.processingFrame = false
          controller.report(error)
        }
      }
    }
  }

  private func consume(
    _ observations: [VNBarcodeObservation],
    image: CIImage,
    imageWidth: Int,
    imageHeight: Int
  ) {
    guard !observations.isEmpty, let control, control.hasEventHandler("detect") else { return }
    guard detectionState.accepts(
      observations.map(\.payloadStringValue), speed: configuration.detectionSpeed)
    else { return }
    if configuration.autoZoom, let first = observations.first { applyAutoZoom(first.boundingBox) }
    var payload: [String: RufletValue] = [
      "value": observations.first?.payloadStringValue.map(RufletValue.string) ?? .null,
      "barcodes": .array(observations.map {
        QRScannerVisionBarcode(
          observation: $0,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          scanWindow: visionRegionOfInterest).rufletValue
      }),
    ]
    if configuration.returnImage,
      let data = CIContext().jpegRepresentation(
        of: image,
        colorSpace: CGColorSpaceCreateDeviceRGB(),
        options: [
          CIImageRepresentationOption(
            rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.8
        ])
    {
      payload["image"] = .string(data.base64EncodedString())
    }
    control.triggerEvent("detect", data: .map(payload))
  }

  private func applyAutoZoom(_ bounds: CGRect) {
    #if os(iOS)
      guard let device = input?.device else { return }
      let side = max(bounds.width, bounds.height)
      guard side > 0, side < 0.35 else { return }
      let desiredFactor = min(device.videoZoomFactor * (0.35 / side), 5)
      try? setZoom(Double((desiredFactor - 1) / 4))
    #endif
  }
}

struct QRScannerVisionBarcode {
  let rawValue: String?
  let displayValue: String?
  let format: String
  let type: QRScannerBarcodeType
  let corners: [CGPoint]

  init(
    observation: VNBarcodeObservation,
    imageWidth: Int,
    imageHeight: Int,
    scanWindow: CGRect?
  ) {
    rawValue = observation.payloadStringValue
    if let value = observation.payloadStringValue,
      let bytes = value.data(using: .isoLatin1),
      let utf8 = String(data: bytes, encoding: .utf8)
    { displayValue = utf8 } else { displayValue = observation.payloadStringValue }
    format = Self.formatName(observation.symbology)
    type = .detect(observation.payloadStringValue)
    corners = Self.pixelCorners(
      topLeft: observation.topLeft,
      topRight: observation.topRight,
      bottomRight: observation.bottomRight,
      bottomLeft: observation.bottomLeft,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      scanWindow: scanWindow)
  }

  var rufletValue: RufletValue {
    var payload: [String: RufletValue] = [
      "raw_value": rawValue.map(RufletValue.string) ?? .null,
      "display_value": displayValue.map(RufletValue.string) ?? .null,
      "format": .string(format),
      "type": .string(type.rawValue),
    ]
    if !corners.isEmpty {
      payload["corners"] = .array(corners.map {
        .map(["x": .double($0.x), "y": .double($0.y)])
      })
    }
    return .map(payload)
  }

  static func pixelCorners(
    topLeft: CGPoint,
    topRight: CGPoint,
    bottomRight: CGPoint,
    bottomLeft: CGPoint,
    imageWidth: Int,
    imageHeight: Int,
    scanWindow: CGRect?
  ) -> [CGPoint] {
    func adjusted(_ point: CGPoint) -> CGPoint {
      guard let scanWindow else { return point }
      return CGPoint(
        x: scanWindow.minX + point.x * scanWindow.width,
        y: scanWindow.minY + point.y * scanWindow.height)
    }
    func pixels(_ point: CGPoint) -> CGPoint {
      let point = adjusted(point)
      return CGPoint(
        x: point.x * CGFloat(imageWidth),
        y: (1 - point.y) * CGFloat(imageHeight))
    }
    #if os(macOS)
      return [pixels(topRight), pixels(topLeft), pixels(bottomLeft), pixels(bottomRight)]
    #else
      return [pixels(topLeft), pixels(topRight), pixels(bottomRight), pixels(bottomLeft)]
    #endif
  }

  static func formatName(_ symbology: VNBarcodeSymbology) -> String {
    if #available(iOS 15, macOS 12, *) {
      switch symbology {
      case .codabar: return "codabar"
      case .gs1DataBar: return "dataBar"
      case .gs1DataBarExpanded: return "dataBarExpanded"
      case .gs1DataBarLimited: return "dataBarLimited"
      default: break
      }
    }
    switch symbology {
    case .code128: return "code128"
    case .code39: return "code39"
    case .code93: return "code93"
    case .dataMatrix: return "dataMatrix"
    case .ean13: return "ean13"
    case .ean8: return "ean8"
    case .i2of5: return "itf2of5"
    case .i2of5Checksum: return "itf2of5WithChecksum"
    case .itf14: return "itf14"
    case .qr: return "qrCode"
    case .upce: return "upcE"
    case .pdf417: return "pdf417"
    case .aztec: return "aztec"
    default: return "unknown"
    }
  }
}
