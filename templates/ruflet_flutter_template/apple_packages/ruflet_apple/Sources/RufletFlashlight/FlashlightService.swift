import Foundation
import RufletEngine
import RufletProtocol

#if canImport(AVFoundation)
  @preconcurrency import AVFoundation
#endif
#if canImport(UIKit)
  import UIKit
#endif
#if canImport(AppKit)
  import AppKit
#endif

/// `Flashlight` — the camera torch.
@MainActor
public final class FlashlightService: RufletService {
  public static let wireType = "Flashlight"

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    #if canImport(AVFoundation) && os(iOS)
      guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
        return call.name == "is_available"
          ? completion(.success(.bool(false)))
          : completion(.failure(RufletServiceError.unavailable("This device has no torch")))
      }

      switch call.name {
      case "is_available":
        completion(.success(.bool(true)))
      case "on", "off":
        do {
          try device.lockForConfiguration()
          device.torchMode = call.name == "on" ? .on : .off
          device.unlockForConfiguration()
          completion(.success(.null))
        } catch {
          completion(.failure(RufletServiceError.failed(error.localizedDescription)))
        }
      default:
        completion(
          .failure(RufletServiceError.unsupportedMethod(type: "Flashlight", method: call.name)))
      }
    #else
      call.name == "is_available"
        ? completion(.success(.bool(false)))
        : completion(.failure(RufletServiceError.unavailable("No torch on this platform")))
    #endif
  }
}
