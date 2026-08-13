import Foundation
import RufletProtocol
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public final class ShareService: RufletInvokableService {
  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    let items: [Any]
    switch name {
    case "share_text":
      guard let text = arguments["text"]?.text else { throw RufletServiceError.missingArgument("text") }
      items = [text]
    case "share_uri":
      guard let value = arguments["uri"]?.text, let url = URL(string: value) else {
        throw RufletServiceError.invalidArgument("uri")
      }
      items = [url]
    case "share_files":
      var values = try shareFileURLs(arguments["files"])
      if let text = arguments["text"]?.text { values.append(text) }
      items = values
    default: throw RufletServiceError.unknownMethod(service: "Share", method: name)
    }
    return try await presentShare(items: items, arguments: arguments)
  }

  private func shareFileURLs(_ value: RufletValue?) throws -> [Any] {
    guard let values = value?.array else { return [] }
    return try values.enumerated().map { index, value -> Any in
      guard let map = value.map else { throw RufletServiceError.invalidArgument("files") }
      if let path = map["path"]?.text { return URL(fileURLWithPath: path) }
      guard let data = map["data"]?.serviceData else { throw RufletServiceError.invalidArgument("files") }
      let name = nonempty(map["name"]?.text) ?? "shared_file_\(index)"
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
      try data.write(to: url, options: .atomic)
      return url
    }
  }

  private func presentShare(
    items: [Any],
    arguments: [String: RufletValue]
  ) async throws -> RufletValue {
    #if os(iOS)
    return try await withCheckedThrowingContinuation { continuation in
      let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
      controller.excludedActivityTypes = arguments["excluded_cupertino_activities"]?.array?.compactMap {
        $0.text.map(UIActivity.ActivityType.init(rawValue:))
      }
      if let origin = arguments["share_position_origin"]?.map,
         let popover = controller.popoverPresentationController {
        let x = origin["x"]?.number ?? 0
        let y = origin["y"]?.number ?? 0
        let width = origin["width"]?.number ?? 0
        let height = origin["height"]?.number ?? 0
        popover.sourceView = try? servicePresentationController().view
        popover.sourceRect = CGRect(x: x, y: y, width: width, height: height)
      }
      controller.completionWithItemsHandler = { activity, completed, _, error in
        if let error { continuation.resume(throwing: error); return }
        continuation.resume(returning: [
          "status": .string(completed ? "success" : "dismissed"),
          "raw": .string(activity?.rawValue ?? ""),
        ])
      }
      do { try servicePresentationController().present(controller, animated: true) }
      catch { continuation.resume(throwing: error) }
    }
    #elseif os(macOS)
    guard let contentView = NSApp.keyWindow?.contentView else {
      throw RufletServiceError.unavailable("No window available for sharing")
    }
    let picker = NSSharingServicePicker(items: items)
    picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
    return ["status": .string("success"), "raw": .string("")]
    #endif
  }
}

private func nonempty(_ value: String?) -> String? {
  guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
  return value
}

