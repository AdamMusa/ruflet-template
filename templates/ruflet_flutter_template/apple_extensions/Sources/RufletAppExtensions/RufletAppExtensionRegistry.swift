import RufletApple

/// The application-owned native peers of FletExtension.
///
/// Add extension types in the same order as the Dart `extensions` list. The
/// first extension returning a view, service, or icon wins. This package is
/// copied from the Ruby project on every build, while the generated Runner and
/// Ruflet Apple engine remain replaceable build artifacts.
public enum RufletAppExtensionRegistry {
  public static let extensions: [any RufletExtension.Type] = [
    // RatingExtension.self,
  ]
}
