import AVFoundation
import Foundation
import QuartzCore
import RufletEngine
import RufletProtocol
import SwiftUI

@MainActor
struct RufletVideoConfiguration: Equatable {
  let title: String
  let outputDriver: String?
  let hardwareDecodingAPI: String?
  let enableHardwareAcceleration: Bool
  let width: Double?
  let height: Double?
  let scale: Double
  let mpvProperties: [String: String]

  init(control: RufletControl) {
    title = control.string("title") ?? "flet-video"
    let value = control.value("configuration")?.map ?? [:]
    outputDriver = value["output_driver"]?.text
    hardwareDecodingAPI = value["hardware_decoding_api"]?.text
    enableHardwareAcceleration = value["enable_hardware_acceleration"]?.bool ?? true
    width = value["width"]?.number
    height = value["height"]?.number
    scale = value["scale"]?.number ?? 1
    mpvProperties =
      value["mpv_properties"]?.map?.compactMapValues { item in
        if let text = item.text { return text }
        if let boolean = item.bool { return boolean ? "yes" : "no" }
        if let number = item.number { return String(number) }
        return nil
      } ?? [:]
  }

  var preferredMaximumResolution: CGSize? {
    guard let width, let height, width > 0, height > 0, scale > 0 else { return nil }
    return CGSize(width: width * scale, height: height * scale)
  }
}

enum RufletVideoFilterQuality: String, Equatable, Sendable {
  case none
  case low
  case medium
  case high

  init(_ value: String?) {
    self = Self(rawValue: value?.lowercased() ?? "") ?? .low
  }

  var layerFilter: CALayerContentsFilter {
    switch self {
    case .none: .nearest
    case .low, .medium: .linear
    case .high: .trilinear
    }
  }
}

func applyVideoFilterQuality(_ quality: RufletVideoFilterQuality, to layer: CALayer?) {
  guard let layer else { return }
  layer.magnificationFilter = quality.layerFilter
  layer.minificationFilter = quality.layerFilter
  for child in layer.sublayers ?? [] {
    applyVideoFilterQuality(quality, to: child)
  }
}

struct RufletVideoMedia: Equatable, Sendable {
  let resource: RufletValue
  let extras: [String: String]
  let httpHeaders: [String: String]
}

enum RufletVideoPlaylistMode: String, Sendable {
  case none
  case single
  case loop
}

struct RufletSubtitleCue: Equatable, Sendable {
  let start: TimeInterval
  let end: TimeInterval
  let text: String
}

struct RufletSubtitleConfiguration {
  let visible: Bool
  let scale: Double
  let color: Color
  let background: Color
  let fontSize: Double
  let horizontalPadding: Double
  let bottomPadding: Double

  init(_ value: RufletValue?) {
    let map = value?.map ?? [:]
    let style = map["text_style"]?.map ?? [:]
    visible = map["visible"]?.bool ?? true
    scale = map["text_scale_factor"]?.number ?? 1
    color = parseColor(style["color"]?.text, .white) ?? .white
    background =
      parseColor(
        style["bgcolor"]?.text ?? style["background_color"]?.text, Color.black.opacity(2 / 3))
      ?? Color.black.opacity(2 / 3)
    fontSize = style["size"]?.number ?? style["font_size"]?.number ?? 32
    let padding = map["padding"]?.map ?? [:]
    horizontalPadding = padding["left"]?.number ?? padding["horizontal"]?.number ?? 16
    bottomPadding = padding["bottom"]?.number ?? padding["vertical"]?.number ?? 24
  }
}

func parseVideoMedia(_ value: RufletValue?) -> RufletVideoMedia? {
  guard let map = value?.map, let resource = map["resource"] else { return nil }
  return RufletVideoMedia(
    resource: resource,
    extras: map["extras"]?.map?.compactMapValues(\.text) ?? [:],
    httpHeaders: map["http_headers"]?.map?.compactMapValues(\.text) ?? [:])
}

func parseVideoMedias(_ value: RufletValue?) -> [RufletVideoMedia] {
  if let values = value?.array { return values.compactMap(parseVideoMedia) }
  return parseVideoMedia(value).map { [$0] } ?? []
}

@MainActor
func makeVideoItem(_ media: RufletVideoMedia, control: RufletControl) throws -> AVPlayerItem {
  guard let source = control.backend.resolveAssetSource(media.resource) else {
    throw RufletVideoError.invalidResource(String(describing: media.resource))
  }
  let url: URL
  if source.isFile {
    url = URL(fileURLWithPath: source.path)
  } else if let parsed = URL(string: source.path) {
    url = parsed
  } else {
    throw RufletVideoError.invalidResource(source.path)
  }
  let options: [String: Any] =
    media.httpHeaders.isEmpty
    ? [:]
    : ["AVURLAssetHTTPHeaderFieldsKey": media.httpHeaders]
  return AVPlayerItem(asset: AVURLAsset(url: url, options: options))
}

func parseVideoDuration(_ value: RufletValue?) -> TimeInterval? {
  guard let value else { return nil }
  if let milliseconds = value.number { return milliseconds / 1_000 }
  if case .extensionValue(let type, let payload) = value,
    type == 3,
    let text = String(data: payload, encoding: .utf8),
    let microseconds = Double(text)
  {
    return microseconds / 1_000_000
  }
  guard let map = value.map else { return nil }
  return (map["days"]?.number ?? 0) * 86_400
    + (map["hours"]?.number ?? 0) * 3_600
    + (map["minutes"]?.number ?? 0) * 60
    + (map["seconds"]?.number ?? 0)
    + (map["milliseconds"]?.number ?? 0) / 1_000
    + (map["microseconds"]?.number ?? 0) / 1_000_000
}

func parseSubtitleCues(_ source: String) -> [RufletSubtitleCue] {
  let normalized =
    source
    .replacingOccurrences(of: "\r\n", with: "\n")
    .replacingOccurrences(of: "\r", with: "\n")
  return normalized.components(separatedBy: "\n\n").compactMap { block in
    let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else { return nil }
    let timing = lines[timingIndex].components(separatedBy: "-->")
    guard timing.count == 2,
      let start = subtitleTime(timing[0]),
      let end = subtitleTime(timing[1])
    else { return nil }
    let text = lines.dropFirst(timingIndex + 1)
      .joined(separator: "\n")
      .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
    guard !text.isEmpty else { return nil }
    return RufletSubtitleCue(start: start, end: end, text: text)
  }
}

private func subtitleTime(_ value: String) -> TimeInterval? {
  let timestamp =
    value.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? ""
  let fields = timestamp.replacingOccurrences(of: ",", with: ".").split(separator: ":")
  guard fields.count >= 2 else { return nil }
  let seconds = Double(fields.last ?? "") ?? 0
  let minutes = Double(fields[fields.count - 2]) ?? 0
  let hours = fields.count >= 3 ? (Double(fields[fields.count - 3]) ?? 0) : 0
  return hours * 3_600 + minutes * 60 + seconds
}
