import Foundation
import os

/// Engine logging.
///
/// A renderer that quietly drops what it does not understand is impossible to
/// debug, so unknown control types, undecodable frames and rejected patches all
/// come through here rather than being ignored.
public enum RufletLog {
  private static let logger = Logger(subsystem: "com.izeesoft.ruflet", category: "engine")

  /// Set to true to see every unmapped control type and property.
  public static var isVerbose = false

  public static func debug(_ message: @autoclosure @escaping () -> String) {
    guard isVerbose else { return }
    logger.debug("\(message(), privacy: .public)")
  }

  public static func info(_ message: @autoclosure @escaping () -> String) {
    logger.info("\(message(), privacy: .public)")
  }

  public static func error(_ message: @autoclosure @escaping () -> String) {
    logger.error("\(message(), privacy: .public)")
  }
}
