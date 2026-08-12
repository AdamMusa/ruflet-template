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
struct AudioPlaybackOptions: Equatable {
  let autoplay: Bool
  let volume: Double
  let balance: Double
  let playbackRate: Double
  let releaseMode: String?

  init(_ node: ControlNode) {
    autoplay = node.bool("autoplay") ?? false
    let requestedVolume = node.double("volume") ?? 1
    volume = (0...1).contains(requestedVolume) ? requestedVolume : 1
    let requestedBalance = node.double("balance") ?? 0
    balance = (-1...1).contains(requestedBalance) ? requestedBalance : 0
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
  private var sourceIdentity: String?
  private var playbackRate: Float = 1

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
          completion(.failure(RufletServiceError.failed("Audio must have \"src\" specified.")))
          return
        }
        if call.name == "play", let milliseconds = call.argument("position")?.doubleValue {
          guard let player else {
            completion(.success(.null))
            return
          }
          player.seek(
            to: CMTime(seconds: milliseconds / 1000, preferredTimescale: 600)
          ) { [weak self] _ in
            Task { @MainActor in
              guard let self else { return }
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
        player?.seek(to: .zero)
        emit("state_change", .map(["state": .string("disposed")]))
        releasePlayer()
        completion(.success(.null))

      case "seek":
        guard let milliseconds = call.argument("position")?.doubleValue else {
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
        completion(.success(.int(Int64(seconds * 1000))))

      case "get_current_position":
        guard let seconds = player?.currentTime().seconds, seconds.isFinite else {
          return completion(.success(.null))
        }
        completion(.success(.int(Int64(seconds * 1000))))

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
      let url: URL?
      let identity: String?
      if let source = node.string("src"), let parsed = URL(string: source), parsed.scheme != nil {
        url = parsed
        identity = "url:\(source)"
      } else if let source = node.string("src") {
        url = URL(fileURLWithPath: source)
        identity = "file:\(source)"
      } else if let encoded = node.string("src_base64"), let data = Data(base64Encoded: encoded) {
        // Flet lets a sound travel inline; AVPlayer needs a file, so the bytes
        // are spilled to a temporary one named for their own digest.
        let file = FileManager.default.temporaryDirectory
          .appendingPathComponent("ruflet-audio-\(encoded.hashValue).m4a")
        try? data.write(to: file)
        url = file
        identity = "base64:\(encoded.hashValue)"
      } else {
        url = nil
        identity = nil
      }
      guard let url, let identity else { return }

      self.context = context
      controlID = node.id
      control = node

      let sourceChanged = player == nil || identity != sourceIdentity
      if sourceChanged {
        releasePlayer()
        if identity.hasPrefix("base64:") { temporarySourceURL = url }
        sourceIdentity = identity
        installPlayer(url: url, node: node)
      }

      guard let player else { return }
      let options = AudioPlaybackOptions(node)
      player.volume = Float(options.volume)
      playbackRate = Float(options.playbackRate)
      if player.rate != 0 { player.rate = playbackRate }
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
                .map(["duration": .int(Int64(item.duration.seconds * 1000))]))
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
    switch control?.string("release_mode")?.lowercased() ?? "release" {
    case "loop":
      player?.seek(to: .zero)
      player?.playImmediately(atRate: playbackRate)
    case "stop":
      player?.pause()
      player?.seek(to: .zero)
    default:
      // audioplayers defaults to ReleaseMode.release.
      releasePlayer()
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
