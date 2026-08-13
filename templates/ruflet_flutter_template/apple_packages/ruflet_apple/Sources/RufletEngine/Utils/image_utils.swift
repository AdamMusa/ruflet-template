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
    if let data = value as? Data { return data.isEmpty ? nil : .data(data) }
    if let bytes = imageBytes(value), !bytes.isEmpty { return .data(bytes) }
    guard let raw = value as? String else { return nil }
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return nil }

    if text.hasPrefix("data:"), let data = Data(base64Encoded: text.stripBase64DataHeader()) {
        return data.isEmpty ? nil : .data(data)
    }
    if isURL(text), let url = URL(string: text) { return .url(url) }

    // Pinned Flet treats dotted strings as asset paths before attempting
    // Base64. Other strings are Base64 when decodable, otherwise assets.
    if !text.contains("."), let data = Data(base64Encoded: text.stripBase64DataHeader()) {
        return data.isEmpty ? nil : .data(data)
    }
    guard let asset = backend.resolveAssetSource(.string(text)) else { return nil }
    if asset.isFile { return .url(URL(fileURLWithPath: asset.path)) }
    return URL(string: asset.path).map(RufletImageSource.url)
}

private func imageBytes(_ value: Any?) -> Data? {
    if let values = value as? [UInt8] { return Data(values) }
    if let values = value as? [Int] {
        guard values.allSatisfy({ 0...255 ~= $0 }) else { return nil }
        return Data(values.map(UInt8.init))
    }
    if let values = value as? [Int64] {
        guard values.allSatisfy({ 0...255 ~= $0 }) else { return nil }
        return Data(values.map(UInt8.init))
    }
    guard let values = value as? [Any] else { return nil }
    var bytes: [UInt8] = []
    bytes.reserveCapacity(values.count)
    for value in values {
        guard let number = value as? NSNumber, 0...255 ~= number.intValue else { return nil }
        bytes.append(UInt8(number.intValue))
    }
    return Data(bytes)
}

@MainActor
struct RufletImageSourceView: View {
    let source: RufletImageSource
    let contentMode: ContentMode
    let onError: (() -> Void)?
    var resizingMode: Image.ResizingMode = .stretch
    var interpolation: Image.Interpolation = .medium
    var antiAlias = false
    var tint: Color?
    var placeholder: AnyView?
    var errorContent: AnyView?
    var fadeInAnimation: ImplicitAnimationDetails?
    @State private var image: RufletPlatformImage?
    @State private var failed = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        Group {
            if let image {
                renderedImage(image)
                    .transition(.opacity)
            } else if failed, let errorContent {
                errorContent
            } else if let placeholder {
                placeholder
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

    @ViewBuilder
    private func renderedImage(_ image: RufletPlatformImage) -> some View {
        if let tint {
            platformImage(image)
                .renderingMode(.template)
                .resizable(resizingMode: resizingMode)
                .interpolation(interpolation)
                .antialiased(antiAlias)
                .aspectRatio(contentMode: contentMode)
                .foregroundStyle(tint)
        } else {
            platformImage(image)
                .resizable(resizingMode: resizingMode)
                .interpolation(interpolation)
                .antialiased(antiAlias)
                .aspectRatio(contentMode: contentMode)
        }
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
            failed = false
            if let fadeInAnimation {
                withAnimation(fadeInAnimation.animation) { image = loaded }
            } else {
                image = loaded
            }
        } catch {
            failed = true
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

enum RufletImageRepeat: String, CaseIterable, RufletStringEnum {
    case noRepeat, repeatX, repeatY, `repeat`

    var resizingMode: Image.ResizingMode { self == .noRepeat ? .stretch : .tile }
}

enum RufletFilterQuality: String, CaseIterable, RufletStringEnum {
    case none, low, medium, high

    var interpolation: Image.Interpolation {
        switch self {
        case .none: .none
        case .low: .low
        case .medium: .medium
        case .high: .high
        }
    }
}
