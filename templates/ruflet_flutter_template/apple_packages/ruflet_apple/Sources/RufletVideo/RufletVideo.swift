import RufletEngine
import RufletUI
import SwiftUI

/// Optional native renderer for Flet's `flet_video` package.
@MainActor
public enum RufletVideo: RufletExtension {
  public static let extensionName = "RufletVideo"

  public static func register(in _: ServiceRegistry) {
    ControlRegistry.register(
      descriptor: ControlDescriptor(
        wireType: "Video", classification: .visible,
        implementation: "RufletVideo.VideoControlView", rendering: .nativeView,
        supportedEvents: [
          "complete", "enter_fullscreen", "error", "exit_fullscreen", "loaded",
          "track_change",
        ],
        supportedMethods: [
          "get_current_position", "get_duration", "is_completed", "is_playing",
          "jump_to", "next", "pause", "play", "play_or_pause", "playlist_add",
          "playlist_remove", "previous", "seek", "stop",
        ])) { node, _ in
      AnyView(VideoControlView(node: node))
    }
  }
}
