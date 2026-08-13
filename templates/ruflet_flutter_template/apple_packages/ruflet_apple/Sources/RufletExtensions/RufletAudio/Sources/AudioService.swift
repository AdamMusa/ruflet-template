import AVFoundation
import Foundation
import RufletEngine
import RufletProtocol

/// Native Apple playback implementation consumed by `RufletAudioExtension`.
///
/// The Dart package uses `audioplayers`; this port deliberately speaks directly
/// to AVFAudio because iOS and macOS are the only renderer platforms.
@MainActor
public final class RufletAudioPlayer: NSObject, AVAudioPlayerDelegate {
  public var onEvent: (@MainActor @Sendable (RufletAudioEvent) -> Void)?

  private var player: AVAudioPlayer?
  private var positionTimer: Timer?
  private var releaseMode: RufletAudioReleaseMode = .release
  private var lastPosition = -1
  private var state: RufletAudioPlayerState = .stopped

  public override init() {
    super.init()
  }

  deinit {
    positionTimer?.invalidate()
  }

  public func load(_ source: RufletAudioSource, autoplay: Bool = false) async throws {
    let data: Data
    switch source {
    case .bytes(let bytes):
      data = bytes
    case .url(let url) where url.isFileURL:
      data = try Data(contentsOf: url, options: .mappedIfSafe)
    case .url(let url):
      let (downloaded, response) = try await URLSession.shared.data(from: url)
      if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
        throw RufletAudioError.httpStatus(http.statusCode)
      }
      data = downloaded
    }

    let nextPlayer = try AVAudioPlayer(data: data)
    nextPlayer.delegate = self
    nextPlayer.enableRate = true
    nextPlayer.numberOfLoops = releaseMode == .loop ? -1 : 0
    guard nextPlayer.prepareToPlay() else {
      throw RufletAudioError.couldNotPrepare
    }

    player?.stop()
    player = nextPlayer
    lastPosition = -1
    onEvent?(.durationChange(milliseconds: Self.milliseconds(nextPlayer.duration)))
    onEvent?(.loaded)
    transition(to: .stopped)

    if autoplay {
      try resume()
    }
  }

  public func configure(
    volume: Double? = nil,
    balance: Double? = nil,
    playbackRate: Double? = nil,
    releaseMode: RufletAudioReleaseMode? = nil
  ) throws {
    if let volume {
      guard (0 ... 1).contains(volume) else { throw RufletAudioError.invalidVolume(volume) }
      player?.volume = Float(volume)
    }
    if let balance {
      guard (-1 ... 1).contains(balance) else { throw RufletAudioError.invalidBalance(balance) }
      player?.pan = Float(balance)
    }
    if let playbackRate {
      guard playbackRate > 0 else { throw RufletAudioError.invalidPlaybackRate(playbackRate) }
      player?.rate = Float(playbackRate)
    }
    if let releaseMode {
      self.releaseMode = releaseMode
      player?.numberOfLoops = releaseMode == .loop ? -1 : 0
    }
  }

  public func play(positionMilliseconds: Int? = nil) throws {
    if let positionMilliseconds {
      try seek(toMilliseconds: positionMilliseconds)
    }
    try resume()
  }

  public func resume() throws {
    let player = try requirePlayer()
    guard player.play() else { throw RufletAudioError.couldNotPlay }
    transition(to: .playing)
    startPositionTimer()
  }

  public func pause() throws {
    let player = try requirePlayer()
    player.pause()
    transition(to: .paused)
    positionTimer?.invalidate()
    positionTimer = nil
  }

  public func stop() throws {
    let player = try requirePlayer()
    player.stop()
    player.currentTime = 0
    transition(to: .stopped)
    emitPosition(force: true)
  }

  public func release() {
    positionTimer?.invalidate()
    positionTimer = nil
    player?.stop()
    player = nil
    lastPosition = -1
    transition(to: .disposed)
  }

  public func seek(toMilliseconds position: Int) throws {
    let player = try requirePlayer()
    let seconds = Double(max(0, position)) / 1_000
    player.currentTime = min(seconds, player.duration)
    emitPosition(force: true)
    onEvent?(.seekComplete)
  }

  public var durationMilliseconds: Int? {
    player.map { Self.milliseconds($0.duration) }
  }

  public var currentPositionMilliseconds: Int? {
    player.map { Self.milliseconds($0.currentTime) }
  }

  public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    positionTimer?.invalidate()
    positionTimer = nil
    emitPosition(force: true)
    transition(to: .completed)

    switch releaseMode {
    case .release:
      self.player = nil
    case .stop:
      player.currentTime = 0
    case .loop:
      break
    }
  }

  private func requirePlayer() throws -> AVAudioPlayer {
    guard let player else { throw RufletAudioError.sourceNotLoaded }
    return player
  }

  private func transition(to nextState: RufletAudioPlayerState) {
    guard state != nextState else { return }
    state = nextState
    onEvent?(.stateChange(nextState))
  }

  private func startPositionTimer() {
    positionTimer?.invalidate()
    positionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.emitPosition()
      }
    }
  }

  /// Mirrors Flet's one-second position event cadence while preserving the
  /// exact final duration at completion.
  private func emitPosition(force: Bool = false) {
    guard let player else { return }
    let exact = Self.milliseconds(player.currentTime)
    let rounded = Int((Double(exact) / 1_000).rounded()) * 1_000
    let position = exact == Self.milliseconds(player.duration) ? exact : rounded
    guard force || position != lastPosition else { return }
    lastPosition = position
    onEvent?(.positionChange(milliseconds: position))
  }

  private static func milliseconds(_ seconds: TimeInterval) -> Int {
    Int((seconds * 1_000).rounded())
  }
}

public enum RufletAudioError: Error, Equatable, Sendable {
  case sourceNotLoaded
  case couldNotPrepare
  case couldNotPlay
  case httpStatus(Int)
  case invalidVolume(Double)
  case invalidBalance(Double)
  case invalidPlaybackRate(Double)
  case invalidSource
  case unknownMethod(String)
}

/// Flet service binding for `Audio` controls.
@MainActor
public final class AudioService: RufletService {
  private let player = RufletAudioPlayer()
  private var invokeToken: UUID?
  private var updateTask: Task<Void, Never>?
  private var loadedSource: RufletValue?

  public required init(control: RufletControl) {
    super.init(control: control)
  }

  public override func initialize() {
    player.onEvent = { [weak self] event in self?.emit(event) }
    invokeToken = control.addInvokeMethodListener { [weak self] name, arguments in
      guard let self else { return .null }
      return try await self.invoke(name, arguments: arguments)
    }
    update()
  }

  public override func update() {
    let sourceValue = control.value("src")
    let sourceChanged = sourceValue != loadedSource
    let autoplay = control.boolean("autoplay", default: false)
    let volume = control.number("volume", default: 1) ?? 1
    let balance = control.number("balance", default: 0) ?? 0
    let playbackRate = control.number("playback_rate", default: 1) ?? 1
    let releaseMode = RufletAudioReleaseMode.parse(control.string("release_mode"))

    updateTask?.cancel()
    updateTask = Task { @MainActor [weak self] in
      guard let self, !Task.isCancelled else { return }
      do {
        try player.configure(
          volume: volume,
          balance: balance,
          playbackRate: playbackRate,
          releaseMode: releaseMode)
        if sourceChanged {
          guard let sourceValue, let source = resolve(sourceValue) else {
            throw RufletAudioError.invalidSource
          }
          try await player.load(source, autoplay: autoplay)
          loadedSource = sourceValue
        }
      } catch {
        control.triggerEvent("error", data: .string(String(describing: error)))
      }
    }
  }

  public override func dispose() {
    updateTask?.cancel()
    if let invokeToken { control.removeInvokeMethodListener(invokeToken) }
    invokeToken = nil
    player.release()
  }

  private func invoke(_ name: String, arguments: RufletValue) async throws -> RufletValue {
    let position = Self.durationMilliseconds(arguments["position"])
    switch name {
    case "play":
      try player.play(positionMilliseconds: position)
      return .null
    case "resume":
      try player.resume()
      return .null
    case "pause":
      try player.pause()
      return .null
    case "release":
      player.release()
      loadedSource = nil
      return .null
    case "seek":
      if let position { try player.seek(toMilliseconds: position) }
      return .null
    case "get_duration":
      return player.durationMilliseconds.map { .int(Int64($0)) } ?? .null
    case "get_current_position":
      return player.currentPositionMilliseconds.map { .int(Int64($0)) } ?? .null
    default:
      throw RufletAudioError.unknownMethod(name)
    }
  }

  private func resolve(_ value: RufletValue) -> RufletAudioSource? {
    switch value {
    case .binary(let data):
      return .bytes(data)
    case .string:
      guard let resolved = control.backend.resolveAssetSource(value) else { return nil }
      if resolved.isFile { return .url(URL(fileURLWithPath: resolved.path)) }
      guard let url = URL(string: resolved.path) else { return nil }
      return .url(url)
    default:
      return nil
    }
  }

  private func emit(_ event: RufletAudioEvent) {
    switch event {
    case .loaded:
      control.triggerEvent("loaded")
    case .durationChange(let milliseconds):
      control.triggerEvent("duration_change", data: ["duration": .int(Int64(milliseconds))])
    case .stateChange(let state):
      control.triggerEvent("state_change", data: ["state": .string(state.rawValue)])
    case .positionChange(let milliseconds):
      control.triggerEvent("position_change", data: ["position": .int(Int64(milliseconds))])
    case .seekComplete:
      control.triggerEvent("seek_complete")
    }
  }

  private static func durationMilliseconds(_ value: RufletValue?) -> Int? {
    guard let value else { return nil }
    if let number = value.number { return Int(number.rounded()) }
    guard let map = value.map else { return nil }
    let days = map["days"]?.number ?? 0
    let hours = map["hours"]?.number ?? 0
    let minutes = map["minutes"]?.number ?? 0
    let seconds = map["seconds"]?.number ?? 0
    let milliseconds = map["milliseconds"]?.number ?? 0
    let microseconds = map["microseconds"]?.number ?? 0
    return Int((days * 86_400_000 + hours * 3_600_000 + minutes * 60_000
      + seconds * 1_000 + milliseconds + microseconds / 1_000).rounded())
  }
}
