import Foundation
import Lottie
import RufletEngine
import RufletProtocol
import SwiftUI

#if os(iOS)
import UIKit
#endif

@MainActor
private final class RufletLottieLoader: ObservableObject {
  @Published var animation: LottieAnimation?
  @Published var error: Error?
  private var loadKey: String?

  func load(control: RufletControl) async {
    let nextSource = control.value("src")
    let enableMergePaths = control.boolean("enable_merge_paths", default: false)
    let backgroundLoading = control.boolean("background_loading", default: false)
    let nextLoadKey = "\(String(describing: nextSource))|\(enableMergePaths)|\(backgroundLoading)"
    guard nextLoadKey != loadKey else { return }
    loadKey = nextLoadKey
    animation = nil
    error = nil
    do {
      let sourceData = try await Self.data(for: nextSource, control: control)
      let data = rufletLottieData(sourceData, enableMergePaths: enableMergePaths)
      if backgroundLoading {
        animation = try await Task.detached(priority: .utility) {
          try LottieAnimation.from(data: data)
        }.value
      } else {
        animation = try LottieAnimation.from(data: data)
      }
      control.triggerEvent("load")
    } catch {
      self.error = error
      if control.hasEventHandler("error") {
        control.triggerEvent("error", data: .string(String(describing: error)))
      }
    }
  }

  private static func data(for source: RufletValue?, control: RufletControl) async throws -> Data {
    guard let source else { throw RufletLottieError.missingSource }
    if case .binary(let data) = source { return data }
    guard case .string = source, let asset = control.backend.resolveAssetSource(source) else {
      throw RufletLottieError.invalidSource
    }
    if asset.isFile { return try Data(contentsOf: URL(fileURLWithPath: asset.path), options: .mappedIfSafe) }
    guard let url = URL(string: asset.path) else { throw RufletLottieError.invalidSource }
    var request = URLRequest(url: url)
    if let headers = control.value("headers")?.map {
      for (name, value) in headers { if let text = value.text { request.setValue(text, forHTTPHeaderField: name) } }
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
      throw RufletLottieError.httpStatus(http.statusCode)
    }
    return data
  }
}

struct LottieControl: View {
  @ObservedObject var control: RufletControl
  @StateObject private var loader = RufletLottieLoader()

  var body: some View {
    Group {
      if let animation = loader.animation {
        configuredView(animation)
      } else if let error = loader.error {
        errorView(error)
      } else {
        ProgressView()
      }
    }
    .task(id: "\(String(describing: control.value("src")))|\(control.boolean("enable_merge_paths", default: false))|\(control.boolean("background_loading", default: false))") {
      await loader.load(control: control)
    }
  }

  private func configuredView(_ animation: LottieAnimation) -> AnyView {
    let repeatAnimation = control.boolean("repeat", default: true)
    let reverse = control.boolean("reverse", default: false)
    let animate = control.boolean("animate", default: true)
    let enableLayersOpacity = control.boolean("enable_layers_opacity", default: false)
    let view = LottieView(animation: animation)
      .resizable()
      .configure { animationView in
        #if os(iOS)
        animationView.contentMode = contentMode
        animationView.layer.allowsGroupOpacity = enableLayersOpacity
        let filter = lottieContentsFilter
        animationView.layer.magnificationFilter = filter
        animationView.layer.minificationFilter = filter
        #elseif os(macOS)
        animationView.contentMode = lottieContentMode
        animationView.layer?.allowsGroupOpacity = enableLayersOpacity
        let filter = lottieContentsFilter
        animationView.layer?.magnificationFilter = filter
        animationView.layer?.minificationFilter = filter
        #endif
      }

    if !animate {
      return AnyView(view.paused(
        at: LottiePlaybackMode.PausedState.progress(reverse ? 1 : 0)))
    }
    let loopMode: LottieLoopMode = repeatAnimation ? .loop : .playOnce
    if reverse {
      return AnyView(view.playing(
        LottiePlaybackMode.PlaybackMode.fromProgress(1, toProgress: 0, loopMode: loopMode)))
    }
    return AnyView(view.playing(
      LottiePlaybackMode.PlaybackMode.fromProgress(0, toProgress: 1, loopMode: loopMode)))
  }

  private var lottieContentsFilter: CALayerContentsFilter {
    switch control.string("filter_quality")?.lowercased() {
    case "none": .nearest
    case "high": .trilinear
    default: .linear
    }
  }

  @ViewBuilder
  private func errorView(_ error: Error) -> some View {
    if let errorContent = control.buildWidget("error_content") {
      errorContent
    } else {
      VStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle")
        Text("Error loading Lottie")
        Text(String(describing: error)).font(.caption).foregroundColor(.secondary)
      }
      .accessibilityElement(children: .combine)
    }
  }

  #if os(iOS)
  private var contentMode: UIView.ContentMode {
    switch control.string("fit")?.lowercased() {
    case "fill": .scaleToFill
    case "cover": .scaleAspectFill
    case "none": .center
    default: .scaleAspectFit
    }
  }
  #elseif os(macOS)
  private var lottieContentMode: LottieContentMode {
    switch control.string("fit")?.lowercased() {
    case "fill": .scaleToFill
    case "cover": .scaleAspectFill
    case "none": .center
    default: .scaleAspectFit
    }
  }
  #endif
}

func rufletLottieData(_ data: Data, enableMergePaths: Bool) -> Data {
  guard !enableMergePaths,
    let root = try? JSONSerialization.jsonObject(with: data),
    JSONSerialization.isValidJSONObject(root)
  else { return data }

  func removeMergePaths(_ value: Any) -> Any {
    if let array = value as? [Any] {
      return array.compactMap { item -> Any? in
        if let map = item as? [String: Any], map["ty"] as? String == "mm" { return nil }
        return removeMergePaths(item)
      }
    }
    if let map = value as? [String: Any] {
      return map.mapValues(removeMergePaths)
    }
    return value
  }

  return (try? JSONSerialization.data(withJSONObject: removeMergePaths(root))) ?? data
}

public enum RufletLottieError: Error, Equatable, Sendable {
  case missingSource
  case invalidSource
  case httpStatus(Int)
}
