import Foundation
import Lottie
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
        ProgressView()
      }
    }
    .task(id: configurationKey) { await load() }
  }

  private var configurationKey: String {
    let headers = (node.map("headers") ?? [:])
      .sorted { $0.key < $1.key }
      .map { "\($0.key)=\($0.value.stringValue ?? "")" }
      .joined(separator: "&")
    return "\(node.string("src") ?? "")|\(headers)"
  }

  private func animationView(_ animation: LottieAnimation) -> AnyView {
    let repeating = node.fletBool("repeat")
    let reverse = node.fletBool("reverse")
    let animate = node.fletBool("animate")
    let loopMode: LottieLoopMode = repeating ? .loop : .playOnce
    let start = reverse ? 1.0 : 0.0
    let end = reverse ? 0.0 : 1.0

    let view = LottieView(animation: animation)
      .resizable()
      .configure { configureContentMode($0) }
    if animate {
      return AnyView(
        view.playing(.fromProgress(start, toProgress: end, loopMode: loopMode))
          .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: ControlProps.alignment(node.value("alignment")) ?? .center))
    }
    return AnyView(
      view.paused(at: .progress(start))
        .frame(
          maxWidth: .infinity,
          maxHeight: .infinity,
          alignment: ControlProps.alignment(node.value("alignment")) ?? .center))
  }

  @MainActor
  private func load() async {
    animation = nil
    errorMessage = nil
    guard let source = node.string("src"), !source.isEmpty else {
      fail("Lottie must have \"src\" specified.")
      return
    }

    do {
      let data = try await sourceData(source)
      animation = try LottieAnimation.from(data: data)
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

  private func sourceData(_ source: String) async throws -> Data {
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

  private func configureContentMode(_ view: LottieAnimationView) {
    let fit = node.string("fit")?.lowercased().replacingOccurrences(of: "_", with: "")
    #if os(iOS)
    switch fit {
    case "fill": view.contentMode = .scaleToFill
    case "cover": view.contentMode = .scaleAspectFill
    case "none": view.contentMode = .center
    default: view.contentMode = .scaleAspectFit
    }
    #elseif os(macOS)
    switch fit {
    case "fill": view.contentMode = .scaleToFill
    case "cover": view.contentMode = .scaleAspectFill
    case "none": view.contentMode = .center
    default: view.contentMode = .scaleAspectFit
    }
    #endif
  }
}

private enum LottieSourceError: LocalizedError {
  case invalidDataURI
  case httpStatus(Int)

  var errorDescription: String? {
    switch self {
    case .invalidDataURI: return "Invalid Lottie data URI."
    case .httpStatus(let status): return "Lottie request failed with HTTP status \(status)."
    }
  }
}
