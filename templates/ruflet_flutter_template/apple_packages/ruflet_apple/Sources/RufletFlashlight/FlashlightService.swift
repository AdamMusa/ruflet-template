import Foundation
import RufletEngine
import RufletProtocol

#if canImport(AVFoundation)
  @preconcurrency import AVFoundation
#endif

public enum FletFlashlightPlatform: Equatable {
  case iOS
  case unsupported
}

public enum FletFlashlightMethod: String, CaseIterable, Equatable {
  case on
  case off
  case isAvailable = "is_available"
}

/// Narrow hardware boundary matching torch_light 1.1.0's iOS plugin. Keeping
/// capture-device existence separate from `hasTorch` preserves its distinct
/// error-versus-false behavior.
@MainActor
public protocol RufletFlashlightBackend: AnyObject {
  var hasCaptureDevice: Bool { get }
  var hasTorch: Bool { get }
  func setTorchEnabled(_ enabled: Bool) throws
}

@MainActor
public final class FlashlightService: RufletService {
  public static let wireType = "Flashlight"

  private let platform: FletFlashlightPlatform
  private let backend: RufletFlashlightBackend

  public init() {
    #if canImport(AVFoundation) && os(iOS)
      platform = .iOS
      backend = AVFoundationFlashlightBackend()
    #else
      platform = .unsupported
      backend = UnavailableFlashlightBackend()
    #endif
  }

  public init(platform: FletFlashlightPlatform, backend: RufletFlashlightBackend) {
    self.platform = platform
    self.backend = backend
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    // Flet checks `isMobilePlatform()` before dispatching the method switch,
    // so even `is_available` throws on macOS rather than returning false.
    guard platform == .iOS else {
      return completion(.failure(RufletServiceError.platformUnsupported(
        type: Self.wireType, method: call.name, platform: "Apple non-mobile")))
    }
    guard let method = FletFlashlightMethod(rawValue: call.name) else {
      return completion(.failure(RufletServiceError.unsupportedMethod(
        type: Self.wireType, method: call.name)))
    }

    switch method {
    case .isAvailable:
      // torch_light reports a plugin error when AVCaptureDevice itself is
      // absent; `false` is reserved for a real video device without a torch.
      guard backend.hasCaptureDevice else {
        return completion(.failure(RufletServiceError.failed(
          "Could not determine if the device has a torch; use a physical iOS device")))
      }
      completion(.success(.bool(backend.hasTorch)))

    case .on, .off:
      let enabling = method == .on
      guard backend.hasCaptureDevice else {
        return completion(.failure(RufletServiceError.failed(
          "Could not \(enabling ? "enable" : "disable") torch; use a physical iOS device")))
      }
      guard backend.hasTorch else {
        return completion(.failure(RufletServiceError.unavailable("Torch is not available")))
      }
      do {
        try backend.setTorchEnabled(enabling)
        completion(.success(.null))
      } catch {
        completion(.failure(RufletServiceError.failed(
          "Could not \(enabling ? "enable" : "disable") torch: \(error.localizedDescription)")))
      }
    }
  }
}

@MainActor
private final class UnavailableFlashlightBackend: RufletFlashlightBackend {
  let hasCaptureDevice = false
  let hasTorch = false
  func setTorchEnabled(_ enabled: Bool) throws {}
}

#if canImport(AVFoundation) && os(iOS)
  @MainActor
  private final class AVFoundationFlashlightBackend: RufletFlashlightBackend {
    private let device: AVCaptureDevice?

    init(device: AVCaptureDevice? = AVCaptureDevice.default(for: .video)) {
      self.device = device
    }

    var hasCaptureDevice: Bool { device != nil }
    var hasTorch: Bool { device?.hasTorch == true }

    func setTorchEnabled(_ enabled: Bool) throws {
      guard let device else { return }
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }
      device.torchMode = enabled ? .on : .off
    }
  }
#endif
