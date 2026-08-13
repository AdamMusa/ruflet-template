import CoreGraphics
import SwiftUI

public enum RufletPagePlatform: String, Equatable, Sendable {
  case iOS = "ios"
  case macOS = "macos"

  public static var current: RufletPagePlatform {
    #if os(iOS)
    .iOS
    #elseif os(macOS)
    .macOS
    #endif
  }
}

/// SwiftUI equivalent of Flet's store-selector mixin. Conforming native
/// controls receive only the page-size model or Apple platform selected by the
/// corresponding wrapper.
@MainActor
public protocol RufletStoreMixin {}

@MainActor
public extension RufletStoreMixin {
  func withPageSize<Content: View>(
    @ViewBuilder _ build: @escaping (RufletPageSizeViewModel) -> Content
  ) -> some View {
    RufletPageSizeStoreView(build: build)
  }

  func withPagePlatform<Content: View>(
    @ViewBuilder _ build: @escaping (RufletPagePlatform) -> Content
  ) -> some View {
    RufletPagePlatformStoreView(build: build)
  }
}

@MainActor
struct RufletPageSizeStoreView<Content: View>: View {
  @EnvironmentObject private var backend: RufletBackend
  let build: (RufletPageSizeViewModel) -> Content

  var body: some View {
    build(Self.selection(size: backend.pageSize, breakpoints: backend.sizeBreakpoints))
  }

  static func selection(
    size: CGSize,
    breakpoints: [String: Double]
  ) -> RufletPageSizeViewModel {
    RufletPageSizeViewModel(size: size, breakpoints: breakpoints)
  }
}

@MainActor
struct RufletPagePlatformStoreView<Content: View>: View {
  let build: (RufletPagePlatform) -> Content

  var body: some View { build(.current) }
}
