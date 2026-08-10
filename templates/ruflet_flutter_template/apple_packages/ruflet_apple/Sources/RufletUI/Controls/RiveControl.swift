import Foundation
import RiveRuntime
import RufletEngine
import RufletProtocol
import SwiftUI

/// Native Apple renderer for Ruflet's `Rive` extension control.
///
/// The source can be remote (including request headers), a file URL, or an
/// asset relative to the packaged Ruby project. Loading bytes ourselves keeps
/// all three forms on one code path and avoids special cases in application
/// Ruby code.
struct RiveControlView: View {
  let node: ControlNode
  @State private var viewModel: RufletRiveViewModel?
  @State private var errorMessage: String?

  var body: some View {
    Group {
      if let viewModel {
        viewModel.view()
      } else if let errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundColor(.secondary)
      } else if let placeholderID = node.controlID(forKey: "placeholder") {
        ControlView(id: placeholderID, axis: .none)
      } else {
        ProgressView()
      }
    }
    .clipped(antialiased: true)
    .task(id: configurationKey) { await load() }
    .onChange(of: node.double("speed_multiplier") ?? 1) { speed in
      viewModel?.speedMultiplier = speed
    }
  }

  private var configurationKey: String {
    [
      node.string("src") ?? "",
      node.string("art_board") ?? "",
      stringList("animations").joined(separator: ","),
      stringList("state_machines").joined(separator: ","),
      node.string("fit") ?? "contain",
      node.string("alignment") ?? "center"
    ].joined(separator: "|")
  }

  @MainActor
  private func load() async {
    viewModel = nil
    errorMessage = nil
    guard let source = node.string("src"), !source.isEmpty else {
      errorMessage = "Rive requires a source."
      return
    }

    do {
      let data = try await sourceData(source)
      let file = try RiveFile(data: data, loadCdn: true)
      let model = RiveModel(riveFile: file)
      let stateMachine = stringList("state_machines").first
      let animation = stringList("animations").first
      let result: RufletRiveViewModel
      if let stateMachine {
        result = RufletRiveViewModel(
          model,
          stateMachineName: stateMachine,
          fit: riveFit,
          alignment: riveAlignment,
          artboardName: node.string("art_board"))
      } else {
        result = RufletRiveViewModel(
          model,
          animationName: animation,
          fit: riveFit,
          alignment: riveAlignment,
          artboardName: node.string("art_board"))
      }
      result.speedMultiplier = node.double("speed_multiplier") ?? 1
      viewModel = result
    } catch {
      errorMessage = "Rive failed to load: \(error.localizedDescription)"
    }
  }

  private func sourceData(_ source: String) async throws -> Data {
    if let url = URL(string: source), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
      var request = URLRequest(url: url)
      for (name, value) in node.map("headers") ?? [:] {
        if let headerValue = value.stringValue { request.setValue(headerValue, forHTTPHeaderField: name) }
      }
      let (data, response) = try await URLSession.shared.data(for: request)
      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        throw URLError(.badServerResponse)
      }
      return data
    }

    if let url = URL(string: source), url.isFileURL {
      return try Data(contentsOf: url)
    }

    let files = FileManager.default
    var candidates: [String] = []
    if source.hasPrefix("/") { candidates.append(source) }
    if let project = BundledProject.locate() {
      candidates.append((project as NSString).appendingPathComponent(source))
      candidates.append((project as NSString).appendingPathComponent("assets/\(source)"))
    }
    if let resources = Bundle.main.resourcePath {
      candidates.append((resources as NSString).appendingPathComponent(source))
    }
    guard let path = candidates.first(where: { files.fileExists(atPath: $0) }) else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try Data(contentsOf: URL(fileURLWithPath: path))
  }

  private func stringList(_ key: String) -> [String] {
    (node.array(key) ?? []).compactMap(\.stringValue)
  }

  private var riveFit: RiveFit {
    switch node.string("fit")?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "fill": return .fill
    case "cover": return .cover
    case "fitheight": return .fitHeight
    case "fitwidth": return .fitWidth
    case "scaledown": return .scaleDown
    case "none": return .noFit
    default: return .contain
    }
  }

  private var riveAlignment: RiveAlignment {
    switch node.string("alignment")?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "topleft": return .topLeft
    case "topcenter": return .topCenter
    case "topright": return .topRight
    case "centerleft": return .centerLeft
    case "centerright": return .centerRight
    case "bottomleft": return .bottomLeft
    case "bottomcenter": return .bottomCenter
    case "bottomright": return .bottomRight
    default: return .center
    }
  }
}

/// Rive's high-level Apple API intentionally plays at authored speed. Ruflet
/// exposes a live `speed_multiplier`, so its native view scales every display
/// tick before handing it to the runtime.
private final class RufletRiveView: RiveView {
  var speedMultiplier = 1.0

  override func advance(delta: Double) {
    super.advance(delta: delta * max(0, speedMultiplier))
  }
}

private final class RufletRiveViewModel: RiveViewModel {
  var speedMultiplier = 1.0 {
    didSet { (riveView as? RufletRiveView)?.speedMultiplier = speedMultiplier }
  }

  override func createRiveView() -> RiveView {
    let view: RufletRiveView
    if let model = riveModel {
      view = RufletRiveView(model: model, autoPlay: autoPlay)
    } else {
      view = RufletRiveView()
    }
    view.speedMultiplier = speedMultiplier
    setRiveView(view: view)
    return view
  }

  override func update(view: RiveView) {
    super.update(view: view)
    (view as? RufletRiveView)?.speedMultiplier = speedMultiplier
  }
}
