import AVFoundation
import AVKit
import Foundation
import RufletEngine
import RufletProtocol
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public enum RufletVideoError: Error, Equatable, Sendable {
  case emptyPlaylist
  case invalidResource(String)
  case invalidMedia
  case unknownMethod(String)
}

@MainActor
final class RufletVideoController: ObservableObject {
  let control: RufletControl
  let player = AVPlayer()
  @Published var subtitle: String?
  @Published var isFullscreen = false

  private var playlist: [RufletVideoMedia]
  private var currentIndex = 0
  private var invokeToken: UUID?
  private var endObserver: NSObjectProtocol?
  private var errorObserver: NSObjectProtocol?
  private var timeObserver: Any?
  private var foregroundObservers: [NSObjectProtocol] = []
  private var itemStatusObservation: NSKeyValueObservation?
  private var subtitleCues: [RufletSubtitleCue] = []
  private var wasPlayingBeforeBackground = false
  private var attached = false

  init(control: RufletControl) {
    self.control = control
    playlist = parseVideoMedias(control.value("playlist"))
    configurePlayer()
    if !playlist.isEmpty { load(index: 0, autoplay: control.boolean("autoplay", default: false)) }
    Task { await loadSubtitles() }
  }

  deinit {
    if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    if let errorObserver { NotificationCenter.default.removeObserver(errorObserver) }
    for observer in foregroundObservers { NotificationCenter.default.removeObserver(observer) }
    if let timeObserver { player.removeTimeObserver(timeObserver) }
  }

  func attach() {
    guard !attached else { return }
    attached = true
    invokeToken = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { throw RufletVideoError.unknownMethod(name) }
      return try await self.invoke(name, arguments: arguments.map ?? [:])
    }
    #if os(iOS)
    if control.boolean("wakelock", default: true) { UIApplication.shared.isIdleTimerDisabled = true }
    #endif
  }

  func detach() {
    guard attached else { return }
    attached = false
    if let invokeToken {
      control.removeInvokeMethodListener(invokeToken)
      self.invokeToken = nil
    }
    #if os(iOS)
    if control.boolean("wakelock", default: true) { UIApplication.shared.isIdleTimerDisabled = false }
    #endif
  }

  func synchronizeProperties() {
    if let volume = control.number("volume"), (0 ... 100).contains(volume) {
      player.volume = Float(volume / 100)
    }
    player.isMuted = control.boolean("muted", default: false)
    let rate = Float(control.number("playback_rate", default: 1) ?? 1)
    if player.timeControlStatus == .playing, rate > 0 { player.rate = rate }
    player.currentItem?.audioTimePitchAlgorithm = pitchAlgorithm(control.number("pitch"))
    let requestedFullscreen = control.boolean("fullscreen", default: false)
    if requestedFullscreen != isFullscreen { setFullscreen(requestedFullscreen, report: false) }
  }

  func setFullscreen(_ value: Bool, report: Bool = true) {
    guard value != isFullscreen else { return }
    isFullscreen = value
    control.updateProperties(["_fullscreen": .bool(value), "fullscreen": .bool(value)], client: true, server: report)
    control.triggerEvent(value ? "enter_fullscreen" : "exit_fullscreen")
  }

  private func configurePlayer() {
    synchronizeProperties()
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      Task { @MainActor [weak self] in
        guard let self, notification.object as? AVPlayerItem === self.player.currentItem else { return }
        self.completeCurrentItem()
      }
    }
    errorObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      Task { @MainActor [weak self] in
        guard let self else { return }
        let message = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription
          ?? "Video playback failed"
        self.control.triggerEvent("error", data: .string(message))
      }
    }
    timeObserver = player.addPeriodicTimeObserver(
      forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
      queue: .main
    ) { [weak self] time in
      Task { @MainActor [weak self] in self?.updateSubtitle(at: time.seconds) }
    }
    registerLifecycleObservers()
  }

  private func registerLifecycleObservers() {
    #if os(iOS)
    let background = UIApplication.didEnterBackgroundNotification
    let foreground = UIApplication.willEnterForegroundNotification
    #elseif os(macOS)
    let background = NSApplication.didResignActiveNotification
    let foreground = NSApplication.didBecomeActiveNotification
    #endif
    foregroundObservers.append(NotificationCenter.default.addObserver(
      forName: background, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.wasPlayingBeforeBackground = self.player.timeControlStatus == .playing
        if self.control.boolean("pause_upon_entering_background_mode", default: true) { self.player.pause() }
      }
    })
    foregroundObservers.append(NotificationCenter.default.addObserver(
      forName: foreground, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self,
              self.wasPlayingBeforeBackground,
              self.control.boolean("resume_upon_entering_foreground_mode", default: false)
        else { return }
        self.player.playImmediately(atRate: Float(self.control.number("playback_rate", default: 1) ?? 1))
      }
    })
  }

  private func load(index: Int, autoplay: Bool) {
    guard playlist.indices.contains(index) else { return }
    do {
      let item = try makeVideoItem(playlist[index], control: control)
      currentIndex = index
      itemStatusObservation?.invalidate()
      player.replaceCurrentItem(with: item)
      synchronizeProperties()
      itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
        Task { @MainActor [weak self] in
          guard let self else { return }
          if item.status == .readyToPlay {
            self.control.triggerEvent("loaded")
          } else if item.status == .failed {
            self.control.triggerEvent("error", data: .string(item.error?.localizedDescription ?? "Video failed to load"))
          }
        }
      }
      control.triggerEvent("track_change", data: .int(Int64(index)))
      if autoplay { player.playImmediately(atRate: Float(control.number("playback_rate", default: 1) ?? 1)) }
    } catch {
      control.triggerEvent("error", data: .string(String(describing: error)))
    }
  }

  private func completeCurrentItem() {
    control.triggerEvent("complete", data: .bool(true))
    switch RufletVideoPlaylistMode(rawValue: control.string("playlist_mode")?.lowercased() ?? "") ?? .none {
    case .single:
      player.seek(to: .zero)
      player.playImmediately(atRate: Float(control.number("playback_rate", default: 1) ?? 1))
    case .loop:
      load(index: playlist.isEmpty ? 0 : (currentIndex + 1) % playlist.count, autoplay: true)
    case .none:
      if currentIndex + 1 < playlist.count { load(index: currentIndex + 1, autoplay: true) }
    }
  }

  private func invoke(_ name: String, arguments: [String: RufletValue]) async throws -> RufletValue {
    switch name {
    case "play":
      player.playImmediately(atRate: Float(control.number("playback_rate", default: 1) ?? 1)); return .null
    case "pause": player.pause(); return .null
    case "play_or_pause":
      if player.timeControlStatus == .playing { player.pause() }
      else { player.playImmediately(atRate: Float(control.number("playback_rate", default: 1) ?? 1)) }
      return .null
    case "stop":
      player.pause(); await player.seek(to: .zero); return .null
    case "seek":
      if let seconds = parseVideoDuration(arguments["position"]) {
        await player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
      }
      return .null
    case "next":
      guard !playlist.isEmpty else { return .null }
      let index = control.boolean("shuffle_playlist", default: false)
        ? Int.random(in: playlist.indices)
        : min(currentIndex + 1, playlist.count - 1)
      load(index: index, autoplay: true); return .null
    case "previous":
      load(index: max(currentIndex - 1, 0), autoplay: true); return .null
    case "jump_to":
      if let index = arguments["media_index"]?.integer { load(index: index, autoplay: true) }
      return .null
    case "playlist_add":
      guard let media = parseVideoMedia(arguments["media"]) else { throw RufletVideoError.invalidMedia }
      playlist.append(media); return .null
    case "playlist_remove":
      if let index = arguments["media_index"]?.integer, playlist.indices.contains(index) {
        playlist.remove(at: index)
        if index == currentIndex {
          if playlist.isEmpty { player.replaceCurrentItem(with: nil) }
          else { load(index: min(index, playlist.count - 1), autoplay: false) }
        } else if index < currentIndex { currentIndex -= 1 }
      }
      return .null
    case "is_playing": return .bool(player.timeControlStatus == .playing)
    case "is_completed":
      let duration = player.currentItem?.duration.seconds ?? .nan
      return .bool(duration.isFinite && player.currentTime().seconds >= duration)
    case "get_duration": return temporalDuration(player.currentItem?.duration.seconds)
    case "get_current_position": return temporalDuration(player.currentTime().seconds)
    default: throw RufletVideoError.unknownMethod(name)
    }
  }

  private func temporalDuration(_ seconds: TimeInterval?) -> RufletValue {
    guard let seconds, seconds.isFinite else { return .null }
    return RufletMessagePack.temporalDuration(microseconds: Int64((seconds * 1_000_000).rounded()))
  }

  private func pitchAlgorithm(_ pitch: Double?) -> AVAudioTimePitchAlgorithm {
    guard let pitch, pitch != 1 else { return .spectral }
    return .timeDomain
  }

  private func loadSubtitles() async {
    guard let value = control.value("subtitle_track")?.map,
          let source = value["src"]?.text,
          source != "none",
          source != "auto"
    else { return }
    let text: String
    if source.hasPrefix("http://") || source.hasPrefix("https://"), let url = URL(string: source) {
      do {
        let (data, _) = try await URLSession.shared.data(from: url)
        text = String(decoding: data, as: UTF8.self)
      } catch {
        control.triggerEvent("error", data: .string(error.localizedDescription))
        return
      }
    } else {
      text = readFileAsStringIfExists(source) ?? source
    }
    subtitleCues = parseSubtitleCues(text)
  }

  private func updateSubtitle(at seconds: TimeInterval) {
    subtitle = subtitleCues.first(where: { seconds >= $0.start && seconds < $0.end })?.text
  }
}

#if os(iOS)
private struct RufletVideoSurface: UIViewControllerRepresentable {
  let player: AVPlayer
  let showControls: Bool
  let fit: String?
  let fullscreenController: RufletVideoController

  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()
    controller.player = player
    controller.showsPlaybackControls = showControls
    controller.videoGravity = gravity
    return controller
  }

  func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
    controller.player = player
    controller.showsPlaybackControls = showControls
    controller.videoGravity = gravity
  }

  private var gravity: AVLayerVideoGravity {
    switch fit?.lowercased() {
    case "fill": .resize
    case "cover": .resizeAspectFill
    default: .resizeAspect
    }
  }
}
#elseif os(macOS)
private struct RufletVideoSurface: NSViewRepresentable {
  let player: AVPlayer
  let showControls: Bool
  let fit: String?
  let fullscreenController: RufletVideoController

  func makeNSView(context: Context) -> AVPlayerView {
    let view = AVPlayerView()
    view.player = player
    view.delegate = context.coordinator
    update(view)
    return view
  }

  func updateNSView(_ view: AVPlayerView, context: Context) {
    view.player = player
    update(view)
    if fullscreenController.isFullscreen, !view.isInFullScreenMode,
       let screen = view.window?.screen ?? NSScreen.main
    {
      _ = view.enterFullScreenMode(screen, withOptions: nil)
    } else if !fullscreenController.isFullscreen, view.isInFullScreenMode {
      view.exitFullScreenMode(options: nil)
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator(controller: fullscreenController) }

  final class Coordinator: NSObject, AVPlayerViewDelegate {
    let controller: RufletVideoController

    init(controller: RufletVideoController) {
      self.controller = controller
    }

    func playerViewDidEnterFullScreen(_ playerView: AVPlayerView) {
      Task { @MainActor [controller] in controller.setFullscreen(true) }
    }

    func playerViewDidExitFullScreen(_ playerView: AVPlayerView) {
      Task { @MainActor [controller] in controller.setFullscreen(false) }
    }
  }

  private func update(_ view: AVPlayerView) {
    view.controlsStyle = showControls ? .floating : .none
    switch fit?.lowercased() {
    case "fill": view.videoGravity = .resize
    case "cover": view.videoGravity = .resizeAspectFill
    default: view.videoGravity = .resizeAspect
    }
  }
}
#endif

struct VideoControl: View {
  @ObservedObject var control: RufletControl
  @StateObject private var controller: RufletVideoController

  init(control: RufletControl) {
    self.control = control
    _controller = StateObject(wrappedValue: RufletVideoController(control: control))
  }

  var body: some View {
    #if os(iOS)
    playerContent
      .background(parseColor(control.string("fill_color"), .black) ?? .black)
      .onAppear {
        controller.attach()
        controller.synchronizeProperties()
      }
      .onDisappear { controller.detach() }
      .onChange(of: propertyIdentity) { _ in controller.synchronizeProperties() }
      .fullScreenCover(isPresented: fullscreenBinding) { playerContent.background(Color.black) }
    #elseif os(macOS)
    playerContent
      .background(parseColor(control.string("fill_color"), .black) ?? .black)
      .onAppear {
        controller.attach()
        controller.synchronizeProperties()
      }
      .onDisappear { controller.detach() }
      .onChange(of: propertyIdentity) { _ in controller.synchronizeProperties() }
    #endif
  }

  private var playerContent: some View {
    RufletVideoSurface(
      player: controller.player,
      showControls: control.boolean("show_controls", default: true),
      fit: control.string("fit"),
      fullscreenController: controller)
      .overlay(alignment: .bottom) { subtitleView }
  }

  @ViewBuilder
  private var subtitleView: some View {
    let configuration = RufletSubtitleConfiguration(control.value("subtitle_configuration"))
    if configuration.visible, let subtitle = controller.subtitle {
      Text(subtitle)
        .font(.system(size: configuration.fontSize * configuration.scale))
        .foregroundColor(configuration.color)
        .multilineTextAlignment(.center)
        .padding(.horizontal, configuration.horizontalPadding)
        .padding(.vertical, 4)
        .background(configuration.background)
        .padding(.bottom, configuration.bottomPadding)
    }
  }

  private var fullscreenBinding: Binding<Bool> {
    Binding(
      get: { controller.isFullscreen },
      set: { controller.setFullscreen($0) })
  }

  private var propertyIdentity: String {
    ["volume", "muted", "pitch", "playback_rate", "fullscreen"]
      .map { String(describing: control.value($0)) }
      .joined(separator: "\u{1f}")
  }
}
