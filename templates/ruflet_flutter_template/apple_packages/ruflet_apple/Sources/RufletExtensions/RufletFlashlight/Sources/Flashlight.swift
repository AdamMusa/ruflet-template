import AVFoundation
import RufletEngine
import RufletProtocol

@MainActor
public final class FlashlightService: RufletService {
  private var invokeToken: UUID?

  public required init(control: RufletControl) {
    super.init(control: control)
  }

  public override func initialize() {
    invokeToken = control.addInvokeMethodListener { [weak self] name, _ in
      guard let self else { return .null }
      return try self.invoke(name)
    }
  }

  public override func dispose() {
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
  }

  private func invoke(_ name: String) throws -> RufletValue {
    switch name {
    case "on":
      try setTorch(enabled: true)
      return .null
    case "off":
      try setTorch(enabled: false)
      return .null
    case "is_available":
      return .bool(Self.torchDevice?.hasTorch == true)
    default:
      throw RufletFlashlightError.unknownMethod(name)
    }
  }

  private func setTorch(enabled: Bool) throws {
    guard let device = Self.torchDevice, device.hasTorch else {
      throw RufletFlashlightError.unavailable
    }
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }
    if enabled {
      try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
    } else {
      device.torchMode = .off
    }
  }

  private static var torchDevice: AVCaptureDevice? {
    #if os(iOS)
    AVCaptureDevice.default(for: .video)
    #elseif os(macOS)
    nil
    #endif
  }
}

public enum RufletFlashlightError: Error, Equatable, Sendable {
  case unavailable
  case unknownMethod(String)
}
