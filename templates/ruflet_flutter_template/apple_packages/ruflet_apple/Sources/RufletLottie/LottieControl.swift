import Foundation
import ImageIO
import Lottie
import QuartzCore
import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

/// Flet's Lottie extension rendered by Airbnb's native Apple runtime.
///
/// Loading is deliberately owned by this control so HTTP headers, packaged
/// project assets and data URIs follow the same `src` contract as Flet.
struct LottieControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var animation: LottieAnimation?
  @State private var dotLottieFile: DotLottieFile?
  @State private var imageDirectory: String?
  @State private var remoteImages: [String: Data] = [:]
  @State private var failure: LottieFailure?

  var body: some View {
    Group {
      if let animation {
        animationView(animation: animation, dotLottieFile: nil)
      } else if let dotLottieFile, let animation = dotLottieFile.animations.first?.animation {
        animationView(animation: animation, dotLottieFile: dotLottieFile)
      } else if failure?.usesErrorContent == true,
        let errorID = node.controlID(forKey: "error_content")
      {
        ControlView(id: errorID, axis: .none)
      } else if let failure {
        Text(failure.detail.isEmpty ? failure.title : "\(failure.title): \(failure.detail)")
          .font(.caption)
          .foregroundColor(.secondary)
      } else {
        Color.clear
      }
    }
    .task(id: configurationKey) { await load() }
  }

  private var configurationKey: String {
    let headers = (node.map("headers") ?? [:])
      .sorted { $0.key < $1.key }
      .map { "\($0.key)=\($0.value.stringValue ?? "")" }
      .joined(separator: "&")
    let source = LottieSource.resolve(node.props["src"]).identity
    return "\(source)|\(headers)"
  }

  private func animationView(
    animation: LottieAnimation,
    dotLottieFile: DotLottieFile?
  ) -> AnyView {
    let repeating = node.rufletBool("repeat")
    let reverse = node.rufletBool("reverse")
    let animate = node.rufletBool("animate")
    let loopMode = LottieControlSemantics.loopMode(repeat: repeating, reverse: reverse)
    let start = 0.0
    let end = 1.0

    let view: LottieView<EmptyView>
    if let dotLottieFile {
      view = LottieView(dotLottieFile: dotLottieFile)
    } else {
      view = LottieView(animation: animation)
    }
    var configuredView = view
      .resizable()
      .logger(runtimeLogger)
      .configure { configureNativeView($0) }
    if let imageDirectory {
      configuredView = configuredView.imageProvider(
        FilepathImageProvider(filepath: imageDirectory))
    } else if !remoteImages.isEmpty {
      configuredView = configuredView.imageProvider(
        RufletNetworkLottieImageProvider(images: remoteImages))
    }
    let playback: AnyView
    if animate {
      playback = AnyView(
        configuredView.playing(.fromProgress(start, toProgress: end, loopMode: loopMode)))
    } else {
      playback = AnyView(configuredView.paused(at: .progress(0)))
    }

    return AnyView(
      GeometryReader { proxy in
        let layout = LottieControlSemantics.layout(
          intrinsic: animation.size,
          container: proxy.size,
          fit: node.string("fit"),
          alignment: node.string("alignment"))
        playback
          .frame(width: layout.size.width, height: layout.size.height)
          .position(
            x: layout.origin.x + layout.size.width / 2,
            y: layout.origin.y + layout.size.height / 2)
      }
      .clipped())
  }

  @MainActor
  private func load() async {
    animation = nil
    dotLottieFile = nil
    imageDirectory = nil
    remoteImages = [:]
    failure = nil
    let source = LottieSource.resolve(node.props["src"])
    switch source {
    case .empty:
      showFailure(
        title: "Lottie must have \"src\" specified.", detail: "",
        emitsEvent: false, usesErrorContent: false)
      return
    case .unsupported(let detail):
      showFailure(
        title: "Error decoding src", detail: detail,
        emitsEvent: false, usesErrorContent: true)
      return
    case .bytes, .uri:
      break
    }

    do {
      let resource = try await sourceData(source)
      imageDirectory = resource.imageDirectory
      let networkAssets = await loadNetworkImages(for: resource)
      remoteImages = networkAssets.images
      if resource.isZip {
        dotLottieFile = try await loadDotLottie(resource.data)
      } else if node.bool("background_loading") == true {
        animation = try await Task.detached(priority: .userInitiated) {
          try LottieAnimation.from(data: resource.data)
        }.value
      } else {
        animation = try LottieAnimation.from(data: resource.data)
      }
      for warning in networkAssets.warnings {
        events.fire(node, "error", data: .string(warning))
      }
      events.fire(node, "load")
    } catch {
      showFailure(
        title: "Error loading Lottie", detail: error.localizedDescription,
        emitsEvent: true, usesErrorContent: true)
    }
  }

  @MainActor
  private func showFailure(
    title: String,
    detail: String,
    emitsEvent: Bool,
    usesErrorContent: Bool
  ) {
    failure = LottieFailure(
      title: title, detail: detail, usesErrorContent: usesErrorContent, emitsEvent: emitsEvent)
    if emitsEvent { events.fire(node, "error", data: .string(detail)) }
  }

  private func sourceData(_ source: LottieSource) async throws -> LottieResource {
    if case .bytes(let bytes) = source { return LottieResource(data: Data(bytes)) }
    guard case .uri(let source) = source else { throw LottieSourceError.missingSource }
    if let url = URL(string: source), let scheme = url.scheme?.lowercased(),
       scheme == "http" || scheme == "https" {
      var request = URLRequest(url: url)
      for (name, value) in node.map("headers") ?? [:] {
        if let headerValue = value.stringValue { request.setValue(headerValue, forHTTPHeaderField: name) }
      }
      let (data, response) = try await URLSession.shared.data(for: request)
      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        throw LottieSourceError.httpStatus(http.statusCode)
      }
      return LottieResource(data: data, networkBaseURL: url)
    }

    if let url = URL(string: source), url.isFileURL {
      return LottieResource(
        data: try Data(contentsOf: url), imageDirectory: url.deletingLastPathComponent().path)
    }
    let manager = FileManager.default
    var candidates: [String] = source.hasPrefix("/") ? [source] : []
    if let project = BundledProject.locate() {
      candidates.append((project as NSString).appendingPathComponent(source))
      candidates.append((project as NSString).appendingPathComponent("assets/\(source)"))
    }
    if let resources = Bundle.main.resourcePath {
      candidates.append((resources as NSString).appendingPathComponent(source))
    }
    guard let path = candidates.first(where: { manager.fileExists(atPath: $0) }) else {
      throw CocoaError(.fileNoSuchFile)
    }
    let url = URL(fileURLWithPath: path)
    return LottieResource(
      data: try Data(contentsOf: url), imageDirectory: url.deletingLastPathComponent().path)
  }

  private func loadDotLottie(_ data: Data) async throws -> DotLottieFile {
    try await withCheckedThrowingContinuation { continuation in
      DotLottieFile.loadedFrom(data: data, filename: "ruflet-lottie") {
        continuation.resume(with: $0)
      }
    }
  }

  private func loadNetworkImages(
    for resource: LottieResource
  ) async -> (images: [String: Data], warnings: [String]) {
    guard !resource.isZip, let baseURL = resource.networkBaseURL,
      let object = try? JSONSerialization.jsonObject(with: resource.data),
      let json = object as? [String: Any], let assets = json["assets"] as? [[String: Any]]
    else { return ([:], []) }

    var images: [String: Data] = [:]
    var warnings: [String] = []
    for asset in assets {
      guard let name = asset["p"] as? String, !name.hasPrefix("data:") else { continue }
      let directory = asset["u"] as? String ?? ""
      let reference = directory + name
      guard let url = URL(string: reference, relativeTo: baseURL)?.absoluteURL else {
        warnings.append("Failed to load image \(asset["id"] as? String ?? name): invalid URL")
        continue
      }
      do {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
          throw LottieSourceError.httpStatus(http.statusCode)
        }
        images[name] = data
        images[reference] = data
      } catch {
        warnings.append(
          "Failed to load image \(asset["id"] as? String ?? name): \(error.localizedDescription)")
      }
    }
    return (images, warnings)
  }

  private func configureNativeView(_ view: LottieAnimationView) {
    // GeometryReader gives the native view the exact Flutter BoxFit rectangle,
    // so the runtime should fill that rectangle rather than fitting it again.
    view.contentMode = .scaleToFill
    let filter = LottieControlSemantics.layerFilter(node.string("filter_quality"))
    view.layer?.magnificationFilter = filter
    view.layer?.minificationFilter = filter
  }

  private var runtimeLogger: LottieLogger {
    LottieLogger(warn: { message, _, _ in
      events.fire(node, "error", data: .string(message()))
    })
  }
}

struct LottieFailure: Equatable {
  let title: String
  let detail: String
  let usesErrorContent: Bool
  let emitsEvent: Bool
}

struct LottieResource: Equatable {
  let data: Data
  var imageDirectory: String? = nil
  var networkBaseURL: URL? = nil

  var isZip: Bool {
    data.count >= 2 && data[data.startIndex] == 0x50 && data[data.index(after: data.startIndex)] == 0x4B
  }
}

struct RufletNetworkLottieImageProvider: AnimationImageProvider, Equatable {
  let images: [String: Data]

  func imageForAsset(asset: ImageAsset) -> CGImage? {
    let data = images[asset.directory + asset.name] ?? images[asset.name]
    guard let data,
      let source = CGImageSourceCreateWithData(data as CFData, nil)
    else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
  }
}

enum LottieSource: Equatable {
  case empty
  case bytes([UInt8])
  case uri(String)
  case unsupported(String)

  static func resolve(_ value: RufletValue?) -> LottieSource {
    guard let value, !value.isNull else { return .empty }
    switch value {
    case .binary(let bytes):
      return bytes.isEmpty ? .empty : .bytes(bytes)
    case .array(let values):
      guard values.allSatisfy({ if case .int = $0 { return true }; return false }) else {
        return .unsupported("src is not a supported source type.")
      }
      let bytes = values.compactMap { value -> UInt8? in
        guard case .int(let byte) = value else { return nil }
        return UInt8(truncatingIfNeeded: byte)
      }
      return bytes.isEmpty ? .empty : .bytes(bytes)
    case .string(let raw):
      let source = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !source.isEmpty else { return .empty }
      if source.hasPrefix("http://") || source.hasPrefix("https://")
        || source.hasPrefix("www.") || source.contains(".")
      {
        return .uri(source)
      }
      var payload = source
      if source.hasPrefix("data:"), let comma = source.firstIndex(of: ",") {
        payload = String(source[source.index(after: comma)...])
      }
      if let data = decodeBase64(payload) { return .bytes(Array(data)) }
      return .uri(source)
    default:
      return .unsupported("src is not a supported source type.")
    }
  }

  var identity: String {
    switch self {
    case .empty: return "empty"
    case .bytes(let bytes): return "bytes:\(Data(bytes).base64EncodedString())"
    case .uri(let uri): return "uri:\(uri)"
    case .unsupported(let detail): return "unsupported:\(detail)"
    }
  }

  private static func decodeBase64(_ payload: String) -> Data? {
    var normalized = payload
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
      .filter { !$0.isWhitespace }
    guard normalized.count % 4 != 1 else { return nil }
    while normalized.count % 4 != 0 { normalized.append("=") }
    return Data(base64Encoded: normalized)
  }
}

/// Source-driven behavior shared by the renderer and exact parity tests.
enum LottieControlSemantics {
  struct Layout: Equatable {
    let origin: CGPoint
    let size: CGSize
  }

  enum NativeOptionSupport: String, Equatable {
    case nativeRuntimeAlwaysOn
  }

  static let mergePathsSupport = NativeOptionSupport.nativeRuntimeAlwaysOn
  static let applyingLayerOpacitySupport = NativeOptionSupport.nativeRuntimeAlwaysOn

  static func loopMode(repeat repeating: Bool, reverse: Bool) -> LottieLoopMode {
    guard repeating else { return .playOnce }
    return reverse ? .autoReverse : .loop
  }

  static func layerFilter(_ value: String?) -> CALayerContentsFilter {
    switch normalized(value) {
    case "none": return .nearest
    case "medium": return .trilinear
    default: return .linear // Flutter low (default) and high use interpolation.
    }
  }

  static func layout(
    intrinsic: CGSize,
    container: CGSize,
    fit: String?,
    alignment: String?
  ) -> Layout {
    guard intrinsic.width > 0, intrinsic.height > 0,
          container.width.isFinite, container.height.isFinite
    else { return Layout(origin: .zero, size: .zero) }

    let sx = container.width / intrinsic.width
    let sy = container.height / intrinsic.height
    let scales: (CGFloat, CGFloat)
    switch normalized(fit) {
    case "fill": scales = (sx, sy)
    case "cover": scales = (max(sx, sy), max(sx, sy))
    case "fitwidth": scales = (sx, sx)
    case "fitheight": scales = (sy, sy)
    case "none": scales = (1, 1)
    case "scaledown":
      let scale = min(1, min(sx, sy))
      scales = (scale, scale)
    default:
      let scale = min(sx, sy)
      scales = (scale, scale)
    }
    let size = CGSize(width: intrinsic.width * scales.0, height: intrinsic.height * scales.1)
    let factor = alignmentFactor(alignment)
    return Layout(
      origin: CGPoint(
        x: (container.width - size.width) * factor.x,
        y: (container.height - size.height) * factor.y),
      size: size)
  }

  private static func alignmentFactor(_ value: String?) -> CGPoint {
    switch normalized(value) {
    case "topleft": return CGPoint(x: 0, y: 0)
    case "topcenter": return CGPoint(x: 0.5, y: 0)
    case "topright": return CGPoint(x: 1, y: 0)
    case "centerleft": return CGPoint(x: 0, y: 0.5)
    case "centerright": return CGPoint(x: 1, y: 0.5)
    case "bottomleft": return CGPoint(x: 0, y: 1)
    case "bottomcenter": return CGPoint(x: 0.5, y: 1)
    case "bottomright": return CGPoint(x: 1, y: 1)
    default: return CGPoint(x: 0.5, y: 0.5)
    }
  }

  private static func normalized(_ value: String?) -> String {
    value?.lowercased().replacingOccurrences(of: "_", with: "") ?? ""
  }
}

private enum LottieSourceError: LocalizedError {
  case invalidDataURI
  case missingSource
  case httpStatus(Int)

  var errorDescription: String? {
    switch self {
    case .invalidDataURI: return "Invalid Lottie data URI."
    case .missingSource: return "Lottie must have \"src\" specified."
    case .httpStatus(let status): return "Lottie request failed with HTTP status \(status)."
    }
  }
}
