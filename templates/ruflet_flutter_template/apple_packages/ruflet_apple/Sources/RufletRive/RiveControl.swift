import Foundation
import RiveRuntime
import RufletEngine
import RufletProtocol
import RufletUI
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
  @State private var artboardSize: CGSize?
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
        Color.clear
      }
    }
    .modifier(
      RiveGeometry(
        intrinsicSize: node.bool("use_art_board_size") == true ? artboardSize : nil,
        clipRect: RufletRiveClipRect(node.props["clip_rect"])))
    .task(id: configurationKey) { await load() }
    .onChange(of: node.double("speed_multiplier") ?? 1) { speed in
      viewModel?.speedMultiplier = speed
    }
  }

  private var configurationKey: String {
    let headers = (node.map("headers") ?? [:])
      .sorted { $0.key < $1.key }
      .map { "\($0.key)=\($0.value.stringValue ?? "")" }
      .joined(separator: "&")
    return [
      node.string("src") ?? "",
      headers,
      node.string("art_board") ?? "",
      stringList("animations").joined(separator: ","),
      stringList("state_machines").joined(separator: ","),
      node.string("fit") ?? "contain",
      node.string("alignment") ?? "center",
      node.bool("use_art_board_size") == true ? "intrinsic" : "layout",
      String(describing: node.props["clip_rect"]),
    ].joined(separator: "|")
  }

  @MainActor
  private func load() async {
    viewModel = nil
    artboardSize = nil
    errorMessage = nil
    guard let source = node.string("src"), !source.isEmpty else {
      errorMessage = "Rive requires a source."
      return
    }

    do {
      let data = try await sourceData(source)
      let file = try RiveFile(data: data, loadCdn: true)
      let model = RiveModel(riveFile: file)
      let requestedAnimations = stringList("animations")
      let requestedStateMachines = stringList("state_machines")
      let probeArtboard = try node.string("art_board").map {
        try file.artboard(fromName: $0)
      } ?? file.artboard()
      var animations = requestedAnimations.filter { probeArtboard.animationNames().contains($0) }
      var stateMachines = requestedStateMachines.filter { probeArtboard.stateMachineNames().contains($0) }
      if requestedAnimations.isEmpty, requestedStateMachines.isEmpty {
        if let defaultMachine = probeArtboard.defaultStateMachine() {
          stateMachines = [defaultMachine.name()]
        } else if let first = probeArtboard.animationNames().first {
          animations = [first]
        }
      }
      let result = RufletRiveViewModel(
        model,
        animationNames: animations,
        stateMachineNames: stateMachines,
        fit: riveFit,
        alignment: riveAlignment,
        artboardName: node.string("art_board"))
      result.speedMultiplier = node.double("speed_multiplier") ?? 1
      artboardSize = model.artboard.bounds().size
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

/// Flutter's `Rect.fromLTRB` wire value used by Rive's custom clipper.
struct RufletRiveClipRect: Equatable {
  let rect: CGRect

  init?(_ value: RufletValue?) {
    guard let map = value?.mapValue,
      let left = map["left"]?.doubleValue,
      let top = map["top"]?.doubleValue,
      let right = map["right"]?.doubleValue,
      let bottom = map["bottom"]?.doubleValue,
      right >= left, bottom >= top
    else { return nil }
    rect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
  }
}

private struct RiveGeometry: ViewModifier {
  let intrinsicSize: CGSize?
  let clipRect: RufletRiveClipRect?

  func body(content: Content) -> some View {
    let sized = AnyView(
      content.frame(width: intrinsicSize?.width, height: intrinsicSize?.height))
    if let clipRect {
      return AnyView(sized.clipShape(RiveClipShape(rect: clipRect.rect)))
    }
    return sized
  }
}

private struct RiveClipShape: Shape {
  let rect: CGRect

  func path(in _: CGRect) -> Path {
    Path(rect)
  }
}

/// Rive's high-level Apple API intentionally plays at authored speed. Ruflet
/// exposes a live `speed_multiplier`, so its native view scales every display
/// tick before handing it to the runtime.
private final class RufletRiveView: RiveView {
  var speedMultiplier = 1.0
  private let modelReference: RiveModel?
  private let configuredFit: RiveFit
  private let configuredAlignment: RiveAlignment
  private var additionalAnimations: [RiveLinearAnimationInstance] = []
  private var additionalStateMachines: [RiveStateMachineInstance] = []

  init(
    model: RiveModel,
    autoPlay: Bool,
    animationNames: [String],
    stateMachineNames: [String],
    fit: RiveFit,
    alignment: RiveAlignment
  ) {
    modelReference = model
    configuredFit = fit
    configuredAlignment = alignment
    super.init()
    try? setModel(model, autoPlay: autoPlay)

    // The high-level RiveModel owns the first active controller. The pinned
    // Flet painter advances every other requested controller on the same
    // artboard as well, including animations and state machines together.
    let firstState = stateMachineNames.first
    let firstAnimation = firstState == nil ? animationNames.first : nil
    additionalAnimations = animationNames.compactMap { name in
      if name == firstAnimation { return nil }
      return try? model.artboard.animation(fromName: name)
    }
    additionalStateMachines = stateMachineNames.compactMap { name in
      if name == firstState { return nil }
      return try? model.artboard.stateMachine(fromName: name)
    }
  }

  override init() {
    modelReference = nil
    configuredFit = .contain
    configuredAlignment = .center
    super.init()
  }

  required init(coder: NSCoder) {
    modelReference = nil
    configuredFit = .contain
    configuredAlignment = .center
    super.init(coder: coder)
  }

  override func advance(delta: Double) {
    let scaled = delta * max(0, speedMultiplier)
    super.advance(delta: scaled)
    for animation in additionalAnimations { _ = animation.advance(by: scaled) }
    for machine in additionalStateMachines { _ = machine.advance(by: scaled) }
  }

  private func pointerLocation(_ location: CGPoint) -> CGPoint? {
    guard let artboard = modelReference?.artboard else { return nil }
    return RiveControlSemantics.artboardLocation(
      location,
      container: bounds.size,
      artboard: artboard.bounds(),
      fit: configuredFit,
      alignment: configuredAlignment)
  }

  #if os(iOS) || os(visionOS) || os(tvOS)
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)
    guard let touch = touches.first, let point = pointerLocation(touch.location(in: self)) else { return }
    for machine in additionalStateMachines { _ = machine.touchBegan(atLocation: point) }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesMoved(touches, with: event)
    guard let touch = touches.first, let point = pointerLocation(touch.location(in: self)) else { return }
    for machine in additionalStateMachines { _ = machine.touchMoved(atLocation: point) }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    guard let touch = touches.first, let point = pointerLocation(touch.location(in: self)) else { return }
    for machine in additionalStateMachines { _ = machine.touchEnded(atLocation: point) }
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesCancelled(touches, with: event)
    guard let touch = touches.first, let point = pointerLocation(touch.location(in: self)) else { return }
    for machine in additionalStateMachines { _ = machine.touchCancelled(atLocation: point) }
  }
  #elseif os(macOS)
  override func mouseDown(with event: NSEvent) {
    super.mouseDown(with: event)
    forward(event) { $0.touchBegan(atLocation: $1) }
  }

  override func mouseMoved(with event: NSEvent) {
    super.mouseMoved(with: event)
    forward(event) { $0.touchMoved(atLocation: $1) }
  }

  override func mouseDragged(with event: NSEvent) {
    super.mouseDragged(with: event)
    forward(event) { $0.touchMoved(atLocation: $1) }
  }

  override func mouseUp(with event: NSEvent) {
    super.mouseUp(with: event)
    forward(event) { $0.touchEnded(atLocation: $1) }
  }

  override func mouseExited(with event: NSEvent) {
    super.mouseExited(with: event)
    forward(event) { $0.touchCancelled(atLocation: $1) }
  }

  private func forward(
    _ event: NSEvent,
    _ action: (RiveStateMachineInstance, CGPoint) -> RiveHitResult
  ) {
    let local = convert(event.locationInWindow, from: nil)
    let flipped = CGPoint(x: local.x, y: bounds.height - local.y)
    guard let point = pointerLocation(flipped) else { return }
    for machine in additionalStateMachines { _ = action(machine, point) }
  }
  #endif
}

private final class RufletRiveViewModel: RiveViewModel {
  private let animationNames: [String]
  private let stateMachineNames: [String]
  private let configuredFit: RiveFit
  private let configuredAlignment: RiveAlignment

  init(
    _ model: RiveModel,
    animationNames: [String],
    stateMachineNames: [String],
    fit: RiveFit,
    alignment: RiveAlignment,
    artboardName: String?
  ) {
    self.animationNames = animationNames
    self.stateMachineNames = stateMachineNames
    configuredFit = fit
    configuredAlignment = alignment
    if let stateMachine = stateMachineNames.first {
      super.init(
        model, stateMachineName: stateMachine, fit: fit,
        alignment: alignment, artboardName: artboardName)
    } else {
      super.init(
        model, animationName: animationNames.first, fit: fit,
        alignment: alignment, artboardName: artboardName)
    }
  }

  var speedMultiplier = 1.0 {
    didSet { (riveView as? RufletRiveView)?.speedMultiplier = speedMultiplier }
  }

  override func createRiveView() -> RiveView {
    let view: RufletRiveView
    if let model = riveModel {
      view = RufletRiveView(
        model: model,
        autoPlay: autoPlay,
        animationNames: animationNames,
        stateMachineNames: stateMachineNames,
        fit: configuredFit,
        alignment: configuredAlignment)
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

enum RiveControlSemantics {
  static func artboardLocation(
    _ point: CGPoint,
    container: CGSize,
    artboard: CGRect,
    fit: RiveFit,
    alignment: RiveAlignment
  ) -> CGPoint {
    let sx = container.width / max(artboard.width, .leastNonzeroMagnitude)
    let sy = container.height / max(artboard.height, .leastNonzeroMagnitude)
    let scales: (CGFloat, CGFloat)
    switch fit {
    case .fill: scales = (sx, sy)
    case .cover: scales = (max(sx, sy), max(sx, sy))
    case .fitWidth: scales = (sx, sx)
    case .fitHeight: scales = (sy, sy)
    case .scaleDown:
      let scale = min(1, min(sx, sy)); scales = (scale, scale)
    case .noFit: scales = (1, 1)
    default:
      let scale = min(sx, sy); scales = (scale, scale)
    }
    let rendered = CGSize(width: artboard.width * scales.0, height: artboard.height * scales.1)
    let factor = alignmentFactor(alignment)
    let origin = CGPoint(
      x: (container.width - rendered.width) * factor.x,
      y: (container.height - rendered.height) * factor.y)
    return CGPoint(
      x: artboard.minX + (point.x - origin.x) / scales.0,
      y: artboard.minY + (point.y - origin.y) / scales.1)
  }

  private static func alignmentFactor(_ alignment: RiveAlignment) -> CGPoint {
    switch alignment {
    case .topLeft: return CGPoint(x: 0, y: 0)
    case .topCenter: return CGPoint(x: 0.5, y: 0)
    case .topRight: return CGPoint(x: 1, y: 0)
    case .centerLeft: return CGPoint(x: 0, y: 0.5)
    case .centerRight: return CGPoint(x: 1, y: 0.5)
    case .bottomLeft: return CGPoint(x: 0, y: 1)
    case .bottomCenter: return CGPoint(x: 0.5, y: 1)
    case .bottomRight: return CGPoint(x: 1, y: 1)
    default: return CGPoint(x: 0.5, y: 0.5)
    }
  }
}
