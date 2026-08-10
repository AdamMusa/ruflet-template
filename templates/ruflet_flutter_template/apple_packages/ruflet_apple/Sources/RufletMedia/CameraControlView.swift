import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

#if canImport(AVFoundation)
  import AVFoundation
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
    .onAppear { model.start(node: node) }
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
    private var pendingCapture: RufletMethodCompletion?
    private var configured = false
  #endif

  func start(node: ControlNode) {
    #if canImport(AVFoundation) && !targetEnvironment(simulator)
      configure(node: node)
      guard !session.isRunning else { return }
      // Starting blocks; AVFoundation asks that it happen off the main thread.
      let session = session
      Task.detached { session.startRunning() }
    #endif
  }

  func stop() {
    #if canImport(AVFoundation) && !targetEnvironment(simulator)
      guard session.isRunning else { return }
      let session = session
      Task.detached { session.stopRunning() }
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
            "id": .string(device.uniqueID),
            "name": .string(device.localizedName),
            "lens_direction": .string(device.position == .front ? "front" : "back")
          ])
        })))
      case "initialize":
        #if targetEnvironment(simulator)
          completion(.failure(RufletServiceError.unavailable("No camera on this simulator")))
        #else
          configure(node: node)
          start(node: node)
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
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        #endif
      case "start", "resume":
        start(node: node)
        completion(.success(.null))
      case "stop", "pause":
        stop()
        completion(.success(.null))
      default:
        completion(.failure(rufletUnsupported("Camera", call)))
      }
    #else
      completion(
        .failure(RufletServiceError.unavailable("No capture device on this platform")))
    #endif
  }
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
          completion?(.failure(RufletServiceError.failed(error.localizedDescription)))
        } else if let data {
          completion?(.success(.binary([UInt8](data))))
        } else {
          completion?(.failure(RufletServiceError.failed("The photo produced no data")))
        }
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
