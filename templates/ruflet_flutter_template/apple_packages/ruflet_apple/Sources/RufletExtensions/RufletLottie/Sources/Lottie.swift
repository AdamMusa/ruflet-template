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
  private var source: RufletValue?

  func load(control: RufletControl) async {
    let nextSource = control.value("src")
    guard nextSource != source else { return }
    source = nextSource
    animation = nil
    error = nil
    do {
      let data = try await Self.data(for: nextSource, control: control)
      animation = try LottieAnimation.from(data: data)
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
    .task(id: control.value("src")) { await loader.load(control: control) }
  }

  private func configuredView(_ animation: LottieAnimation) -> AnyView {
    let repeatAnimation = control.boolean("repeat", default: true)
    let reverse = control.boolean("reverse", default: false)
    let animate = control.boolean("animate", default: true)
    let view = LottieView(animation: animation)
      .resizable()
      .configure { animationView in
        #if os(iOS)
        animationView.contentMode = contentMode
        #elseif os(macOS)
        animationView.contentMode = lottieContentMode
        #endif
      }

    if !animate { return AnyView(view.paused(at: .progress(reverse ? 1 : 0))) }
    let loopMode: LottieLoopMode = repeatAnimation ? .loop : .playOnce
    if reverse {
      return AnyView(view.playing(.fromProgress(1, toProgress: 0, loopMode: loopMode)))
    }
    return AnyView(view.playing(.fromProgress(0, toProgress: 1, loopMode: loopMode)))
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

public enum RufletLottieError: Error, Equatable, Sendable {
  case missingSource
  case invalidSource
  case httpStatus(Int)
}
