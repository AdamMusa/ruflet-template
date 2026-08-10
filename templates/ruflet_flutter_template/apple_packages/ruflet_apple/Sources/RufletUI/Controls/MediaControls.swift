import RufletEngine
import RufletProtocol
import SwiftUI

#if canImport(WebKit)
  import WebKit
#endif
#if canImport(AVKit)
  import AVKit
#endif
#if canImport(MapKit)
  import MapKit
#endif

/// `Canvas` — Flet's immediate-mode drawing surface.
///
/// The shapes arrive as child controls (`Line`, `Rect`, `Circle`, `Path`, …)
/// with a `paint` map, so they are drawn in order into a SwiftUI `Canvas`
/// rather than each becoming its own view.
struct CanvasControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  var body: some View {
    ZStack {
      Canvas { context, size in
        for shapeID in node.controlIDs(forKey: "shapes") + node.childIDs {
          guard let shape = store.node(shapeID) else { continue }
          draw(shape, in: &context, size: size)
        }
      }
      if let contentID = node.controlID(forKey: "content") {
        ControlView(id: contentID, axis: .none)
      }
    }
    .modifier(TapReporter(node: node, events: events))
  }

  private func draw(_ shape: ControlNode, in context: inout GraphicsContext, size: CGSize) {
    let paint = shape.map("paint") ?? [:]
    let stroke = MaterialPalette.color(paint["color"]?.stringValue, default: .primary)
    let width = CGFloat(paint["stroke_width"]?.doubleValue ?? 1)
    let filled = paint["style"]?.stringValue?.lowercased() == "fill"

    switch shape.type {
    case "Line":
      var path = Path()
      path.move(to: CGPoint(x: shape.double("x1") ?? 0, y: shape.double("y1") ?? 0))
      path.addLine(to: CGPoint(x: shape.double("x2") ?? 0, y: shape.double("y2") ?? 0))
      context.stroke(path, with: .color(stroke), lineWidth: width)

    case "Rect":
      let rect = CGRect(
        x: shape.double("x") ?? 0, y: shape.double("y") ?? 0,
        width: shape.double("width") ?? 0, height: shape.double("height") ?? 0)
      let radius = ControlProps.cornerRadius(shape.props["border_radius"]) ?? 0
      let path = Path(roundedRect: rect, cornerRadius: radius)
      filled
        ? context.fill(path, with: .color(stroke))
        : context.stroke(path, with: .color(stroke), lineWidth: width)

    case "Circle":
      let radius = CGFloat(shape.double("radius") ?? 0)
      let rect = CGRect(
        x: (shape.double("x") ?? 0) - radius, y: (shape.double("y") ?? 0) - radius,
        width: radius * 2, height: radius * 2)
      let path = Path(ellipseIn: rect)
      filled
        ? context.fill(path, with: .color(stroke))
        : context.stroke(path, with: .color(stroke), lineWidth: width)

    case "Oval", "Arc":
      let rect = CGRect(
        x: shape.double("x") ?? 0, y: shape.double("y") ?? 0,
        width: shape.double("width") ?? 0, height: shape.double("height") ?? 0)
      let path = Path(ellipseIn: rect)
      filled
        ? context.fill(path, with: .color(stroke))
        : context.stroke(path, with: .color(stroke), lineWidth: width)

    case "Fill":
      context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(stroke))

    case "Points":
      for point in shape.array("points") ?? [] {
        guard let map = point.mapValue else { continue }
        let rect = CGRect(
          x: (map["x"]?.doubleValue ?? 0) - width / 2,
          y: (map["y"]?.doubleValue ?? 0) - width / 2,
          width: width, height: width)
        context.fill(Path(ellipseIn: rect), with: .color(stroke))
      }

    case "Text":
      context.draw(
        Text(shape.string("text") ?? "").foregroundColor(stroke),
        at: CGPoint(x: shape.double("x") ?? 0, y: shape.double("y") ?? 0),
        anchor: .topLeading)

    case "Path":
      let path = Self.path(from: shape.array("elements") ?? [])
      filled
        ? context.fill(path, with: .color(stroke))
        : context.stroke(path, with: .color(stroke), lineWidth: width)

    case "Color":
      // Flet's Color shape paints the whole canvas in a blend mode.
      context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(stroke))

    case "Shadow":
      // A shadow with no shape to cast from is a soft blur of the canvas edge,
      // which is what Flutter draws for a bare Shadow element.
      var shadowed = context
      shadowed.addFilter(
        .shadow(
          color: stroke,
          radius: CGFloat(shape.double("blur_radius") ?? 4),
          x: CGFloat(shape.double("dx") ?? 0),
          y: CGFloat(shape.double("dy") ?? 0)))

    default:
      RufletLog.debug("Canvas shape `\(shape.type)` is not drawn by the Apple engine")
    }
  }

  /// Flet's `Path` carries a list of typed elements: `MoveTo`, `LineTo`,
  /// `QuadraticTo`, `CubicTo`, `Arc`, `Oval`, `Rect`, `SubPath` and `Close`.
  private static func path(from elements: [RufletValue]) -> Path {
    var path = Path()
    for element in elements {
      guard let map = element.mapValue else { continue }
      let x = map["x"]?.doubleValue ?? 0
      let y = map["y"]?.doubleValue ?? 0

      switch (map["_type"]?.stringValue ?? map["type"]?.stringValue ?? "").lowercased() {
      case "moveto":
        path.move(to: CGPoint(x: x, y: y))
      case "lineto":
        path.addLine(to: CGPoint(x: x, y: y))
      case "quadraticto":
        path.addQuadCurve(
          to: CGPoint(x: map["x"]?.doubleValue ?? 0, y: map["y"]?.doubleValue ?? 0),
          control: CGPoint(
            x: map["cp1x"]?.doubleValue ?? 0, y: map["cp1y"]?.doubleValue ?? 0))
      case "cubicto":
        path.addCurve(
          to: CGPoint(x: x, y: y),
          control1: CGPoint(
            x: map["cp1x"]?.doubleValue ?? 0, y: map["cp1y"]?.doubleValue ?? 0),
          control2: CGPoint(
            x: map["cp2x"]?.doubleValue ?? 0, y: map["cp2y"]?.doubleValue ?? 0))
      case "arc":
        path.addEllipse(
          in: CGRect(
            x: x, y: y,
            width: map["width"]?.doubleValue ?? 0,
            height: map["height"]?.doubleValue ?? 0))
      case "oval":
        path.addEllipse(
          in: CGRect(
            x: x, y: y,
            width: map["width"]?.doubleValue ?? 0,
            height: map["height"]?.doubleValue ?? 0))
      case "rect":
        path.addRect(
          CGRect(
            x: x, y: y,
            width: map["width"]?.doubleValue ?? 0,
            height: map["height"]?.doubleValue ?? 0))
      case "close":
        path.closeSubpath()
      default:
        continue
      }
    }
    return path
  }
}

/// The chart family, drawn from the same series data Flet's charts take.
///
/// Line, bar and scatter charts share one plotting routine because they differ
/// only in how a data point is marked; pie charts get their own.
struct ChartControlView: View {
  let node: ControlNode
  @EnvironmentObject private var store: ControlStore

  var body: some View {
    Canvas { context, size in
      let plot = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)
      switch node.type {
      case "PieChart":
        drawPie(in: &context, plot: plot)
      case "RadarChart":
        drawRadar(in: &context, plot: plot)
      case "CandlestickChart":
        drawCandlesticks(in: &context, plot: plot)
      default:
        drawSeries(in: &context, plot: plot)
      }
    }
    .frame(minHeight: 120)
  }

  private struct Point {
    let x: Double
    let y: Double
  }

  private var series: [(color: Color, points: [Point])] {
    let ids = node.controlIDs(forKey: "data_series") + node.childIDs
    return ids.compactMap { id -> (Color, [Point])? in
      guard let group = store.node(id) else { return nil }
      return (MaterialPalette.color(group.string("color") ?? "primary", default: .primary), points(in: group))
    }
    .filter { !$0.1.isEmpty }
  }

  /// A series' points are controls, not inline maps: the store turns every
  /// nested control into a `.controlRef`, so they have to be resolved rather
  /// than read out of the array. A plain `{x:, y:}` map is still accepted, for
  /// a host that builds a chart by hand.
  private func points(in group: ControlNode) -> [Point] {
    for key in ["data_points", "points", "spots"] {
      let resolved = group.controlIDs(forKey: key).compactMap { id -> Point? in
        guard let point = store.node(id) else { return nil }
        return Point(x: point.double("x") ?? 0, y: point.double("y") ?? 0)
      }
      if !resolved.isEmpty { return resolved }

      let inline = (group.array(key) ?? []).compactMap { value -> Point? in
        guard let map = value.mapValue else { return nil }
        return Point(x: map["x"]?.doubleValue ?? 0, y: map["y"]?.doubleValue ?? 0)
      }
      if !inline.isEmpty { return inline }
    }
    return []
  }

  private func drawSeries(in context: inout GraphicsContext, plot: CGRect) {
    let all = series
    let xs = all.flatMap { $0.points.map(\.x) }
    let ys = all.flatMap { $0.points.map(\.y) }
    guard let minX = xs.min(), let maxX = xs.max(),
      let minY = ys.min(), let maxY = ys.max()
    else { return }

    let spanX = max(maxX - minX, .ulpOfOne)
    let spanY = max(maxY - minY, .ulpOfOne)

    func project(_ point: Point) -> CGPoint {
      CGPoint(
        x: plot.minX + CGFloat((point.x - minX) / spanX) * plot.width,
        y: plot.maxY - CGFloat((point.y - minY) / spanY) * plot.height)
    }

    for entry in all {
      switch node.type {
      case "BarChart":
        let barWidth = plot.width / CGFloat(max(entry.points.count, 1)) * 0.6
        for point in entry.points {
          let origin = project(point)
          let rect = CGRect(
            x: origin.x - barWidth / 2, y: origin.y,
            width: barWidth, height: plot.maxY - origin.y)
          context.fill(Path(rect), with: .color(entry.color))
        }
      case "ScatterChart":
        for point in entry.points {
          let origin = project(point)
          context.fill(
            Path(ellipseIn: CGRect(x: origin.x - 3, y: origin.y - 3, width: 6, height: 6)),
            with: .color(entry.color))
        }
      default:
        var path = Path()
        for (index, point) in entry.points.enumerated() {
          let projected = project(point)
          index == 0 ? path.move(to: projected) : path.addLine(to: projected)
        }
        context.stroke(path, with: .color(entry.color), lineWidth: 2)
      }
    }
  }

  /// `RadarChart` — one closed polygon per data set over a spoked grid.
  private func drawRadar(in context: inout GraphicsContext, plot: CGRect) {
    let sets = (node.controlIDs(forKey: "data_sets") + node.childIDs)
      .compactMap { store.node($0) }
      .filter { $0.type == "RadarDataSet" }
    guard !sets.isEmpty else { return }

    let entries = sets.map { set in
      set.controlIDs(forKey: "data_entries")
        .compactMap { store.node($0)?.double("value") }
    }
    let spokes = entries.map(\.count).max() ?? 0
    guard spokes >= 3 else { return }

    let centre = CGPoint(x: plot.midX, y: plot.midY)
    let radius = min(plot.width, plot.height) / 2
    let maximum = max(entries.flatMap { $0 }.max() ?? 1, .ulpOfOne)

    func point(spoke: Int, magnitude: Double) -> CGPoint {
      // Start at twelve o'clock, like Flutter's radar chart.
      let angle = Double(spoke) / Double(spokes) * 2 * .pi - .pi / 2
      let distance = radius * CGFloat(magnitude / maximum)
      return CGPoint(x: centre.x + distance * cos(angle), y: centre.y + distance * sin(angle))
    }

    // The grid first, so the data sits on top of it.
    var grid = Path()
    for spoke in 0..<spokes {
      grid.move(to: centre)
      grid.addLine(to: point(spoke: spoke, magnitude: maximum))
    }
    context.stroke(grid, with: .color(.secondary.opacity(0.3)), lineWidth: 1)

    for (index, values) in entries.enumerated() where !values.isEmpty {
      var path = Path()
      for (spoke, value) in values.enumerated() {
        let projected = point(spoke: spoke, magnitude: value)
        spoke == 0 ? path.move(to: projected) : path.addLine(to: projected)
      }
      path.closeSubpath()

      let colour = MaterialPalette.color(sets[index].string("color") ?? "primary", default: .primary)
      context.fill(path, with: .color(colour.opacity(0.25)))
      context.stroke(path, with: .color(colour), lineWidth: 2)
    }
  }

  /// `CandlestickChart` — a wick from low to high with an open/close body,
  /// filled green when the close is above the open and red when below.
  private func drawCandlesticks(in context: inout GraphicsContext, plot: CGRect) {
    let spots = (node.controlIDs(forKey: "spots") + node.childIDs)
      .compactMap { store.node($0) }
      .filter { $0.type == "CandlestickChartSpot" }
    guard !spots.isEmpty else { return }

    let lows = spots.compactMap { $0.double("low") }
    let highs = spots.compactMap { $0.double("high") }
    guard let minimum = lows.min(), let maximum = highs.max() else { return }
    let span = max(maximum - minimum, .ulpOfOne)

    func y(_ value: Double) -> CGFloat {
      plot.maxY - CGFloat((value - minimum) / span) * plot.height
    }

    let step = plot.width / CGFloat(spots.count)
    let bodyWidth = max(step * 0.6, 1)

    for (index, spot) in spots.enumerated() {
      let open = spot.double("open") ?? 0
      let close = spot.double("close") ?? 0
      let x = plot.minX + step * (CGFloat(index) + 0.5)
      let colour: Color = close >= open ? .green : .red

      var wick = Path()
      wick.move(to: CGPoint(x: x, y: y(spot.double("high") ?? 0)))
      wick.addLine(to: CGPoint(x: x, y: y(spot.double("low") ?? 0)))
      context.stroke(wick, with: .color(colour), lineWidth: 1)

      let top = min(y(open), y(close))
      let body = CGRect(
        x: x - bodyWidth / 2, y: top,
        width: bodyWidth, height: max(abs(y(open) - y(close)), 1))
      context.fill(Path(body), with: .color(colour))
    }
  }

  private func drawPie(in context: inout GraphicsContext, plot: CGRect) {
    let sections = (node.controlIDs(forKey: "sections") + node.childIDs)
      .compactMap { store.node($0) }
    let total = sections.reduce(0.0) { $0 + ($1.double("value") ?? 0) }
    guard total > 0 else { return }

    let centre = CGPoint(x: plot.midX, y: plot.midY)
    let radius = min(plot.width, plot.height) / 2
    var start = Angle.degrees(-90)

    for section in sections {
      let sweep = Angle.degrees((section.double("value") ?? 0) / total * 360)
      var path = Path()
      path.move(to: centre)
      path.addArc(
        center: centre, radius: radius,
        startAngle: start, endAngle: start + sweep, clockwise: false)
      context.fill(
        path, with: .color(MaterialPalette.color(section.string("color") ?? "primary", default: .primary)))
      start = start + sweep
    }
  }
}

/// `WebView` — WKWebView, wrapped for SwiftUI.
struct WebViewControlView: View {
  let node: ControlNode

  var body: some View {
    #if canImport(WebKit)
      WebViewRepresentable(url: node.string("url"), html: node.string("html"))
    #else
      Color.clear
    #endif
  }
}

#if canImport(WebKit)
  private struct WebViewRepresentable {
    let url: String?
    let html: String?

    func makeWebView() -> WKWebView {
      let view = WKWebView()
      load(into: view)
      return view
    }

    func load(into view: WKWebView) {
      if let html, !html.isEmpty {
        view.loadHTMLString(html, baseURL: nil)
      } else if let url, let resolved = URL(string: url) {
        view.load(URLRequest(url: resolved))
      }
    }
  }

  #if canImport(UIKit)
    extension WebViewRepresentable: UIViewRepresentable {
      func makeUIView(context: Context) -> WKWebView { makeWebView() }
      func updateUIView(_ view: WKWebView, context: Context) { load(into: view) }
    }
  #elseif canImport(AppKit)
    extension WebViewRepresentable: NSViewRepresentable {
      func makeNSView(context: Context) -> WKWebView { makeWebView() }
      func updateNSView(_ view: WKWebView, context: Context) { load(into: view) }
    }
  #endif
#endif

/// `Video` — the platform player, with the imperative API Flet exposes.
///
/// The player lives in a `@StateObject` rather than being rebuilt each pass,
/// because `video.play` has to reach the same `AVPlayer` the user is watching.
struct VideoControlView: View {
  let node: ControlNode
  @StateObject private var model = VideoPlayerModel()
  @Environment(\.rufletEvents) private var events

  var body: some View {
    Group {
      #if canImport(AVKit)
        PlayerView(
          model: model,
          showsControls: node.bool("show_controls") ?? true,
          fit: node.string("fit"),
          fullscreen: node.bool("fullscreen") ?? false,
          node: node,
          events: events)
      #else
        Color.black
      #endif
    }
    .onAppear { model.configure(from: node, events: events) }
    .onChange(of: node) { updated in model.configure(from: updated, events: events) }
    .rufletCommandHandler(node.id) { call, completion in
      model.handle(call, completion: completion)
    }
  }
}

/// Owns the player and answers Ruby's method calls against it.
@MainActor
final class VideoPlayerModel: ObservableObject {
  #if canImport(AVKit)
    let player = AVPlayer()
  #endif

  private var playlist: [URL] = []
  private var index = 0
  private var configured = false
  private var playbackRate: Float = 1
  private var completionObserver: Any?
  #if canImport(AVKit)
    private var itemStatusObserver: NSKeyValueObservation?
  #endif
  /// Held rather than captured: the notification closure is `@Sendable` and
  /// neither the node nor the sink is.
  private var node: ControlNode?
  private var events: RufletEventSink?

  /// Flet's `playlist` is a list of `{resource_url:}` maps; `src` is the
  /// single-source shorthand.
  func configure(from node: ControlNode, events: RufletEventSink) {
    let sources = Self.sources(in: node)

    #if canImport(AVKit)
      player.isMuted = node.bool("muted") ?? false
      let volume = node.double("volume") ?? 100
      player.volume = Float(max(0, min(volume > 1 ? volume / 100 : volume, 1)))
      playbackRate = Float(node.double("playback_rate") ?? 1)
      if sources != playlist || !configured {
        playlist = sources
        index = min(index, max(sources.count - 1, 0))
        configured = true
        load(at: index)
      }

      self.node = node
      self.events = events

      if let completionObserver { NotificationCenter.default.removeObserver(completionObserver) }
      completionObserver = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.itemDidFinish() }
      }

      if node.bool("autoplay") == true { play() }
    #endif
  }

  /// Reports `completed` and advances when the control carries a playlist,
  /// which is what Flet's video does at the end of an item.
  private func itemDidFinish() {
    #if canImport(AVKit)
      if let node, let events {
        events.fire(node, "completed", data: .int(Int64(index)))
      }
      guard playlist.count > 1, index + 1 < playlist.count else { return }
      load(at: index + 1)
      play()
    #endif
  }

  private static func sources(in node: ControlNode) -> [URL] {
    if let playlist = node.array("playlist") {
      return playlist.compactMap { entry in
        guard let raw = entry["resource"]?.stringValue
          ?? entry["resource_url"]?.stringValue
          ?? entry["src"]?.stringValue
          ?? entry.stringValue else { return nil }
        return URL(string: raw) ?? URL(fileURLWithPath: raw)
      }
    }
    guard let raw = node.string("src") else { return [] }
    return [URL(string: raw) ?? URL(fileURLWithPath: raw)]
  }

  #if canImport(AVKit)
    private func play() {
      player.playImmediately(atRate: playbackRate)
    }

    private func load(at position: Int) {
      guard playlist.indices.contains(position) else { return }
      index = position
      let item = AVPlayerItem(url: playlist[position])
      itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
        Task { @MainActor in
          guard let self, let node = self.node, let events = self.events else { return }
          switch item.status {
          case .readyToPlay:
            events.fire(node, "loaded", data: .int(Int64(self.index)))
          case .failed:
            events.fire(
              node, "error",
              data: .string(item.error?.localizedDescription ?? "The video could not be loaded"))
          default:
            break
          }
        }
      }
      player.replaceCurrentItem(with: item)
    }

    private var positionMilliseconds: Int64? {
      let seconds = player.currentTime().seconds
      return seconds.isFinite ? Int64(seconds * 1000) : nil
    }

    private var durationMilliseconds: Int64? {
      guard let seconds = player.currentItem?.duration.seconds, seconds.isFinite else {
        return nil
      }
      return Int64(seconds * 1000)
    }
  #endif

  /// The method surface of Ruflet's `VideoControl`.
  func handle(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
    #if canImport(AVKit)
      switch call.name {
      case "play":
        play()
        completion(.success(.null))
      case "pause":
        player.pause()
        completion(.success(.null))
      case "play_or_pause":
        player.rate == 0 ? play() : player.pause()
        completion(.success(.null))
      case "stop":
        player.pause()
        player.seek(to: .zero)
        completion(.success(.null))
      case "seek":
        if let milliseconds = call.argument("position")?.doubleValue {
          player.seek(to: CMTime(seconds: milliseconds / 1000, preferredTimescale: 600))
        }
        completion(.success(.null))
      case "jump_to":
        // Takes a playlist index rather than a time.
        if let position = call.argument("media_index")?.intValue {
          load(at: position)
          play()
        }
        completion(.success(.null))
      case "next":
        load(at: index + 1)
        play()
        completion(.success(.null))
      case "previous":
        load(at: index - 1)
        play()
        completion(.success(.null))
      case "get_current_position":
        completion(.success(positionMilliseconds.map { RufletValue.int($0) } ?? .null))
      case "get_duration":
        completion(.success(durationMilliseconds.map { RufletValue.int($0) } ?? .null))
      case "is_playing":
        completion(.success(.bool(player.rate != 0)))
      case "is_completed":
        guard let position = positionMilliseconds, let duration = durationMilliseconds,
          duration > 0
        else { return completion(.success(.bool(false))) }
        completion(.success(.bool(position >= duration)))
      case "playlist_add":
        if let raw = call.argument("media")?["resource_url"]?.stringValue {
          playlist.append(URL(string: raw) ?? URL(fileURLWithPath: raw))
        }
        completion(.success(.null))
      case "playlist_remove":
        if let position = call.argument("media_index")?.intValue,
          playlist.indices.contains(position)
        {
          playlist.remove(at: position)
        }
        completion(.success(.null))
      default:
        completion(.failure(rufletUnsupported("Video", call)))
      }
    #else
      completion(.failure(rufletUnsupported("Video", call)))
    #endif
  }

  deinit {
    if let completionObserver { NotificationCenter.default.removeObserver(completionObserver) }
    itemStatusObserver?.invalidate()
  }
}

#if canImport(AVKit)
  /// `AVPlayerViewController` is the UIKit player; AppKit has `AVPlayerView`.
  /// Neither is a SwiftUI view, so each platform gets its own representable.
  private struct PlayerView {
    let model: VideoPlayerModel
    let showsControls: Bool
    let fit: String?
    let fullscreen: Bool
    let node: ControlNode
    let events: RufletEventSink
  }

  #if canImport(UIKit)
    extension PlayerView: UIViewControllerRepresentable {
      final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var fullscreenController: AVPlayerViewController?
        var node: ControlNode?
        var events: RufletEventSink?

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
          if let node, let events { events.fire(node, "exit_fullscreen") }
          fullscreenController = nil
        }
      }

      func makeCoordinator() -> Coordinator { Coordinator() }

      func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = model.player
        configure(controller)
        return controller
      }
      func updateUIViewController(
        _ controller: AVPlayerViewController, context: Context
      ) {
        if controller.player !== model.player { controller.player = model.player }
        configure(controller)
        context.coordinator.node = node
        context.coordinator.events = events

        if fullscreen, context.coordinator.fullscreenController == nil {
          DispatchQueue.main.async {
            guard context.coordinator.fullscreenController == nil,
              let presenter = controller.view.window?.rootViewController
            else { return }
            let fullscreenController = AVPlayerViewController()
            fullscreenController.player = model.player
            fullscreenController.showsPlaybackControls = showsControls
            fullscreenController.videoGravity = videoGravity
            fullscreenController.modalPresentationStyle = .fullScreen
            fullscreenController.presentationController?.delegate = context.coordinator
            context.coordinator.fullscreenController = fullscreenController
            presenter.present(fullscreenController, animated: true) {
              events.fire(node, "enter_fullscreen")
            }
          }
        } else if !fullscreen, let fullscreenController = context.coordinator.fullscreenController {
          fullscreenController.dismiss(animated: true)
          context.coordinator.fullscreenController = nil
        }
      }

      private func configure(_ controller: AVPlayerViewController) {
        controller.showsPlaybackControls = showsControls
        controller.videoGravity = videoGravity
      }

      private var videoGravity: AVLayerVideoGravity {
        switch fit?.lowercased() {
        case "cover": return .resizeAspectFill
        case "fill": return .resize
        default: return .resizeAspect
        }
      }
    }
  #elseif canImport(AppKit)
    extension PlayerView: NSViewRepresentable {
      func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = model.player
        view.controlsStyle = showsControls ? .inline : .none
        return view
      }
      func updateNSView(_ view: AVPlayerView, context: Context) {
        view.player = model.player
        view.controlsStyle = showsControls ? .inline : .none
      }
    }
  #endif
#endif

/// `Map` — MapKit, with the camera methods Flet's map exposes.
///
/// Uses `MKMapView` rather than SwiftUI's `Map`: the SwiftUI wrapper lives in a
/// cross-import overlay SwiftPM does not reliably enable, and only the UIKit
/// view can be moved imperatively by `move_to`/`zoom_to`.
struct MapControlView: View {
  let node: ControlNode
  @StateObject private var model = MapModel()

  var body: some View {
    Group {
      #if canImport(MapKit)
        MapContainer(model: model)
      #else
        Color.gray.opacity(0.2)
      #endif
    }
    .onAppear { model.configure(from: node) }
    .rufletCommandHandler(node.id) { call, completion in
      model.handle(call, completion: completion)
    }
  }
}

#if canImport(MapKit)
  /// Owns the map view so the camera methods reach the one on screen.
  @MainActor
  final class MapModel: ObservableObject {
    let view = MKMapView()
    private var configured = false

    /// Web-tile zoom levels halve the visible span with each step, which is the
    /// convention Flet's map configuration uses.
    static func span(forZoom zoom: Double) -> MKCoordinateSpan {
      let degrees = 360 / pow(2, max(zoom, 1))
      return MKCoordinateSpan(latitudeDelta: degrees, longitudeDelta: degrees)
    }

    static func zoom(forSpan span: MKCoordinateSpan) -> Double {
      log2(360 / max(span.latitudeDelta, 0.0001))
    }

    func configure(from node: ControlNode) {
      guard !configured else { return }
      configured = true

      let centre = node.map("initial_center")
      view.setRegion(
        MKCoordinateRegion(
          center: CLLocationCoordinate2D(
            latitude: centre?["latitude"]?.doubleValue ?? 0,
            longitude: centre?["longitude"]?.doubleValue ?? 0),
          span: Self.span(forZoom: node.double("initial_zoom") ?? 13)),
        animated: false)

      let interactive = node.bool("interaction_enabled") ?? true
      view.isZoomEnabled = interactive
      view.isScrollEnabled = interactive
      view.isRotateEnabled = interactive
    }

    private func coordinate(_ call: RufletMethodCall) -> CLLocationCoordinate2D? {
      let source = call.argument("point") ?? call.args
      guard let latitude = source["latitude"]?.doubleValue,
        let longitude = source["longitude"]?.doubleValue
      else { return nil }
      return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func handle(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      switch call.name {
      case "move_to", "center_on":
        guard let target = coordinate(call) else {
          return completion(.failure(RufletServiceError.invalidArguments("a point is required")))
        }
        var region = view.region
        region.center = target
        if let zoom = call.argument("zoom")?.doubleValue {
          region.span = Self.span(forZoom: zoom)
        }
        view.setRegion(region, animated: true)
        completion(.success(.null))

      case "zoom_to":
        guard let zoom = call.argument("zoom")?.doubleValue else {
          return completion(.failure(RufletServiceError.invalidArguments("zoom is required")))
        }
        view.setRegion(
          MKCoordinateRegion(center: view.region.center, span: Self.span(forZoom: zoom)),
          animated: true)
        completion(.success(.null))

      case "zoom_in", "zoom_out":
        let step = call.argument("zoom")?.doubleValue ?? 1
        let current = Self.zoom(forSpan: view.region.span)
        let next = call.name == "zoom_in" ? current + step : current - step
        view.setRegion(
          MKCoordinateRegion(center: view.region.center, span: Self.span(forZoom: next)),
          animated: true)
        completion(.success(.null))

      case "rotate_from":
        let camera = view.camera.copy() as! MKMapCamera
        camera.heading += call.argument("degree")?.doubleValue ?? 0
        view.setCamera(camera, animated: true)
        completion(.success(.null))

      case "reset_rotation":
        let camera = view.camera.copy() as! MKMapCamera
        camera.heading = 0
        view.setCamera(camera, animated: true)
        completion(.success(.null))

      default:
        completion(.failure(rufletUnsupported("Map", call)))
      }
    }
  }

  private struct MapContainer {
    let model: MapModel
  }

  #if canImport(UIKit)
    extension MapContainer: UIViewRepresentable {
      func makeUIView(context: Context) -> MKMapView { model.view }
      func updateUIView(_ view: MKMapView, context: Context) {}
    }
  #elseif canImport(AppKit)
    extension MapContainer: NSViewRepresentable {
      func makeNSView(context: Context) -> MKMapView { model.view }
      func updateNSView(_ view: MKMapView, context: Context) {}
    }
  #endif
#else
  @MainActor
  final class MapModel: ObservableObject {
    func configure(from node: ControlNode) {}
    func handle(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      completion(.failure(rufletUnsupported("Map", call)))
    }
  }
#endif
