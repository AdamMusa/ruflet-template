import Foundation
import RiveRuntime
import RufletEngine
import RufletProtocol
import SwiftUI

@MainActor
private final class RufletRiveLoader: ObservableObject {
  @Published var viewModel: RiveViewModel?
  @Published var error: Error?
  @Published var animationNames: [String] = []
  @Published var stateMachineNames: [String] = []
  private var identity = ""

  func load(control: RufletControl) async {
    let newIdentity = Self.identity(for: control)
    guard newIdentity != identity else { return }
    identity = newIdentity
    viewModel = nil
    error = nil
    animationNames = []
    stateMachineNames = []

    do {
      let data = try await Self.loadData(control: control)
      let file = try RiveFile(data: data, loadCdn: true)
      let model = RiveModel(riveFile: file)
      let stateMachines = Self.strings(control.value("state_machines"))
      let animations = Self.strings(control.value("animations"))
      animationNames = animations
      stateMachineNames = stateMachines
      let artboardName = control.string("art_board")
      let fit = Self.fit(control.string("fit"))
      let alignment = Self.alignment(control.value("alignment"))

      if let stateMachine = stateMachines.first {
        viewModel = RiveViewModel(
          model,
          stateMachineName: stateMachine,
          fit: fit,
          alignment: alignment,
          autoPlay: true,
          artboardName: artboardName)
      } else {
        viewModel = RiveViewModel(
          model,
          animationName: animations.first,
          fit: fit,
          alignment: alignment,
          autoPlay: true,
          artboardName: artboardName)
      }
    } catch {
      self.error = error
    }
  }

  private static func identity(for control: RufletControl) -> String {
    [
      control.string("src") ?? "",
      control.string("art_board") ?? "",
      String(describing: control.value("animations")),
      String(describing: control.value("state_machines")),
      String(describing: control.value("headers")),
      control.string("fit") ?? "",
      String(describing: control.value("alignment")),
    ].joined(separator: "\u{1f}")
  }

  private static func loadData(control: RufletControl) async throws -> Data {
    guard let source = control.value("src"), let asset = control.backend.resolveAssetSource(source) else {
      throw RufletRiveError.missingSource
    }
    if asset.isFile {
      return try Data(contentsOf: URL(fileURLWithPath: asset.path), options: .mappedIfSafe)
    }
    guard let url = URL(string: asset.path) else { throw RufletRiveError.invalidSource }
    var request = URLRequest(url: url)
    for (name, value) in control.value("headers")?.map ?? [:] {
      if let value = value.text { request.setValue(value, forHTTPHeaderField: name) }
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    if let response = response as? HTTPURLResponse, !(200 ... 299).contains(response.statusCode) {
      throw RufletRiveError.httpStatus(response.statusCode)
    }
    return data
  }

  private static func strings(_ value: RufletValue?) -> [String] {
    value?.array?.compactMap(\.text) ?? []
  }

  private static func fit(_ value: String?) -> RiveFit {
    switch value?.lowercased() {
    case "fill": .fill
    case "cover": .cover
    case "fitheight", "fit_height": .fitHeight
    case "fitwidth", "fit_width": .fitWidth
    case "none": .noFit
    case "scaledown", "scale_down": .scaleDown
    default: .contain
    }
  }

  private static func alignment(_ value: RufletValue?) -> RiveAlignment {
    guard let map = value?.map else { return .center }
    let x = map["x"]?.number ?? 0
    let y = map["y"]?.number ?? 0
    if y < -0.5 {
      if x < -0.5 { return .topLeft }
      if x > 0.5 { return .topRight }
      return .topCenter
    }
    if y > 0.5 {
      if x < -0.5 { return .bottomLeft }
      if x > 0.5 { return .bottomRight }
      return .bottomCenter
    }
    if x < -0.5 { return .centerLeft }
    if x > 0.5 { return .centerRight }
    return .center
  }
}

private final class RufletSpeedRiveView: RiveView {
  var speedMultiplier = 1.0
  private var additionalAnimations: [RiveLinearAnimationInstance] = []
  private var additionalStateMachines: [RiveStateMachineInstance] = []

  func configureAdditionalControllers(
    viewModel: RiveViewModel,
    animationNames: [String],
    stateMachineNames: [String]
  ) {
    guard let model = viewModel.riveModel else { return }
    let primaryAnimation = model.animation?.name()
    let primaryStateMachine = model.stateMachine?.name()
    additionalAnimations = animationNames.compactMap { name in
      guard name != primaryAnimation else { return nil }
      return try? model.artboard.animation(fromName: name)
    }
    additionalStateMachines = stateMachineNames.compactMap { name in
      guard name != primaryStateMachine else { return nil }
      return try? model.artboard.stateMachine(fromName: name)
    }
  }

  override func advance(delta: Double) {
    let scaled = delta * speedMultiplier
    for animation in additionalAnimations { _ = animation.advance(by: scaled) }
    for stateMachine in additionalStateMachines { _ = stateMachine.advance(by: scaled) }
    super.advance(delta: scaled)
  }
}

#if os(iOS)
private struct RufletRiveRuntimeView: UIViewRepresentable {
  let viewModel: RiveViewModel
  let speedMultiplier: Double
  let animationNames: [String]
  let stateMachineNames: [String]

  func makeUIView(context: Context) -> RufletSpeedRiveView {
    let view = RufletSpeedRiveView()
    view.speedMultiplier = speedMultiplier
    viewModel.setView(view)
    view.configureAdditionalControllers(
      viewModel: viewModel,
      animationNames: animationNames,
      stateMachineNames: stateMachineNames)
    return view
  }

  func updateUIView(_ view: RufletSpeedRiveView, context: Context) {
    view.speedMultiplier = speedMultiplier
    viewModel.update(view: view)
  }

  func makeCoordinator() -> RiveCoordinator { RiveCoordinator(viewModel: viewModel) }

  static func dismantleUIView(_ view: RufletSpeedRiveView, coordinator: RiveCoordinator) {
    coordinator.viewModel.stop()
    coordinator.viewModel.deregisterView()
  }
}
#elseif os(macOS)
private struct RufletRiveRuntimeView: NSViewRepresentable {
  let viewModel: RiveViewModel
  let speedMultiplier: Double
  let animationNames: [String]
  let stateMachineNames: [String]

  func makeNSView(context: Context) -> RufletSpeedRiveView {
    let view = RufletSpeedRiveView()
    view.speedMultiplier = speedMultiplier
    viewModel.setView(view)
    view.configureAdditionalControllers(
      viewModel: viewModel,
      animationNames: animationNames,
      stateMachineNames: stateMachineNames)
    return view
  }

  func updateNSView(_ view: RufletSpeedRiveView, context: Context) {
    view.speedMultiplier = speedMultiplier
    viewModel.update(view: view)
  }

  func makeCoordinator() -> RiveCoordinator { RiveCoordinator(viewModel: viewModel) }

  static func dismantleNSView(_ view: RufletSpeedRiveView, coordinator: RiveCoordinator) {
    coordinator.viewModel.stop()
    coordinator.viewModel.deregisterView()
  }
}
#endif

private final class RiveCoordinator {
  let viewModel: RiveViewModel

  init(viewModel: RiveViewModel) {
    self.viewModel = viewModel
  }
}

private struct RufletRiveClipShape: Shape {
  let clipRect: CGRect

  func path(in rect: CGRect) -> Path {
    Path(CGRect(
      x: clipRect.minX,
      y: clipRect.minY,
      width: clipRect.width,
      height: clipRect.height))
  }
}

struct RiveControl: View {
  @ObservedObject var control: RufletControl
  @StateObject private var loader = RufletRiveLoader()

  var body: some View {
    Group {
      if let viewModel = loader.viewModel {
        riveView(viewModel)
      } else if let error = loader.error {
        VStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle")
          Text("Rive failed to load")
          Text(String(describing: error)).font(.caption).foregroundColor(.secondary)
        }
      } else if let placeholder = control.buildWidget("placeholder") {
        placeholder
      } else {
        ProgressView()
      }
    }
    .task(id: loaderIdentity) { await loader.load(control: control) }
  }

  @ViewBuilder
  private func riveView(_ viewModel: RiveViewModel) -> some View {
    let speed = control.number("speed_multiplier", default: 1) ?? 1
    let content = RufletRiveRuntimeView(
      viewModel: viewModel,
      speedMultiplier: speed,
      animationNames: loader.animationNames,
      stateMachineNames: loader.stateMachineNames)
    let sized = useArtboardSize
      ? AnyView(content.frame(width: artboardSize(viewModel).width, height: artboardSize(viewModel).height))
      : AnyView(content)
    if let clipRect {
      sized.clipShape(RufletRiveClipShape(clipRect: clipRect))
    } else {
      sized
    }
  }

  private var loaderIdentity: String {
    [
      String(describing: control.value("src")),
      String(describing: control.value("art_board")),
      String(describing: control.value("animations")),
      String(describing: control.value("state_machines")),
      String(describing: control.value("headers")),
      String(describing: control.value("fit")),
      String(describing: control.value("alignment")),
    ].joined(separator: "\u{1f}")
  }

  private var useArtboardSize: Bool { control.boolean("use_art_board_size", default: false) }

  private func artboardSize(_ viewModel: RiveViewModel) -> CGSize {
    viewModel.riveModel?.artboard.bounds().size ?? .zero
  }

  private var clipRect: CGRect? {
    guard let map = control.value("clip_rect")?.map else { return nil }
    if let left = map["left"]?.number,
       let top = map["top"]?.number,
       let right = map["right"]?.number,
       let bottom = map["bottom"]?.number
    {
      return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }
    guard let x = map["x"]?.number,
          let y = map["y"]?.number,
          let width = map["width"]?.number,
          let height = map["height"]?.number
    else { return nil }
    return CGRect(x: x, y: y, width: width, height: height)
  }
}

public enum RufletRiveError: Error, Equatable, Sendable {
  case missingSource
  case invalidSource
  case httpStatus(Int)
}
