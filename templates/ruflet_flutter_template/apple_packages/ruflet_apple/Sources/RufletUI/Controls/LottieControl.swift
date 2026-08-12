import Foundation
import Lottie
import QuartzCore
import RufletEngine
import RufletProtocol
import SwiftUI

/// Flet's Lottie extension rendered by Airbnb's native Apple runtime.
///
/// Loading is deliberately owned by this control so HTTP headers, packaged
/// project assets and data URIs follow the same `src` contract as Flet.
struct LottieControlView: View {
  let node: ControlNode
  @Environment(\.rufletEvents) private var events
  @State private var animation: LottieAnimation?
  @State private var errorMessage: String?

  var body: some View {
    Group {
      if let animation {
        animationView(animation)
      } else if errorMessage != nil, let errorID = node.controlID(forKey: "error_content") {
        ControlView(id: errorID, axis: .none)
      } else if let errorMessage {
        Text("Error loading Lottie: \(errorMessage)")
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
    let source: String
    switch node.props["src"] {
    case .binary(let bytes): source = "binary:\(Data(bytes).base64EncodedString())"
    default: source = node.string("src") ?? ""
    }
    return "\(source)|\(headers)"
  }

  private func animationView(_ animation: LottieAnimation) -> AnyView {
    let repeating = node.rufletBool("repeat")
    let reverse = node.rufletBool("reverse")
    let animate = node.rufletBool("animate")
    let loopMode = LottieControlSemantics.loopMode(repeat: repeating, reverse: reverse)
    let start = 0.0
    let end = 1.0

    let view = LottieView(animation: animation)
      .resizable()
      .configure { configureNativeView($0) }
    let playback: AnyView
    if animate {
      playback = AnyView(view.playing(.fromProgress(start, toProgress: end, loopMode: loopMode)))
    } else {
      playback = AnyView(view.paused(at: .progress(0)))
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
    errorMessage = nil
    guard let sourceValue = node.props["src"], !sourceValue.isNull else {
      fail("Lottie must have \"src\" specified.")
      return
    }

    do {
      let data = try await sourceData(sourceValue)
      if node.bool("background_loading") == true {
        animation = try await Task.detached(priority: .userInitiated) {
          try LottieAnimation.from(data: data)
        }.value
      } else {
        animation = try LottieAnimation.from(data: data)
      }
      events.fire(node, "load")
    } catch {
      fail(error.localizedDescription)
    }
  }

  @MainActor
  private func fail(_ message: String) {
    errorMessage = message
    events.fire(node, "error", data: .string(message))
  }

  private func sourceData(_ value: RufletValue) async throws -> Data {
    if case .binary(let bytes) = value { return Data(bytes) }
    guard let source = value.stringValue, !source.isEmpty else {
      throw LottieSourceError.missingSource
    }
    if source.lowercased().hasPrefix("data:") {
      guard let comma = source.firstIndex(of: ",") else { throw LottieSourceError.invalidDataURI }
      let metadata = source[..<comma].lowercased()
      let payload = String(source[source.index(after: comma)...])
      if metadata.contains(";base64") {
        guard let data = Data(base64Encoded: payload) else { throw LottieSourceError.invalidDataURI }
        return data
      }
      guard let decoded = payload.removingPercentEncoding?.data(using: .utf8) else {
        throw LottieSourceError.invalidDataURI
      }
      return decoded
    }

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
      return data
    }

    if let url = URL(string: source), url.isFileURL { return try Data(contentsOf: url) }
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
    return try Data(contentsOf: URL(fileURLWithPath: path))
  }

  private func configureNativeView(_ view: LottieAnimationView) {
    // GeometryReader gives the native view the exact Flutter BoxFit rectangle,
    // so the runtime should fill that rectangle rather than fitting it again.
    view.contentMode = .scaleToFill
    let filter = LottieControlSemantics.layerFilter(node.string("filter_quality"))
    view.layer?.magnificationFilter = filter
    view.layer?.minificationFilter = filter
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
