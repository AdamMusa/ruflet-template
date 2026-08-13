import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum RufletCameraLensDirection: String, Sendable {
  case front
  case back
  case external
}

public enum RufletCameraLensType: String, Sendable {
  case wide
  case telephoto
  case ultraWide
  case dual
  case triple
  case trueDepth
  case external
  case unknown
}

public struct RufletCameraDescription: Equatable, Sendable {
  public let name: String
  public let lensDirection: RufletCameraLensDirection
  public let sensorOrientation: Int
  public let lensType: RufletCameraLensType

  public init(
    name: String,
    lensDirection: RufletCameraLensDirection,
    sensorOrientation: Int,
    lensType: RufletCameraLensType
  ) {
    self.name = name
    self.lensDirection = lensDirection
    self.sensorOrientation = sensorOrientation
    self.lensType = lensType
  }

  public var map: [String: Any] {
    [
      "name": name,
      "lens_direction": lensDirection.rawValue,
      "sensor_orientation": sensorOrientation,
      "lens_type": lensType.rawValue,
    ]
  }
}

public struct RufletCameraImage: Equatable, Sendable {
  public let width: Int
  public let height: Int
  public let format: String
  public let encodedFormat: String
  public let bytes: Data

  public init(width: Int, height: Int, format: String, encodedFormat: String, bytes: Data) {
    self.width = width
    self.height = height
    self.format = format
    self.encodedFormat = encodedFormat
    self.bytes = bytes
  }
}

public enum RufletResolutionPreset: String, Sendable {
  case low
  case medium
  case high
  case veryHigh
  case ultraHigh
  case max

  var sessionPreset: AVCaptureSession.Preset {
    switch self {
    case .low: .low
    case .medium: .medium
    case .high: .high
    case .veryHigh: .hd1920x1080
    case .ultraHigh, .max: .hd4K3840x2160
    }
  }
}

public enum RufletCameraFlashMode: String, Sendable {
  case off
  case auto
  case always
  case torch
}

public enum RufletCameraExposureMode: String, Sendable {
  case auto
  case locked
}

public enum RufletCameraFocusMode: String, Sendable {
  case auto
  case locked
}

public struct RufletCameraState: Sendable {
  public var isInitialized = false
  public var isRecordingVideo = false
  public var isRecordingPaused = false
  public var isTakingPicture = false
  public var isStreamingImages = false
  public var isPreviewPaused = false
  public var isCaptureOrientationLocked = false
  public var flashMode: RufletCameraFlashMode = .off
  public var exposureMode: RufletCameraExposureMode = .auto
  public var focusMode: RufletCameraFocusMode = .auto
  public var exposurePointSupported = false
  public var focusPointSupported = false
  public var previewSize: CGSize?
  public var errorDescription: String?
  public var description: RufletCameraDescription?

  public var map: [String: Any] {
    var value: [String: Any] = [
      "is_initialized": isInitialized,
      "is_recording_video": isRecordingVideo,
      "is_recording_paused": isRecordingPaused,
      "is_taking_picture": isTakingPicture,
      "is_streaming_images": isStreamingImages,
      "is_preview_paused": isPreviewPaused,
      "is_capture_orientation_locked": isCaptureOrientationLocked,
      "flash_mode": flashMode.rawValue,
      "exposure_mode": exposureMode.rawValue,
      "focus_mode": focusMode.rawValue,
      "exposure_point_supported": exposurePointSupported,
      "focus_point_supported": focusPointSupported,
      "has_error": errorDescription != nil,
    ]
    if let previewSize {
      value["preview_size"] = ["width": previewSize.width, "height": previewSize.height]
      value["aspect_ratio"] = previewSize.height == 0 ? 0 : previewSize.width / previewSize.height
    }
    value["error_description"] = errorDescription
    value["description"] = description?.map
    return value.compactMapValues { $0 }
  }
}

enum RufletCameraMapping {
  static func description(for device: AVCaptureDevice) -> RufletCameraDescription {
    RufletCameraDescription(
      name: device.uniqueID,
      lensDirection: lensDirection(for: device.position),
      sensorOrientation: sensorOrientation(for: device.position),
      lensType: lensType(for: device.deviceType))
  }

  static func lensDirection(for position: AVCaptureDevice.Position) -> RufletCameraLensDirection {
    switch position {
    case .front: .front
    case .back: .back
    case .unspecified: .external
    @unknown default: .external
    }
  }

  static func sensorOrientation(for position: AVCaptureDevice.Position) -> Int {
    switch position {
    case .front: 270
    case .back: 90
    case .unspecified: 0
    @unknown default: 0
    }
  }

  static func lensType(for type: AVCaptureDevice.DeviceType) -> RufletCameraLensType {
    #if os(iOS)
    switch type {
    case .builtInWideAngleCamera: .wide
    case .builtInTelephotoCamera: .telephoto
    case .builtInUltraWideCamera: .ultraWide
    case .builtInDualCamera, .builtInDualWideCamera: .dual
    case .builtInTripleCamera: .triple
    case .builtInTrueDepthCamera: .trueDepth
    case .external: .external
    default: .unknown
    }
    #elseif os(macOS)
    return type == .builtInWideAngleCamera ? .wide : .external
    #endif
  }

  static func jpegData(from sampleBuffer: CMSampleBuffer) -> Data? {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
    let context = CIContext(options: nil)
    guard let image = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
      data,
      UTType.jpeg.identifier as CFString,
      1,
      nil)
    else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
  }
}
