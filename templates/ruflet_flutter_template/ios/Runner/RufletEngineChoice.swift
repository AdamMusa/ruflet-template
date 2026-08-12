import Foundation
import RufletApple

// The optional extension modules. `canImport` is what makes them optional: a
// target that does not link one simply compiles this file without it, so
// dropping a module from the target's dependencies is all it takes to keep
// CoreMotion, CoreLocation or AVFoundation capture — and the usage string each
// one obliges you to declare — out of the app.
#if canImport(RufletMotion)
  import RufletMotion
#endif
#if canImport(RufletLocation)
  import RufletLocation
#endif
#if canImport(RufletMedia)
  import RufletMedia
#endif

/// Which renderer this app uses, and which extensions it carries.
///
/// The renderer is chosen by platform, and the choice is structural: this file
/// compiles only into the iOS and macOS runners, so Android, web, Linux and
/// Windows keep the Flutter (Flet) engine without a branch being taken
/// anywhere. The Ruby application is identical on all of them.
enum RufletEngineChoice {
  /// True unless the app opted out.
  ///
  /// `RufletUseFlutterEngine` in Info.plist sends an Apple build back to the
  /// Flutter client — for a Flutter-only extension, or while migrating.
  static var usesNativeRenderer: Bool {
    let optOut = Bundle.main.object(forInfoDictionaryKey: "RufletUseFlutterEngine")
    if let flag = optOut as? Bool { return !flag }
    if let flag = optOut as? NSNumber { return !flag.boolValue }
    return true
  }

  /// The optional extension modules this target links.
  ///
  /// Each Flet extension has its own Swift product. As those products are
  /// added to the app target, their `canImport` branches belong here; the core
  /// renderer never imports their SDKs.
  static var extensions: [any RufletExtension.Type] {
    var extensions: [any RufletExtension.Type] = []
    #if canImport(RufletMotion)
      extensions.append(RufletMotion.self)
    #endif
    #if canImport(RufletLocation)
      extensions.append(RufletLocation.self)
    #endif
    #if canImport(RufletMedia)
      extensions.append(RufletMedia.self)
    #endif
    return extensions
  }

  @available(*, deprecated, renamed: "extensions")
  static var services: [any RufletServiceBundle.Type] { extensions }
}
