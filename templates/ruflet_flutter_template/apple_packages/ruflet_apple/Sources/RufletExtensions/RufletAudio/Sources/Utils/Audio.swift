import Foundation

/// Apple equivalent of `audioplayers.ReleaseMode` used by Flet's Audio service.
public enum RufletAudioReleaseMode: String, CaseIterable, Sendable {
  case release
  case loop
  case stop

  public static func parse(_ value: String?, default defaultValue: Self? = nil) -> Self? {
    guard let value else { return defaultValue }
    return allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }
      ?? defaultValue
  }
}

public enum RufletAudioSource: Sendable, Equatable {
  case url(URL)
  case bytes(Data)
}

public enum RufletAudioPlayerState: String, Sendable {
  case stopped
  case playing
  case paused
  case completed
  case disposed
}

public enum RufletAudioEvent: Sendable, Equatable {
  case loaded
  case durationChange(milliseconds: Int)
  case stateChange(RufletAudioPlayerState)
  case positionChange(milliseconds: Int)
  case seekComplete
}
