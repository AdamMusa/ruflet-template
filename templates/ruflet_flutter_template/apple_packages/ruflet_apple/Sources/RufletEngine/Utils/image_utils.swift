import Foundation
import SwiftUI

#if os(iOS)
import UIKit
typealias RufletPlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias RufletPlatformImage = NSImage
#endif

enum RufletImageSource: Equatable {
    case data(Data)
    case url(URL)
}

@MainActor
func parseImageSource(_ value: Any?, backend: RufletBackendProtocol) -> RufletImageSource? {
    if let data = value as? Data { return .data(data) }
    guard let text = value.map(String.init(describing:)), !text.isEmpty else { return nil }
    let payload = text.stripBase64DataHeader()
    if text.hasPrefix("data:"), let data = Data(base64Encoded: payload) {
        return .data(data)
    }
    if !isURL(text), let data = Data(base64Encoded: payload) {
        return .data(data)
    }
    if let url = URL(string: text), url.scheme != nil {
        return .url(url)
    }
    if let pageURL = backend.pageURI, let url = URL(string: text, relativeTo: pageURL)?.absoluteURL {
        return .url(url)
    }
    return URL(fileURLWithPath: text).standardizedFileURL.isFileURL
        ? .url(URL(fileURLWithPath: text).standardizedFileURL)
        : nil
}

@MainActor
struct RufletImageSourceView: View {
    let source: RufletImageSource
    let contentMode: ContentMode
    let onError: (() -> Void)?
    @State private var image: RufletPlatformImage?
    @State private var task: Task<Void, Never>?

    var body: some View {
        Group {
            if let image {
                platformImage(image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color.clear
            }
        }
        .task(id: source) { await load() }
        .onDisappear { task?.cancel() }
    }

    @ViewBuilder
    private func platformImage(_ image: RufletPlatformImage) -> Image {
        #if os(iOS)
        Image(uiImage: image)
        #elseif os(macOS)
        Image(nsImage: image)
        #endif
    }

    private func load() async {
        do {
            let data: Data
            switch source {
            case let .data(value): data = value
            case let .url(url) where url.isFileURL: data = try Data(contentsOf: url)
            case let .url(url):
                let (value, response) = try await URLSession.shared.data(from: url)
                guard (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) != false else {
                    throw URLError(.badServerResponse)
                }
                data = value
            }
            guard let loaded = RufletPlatformImage(data: data) else { throw URLError(.cannotDecodeContentData) }
            image = loaded
        } catch {
            onError?()
        }
    }
}

enum RufletImageFit: String, CaseIterable, RufletStringEnum {
    case fill, contain, cover, fitWidth, fitHeight, none, scaleDown

    var contentMode: ContentMode {
        switch self {
        case .cover, .fill: .fill
        default: .fit
        }
    }
}
