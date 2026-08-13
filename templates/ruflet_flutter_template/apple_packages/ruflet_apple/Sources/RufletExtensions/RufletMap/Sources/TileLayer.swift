import Foundation
import MapKit
import RufletEngine
import RufletProtocol
import SwiftUI

struct RufletTileDescriptor {
  let control: RufletControl
  let urlTemplate: String?
  let fallbackURL: String?
  let subdomains: [String]
  let display: RufletTileDisplay
  let tileSize: Int
  let minimumNativeZoom: Int
  let maximumNativeZoom: Int
  let zoomReverse: Bool
  let zoomOffset: Double
  let tms: Bool
  let retinaMode: Bool
  let minimumZoom: Double
  let maximumZoom: Double
  let bounds: RufletMapBounds?
  let additionalOptions: [String: String]
  let errorImageURL: URL?
}

@MainActor
func rufletTileDescriptor(_ control: RufletControl) -> RufletTileDescriptor {
  let subdomains = control.value("subdomains")?.array?.compactMap(\.text) ?? ["a", "b", "c"]
  var options: [String: String] = [:]
  if let rawOptions = rufletStringMap(control.value("additional_options")) {
    for (key, value) in rawOptions {
      options[key] = value.text
        ?? value.number.map { String($0) }
        ?? value.bool.map { String($0) }
    }
  }
  let errorImageURL: URL?
  if let source = control.string("errorImageSrc"),
     let asset = control.backend.resolveAssetSource(.string(source)) {
    errorImageURL = asset.isFile ? URL(fileURLWithPath: asset.path) : URL(string: asset.path)
  } else {
    errorImageURL = nil
  }
  return RufletTileDescriptor(
    control: control,
    urlTemplate: control.string("url_template"),
    fallbackURL: control.string("fallback_url"),
    subdomains: subdomains,
    display: rufletTileDisplay(control.value("display_mode")),
    tileSize: control.integer("tile_size", default: 256) ?? 256,
    minimumNativeZoom: control.integer("min_native_zoom", default: 0) ?? 0,
    maximumNativeZoom: control.integer("max_native_zoom", default: 19) ?? 19,
    zoomReverse: control.boolean("zoom_reverse", default: false),
    zoomOffset: control.number("zoom_offset", default: 0) ?? 0,
    tms: control.boolean("enable_tms", default: false),
    retinaMode: control.boolean("enable_retina_mode") ?? false,
    minimumZoom: control.number("min_zoom", default: 0) ?? 0,
    maximumZoom: control.number("max_zoom") ?? .infinity,
    bounds: rufletMapBounds(control.value("tile_bounds")),
    additionalOptions: options,
    errorImageURL: errorImageURL)
}

final class RufletTileOverlay: MKTileOverlay {
  let descriptor: RufletTileDescriptor

  init(descriptor: RufletTileDescriptor) {
    self.descriptor = descriptor
    super.init(urlTemplate: nil)
    tileSize = CGSize(width: descriptor.tileSize, height: descriptor.tileSize)
    minimumZ = descriptor.minimumNativeZoom
    maximumZ = descriptor.maximumNativeZoom
    canReplaceMapContent = false
    isGeometryFlipped = descriptor.tms
  }

  override func url(forTilePath path: MKTileOverlayPath) -> URL {
    resolvedURL(template: descriptor.urlTemplate ?? "", path: path)
      ?? URL(string: "about:blank")!
  }

  override func loadTile(
    at path: MKTileOverlayPath,
    result: @escaping (Data?, (any Error)?) -> Void
  ) {
    guard tileIsInsideBounds(path),
          let primary = resolvedURL(template: descriptor.urlTemplate ?? "", path: path)
    else {
      result(nil, URLError(.badURL))
      return
    }
    load(primary) { [weak self] data, error in
      guard let self else { result(data, error); return }
      if let data { result(data, nil); return }
      if let fallback = self.descriptor.fallbackURL,
         let fallbackURL = self.resolvedURL(template: fallback, path: path) {
        self.load(fallbackURL) { data, fallbackError in
          if let data { result(data, nil) }
          else { self.finishError(error: fallbackError ?? error, result: result) }
        }
      } else {
        self.finishError(error: error, result: result)
      }
    }
  }

  private func load(_ url: URL, completion: @escaping (Data?, Error?) -> Void) {
    if url.isFileURL {
      DispatchQueue.global(qos: .utility).async {
        do { completion(try Data(contentsOf: url), nil) }
        catch { completion(nil, error) }
      }
      return
    }
    URLSession.shared.dataTask(with: url) { data, response, error in
      if let response = response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
        completion(nil, URLError(.badServerResponse))
      } else {
        completion(data, error)
      }
    }.resume()
  }

  private func finishError(
    error: Error?,
    result: @escaping (Data?, (any Error)?) -> Void
  ) {
    let reportedError = error ?? URLError(.resourceUnavailable)
    Task { @MainActor [weak self] in
      self?.descriptor.control.triggerEvent("image_error", data: .string(reportedError.localizedDescription))
    }
    guard let errorImageURL = descriptor.errorImageURL else {
      result(nil, reportedError)
      return
    }
    load(errorImageURL) { data, _ in result(data, data == nil ? reportedError : nil) }
  }

  private func resolvedURL(template: String, path: MKTileOverlayPath) -> URL? {
    guard !template.isEmpty else { return nil }
    let sourceZ = path.z
    let zoom = descriptor.zoomReverse
      ? descriptor.maximumNativeZoom - sourceZ + descriptor.minimumNativeZoom
      : sourceZ
    let adjustedZoom = zoom + Int(descriptor.zoomOffset.rounded())
    let maxIndex = adjustedZoom >= 0 && adjustedZoom < Int.bitWidth - 1
      ? (1 << adjustedZoom) - 1
      : path.y
    let y = descriptor.tms ? maxIndex - path.y : path.y
    let domain = descriptor.subdomains.isEmpty
      ? ""
      : descriptor.subdomains[abs(path.x + path.y) % descriptor.subdomains.count]
    var result = template
      .replacingOccurrences(of: "{x}", with: String(path.x))
      .replacingOccurrences(of: "{y}", with: String(y))
      .replacingOccurrences(of: "{z}", with: String(adjustedZoom))
      .replacingOccurrences(of: "{s}", with: domain)
      .replacingOccurrences(of: "{r}", with: descriptor.retinaMode ? "@2x" : "")
    for (key, value) in descriptor.additionalOptions {
      result = result.replacingOccurrences(of: "{\(key)}", with: value)
    }
    return URL(string: result)
  }

  private func tileIsInsideBounds(_ path: MKTileOverlayPath) -> Bool {
    guard let bounds = descriptor.bounds else { return true }
    let tileRect = rectForTile(path)
    return tileRect.intersects(bounds.mapRect)
  }

  private func rectForTile(_ path: MKTileOverlayPath) -> MKMapRect {
    let scale = pow(2, Double(path.z))
    let width = MKMapSize.world.width / scale
    return MKMapRect(
      x: Double(path.x) * width, y: Double(path.y) * width,
      width: width, height: width)
  }
}

struct TileLayerControl: View {
  @ObservedObject var control: RufletControl
  var body: some View { EmptyView() }
}
