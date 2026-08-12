import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

#if canImport(AVKit)
  import AVKit
#endif
#if canImport(MediaPlayer)
  import MediaPlayer
#endif
#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// `Video` — the platform player, with the imperative API Flet exposes.
///
/// The player lives in a `@StateObject` rather than being rebuilt each pass,
/// because `video.play` has to reach the same `AVPlayer` the user is watching.
struct VideoSubtitleConfiguration: Equatable {
  var visible = true
  var scale: CGFloat = 1
  var alignment = "center"
  var padding = EdgeInsets(top: 0, leading: 16, bottom: 24, trailing: 16)
  var style = RufletTextStyle(map: [
    "size": .double(32), "height": .double(1.4), "color": .string("#ffffffff"),
    "bgcolor": .string("#aa000000"), "weight": .string("normal"),
  ])

  init(_ value: RufletValue?) {
    guard let map = value?.mapValue else { return }
    visible = map["visible"]?.boolValue ?? true
    scale = CGFloat(map["text_scale_factor"]?.doubleValue ?? 1)
    alignment = map["text_align"]?.stringValue ?? "center"
    padding = ControlProps.edgeInsets(map["padding"])
      ?? EdgeInsets(top: 0, leading: 16, bottom: 24, trailing: 16)
    if let textStyle = map["text_style"]?.mapValue { style = RufletTextStyle(map: textStyle) }
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.visible == rhs.visible && lhs.scale == rhs.scale && lhs.alignment == rhs.alignment
      && lhs.padding == rhs.padding
  }
}

enum VideoSubtitleTrack: Equatable {
  case automatic
  case none
  case external(String)

  init?(_ value: RufletValue?) {
    guard let map = value?.mapValue, let source = map["src"]?.stringValue else { return nil }
    switch source.lowercased() {
    case "auto": self = .automatic
    case "none": self = .none
    default: self = .external(source)
    }
  }
}

struct VideoSubtitleCue: Equatable {
  let start: TimeInterval
  let end: TimeInterval
  let text: String

  static func parse(_ source: String) -> [Self] {
    source.replacingOccurrences(of: "\r\n", with: "\n")
      .components(separatedBy: "\n\n")
      .compactMap { block in
        let lines = block.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else { return nil }
        let endpoints = lines[timingIndex].components(separatedBy: "-->")
        guard endpoints.count == 2,
          let start = parseTime(endpoints[0]), let end = parseTime(endpoints[1]), end >= start
        else { return nil }
        let text = lines.dropFirst(timingIndex + 1)
          .joined(separator: "\n")
          .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        return text.isEmpty ? nil : Self(start: start, end: end, text: text)
      }
  }

  private static func parseTime(_ raw: String) -> TimeInterval? {
    let token = raw.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init)
      ?? ""
    let parts = token.replacingOccurrences(of: ",", with: ".").split(separator: ":")
    guard parts.count >= 2, let seconds = Double(parts.last ?? "") else { return nil }
    let minutes = Double(parts[parts.count - 2]) ?? 0
    let hours = parts.count > 2 ? (Double(parts[parts.count - 3]) ?? 0) : 0
    return hours * 3600 + minutes * 60 + seconds
  }
}

struct VideoControllerOptions: Equatable {
  let outputDriver: String?
  let hardwareDecodingAPI: String?
  let enablesHardwareAcceleration: Bool
  let width: Int?
  let height: Int?
  let scale: Double
  let mpvProperties: [String: String]

  init(_ value: RufletValue?) {
    let map = value?.mapValue ?? [:]
    outputDriver = map["output_driver"]?.stringValue
    hardwareDecodingAPI = map["hardware_decoding_api"]?.stringValue
    enablesHardwareAcceleration = map["enable_hardware_acceleration"]?.boolValue ?? true
    width = map["width"]?.intValue
    height = map["height"]?.intValue
    scale = map["scale"]?.doubleValue ?? 1
    mpvProperties = map["mpv_properties"]?.mapValue?.reduce(into: [:]) { result, entry in
      if let boolean = entry.value.boolValue { result[entry.key] = boolean ? "yes" : "no" }
      else if let string = entry.value.stringValue { result[entry.key] = string }
      else if let number = entry.value.doubleValue { result[entry.key] = String(number) }
    } ?? [:]
  }

  /// These settings configure media_kit's MPV backend. AVFoundation owns its
  /// decoder/output selection and exposes no equivalent knobs; retaining the
  /// parsed values makes that platform boundary explicit instead of silently
  /// pretending to apply them.
  var avFoundationUnsupportedKeys: Set<String> {
    var keys = Set(mpvProperties.keys.map { "mpv_properties.\($0)" })
    if outputDriver != nil { keys.insert("output_driver") }
    if hardwareDecodingAPI != nil { keys.insert("hardware_decoding_api") }
    if width != nil { keys.insert("width") }
    if height != nil { keys.insert("height") }
    if scale != 1 { keys.insert("scale") }
    if !enablesHardwareAcceleration { keys.insert("enable_hardware_acceleration") }
    return keys
  }
}

struct VideoPresentationOptions: Equatable {
  let title: String
  let muted: Bool
  let volume: Double?
  let pitch: Double?
  let playbackRate: Double?
  let shufflePlaylist: Bool?
  let showControls: Bool
  let playlistMode: String?
  let fullscreen: Bool
  let wakelock: Bool
  let pausesInBackground: Bool
  let resumesInForeground: Bool
  let alignment: String
  let fit: String
  let filterQuality: String
  let fillColor: String
  let autoplay: Bool

  init(_ node: ControlNode) {
    title = node.string("title") ?? "flet-video"
    muted = node.bool("muted") ?? false
    let requestedVolume = node.double("volume")
    volume = requestedVolume.flatMap { (0...100).contains($0) ? $0 : nil }
    pitch = node.double("pitch")
    playbackRate = node.double("playback_rate")
    shufflePlaylist = node.bool("shuffle_playlist")
    showControls = node.bool("show_controls") ?? true
    playlistMode = node.string("playlist_mode")
    fullscreen = node.bool("fullscreen") ?? false
    wakelock = node.bool("wakelock") ?? true
    pausesInBackground = node.bool("pause_upon_entering_background_mode") ?? true
    resumesInForeground = node.bool("resume_upon_entering_foreground_mode") ?? false
    alignment = node.string("alignment") ?? "center"
    fit = node.string("fit") ?? "contain"
    filterQuality = node.string("filter_quality") ?? "low"
    fillColor = node.string("fill_color") ?? "black"
    autoplay = node.bool("autoplay") ?? false
  }
}

public struct VideoControlView: View {
  public let node: ControlNode
  @StateObject private var model = VideoPlayerModel()
  @Environment(\.rufletEvents) private var events
  @Environment(\.scenePhase) private var scenePhase

  public init(node: ControlNode) { self.node = node }

  public var body: some View {
    Group {
      #if canImport(AVKit)
        ZStack(alignment: .bottom) {
          PlayerView(
          model: model,
          showsControls: node.bool("show_controls") ?? true,
          fit: node.string("fit"),
          filterQuality: node.string("filter_quality") ?? "low",
          fullscreen: node.bool("fullscreen") ?? false,
          node: node,
          events: events)
          if model.subtitleConfiguration.visible, !model.subtitleText.isEmpty {
            Text(model.subtitleText)
              .rufletTextStyle(model.subtitleConfiguration.style)
              .multilineTextAlignment(model.subtitleConfiguration.alignment == "start" ? .leading
                : model.subtitleConfiguration.alignment == "end" ? .trailing : .center)
              .scaleEffect(model.subtitleConfiguration.scale)
              .padding(model.subtitleConfiguration.padding)
          }
        }
        .background(MaterialPalette.color(node.string("fill_color"), default: .black))
      #else
        Color.black
      #endif
    }
    .onAppear { model.configure(from: node, events: events) }
    .onDisappear { model.disappear() }
    .onChange(of: node) { updated in model.configure(from: updated, events: events) }
    .onChange(of: scenePhase) { model.scenePhaseChanged($0) }
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

  private var playlist: [VideoMediaSource] = []
  private var index = 0
  private var configured = false
  private var didEmitLoaded = false
  private var playbackRate: Float = 1
  private var completionObserver: Any?
  private var subtitleTimeObserver: Any?
  #if canImport(AVKit)
    private var itemStatusObserver: NSKeyValueObservation?
  #endif
  @Published private(set) var subtitleText = ""
  @Published private(set) var subtitleConfiguration = VideoSubtitleConfiguration(nil)
  private(set) var controllerOptions = VideoControllerOptions(nil)
  private(set) var avFoundationUnsupportedProperties: Set<String> = []
  private var subtitleTrack: VideoSubtitleTrack?
  private var subtitleCues: [VideoSubtitleCue] = []
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
      player.volume = Float(max(0, min(volume / 100, 1)))
      let newPlaybackRate = Float(node.double("playback_rate") ?? 1)
      let rateChangedWhilePlaying = playbackRate != newPlaybackRate && player.rate != 0
      playbackRate = newPlaybackRate
      self.node = node
      self.events = events
      subtitleConfiguration = VideoSubtitleConfiguration(node.props["subtitle_configuration"])
      controllerOptions = VideoControllerOptions(node.props["configuration"])
      let presentation = VideoPresentationOptions(node)
      avFoundationUnsupportedProperties = controllerOptions.avFoundationUnsupportedKeys
      if node.double("pitch") != nil { avFoundationUnsupportedProperties.insert("pitch") }
      if presentation.alignment.lowercased() != "center" {
        avFoundationUnsupportedProperties.insert("alignment")
      }
      if !["contain", "cover", "fill"].contains(presentation.fit.lowercased()) {
        avFoundationUnsupportedProperties.insert("fit.\(presentation.fit)")
      }
      let newSubtitleTrack = VideoSubtitleTrack(node.props["subtitle_track"])
      let subtitleChanged = newSubtitleTrack != subtitleTrack
      subtitleTrack = newSubtitleTrack
      let sourcesChanged = sources != playlist || !configured
      if sourcesChanged {
        playlist = sources
        index = min(index, max(sources.count - 1, 0))
        configured = true
        load(at: index)
      } else if subtitleChanged {
        applySubtitleTrack()
      }

      // media_kit supports independent pitch. AVPlayer does not expose a pitch
      // control; changing its time-pitch preservation algorithm would not be an
      // equivalent implementation and is therefore deliberately avoided.
      player.appliesMediaSelectionCriteriaAutomatically = true
      // Flutter's playlist modes: loop the item, loop the list, or stop.
      playlistMode = node.string("playlist_mode")?.lowercased() ?? "none"
      shuffles = node.bool("shuffle_playlist") == true
      pausesInBackground = node.bool("pause_upon_entering_background_mode") ?? true
      resumesInForeground = node.bool("resume_upon_entering_foreground_mode") ?? false
      holdsWakelock = node.bool("wakelock") ?? true
      setWakelock(holdsWakelock)

      if sourcesChanged, node.bool("autoplay") == true { play() }
      else if rateChangedWhilePlaying { play() }
    #endif
  }

  /// The playlist behaviour Flet carries beside the sources.
  private var playlistMode = "none"
  private var shuffles = false
  private var pausesInBackground = true
  private var resumesInForeground = false
  private var holdsWakelock = true
  private var wasPlayingBeforeBackground = false

  /// Reports Flet's canonical `complete` event and advances when the control carries a playlist,
  /// which is what Flet's video does at the end of an item.
  private func itemDidFinish() {
    #if canImport(AVKit)
      if let node, let events {
        events.fire(node, "complete", data: .bool(true))
      }
      // `single` repeats the item, `loop` wraps the list, anything else stops
      // at the end — which is what Flutter's PlaylistMode does.
      if playlistMode == "single" {
        load(at: index)
        play()
        return
      }
      guard playlist.count > 1 else { return }
      let next = shuffles
        ? Int.random(in: 0..<playlist.count)
        : index + 1
      guard next < playlist.count || playlistMode == "loop" else { return }
      load(at: next < playlist.count ? next : 0)
      play()
    #endif
  }

  static func sources(in node: ControlNode) -> [VideoMediaSource] {
    if let playlist = node.array("playlist") {
      return playlist.compactMap(VideoMediaSource.init)
    }
    guard let raw = node.string("src") else { return [] }
    return [VideoMediaSource(resource: raw)]
  }

  #if canImport(AVKit)
    private func play() {
      player.playImmediately(atRate: playbackRate)
    }

    private func load(at position: Int) {
      guard playlist.indices.contains(position) else { return }
      index = position
      if let node, let events {
        events.fire(node, "track_change", data: .int(Int64(position)))
      }
      let source = playlist[position]
      let asset: AVURLAsset
      if source.httpHeaders.isEmpty {
        asset = AVURLAsset(url: source.url)
      } else {
        asset = AVURLAsset(
          url: source.url,
          options: ["AVURLAssetHTTPHeaderFieldsKey": source.httpHeaders])
      }
      let item = AVPlayerItem(asset: asset)
      applyTitle(to: item)
      if let completionObserver { NotificationCenter.default.removeObserver(completionObserver) }
      completionObserver = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.itemDidFinish() }
      }
      itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
        Task { @MainActor in
          guard let self, let node = self.node, let events = self.events else { return }
          switch item.status {
          case .readyToPlay:
            if !self.didEmitLoaded {
              self.didEmitLoaded = true
              events.fire(node, "loaded")
            }
            events.fire(node, "complete", data: .bool(false))
            self.applySubtitleTrack()
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
      installSubtitleTimeObserverIfNeeded()
    }

    private func applyTitle(to item: AVPlayerItem) {
      let title = node?.string("title") ?? "flet-video"
      #if canImport(MediaPlayer)
        var information = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        information[MPMediaItemPropertyTitle] = title
        MPNowPlayingInfoCenter.default().nowPlayingInfo = information
      #else
        avFoundationUnsupportedProperties.insert("title")
      #endif
    }

    private func installSubtitleTimeObserverIfNeeded() {
      guard subtitleTimeObserver == nil else { return }
      subtitleTimeObserver = player.addPeriodicTimeObserver(
        forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main
      ) { [weak self] time in
        Task { @MainActor in self?.updateSubtitle(at: time.seconds) }
      }
    }

    private func applySubtitleTrack() {
      subtitleText = ""
      subtitleCues = []
      guard let item = player.currentItem else { return }
      switch subtitleTrack {
      case .automatic, nil:
        player.appliesMediaSelectionCriteriaAutomatically = true
      case .some(.none):
        player.appliesMediaSelectionCriteriaAutomatically = false
        Task { @MainActor in
          if let group = try? await item.asset.loadMediaSelectionGroup(
            for: .legible)
          {
            item.select(nil, in: group)
          }
        }
      case .external(let source):
        player.appliesMediaSelectionCriteriaAutomatically = false
        loadExternalSubtitle(source)
      }
    }

    private func loadExternalSubtitle(_ source: String) {
      if let url = URL(string: source), let scheme = url.scheme,
        scheme == "http" || scheme == "https"
      {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
          guard let data, let contents = String(data: data, encoding: .utf8) else { return }
          Task { @MainActor in self?.subtitleCues = VideoSubtitleCue.parse(contents) }
        }.resume()
      } else if FileManager.default.fileExists(atPath: source),
        let contents = try? String(contentsOfFile: source, encoding: .utf8)
      {
        subtitleCues = VideoSubtitleCue.parse(contents)
      } else {
        // Flet treats a non-URL, non-file value as raw subtitle contents.
        subtitleCues = VideoSubtitleCue.parse(source)
      }
    }

    private func updateSubtitle(at seconds: TimeInterval) {
      guard seconds.isFinite else { return }
      subtitleText = subtitleCues.first(where: { $0.start <= seconds && seconds <= $0.end })?.text
        ?? ""
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
        if !playlist.isEmpty { load(at: 0) }
        completion(.success(.null))
      case "seek":
        if let milliseconds = call.argument("position")?.doubleValue {
          player.seek(to: CMTime(seconds: milliseconds / 1000, preferredTimescale: 600))
        }
        completion(.success(.null))
      case "jump_to":
        // Takes a playlist index rather than a time.
        if let position = call.argument("media_index")?.intValue {
          let wasPlaying = player.rate != 0
          load(at: position)
          if wasPlaying { play() }
        }
        completion(.success(.null))
      case "next":
        if index + 1 < playlist.count {
          let wasPlaying = player.rate != 0
          load(at: index + 1)
          if wasPlaying { play() }
        }
        completion(.success(.null))
      case "previous":
        if index > 0 {
          let wasPlaying = player.rate != 0
          load(at: index - 1)
          if wasPlaying { play() }
        }
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
        if let media = call.argument("media"), let source = VideoMediaSource(media) {
          playlist.append(source)
        }
        completion(.success(.null))
      case "playlist_remove":
        if let position = call.argument("media_index")?.intValue,
          playlist.indices.contains(position)
        {
          let wasPlaying = player.rate != 0
          playlist.remove(at: position)
          if playlist.isEmpty {
            index = 0
            player.replaceCurrentItem(with: nil)
          } else if position == index {
            index = min(position, playlist.count - 1)
            load(at: index)
            if wasPlaying { play() }
          } else if position < index {
            index -= 1
          }
        }
        completion(.success(.null))
      default:
        completion(.failure(rufletUnsupported("Video", call)))
      }
    #else
      completion(.failure(rufletUnsupported("Video", call)))
    #endif
  }

  func scenePhaseChanged(_ phase: ScenePhase) {
    #if canImport(AVKit)
      switch phase {
      case .background, .inactive:
        guard pausesInBackground else { return }
        wasPlayingBeforeBackground = player.rate != 0
        player.pause()
      case .active:
        if resumesInForeground && wasPlayingBeforeBackground { play() }
        wasPlayingBeforeBackground = false
      @unknown default:
        break
      }
    #endif
  }

  func disappear() {
    setWakelock(false)
  }

  private func setWakelock(_ enabled: Bool) {
    #if canImport(UIKit)
      UIApplication.shared.isIdleTimerDisabled = enabled
    #endif
  }

  deinit {
    if let completionObserver { NotificationCenter.default.removeObserver(completionObserver) }
    if let subtitleTimeObserver {
      #if canImport(AVKit)
        player.removeTimeObserver(subtitleTimeObserver)
      #endif
    }
    itemStatusObserver?.invalidate()
  }
}

/// The exact serializable subset of media_kit's `Media`: resource and HTTP
/// headers. `extras` are mpv-specific and intentionally do not alter Apple's
/// AVURLAsset behavior.
struct VideoMediaSource: Equatable {
  let resource: String
  let url: URL
  let httpHeaders: [String: String]

  init(resource: String, httpHeaders: [String: String] = [:]) {
    self.resource = resource
    self.url = URL(string: resource) ?? URL(fileURLWithPath: resource)
    self.httpHeaders = httpHeaders
  }

  init?(_ value: RufletValue) {
    if let raw = value.stringValue {
      self.init(resource: raw)
      return
    }
    guard let map = value.mapValue,
      let resource = map["resource"]?.stringValue
        ?? map["resource_url"]?.stringValue
        ?? map["src"]?.stringValue
    else { return nil }
    let headers = map["http_headers"]?.mapValue?.reduce(into: [String: String]()) {
      if let string = $1.value.stringValue { $0[$1.key] = string }
    } ?? [:]
    self.init(resource: resource, httpHeaders: headers)
  }
}

#if canImport(AVKit)
  /// `AVPlayerViewController` is the UIKit player; AppKit has `AVPlayerView`.
  /// Neither is a SwiftUI view, so each platform gets its own representable.
  private struct PlayerView {
    let model: VideoPlayerModel
    let showsControls: Bool
    let fit: String?
    let filterQuality: String
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
          events.fire(node, "exit_fullscreen")
          fullscreenController.dismiss(animated: true)
          context.coordinator.fullscreenController = nil
        }
      }

      private func configure(_ controller: AVPlayerViewController) {
        controller.showsPlaybackControls = showsControls
        controller.videoGravity = videoGravity
        controller.view.layer.magnificationFilter = layerFilter
        controller.view.layer.minificationFilter = layerFilter
      }

      private var layerFilter: CALayerContentsFilter {
        filterQuality.lowercased() == "none" ? .nearest
          : filterQuality.lowercased() == "high" ? .trilinear : .linear
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
        view.wantsLayer = true
        view.player = model.player
        view.controlsStyle = showsControls ? .inline : .none
        view.layer?.magnificationFilter = layerFilter
        view.layer?.minificationFilter = layerFilter
        return view
      }
      func updateNSView(_ view: AVPlayerView, context: Context) {
        view.player = model.player
        view.controlsStyle = showsControls ? .inline : .none
        view.layer?.magnificationFilter = layerFilter
        view.layer?.minificationFilter = layerFilter
      }

      private var layerFilter: CALayerContentsFilter {
        filterQuality.lowercased() == "none" ? .nearest
          : filterQuality.lowercased() == "high" ? .trilinear : .linear
      }
    }
  #endif
#endif
