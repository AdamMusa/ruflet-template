import AVFoundation
import SwiftUI

public struct RufletCameraPreview: View {
  public let session: AVCaptureSession
  public var previewEnabled: Bool
  public var overlay: AnyView?

  public init(session: AVCaptureSession, previewEnabled: Bool = true, overlay: AnyView? = nil) {
    self.session = session
    self.previewEnabled = previewEnabled
    self.overlay = overlay
  }

  public var body: some View {
    ZStack {
      if previewEnabled {
        PreviewRepresentable(session: session)
      }
      overlay
    }
  }
}

#if os(iOS)
private struct PreviewRepresentable: UIViewRepresentable {
  let session: AVCaptureSession

  func makeUIView(context: Context) -> PreviewView {
    let view = PreviewView()
    view.layer.videoGravity = .resizeAspect
    view.layer.session = session
    return view
  }

  func updateUIView(_ view: PreviewView, context: Context) {
    view.layer.session = session
  }
}

private final class PreviewView: UIView {
  override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
  override var layer: AVCaptureVideoPreviewLayer { super.layer as! AVCaptureVideoPreviewLayer }
}
#elseif os(macOS)
private struct PreviewRepresentable: NSViewRepresentable {
  let session: AVCaptureSession

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    view.wantsLayer = true
    let preview = AVCaptureVideoPreviewLayer(session: session)
    preview.videoGravity = .resizeAspect
    preview.frame = view.bounds
    preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    view.layer = preview
    return view
  }

  func updateNSView(_ view: NSView, context: Context) {
    (view.layer as? AVCaptureVideoPreviewLayer)?.session = session
  }
}
#endif
