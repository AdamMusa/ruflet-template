import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

@MainActor
final class RufletScreenshotCaptureCoordinator: ObservableObject {
  private var captureHandler: ((CGFloat) -> Data?)?

  func install(_ handler: @escaping (CGFloat) -> Data?) {
    captureHandler = handler
  }

  func uninstall() {
    captureHandler = nil
  }

  func capture(pixelRatio: CGFloat) -> Data? {
    captureHandler?(pixelRatio)
  }
}

#if os(iOS)
  struct RufletScreenshotCaptureHost: UIViewControllerRepresentable {
    let content: AnyView
    let captureCoordinator: RufletScreenshotCaptureCoordinator

    func makeUIViewController(context: Context) -> RufletScreenshotViewController {
      let controller = RufletScreenshotViewController(content: content)
      // SwiftUI may expose the control to Ruby before its first update pass.
      // Register during creation so an immediate `capture()` invocation never
      // observes an empty coordinator.
      captureCoordinator.install(controller.capture(pixelRatio:))
      return controller
    }

    func updateUIViewController(_ controller: RufletScreenshotViewController, context: Context) {
      controller.update(content: content)
      captureCoordinator.install(controller.capture(pixelRatio:))
    }

    func sizeThatFits(
      _ proposal: ProposedViewSize,
      uiViewController controller: RufletScreenshotViewController,
      context: Context
    ) -> CGSize? {
      controller.sizeThatFits(proposal)
    }

    static func dismantleUIViewController(
      _ controller: RufletScreenshotViewController,
      coordinator: ()
    ) {}
  }

  final class RufletScreenshotViewController: UIViewController {
    private let host: UIHostingController<AnyView>

    init(content: AnyView) {
      host = UIHostingController(rootView: content)
      super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .clear
      addChild(host)
      host.view.translatesAutoresizingMaskIntoConstraints = false
      host.view.backgroundColor = .clear
      view.addSubview(host.view)
      NSLayoutConstraint.activate([
        host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        host.view.topAnchor.constraint(equalTo: view.topAnchor),
        host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])
      host.didMove(toParent: self)
    }

    func update(content: AnyView) {
      host.rootView = content
      host.view.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize {
      let fittingWidth = proposal.width ?? UIView.layoutFittingExpandedSize.width
      let fittingHeight = proposal.height ?? UIView.layoutFittingExpandedSize.height
      return host.sizeThatFits(in: CGSize(width: fittingWidth, height: fittingHeight))
    }

    func capture(pixelRatio: CGFloat) -> Data? {
      let bounds = view.bounds
      guard bounds.width > 0, bounds.height > 0 else { return nil }
      view.layoutIfNeeded()
      let format = UIGraphicsImageRendererFormat()
      format.scale = pixelRatio
      format.opaque = view.isOpaque
      let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
      return renderer.image { _ in
        view.drawHierarchy(in: bounds, afterScreenUpdates: true)
      }.pngData()
    }
  }

#elseif os(macOS)
  struct RufletScreenshotCaptureHost: NSViewControllerRepresentable {
    let content: AnyView
    let captureCoordinator: RufletScreenshotCaptureCoordinator

    func makeNSViewController(context: Context) -> RufletScreenshotViewController {
      let controller = RufletScreenshotViewController(content: content)
      captureCoordinator.install(controller.capture(pixelRatio:))
      return controller
    }

    func updateNSViewController(_ controller: RufletScreenshotViewController, context: Context) {
      controller.update(content: content)
      captureCoordinator.install(controller.capture(pixelRatio:))
    }

    static func dismantleNSViewController(
      _ controller: RufletScreenshotViewController,
      coordinator: ()
    ) {}
  }

  final class RufletScreenshotViewController: NSViewController {
    private let host: NSHostingController<AnyView>

    init(content: AnyView) {
      host = NSHostingController(rootView: content)
      super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
      view = NSView(frame: .zero)
      addChild(host)
      host.view.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(host.view)
      NSLayoutConstraint.activate([
        host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        host.view.topAnchor.constraint(equalTo: view.topAnchor),
        host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])
    }

    func update(content: AnyView) {
      host.rootView = content
    }

    func capture(pixelRatio: CGFloat) -> Data? {
      let bounds = view.bounds
      guard bounds.width > 0, bounds.height > 0 else { return nil }
      view.layoutSubtreeIfNeeded()
      guard
        let representation = NSBitmapImageRep(
          bitmapDataPlanes: nil,
          pixelsWide: max(Int((bounds.width * pixelRatio).rounded()), 1),
          pixelsHigh: max(Int((bounds.height * pixelRatio).rounded()), 1),
          bitsPerSample: 8,
          samplesPerPixel: 4,
          hasAlpha: true,
          isPlanar: false,
          colorSpaceName: .deviceRGB,
          bytesPerRow: 0,
          bitsPerPixel: 0)
      else { return nil }
      representation.size = bounds.size
      view.cacheDisplay(in: bounds, to: representation)
      return representation.representation(using: .png, properties: [:])
    }
  }
#endif
