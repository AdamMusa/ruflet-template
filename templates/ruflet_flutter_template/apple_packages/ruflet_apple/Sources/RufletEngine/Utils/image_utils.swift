import Foundation
import ImageIO
import SwiftUI
import WebKit

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

    var hasSVGPathExtension: Bool {
        guard case .url(let url) = self else { return false }
        return url.pathExtension.lowercased() == "svg"
    }
}

enum RufletImageFormat: Equatable {
    case bitmap
    case svg
}

/// Pinned Flet uses this namespace marker to distinguish inline SVG markup
/// from an asset path. Keep the recognition in the shared source parser so
/// Image, Markdown, avatars, and future image consumers behave identically.
private let rufletSVGNamespace = Data(#" xmlns="http://www.w3.org/2000/svg""#.utf8)

func rufletIsSVGData(_ data: Data) -> Bool {
    data.range(of: rufletSVGNamespace) != nil
}

func rufletImageFormat(
    source: RufletImageSource,
    data: Data,
    mimeType: String? = nil
) -> RufletImageFormat {
    if rufletIsSVGData(data)
        || source.hasSVGPathExtension
        || mimeType?.lowercased() == "image/svg+xml"
    {
        return .svg
    }
    return .bitmap
}

func rufletDecodePlatformImage(
    _ data: Data,
    cacheWidth: Int? = nil,
    cacheHeight: Int? = nil
) -> RufletPlatformImage? {
    if let requested = [cacheWidth, cacheHeight].compactMap({ $0 }).filter({ $0 > 0 }).max(),
       let source = CGImageSourceCreateWithData(data as CFData, nil),
       let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: requested,
       ] as CFDictionary)
    {
        #if os(iOS)
        return UIImage(cgImage: image)
        #elseif os(macOS)
        return NSImage(cgImage: image, size: .zero)
        #endif
    }
    return RufletPlatformImage(data: data)
}

@MainActor
func parseImageSource(_ value: Any?, backend: RufletBackendProtocol) -> RufletImageSource? {
    if let data = value as? Data { return data.isEmpty ? nil : .data(data) }
    if let bytes = imageBytes(value), !bytes.isEmpty { return .data(bytes) }
    guard let raw = value as? String else { return nil }
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return nil }

    let textData = Data(text.utf8)
    if rufletIsSVGData(textData) { return .data(textData) }
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
    var colorBlendMode: BlendMode = .sourceAtop
    var gaplessPlayback = false
    var cacheWidth: Int?
    var cacheHeight: Int?
    var placeholder: AnyView?
    var errorContent: AnyView?
    var fadeInAnimation: ImplicitAnimationDetails?
    var placeholderFadeOutAnimation: ImplicitAnimationDetails?
    var svgFit: RufletImageFit?
    @State private var image: RufletPlatformImage?
    @State private var svgData: Data?
    @State private var failed = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        Group {
            if let svgData {
                renderedSVG(svgData)
                    .transition(.opacity)
            } else if let image {
                renderedImage(image)
                    .transition(.opacity)
            } else if failed, let errorContent {
                errorContent
            } else if let placeholder {
                placeholder.transition(.opacity)
            } else {
                Color.clear
            }
        }
        .task(id: source) { await load() }
        .animation(placeholderFadeOutAnimation?.animation, value: image == nil && svgData == nil)
        .onDisappear { task?.cancel() }
    }

    @ViewBuilder
    private func renderedSVG(_ data: Data) -> some View {
        let nativeView = RufletSVGNativeView(
            data: data,
            fit: svgFit ?? (contentMode == .fill ? .cover : .contain)
        )
        .allowsHitTesting(false)
        if let tint {
            nativeView
                .overlay(tint.blendMode(.sourceAtop))
                .compositingGroup()
        } else {
            nativeView
        }
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
                .resizable(resizingMode: resizingMode)
                .interpolation(interpolation)
                .antialiased(antiAlias)
                .aspectRatio(contentMode: contentMode)
                .overlay(tint.blendMode(colorBlendMode))
                .compositingGroup()
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
            if !gaplessPlayback {
                image = nil
                svgData = nil
            }
            let data: Data
            var mimeType: String?
            switch source {
            case let .data(value): data = value
            case let .url(url) where url.isFileURL: data = try Data(contentsOf: url)
            case let .url(url):
                let (value, response) = try await URLSession.shared.data(from: url)
                guard (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) != false else {
                    throw URLError(.badServerResponse)
                }
                data = value
                mimeType = response.mimeType
            }
            if rufletImageFormat(source: source, data: data, mimeType: mimeType) == .svg {
                failed = false
                if let fadeInAnimation {
                    withAnimation(fadeInAnimation.animation) {
                        image = nil
                        svgData = data
                    }
                } else {
                    image = nil
                    svgData = data
                }
                return
            }
            guard let loaded = rufletDecodePlatformImage(
                data, cacheWidth: cacheWidth, cacheHeight: cacheHeight)
            else {
                throw URLError(.cannotDecodeContentData)
            }
            failed = false
            if let fadeInAnimation {
                withAnimation(fadeInAnimation.animation) {
                    svgData = nil
                    image = loaded
                }
            } else {
                svgData = nil
                image = loaded
            }
        } catch {
            image = nil
            svgData = nil
            failed = true
            onError?()
        }
    }
}

func rufletSVGDocument(data: Data, fit: RufletImageFit) -> String? {
    guard var svg = String(data: data, encoding: .utf8) else { return nil }
    let preserveAspectRatio: String
    let sizing: String
    switch fit {
    case .fill:
        preserveAspectRatio = "none"
        sizing = "width:100%;height:100%;"
    case .cover:
        preserveAspectRatio = "xMidYMid slice"
        sizing = "width:100%;height:100%;"
    case .fitWidth:
        preserveAspectRatio = "xMidYMid meet"
        sizing = "width:100%;height:auto;max-height:100%;"
    case .fitHeight:
        preserveAspectRatio = "xMidYMid meet"
        sizing = "width:auto;height:100%;max-width:100%;"
    case .none:
        preserveAspectRatio = "xMidYMid meet"
        sizing = "width:auto;height:auto;max-width:none;max-height:none;"
    case .scaleDown:
        preserveAspectRatio = "xMidYMid meet"
        sizing = "width:auto;height:auto;max-width:100%;max-height:100%;"
    case .contain:
        preserveAspectRatio = "xMidYMid meet"
        sizing = "width:100%;height:100%;"
    }

    guard let openingStart = svg.range(of: "<svg", options: .caseInsensitive),
        let openingEnd = svg[openingStart.lowerBound...].firstIndex(of: ">")
    else { return nil }
    let openingRange = openingStart.lowerBound..<svg.index(after: openingEnd)
    var opening = String(svg[openingRange])
    if let expression = try? NSRegularExpression(
        pattern: #"(?i)\s+preserveAspectRatio\s*=\s*("[^"]*"|'[^']*')"#)
    {
        opening = expression.stringByReplacingMatches(
            in: opening,
            range: NSRange(opening.startIndex..., in: opening),
            withTemplate: "")
    }
    opening.insert(
        contentsOf: " preserveAspectRatio=\"\(preserveAspectRatio)\"",
        at: opening.index(before: opening.endIndex))
    svg.replaceSubrange(openingRange, with: opening)

    return """
        <!doctype html>
        <html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
        html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:transparent}
        body{display:flex;align-items:center;justify-content:center}
        svg{display:block;\(sizing)}
        </style></head><body>\(svg)</body></html>
        """
}

@MainActor
private struct RufletSVGNativeView {
    let data: Data
    let fit: RufletImageFit

    final class Coordinator {
        var document: String?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.underPageBackgroundColor = .clear
        return webView
    }

    func update(_ webView: WKWebView, coordinator: Coordinator) {
        guard let document = rufletSVGDocument(data: data, fit: fit),
            coordinator.document != document
        else { return }
        coordinator.document = document
        webView.loadHTMLString(document, baseURL: nil)
    }
}

#if os(iOS)
extension RufletSVGNativeView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = makeWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        update(webView, coordinator: context.coordinator)
    }
}
#elseif os(macOS)
extension RufletSVGNativeView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let webView = makeWebView()
        webView.enclosingScrollView?.drawsBackground = false
        webView.enclosingScrollView?.hasHorizontalScroller = false
        webView.enclosingScrollView?.hasVerticalScroller = false
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        update(webView, coordinator: context.coordinator)
    }
}
#endif

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
