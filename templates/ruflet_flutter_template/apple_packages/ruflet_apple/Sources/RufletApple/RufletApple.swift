@_exported import RufletEngine
@_exported import RufletProtocol
@_exported import RufletUI

import Foundation
import SwiftUI

/// The Ruflet Apple engine.
///
/// A native renderer for the Ruflet protocol: it attaches to a Ruflet runtime
/// the same way the Flutter client does, so the same Ruby application runs
/// against either without renderer-specific flags or platform-specific code.
public enum RufletApple {
  /// The engine version, tracked against the Ruby packages it speaks to.
  public static let version = "0.0.14"

  /// Turns on verbose logging of unmapped control types and properties.
  public static func enableVerboseLogging() {
    RufletLog.isVerbose = true
  }
}
