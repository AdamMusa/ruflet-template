import CoreGraphics
import Foundation
import RufletEngine
import RufletProtocol

enum QRScannerCameraFacing: String, Equatable, Sendable {
  case front
  case back
}

enum QRScannerDetectionSpeed: String, Equatable, Sendable {
  case noDuplicates = "no_duplicates"
  case normal
  case unrestricted
}

/// Names intentionally match `mobile_scanner` 7.4.0. Punctuation and case
/// normalization is the literal behavior of the pinned Dart parser.
enum QRScannerBarcodeFormat: String, CaseIterable, Equatable, Sendable {
  case unknown, all, code128, code39, code93, codabar, dataMatrix, ean13, ean8
  case itf2of5, itf2of5WithChecksum, itf, itf14, qrCode, upcA, upcE, pdf417
  case aztec, maxiCode, microQrCode, dataBar, dataBarExpanded, dataBarLimited
}

enum QRScannerBarcodeType: String, Equatable, Sendable {
  case unknown, contactInfo, email, isbn, phone, product, sms, text, url, wifi
  case geo, calendarEvent, driverLicense

  static func detect(_ value: String?) -> QRScannerBarcodeType {
    guard let value else { return .unknown }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return .unknown }
    let upper = trimmed.uppercased()
    if upper.hasPrefix("BEGIN:VCARD") { return .contactInfo }
    if upper.hasPrefix("BEGIN:VCALENDAR") { return .calendarEvent }
    if upper.hasPrefix("WIFI:") { return .wifi }
    if upper.hasPrefix("MAILTO:") { return .email }
    if upper.hasPrefix("TEL:") { return .phone }
    if upper.hasPrefix("SMS:") { return .sms }
    if upper.hasPrefix("GEO:") { return .geo }
    if upper.hasPrefix("MEBKM:") || upper.hasPrefix("HTTP://") || upper.hasPrefix("HTTPS://") {
      return .url
    }
    let isbn = trimmed.replacingOccurrences(of: "-", with: "")
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "ISBN", with: "", options: .caseInsensitive)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if isbn.allSatisfy(\.isNumber),
      isbn.count == 10 || (isbn.count == 13 && (isbn.hasPrefix("978") || isbn.hasPrefix("979")))
    { return .isbn }
    let digits = trimmed.filter(\.isNumber)
    if [8, 12, 13].contains(digits.count) { return .product }
    return .text
  }
}

struct QRScannerRect: Equatable, Sendable {
  let x: Double
  let y: Double
  let width: Double
  let height: Double
}

struct QRScannerDetectionState: Equatable, Sendable {
  private(set) var lastScanned: [String]?

  mutating func accepts(_ rawValues: [String?], speed: QRScannerDetectionSpeed) -> Bool {
    guard speed == .noDuplicates else { return true }
    let signature = rawValues.compactMap { $0 }.sorted()
    guard signature != lastScanned else { return false }
    if !signature.isEmpty { lastScanned = signature }
    return true
  }

  mutating func reset() { lastScanned = nil }

  static func shouldThrottle(
    speed: QRScannerDetectionSpeed,
    elapsedMilliseconds: Double,
    timeoutMilliseconds: Int
  ) -> Bool {
    speed == .normal && elapsedMilliseconds < Double(timeoutMilliseconds)
  }
}

struct QRScannerConfiguration: Equatable, Sendable {
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

  @MainActor
  init(control: RufletControl) {
    autoStart = control.boolean("auto_start", default: true)
    autoZoom = control.boolean("auto_zoom", default: false)
    cameraFacing = Self.parseCameraFacing(control.string("camera_facing"))
    detectionSpeed = Self.parseDetectionSpeed(control.string("detection_speed"))
    detectionTimeoutMilliseconds = control.integer("detection_timeout", default: 250) ?? 250
    fit = control.string("fit", default: "cover") ?? "cover"
    formats = Self.parseFormats(control.value("formats")?.array)
    invertImage = control.boolean("invert_image", default: false)
    returnImage = control.boolean("return_image", default: false)
    scanWindow = Self.parseScanWindow(control.value("scan_window"))
    tapToFocus = control.boolean("tap_to_focus", default: false)
    torchEnabled = control.boolean("torch_enabled", default: false)
    zoomScale = control.number("zoom_scale", default: 1) ?? 1
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
      let name = normalized(value.text)
      guard let format = QRScannerBarcodeFormat.allCases.first(where: {
        normalized($0.rawValue) == name
      }), !result.contains(format) else { continue }
      result.append(format)
    }
    return result
  }

  static func parseScanWindow(_ value: RufletValue?) -> QRScannerRect? {
    guard let map = value?.map,
      let left = (map["left"] ?? map["x"])?.number,
      let top = (map["top"] ?? map["y"])?.number
    else { return nil }
    if let right = map["right"]?.number, let bottom = map["bottom"]?.number {
      return QRScannerRect(x: left, y: top, width: right - left, height: bottom - top)
    }
    if let width = map["width"]?.number, let height = map["height"]?.number {
      return QRScannerRect(x: left, y: top, width: width, height: height)
    }
    return nil
  }

  private static func normalized(_ value: String?) -> String {
    (value ?? "").unicodeScalars
      .filter { CharacterSet.alphanumerics.contains($0) }
      .map(String.init)
      .joined()
      .lowercased()
  }
}

enum QRScannerError: Error, Equatable, Sendable {
  case unavailable(String)
  case missingValue
  case unknownMethod(String)
}

enum QRScannerErrorEvent {
  static func payload(_ error: Error, stackTrace: String? = nil) -> RufletValue {
    var data: [String: RufletValue] = [
      "message": .string(String(describing: error)),
      "type": .string(String(describing: type(of: error))),
    ]
    if let stackTrace { data["stack_trace"] = .string(stackTrace) }
    return .map(data)
  }
}
