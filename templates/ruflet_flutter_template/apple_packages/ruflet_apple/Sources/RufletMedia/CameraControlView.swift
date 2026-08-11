import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

#if canImport(AVFoundation)
  import AVFoundation
  import CoreImage
#endif

/// `Camera` — a live preview plus the capture methods.
///
/// Ruflet treats camera as a *visual* service (`Page#visual_service_type?`), so
/// unlike the other services it appears in the control tree and has to render.
public struct CameraControlView: View {
  let node: ControlNode
  @StateObject private var model = CameraModel()

  public init(node: ControlNode) { self.node = node }
  @Environment(\.rufletEvents) private var events

  public var body: some View {
    Group {
      #if canImport(AVFoundation) && !targetEnvironment(simulator)
        CameraPreview(model: model)
      #else
        // The simulator has no capture device; a black frame is what a camera
        // view looks like there, and it keeps the layout honest.
        Color.black
      #endif
    }
    .onAppear { model.start(node: node, events: events) }
    .onDisappear { model.stop() }
    .rufletCommandHandler(node.id) { call, completion in
      model.handle(call, node: node, events: events, completion: completion)
    }
  }
}

@MainActor
final class CameraModel: NSObject, ObservableObject {
  #if canImport(AVFoundation)
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "com.izeesoft.ruflet.camera.images")
    private var pendingCapture: RufletMethodCompletion?
    private var configured = false
    private var streamingImages = false
    private var control: ControlNode?
    private var events = RufletEventSink()
  #endif

  func start(node: ControlNode, events: RufletEventSink) {
    #if canImport(AVFoundation) && !targetEnvironment(simulator)
      control = node
      self.events = events
      configure(node: node)
      guard !session.isRunning else { return }
      // Starting blocks; AVFoundation asks that it happen off the main thread.
      let session = session
      Task { [weak self] in
        await Task.detached { session.startRunning() }.value
        self?.emitState()
      }
    #endif
  }

  func stop() {
    #if canImport(AVFoundation) && !targetEnvironment(simulator)
      guard session.isRunning else { return }
      let session = session
      Task { [weak self] in
        await Task.detached { session.stopRunning() }.value
        self?.emitState()
      }
    #endif
  }

  #if canImport(AVFoundation)
    private func configure(node: ControlNode) {
      guard !configured else { return }
      configured = true

      session.beginConfiguration()
      session.sessionPreset = .photo

      // Flet's camera names the lens as "front"/"back".
      let wantsFront = node.string("lens_direction")?.lowercased() == "front"
      if let device = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera],
        mediaType: .video,
        position: wantsFront ? .front : .back
      ).devices.first,
        let input = try? AVCaptureDeviceInput(device: device),
        session.canAddInput(input)
      {
        session.addInput(input)
      }
      if session.canAddOutput(photoOutput) {
        session.addOutput(photoOutput)
      }
      session.commitConfiguration()
    }
  #endif

  func handle(
    _ call: RufletMethodCall,
    node: ControlNode,
    events: RufletEventSink,
    completion: @escaping RufletMethodCompletion
  ) {
    #if canImport(AVFoundation)
      switch call.name {
      case "get_available_cameras", "get_cameras", "available_cameras":
        let devices = AVCaptureDevice.DiscoverySession(
          deviceTypes: [.builtInWideAngleCamera],
          mediaType: .video,
          position: .unspecified
        ).devices
        completion(.success(.array(devices.map { device in
          .map([
            "name": .string(device.localizedName),
            "lens_direction": .string(device.position == .front ? "front" : "back"),
            "sensor_orientation": .int(device.position == .front ? 270 : 90),
            "lens_type": .string("wide")
          ])
        })))
      case "initialize":
        #if targetEnvironment(simulator)
          completion(.failure(RufletServiceError.unavailable("No camera on this simulator")))
        #else
          configure(node: node)
          start(node: node, events: events)
          emitState()
          completion(.success(.null))
        #endif
      case "take_picture", "capture":
        #if targetEnvironment(simulator)
          completion(.failure(RufletServiceError.unavailable("No camera on this simulator")))
        #else
        guard pendingCapture == nil else {
          return completion(.failure(RufletServiceError.failed("A capture is already in flight")))
        }
        pendingCapture = completion
        emitState(takingPicture: true)
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        #endif
      case "start", "resume":
        start(node: node, events: events)
        completion(.success(.null))
      case "stop", "pause":
        stop()
        completion(.success(.null))
      case "start_image_stream":
        startImageStream(node: node, events: events, completion: completion)
      case "stop_image_stream":
        stopImageStream(completion: completion)
      case "supports_image_streaming":
        completion(.success(.bool(true)))
      default:
        completion(.failure(rufletUnsupported("Camera", call)))
      }
    #else
      completion(
        .failure(RufletServiceError.unavailable("No capture device on this platform")))
    #endif
  }

  #if canImport(AVFoundation)
    private func startImageStream(
      node: ControlNode,
      events: RufletEventSink,
      completion: @escaping RufletMethodCompletion
    ) {
      control = node
      self.events = events
      configure(node: node)
      guard !streamingImages else { return completion(.success(.null)) }
      videoOutput.alwaysDiscardsLateVideoFrames = true
      videoOutput.videoSettings = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
      ]
      videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
      session.beginConfiguration()
      if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
      session.commitConfiguration()
      streamingImages = session.outputs.contains { $0 === videoOutput }
      emitState()
      completion(.success(.null))
    }

    private func stopImageStream(completion: @escaping RufletMethodCompletion) {
      guard streamingImages else { return completion(.success(.null)) }
      videoOutput.setSampleBufferDelegate(nil, queue: nil)
      session.beginConfiguration()
      session.removeOutput(videoOutput)
      session.commitConfiguration()
      streamingImages = false
      emitState()
      completion(.success(.null))
    }

    private func emitState(takingPicture: Bool = false) {
      guard let control else { return }
      events.fire(control, "state_change", data: stateValue(takingPicture: takingPicture))
    }

    private func stateValue(takingPicture: Bool = false) -> RufletValue {
      let input = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }.first
      let device = input?.device
      var state: [String: RufletValue] = [
        "is_initialized": .bool(configured),
        "is_recording_video": .bool(false),
        "is_recording_paused": .bool(false),
        "is_taking_picture": .bool(takingPicture),
        "is_streaming_images": .bool(streamingImages),
        "is_preview_paused": .bool(!session.isRunning),
        "is_capture_orientation_locked": .bool(false),
        "has_error": .bool(false)
      ]
      if let device {
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        let width = Double(dimensions.width)
        let height = Double(dimensions.height)
        state["description"] = .map([
          "name": .string(device.localizedName),
          "lens_direction": .string(device.position == .front ? "front" : "back"),
          "sensor_orientation": .int(device.position == .front ? 270 : 90),
          "lens_type": .string("wide")
        ])
        state["device_orientation"] = .string("portrait_up")
        state["flash_mode"] = .string("auto")
        state["exposure_mode"] = .string(
          device.exposureMode == .continuousAutoExposure ? "auto" : "locked")
        state["focus_mode"] = .string(
          device.focusMode == .continuousAutoFocus ? "auto" : "locked")
        state["exposure_point_supported"] = .bool(device.isExposurePointOfInterestSupported)
        state["focus_point_supported"] = .bool(device.isFocusPointOfInterestSupported)
        state["preview_size"] = .map([
          "width": .double(width),
          "height": .double(height)
        ])
        if height > 0 { state["aspect_ratio"] = .double(width / height) }
      }
      return .map(state)
    }
  #endif
}

#if canImport(AVFoundation)
  extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
      _ output: AVCapturePhotoOutput,
      didFinishProcessingPhoto photo: AVCapturePhoto,
      error: Error?
    ) {
      let data = photo.fileDataRepresentation()
      Task { @MainActor in
        let completion = pendingCapture
        pendingCapture = nil
        if let error {
          emitState()
          completion?(.failure(RufletServiceError.failed(error.localizedDescription)))
        } else if let data {
          emitState()
          completion?(.success(.binary([UInt8](data))))
        } else {
          completion?(.failure(RufletServiceError.failed("The photo produced no data")))
        }
      }
    }
  }

  extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
      _ output: AVCaptureOutput,
      didOutput sampleBuffer: CMSampleBuffer,
      from connection: AVCaptureConnection
    ) {
      guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
      let image = CIImage(cvPixelBuffer: imageBuffer)
      let context = CIContext(options: nil)
      guard let data = context.jpegRepresentation(
        of: image,
        colorSpace: CGColorSpaceCreateDeviceRGB(),
        options: [:]
      ) else { return }
      let width = CVPixelBufferGetWidth(imageBuffer)
      let height = CVPixelBufferGetHeight(imageBuffer)
      Task { @MainActor [data] in
        guard let control = self.control else { return }
        self.events.fire(control, "stream_image", data: .map([
          "width": .int(Int64(width)),
          "height": .int(Int64(height)),
          "format": .string("bgra8888"),
          "encoded_format": .string("jpeg"),
          "bytes": .binary([UInt8](data))
        ]))
      }
    }
  }

  #if !targetEnvironment(simulator)
    /// `AVCaptureVideoPreviewLayer` is a CALayer, so it needs a hosting view on
    /// each platform.
    private struct CameraPreview {
      let model: CameraModel
    }

    #if canImport(UIKit)
      final class CameraPreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
      }

      extension CameraPreview: UIViewRepresentable {
        func makeUIView(context: Context) -> CameraPreviewView {
          let view = CameraPreviewView()
          view.previewLayer.session = model.session
          view.previewLayer.videoGravity = .resizeAspectFill
          return view
        }
        func updateUIView(_ view: CameraPreviewView, context: Context) {}
      }
    #elseif canImport(AppKit)
      extension CameraPreview: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
          let view = NSView()
          view.wantsLayer = true
          let preview = AVCaptureVideoPreviewLayer(session: model.session)
          preview.videoGravity = .resizeAspectFill
          preview.frame = view.bounds
          preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
          view.layer = preview
          return view
        }
        func updateNSView(_ view: NSView, context: Context) {}
      }
    #endif
  #endif
#endif
