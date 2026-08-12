import Foundation
import RufletEngine
import RufletProtocol

#if canImport(AVFoundation)
  @preconcurrency import AVFoundation
#endif
#if canImport(UIKit)
  import UIKit
#endif
#if canImport(AppKit)
  import AppKit
#endif

/// `Audio` — playback of a single source, driven entirely by method calls.
enum FletAudioReleaseMode: String, Equatable {
  case release
  case loop
  case stop
}

enum FletAudioSource: Equatable {
  case uri(String)
  case bytes([UInt8])

  enum ResolutionError: Error, Equatable {
    case unsupported
  }

  /// Mirrors Flet's `ResolvedAssetSource.from`: byte lists stay bytes, HTTP
  /// URLs and dotted asset paths stay URIs, and an otherwise-valid Base64
  /// string is decoded before falling back to an asset path.
  static func resolve(_ value: RufletValue?) throws -> FletAudioSource? {
    guard let value, !value.isNull else { return nil }
    switch value {
    case .binary(let bytes):
      return bytes.isEmpty ? nil : .bytes(bytes)
    case .array(let values):
      guard values.allSatisfy({ value in
        if case .int = value { return true }
        return false
      }) else { throw ResolutionError.unsupported }
      let bytes = values.compactMap { value -> UInt8? in
        guard case .int(let byte) = value else { return nil }
        // Uint8List.fromList truncates integers to eight bits.
        return UInt8(truncatingIfNeeded: byte)
      }
      return bytes.isEmpty ? nil : .bytes(bytes)
    case .string(let raw):
      let source = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !source.isEmpty else { return nil }
      if source.hasPrefix("http://") || source.hasPrefix("https://")
        || source.hasPrefix("www.") || source.contains(".")
      {
        return .uri(source)
      }
      let payload: String
      if source.hasPrefix("data:"), let comma = source.firstIndex(of: ",") {
        payload = String(source[source.index(after: comma)...])
      } else {
        payload = source
      }
      if let data = decodeBase64(payload) { return .bytes(Array(data)) }
      return .uri(source)
    default:
      throw ResolutionError.unsupported
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

enum FletAudioDuration {
  /// Flet's `parseDuration`: scalar integers are milliseconds, component maps
  /// are summed, and Ruflet Duration extensions carry microseconds.
  static func milliseconds(_ value: RufletValue?) -> Double? {
    guard let value, !value.isNull else { return nil }
    switch value {
    case .int(let value): return Double(value)
    case .double: return 0
    case .string(let value): return Double(Int64(value) ?? 0)
    case .extended(type: 3, let microseconds):
      return Double(Int64(microseconds) ?? 0) / 1_000
    case .map(let values):
      func integer(_ key: String) -> Int64 {
        switch values[key] {
        case .int(let value): return value
        case .string(let value), .extended(_, let value): return Int64(value) ?? 0
        default: return 0
        }
      }
      let microseconds = integer("microseconds")
        + 1_000 * integer("milliseconds")
        + 1_000_000 * integer("seconds")
        + 60_000_000 * integer("minutes")
        + 3_600_000_000 * integer("hours")
        + 86_400_000_000 * integer("days")
      return Double(microseconds) / 1_000
    default: return 0
    }
  }

  static func wireValue(milliseconds: Int64) -> RufletValue {
    .extended(type: 3, string: String(milliseconds * 1_000))
  }
}

struct AudioPlaybackOptions: Equatable {
  let autoplay: Bool
  let volume: Double
  let validVolume: Double?
  let balance: Double
  let validBalance: Double?
  let playbackRate: Double
  let releaseMode: String?

  init(_ node: ControlNode) {
    autoplay = node.bool("autoplay") ?? false
    let requestedVolume = node.double("volume") ?? 1
    validVolume = (0...1).contains(requestedVolume) ? requestedVolume : nil
    volume = validVolume ?? 1
    let requestedBalance = node.double("balance") ?? 0
    validBalance = (-1...1).contains(requestedBalance) ? requestedBalance : nil
    balance = validBalance ?? 0
    playbackRate = node.double("playback_rate") ?? 1
    releaseMode = node.string("release_mode")?.lowercased()
  }

  /// audioplayers_darwin 6.4.0 accepts `setBalance` but its Apple backend
  /// implements it as a no-op. AVPlayer likewise has no stereo-pan property.
  static let avFoundationUnsupportedProperties: Set<String> = ["balance"]
}
@MainActor
public final class AudioService: RufletStreamingService {
  public static let wireType = "Audio"

  #if canImport(AVFoundation)
    private var player: AVPlayer?
    private var observer: Any?
    private var timeObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var temporarySourceURL: URL?
  #endif
  /// Held rather than captured: the notification closure is `@Sendable`, and
  /// the context is not.
  private var context: RufletServiceContext?
  private var controlID: Int?
  private var control: ControlNode?
  private var sourceIdentity: FletAudioSource?
  private var sourceError: String?
  private var playbackRate: Float = 1
  private var releaseMode: FletAudioReleaseMode = .release

  public init() {}

  public func activate(node: ControlNode, context: RufletServiceContext) {
    ensurePlayer(node: node, context: context)
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    #if canImport(AVFoundation)
      switch call.name {
      case "play", "resume":
        ensurePlayer(node: node, context: context)
        guard player != nil else {
          completion(.failure(RufletServiceError.failed(
            sourceError ?? "Audio must have \"src\" specified.")))
          return
        }
        if call.name == "play",
          let milliseconds = FletAudioDuration.milliseconds(call.argument("position"))
        {
          guard let player else {
            completion(.success(.null))
            return
          }
          player.seek(
            to: CMTime(seconds: milliseconds / 1000, preferredTimescale: 600)
          ) { [weak self] _ in
            Task { @MainActor in
              guard let self else { return }
              self.emit("seek_complete", .null)
              player.playImmediately(atRate: self.playbackRate)
              self.emit("state_change", .map(["state": .string("playing")]))
              completion(.success(.null))
            }
          }
          return
        }
        player?.playImmediately(atRate: playbackRate)
        emit("state_change", .map(["state": .string("playing")]))
        completion(.success(.null))

      case "pause":
        player?.pause()
        emit("state_change", .map(["state": .string("paused")]))
        completion(.success(.null))

      case "release":
        player?.pause()
        if releaseMode != .release, let player, player.currentTime().seconds != 0 {
          player.seek(to: .zero) { [weak self] _ in
            Task { @MainActor in
              guard let self else { return }
              self.emit("seek_complete", .null)
              self.emit("state_change", .map(["state": .string("stopped")]))
              self.releasePlayer()
              completion(.success(.null))
            }
          }
        } else {
          emit("state_change", .map(["state": .string("stopped")]))
          releasePlayer()
          completion(.success(.null))
        }

      case "seek":
        guard let milliseconds = FletAudioDuration.milliseconds(call.argument("position")) else {
          completion(.success(.null))
          return
        }
        guard let player else {
          completion(.success(.null))
          return
        }
        player.seek(
          to: CMTime(seconds: milliseconds / 1000, preferredTimescale: 600)
        ) { [weak self] _ in
          Task { @MainActor in
            self?.emit("seek_complete", .null)
            completion(.success(.null))
          }
        }

      case "get_duration":
        guard let seconds = player?.currentItem?.duration.seconds, seconds.isFinite else {
          return completion(.success(.null))
        }
        completion(.success(FletAudioDuration.wireValue(milliseconds: Int64(seconds * 1000))))

      case "get_current_position":
        guard let seconds = player?.currentTime().seconds, seconds.isFinite else {
          return completion(.success(.null))
        }
        completion(.success(FletAudioDuration.wireValue(milliseconds: Int64(seconds * 1000))))

      default:
        completion(
          .failure(RufletServiceError.unsupportedMethod(type: "Audio", method: call.name)))
      }
    #else
      completion(.failure(RufletServiceError.unavailable("AVFoundation is unavailable")))
    #endif
  }

  #if canImport(AVFoundation)
    /// The source lives on the control's `src`, and Flet reports `state_change`
    /// when playback finishes, so both are wired here.
    private func ensurePlayer(node: ControlNode?, context: RufletServiceContext) {
      guard let node else { return }
      self.context = context
      controlID = node.id
      control = node

      let source: FletAudioSource?
      do {
        if let legacy = node.props["src_base64"], node.props["src"] == nil {
          source = try FletAudioSource.resolve(legacy)
        } else {
          source = try FletAudioSource.resolve(node.props["src"])
        }
      } catch {
        sourceError = "Audio src decode error: unsupported source type."
        return
      }
      guard let source else {
        sourceError = "Audio must have \"src\" specified."
        return
      }
      sourceError = nil

      let sourceChanged = player == nil || source != sourceIdentity
      if sourceChanged {
        releasePlayer()
        guard let url = nativeURL(for: source) else {
          sourceError = "Audio src decode error: source could not be prepared."
          return
        }
        sourceIdentity = source
        installPlayer(url: url, node: node)
      }

      guard let player else { return }
      let options = AudioPlaybackOptions(node)
      if let volume = options.validVolume { player.volume = Float(volume) }
      playbackRate = Float(options.playbackRate)
      if player.rate != 0 { player.rate = playbackRate }
      if let rawReleaseMode = options.releaseMode,
        let releaseMode = FletAudioReleaseMode(rawValue: rawReleaseMode)
      {
        self.releaseMode = releaseMode
      }
      // Keep parity with audioplayers_darwin 6.4.0: Flet forwards balance,
      // while the pinned Apple backend explicitly treats setBalance as a
      // no-op. AVPlayer has no channel-pan API, so applying whole-track volume
      // here would be observably incorrect.

      // Flet applies autoplay when a source is mounted/replaced. A later
      // property update must not unexpectedly resume audio the user paused.
      if sourceChanged, node.bool("autoplay") == true {
        player.playImmediately(atRate: playbackRate)
        emit("state_change", .map(["state": .string("playing")]))
      }
    }

    private func nativeURL(for source: FletAudioSource) -> URL? {
      switch source {
      case .uri(let source):
        if source.hasPrefix("http://") || source.hasPrefix("https://")
          || source.hasPrefix("www.")
        {
          return URL(string: source)
        }
        if source.hasPrefix("file://") { return URL(string: source) }
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent(source),
          FileManager.default.fileExists(atPath: resourceURL.path)
        {
          return resourceURL
        }
        return URL(fileURLWithPath: source)
      case .bytes(let bytes):
        let file = FileManager.default.temporaryDirectory
          .appendingPathComponent("ruflet-audio-\(UUID().uuidString)")
        do {
          try Data(bytes).write(to: file, options: .atomic)
          temporarySourceURL = file
          return file
        } catch {
          return nil
        }
      }
    }

    private func installPlayer(url: URL, node: ControlNode) {
      let player = AVPlayer(url: url)
      self.player = player

      itemStatusObserver = player.currentItem?.observe(\.status, options: [.initial, .new]) {
        [weak self] item, _ in
        Task { @MainActor in
          guard let self else { return }
          switch item.status {
          case .readyToPlay:
            self.emit("loaded", .null)
            if item.duration.seconds.isFinite {
              self.emit(
                "duration_change",
                .map(["duration": FletAudioDuration.wireValue(
                  milliseconds: Int64(item.duration.seconds * 1000))]))
            }
          case .failed:
            self.emit(
              "error",
              .string(item.error?.localizedDescription ?? "The audio could not be loaded"))
          default:
            break
          }
        }
      }
      timeObserver = player.addPeriodicTimeObserver(
        forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main
      ) { [weak self] time in
        Task { @MainActor in
          guard time.seconds.isFinite else { return }
          self?.emit(
            "position_change",
            .map(["position": .int(Int64(time.seconds.rounded() * 1000))]))
        }
      }
      observer = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime,
        object: player.currentItem,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.reportCompletion() }
      }

    }

  #endif

  private func reportCompletion() {
    emit("state_change", .map(["state": .string("completed")]))
    guard let player else { return }
    player.seek(to: .zero) { [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        self.emit("seek_complete", .null)
        switch self.releaseMode {
        case .loop:
          player.playImmediately(atRate: self.playbackRate)
        case .stop:
          player.pause()
        case .release:
          self.releasePlayer()
        }
      }
    }
  }

  private func emit(_ name: String, _ data: RufletValue) {
    guard let context, let controlID, let control, control.handlesEvent(name) else { return }
    context.emitEvent(controlID, name, data)
  }

  #if canImport(AVFoundation)
    private func releasePlayer() {
      if let observer { NotificationCenter.default.removeObserver(observer) }
      observer = nil
      if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
      timeObserver = nil
      itemStatusObserver?.invalidate()
      itemStatusObserver = nil
      player = nil
      if let temporarySourceURL { try? FileManager.default.removeItem(at: temporarySourceURL) }
      temporarySourceURL = nil
      sourceIdentity = nil
    }
  #endif

  deinit {
    #if canImport(AVFoundation)
      if let observer { NotificationCenter.default.removeObserver(observer) }
      if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
      itemStatusObserver?.invalidate()
    #endif
  }
}
