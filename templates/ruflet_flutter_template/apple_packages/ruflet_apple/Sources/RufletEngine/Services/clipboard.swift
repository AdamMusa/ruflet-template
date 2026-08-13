import Foundation
import RufletProtocol
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public final class ClipboardService: RufletInvokableService {
  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    switch name {
    case "set":
      #if os(iOS)
      UIPasteboard.general.string = arguments["data"]?.text
      #elseif os(macOS)
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      if let text = arguments["data"]?.text { pasteboard.setString(text, forType: .string) }
      #endif
      return nil
    case "get":
      #if os(iOS)
      return UIPasteboard.general.string.map(RufletValue.string) ?? .null
      #elseif os(macOS)
      return NSPasteboard.general.string(forType: .string).map(RufletValue.string) ?? .null
      #endif
    case "set_image":
      guard let data = arguments["data"]?.serviceData else {
        throw RufletServiceError.invalidArgument("data")
      }
      #if os(iOS)
      guard let image = UIImage(data: data) else { throw RufletServiceError.invalidArgument("data") }
      UIPasteboard.general.image = image
      #elseif os(macOS)
      guard let image = NSImage(data: data) else { throw RufletServiceError.invalidArgument("data") }
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.writeObjects([image])
      #endif
      return nil
    case "get_image":
      #if os(iOS)
      return UIPasteboard.general.image?.pngData().map(RufletValue.binary) ?? .null
      #elseif os(macOS)
      guard let image = NSImage(pasteboard: NSPasteboard.general),
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
      else { return .null }
      return .binary(png)
      #endif
    case "set_files":
      guard let paths = serviceStringArray(arguments["files"]) else {
        throw RufletServiceError.invalidArgument("files")
      }
      let urls = paths.map(URL.init(fileURLWithPath:))
      #if os(iOS)
      UIPasteboard.general.urls = urls
      return .bool(true)
      #elseif os(macOS)
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      return .bool(pasteboard.writeObjects(urls as [NSURL]))
      #endif
    case "get_files":
      #if os(iOS)
      let paths = (UIPasteboard.general.urls ?? []).filter(\.isFileURL).map(\.path)
      #elseif os(macOS)
      let paths = (NSPasteboard.general.readObjects(
        forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []).map(\.path)
      #endif
      return .array(paths.map(RufletValue.string))
    default: throw RufletServiceError.unknownMethod(service: "Clipboard", method: name)
    }
  }
}

