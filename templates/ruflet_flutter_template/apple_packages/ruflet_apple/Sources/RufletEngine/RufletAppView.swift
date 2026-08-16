import Foundation
import RufletProtocol
import SwiftUI

/// Validates the page address handed to the Apple host by Flutter.
///
/// The returned URL is the original Flet page address. Transport-specific
/// conversion happens once, inside `RufletBackendChannelFactory`.
public enum RufletPageAddress {
  public static func parse(_ rawValue: String) -> URL? {
    guard !rawValue.isEmpty,
      rawValue == rawValue.trimmingCharacters(in: .whitespacesAndNewlines),
      let address = URL(string: rawValue)
    else { return nil }

    switch address.scheme?.lowercased() {
    case "http", "https":
      return address.host == nil ? nil : address
    case "tcp":
      return address.host == nil || address.port == nil ? nil : address
    case nil:
      return address.path.hasPrefix("/") ? address : nil
    default:
      return nil
    }
  }
}

/// Single-view Apple host used by both server-driven and self-contained apps.
@MainActor
public struct RufletAppView: View {
  private let pageURL: URL
  private let assetsDirectory: String
  private let extensions: [any RufletExtension]

  public init(
    pageURL: URL,
    assetsDirectory: String = "",
    extensions: [any RufletExtension] = []
  ) {
    self.pageURL = pageURL
    self.assetsDirectory = assetsDirectory
    self.extensions = extensions
  }

  public var body: some View {
    RufletApp(
      pageURL: pageURL.absoluteString,
      assetsDirectory: assetsDirectory,
      extensions: extensions)
  }
}

/// One native Apple scene in a Flet multi-view session.
public struct RufletNativeScene: Identifiable, Equatable, Sendable {
  public let id: Int
  public let sessionIdentifier: String
  public let initialData: [String: RufletValue]

  public var viewID: Int { id }

  public init(
    viewID: Int,
    sessionIdentifier: String,
    initialData: [String: RufletValue]
  ) {
    id = viewID
    self.sessionIdentifier = sessionIdentifier
    self.initialData = initialData
  }

  public var multiView: RufletMultiView {
    RufletMultiView(viewID: viewID, initialData: initialData)
  }
}

/// Owns one backend and the ordered set of Apple scenes attached to it.
///
/// Flet multi-view is one protocol session, not one connection per window.
@MainActor
public final class RufletMultiViewApplication: ObservableObject {
  public let backend: RufletBackend
  @Published public private(set) var scenes: [RufletNativeScene] = []

  private var nextViewID = 1
  private var registeredFromMultiViews = false

  public init(
    pageURL: URL,
    assetsDirectory: String = "",
    extensions: [any RufletExtension] = []
  ) {
    backend = RufletBackend(
      pageURL: pageURL,
      assetsDirectory: assetsDirectory,
      multiView: true,
      extensions: extensions)
  }

  @discardableResult
  public func connect(
    sessionIdentifier: String,
    initialData: [String: RufletValue] = [:]
  ) -> RufletNativeScene {
    if let existing = scenes.first(where: { $0.sessionIdentifier == sessionIdentifier }) {
      return existing
    }

    let scene = RufletNativeScene(
      viewID: nextViewID,
      sessionIdentifier: sessionIdentifier,
      initialData: initialData)
    nextViewID += 1
    scenes.append(scene)
    RufletPageEventContract.multiViewAdded(backend.page, view: scene.multiView)

    if !registeredFromMultiViews {
      registeredFromMultiViews = true
      // Match Flet's post-frame ordering: add the first view before the route
      // releases backend registration.
      Task { @MainActor [weak self] in self?.backend.onRouteUpdated("/") }
    }
    return scene
  }

  public func disconnect(sessionIdentifier: String) {
    guard
      let index = scenes.firstIndex(where: {
        $0.sessionIdentifier == sessionIdentifier
      })
    else { return }
    let scene = scenes.remove(at: index)
    RufletPageEventContract.multiViewRemoved(backend.page, viewID: scene.viewID)
  }

  public func scene(sessionIdentifier: String) -> RufletNativeScene? {
    scenes.first(where: { $0.sessionIdentifier == sessionIdentifier })
  }

  var pageLifecycleOwnerID: Int? {
    scenes.first?.viewID
  }

  public func dispose() {
    backend.dispose()
  }
}

/// Converts UIKit scene restoration payloads into Flet's exact wire values.
public enum RufletSceneInitialData {
  public static func convert(_ value: Any) -> RufletValue? {
    switch value {
    case is NSNull:
      return .null
    case let value as Bool:
      return .bool(value)
    case let value as Int:
      return .int(Int64(value))
    case let value as Int8:
      return .int(Int64(value))
    case let value as Int16:
      return .int(Int64(value))
    case let value as Int32:
      return .int(Int64(value))
    case let value as Int64:
      return .int(value)
    case let value as UInt where value <= UInt(Int64.max):
      return .int(Int64(value))
    case let value as UInt8:
      return .int(Int64(value))
    case let value as UInt16:
      return .int(Int64(value))
    case let value as UInt32:
      return .int(Int64(value))
    case let value as UInt64 where value <= UInt64(Int64.max):
      return .int(Int64(value))
    case let value as Float:
      return .double(Double(value))
    case let value as Double:
      return .double(value)
    case let value as String:
      return .string(value)
    case let value as Data:
      return .binary(value)
    case let value as [Any]:
      let converted = value.compactMap(convert)
      return converted.count == value.count ? .array(converted) : nil
    case let value as [String: Any]:
      var converted: [String: RufletValue] = [:]
      for (key, item) in value {
        guard let item = convert(item) else { return nil }
        converted[key] = item
      }
      return .map(converted)
    default:
      return nil
    }
  }
}

/// The scene-local surface of one shared Flet multi-view backend.
@MainActor
public struct RufletMultiViewAppView: View {
  @ObservedObject private var application: RufletMultiViewApplication
  private let scene: RufletNativeScene

  public init(application: RufletMultiViewApplication, scene: RufletNativeScene) {
    self.application = application
    self.scene = scene
  }

  public var body: some View {
    RufletHeroScope {
      ZStack {
        // Pinned Flet owns one PageControl for the shared multi-view backend.
        // Keep exactly one scene responsible for that lifecycle surface.
        if application.pageLifecycleOwnerID == scene.viewID {
          ControlWidget(control: application.backend.page)
            .hidden()
            .allowsHitTesting(false)
        }

        RufletMultiViewSceneContent(
          backend: application.backend,
          page: application.backend.page,
          scene: scene)
      }
    }
    .environmentObject(application.backend.extensionRegistry)
    .environmentObject(application.backend)
    .onOpenURL { application.backend.onRouteUpdated($0.absoluteString) }
  }
}

@MainActor
private struct RufletMultiViewSceneContent: View {
  @ObservedObject var backend: RufletBackend
  @ObservedObject var page: RufletControl
  let scene: RufletNativeScene
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    PageContext(themeMode: themeMode, theme: activePageTheme, design: pageDesign) {
      ZStack {
        if let viewControl {
          ControlWidget(control: viewControl)
        } else {
          LoadingPage(
            isLoading: backend.isLoading,
            message: backend.isLoading
              ? backend.appStartupScreenMessage ?? "Loading..."
              : backend.formatAppErrorMessage(backend.error))
        }
        RufletPageMedia(control: multiViewControl ?? page)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var multiViewControl: RufletControl? {
    RufletPageEventContract.multiViewControls(in: page).first {
      $0.integer("view_id") == scene.viewID
    }
  }

  private var viewControl: RufletControl? {
    multiViewControl?.children("views").first
  }

  private var themeMode: RufletThemeMode {
    let source = multiViewControl ?? page
    return parseEnum(RufletThemeMode.self, source.string("theme_mode"), .system)!
  }

  private var activePageTheme: RufletTheme {
    let source = multiViewControl ?? page
    return parsePageThemes(
      theme: source.dynamicValue("theme"),
      darkTheme: source.dynamicValue("dark_theme")
    ).active(themeMode: themeMode, systemColorScheme: colorScheme)
  }

  private var pageDesign: RufletPageDesign {
    let source = multiViewControl ?? page
    return rufletPageDesign(
      adaptive: source.boolean("adaptive", default: false),
      platform: source.string("platform"),
      defaultPlatform: rufletDefaultTargetPlatform)
  }
}
