#if os(iOS)
  @preconcurrency import AVFoundation
#endif

/// Prepares the process-wide Apple audio route for audible media playback.
///
/// Recording services legitimately switch iOS to a play-and-record session.
/// A later Audio or Video control must reclaim the ordinary playback route,
/// just as the Flet media plugins do, or sound can remain routed to the phone
/// receiver after a recorder is stopped.
@MainActor
public func prepareRufletAppleMediaPlayback() throws {
  #if os(iOS)
    let session = AVAudioSession.sharedInstance()
    if session.category != .playback {
      try session.setCategory(.playback, mode: .moviePlayback)
    }
    try session.setActive(true)
  #endif
}
