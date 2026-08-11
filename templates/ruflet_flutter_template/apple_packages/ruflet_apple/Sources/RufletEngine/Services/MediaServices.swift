import Foundation
import RufletProtocol

#if canImport(UIKit)
  import UIKit
#endif
#if canImport(AppKit)
  import AppKit
#endif
#if canImport(UniformTypeIdentifiers)
  import UniformTypeIdentifiers
#endif

/// `FilePicker` — the system open/save panels.
@MainActor
public final class FilePickerService: NSObject, RufletService {
  public static let wireType = "FilePicker"

  private var pending: RufletMethodCompletion?

  public override init() {
    super.init()
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    switch call.name {
    case "pick_files":
      pickFiles(call, completion: completion)
    case "save_file":
      saveFile(call, completion: completion)
    case "get_directory_path":
      pickDirectory(call, completion: completion)
    case "upload":
      completion(.failure(RufletServiceError.platformUnsupported(
        type: Self.wireType, method: call.name, platform: Self.platformName)))
    default:
      completion(
        .failure(RufletServiceError.unsupportedMethod(type: "FilePicker", method: call.name)))
    }
  }

  private static var platformName: String {
    #if os(iOS)
      return "iOS"
    #elseif os(macOS)
      return "macOS"
    #else
      return "this Apple platform"
    #endif
  }

  /// The result shape Flet's file picker returns: a list of
  /// `{name:, path:, size:}` maps.
  private func describe(_ urls: [URL]) -> RufletValue {
    .array(
      urls.map { url in
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return .map([
          "name": .string(url.lastPathComponent),
          "path": .string(url.path),
          "size": .int(Int64(size))
        ])
      })
  }

  #if canImport(AppKit)
    private func pickFiles(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      let panel = NSOpenPanel()
      panel.canChooseFiles = true
      panel.canChooseDirectories = false
      panel.allowsMultipleSelection = call.argument("allow_multiple")?.boolValue ?? false
      panel.message = call.argument("dialog_title")?.stringValue ?? ""
      applyExtensions(call, to: panel)

      panel.begin { response in
        Task { @MainActor in
          completion(.success(response == .OK ? self.describe(panel.urls) : .null))
        }
      }
    }

    private func saveFile(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      let panel = NSSavePanel()
      panel.nameFieldStringValue = call.argument("file_name")?.stringValue ?? ""
      panel.message = call.argument("dialog_title")?.stringValue ?? ""

      panel.begin { response in
        Task { @MainActor in
          completion(.success(response == .OK ? .string(panel.url?.path ?? "") : .null))
        }
      }
    }

    private func pickDirectory(
      _ call: RufletMethodCall, completion: @escaping RufletMethodCompletion
    ) {
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.message = call.argument("dialog_title")?.stringValue ?? ""

      panel.begin { response in
        Task { @MainActor in
          completion(.success(response == .OK ? .string(panel.urls.first?.path ?? "") : .null))
        }
      }
    }

    private func applyExtensions(_ call: RufletMethodCall, to panel: NSOpenPanel) {
      let extensions = (call.argument("allowed_extensions")?.arrayValue ?? [])
        .compactMap(\.stringValue)
      guard !extensions.isEmpty else { return }
      if #available(macOS 12.0, *) {
        panel.allowedContentTypes = extensions.compactMap { UTType(filenameExtension: $0) }
      }
    }
  #elseif canImport(UIKit)
    private func pickFiles(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      let types = (call.argument("allowed_extensions")?.arrayValue ?? [])
        .compactMap(\.stringValue)
        .compactMap { UTType(filenameExtension: $0) }
      let controller = UIDocumentPickerViewController(
        forOpeningContentTypes: types.isEmpty ? [.item] : types)
      controller.allowsMultipleSelection = call.argument("allow_multiple")?.boolValue ?? false
      present(controller, completion: completion)
    }

    private func saveFile(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      // iOS saves by exporting an existing file, so there is nothing to show
      // until the caller has written one.
      completion(
        .failure(
          RufletServiceError.unavailable(
            "save_file needs a source file on iOS; write it first, then share it")))
    }

    private func pickDirectory(
      _ call: RufletMethodCall, completion: @escaping RufletMethodCompletion
    ) {
      let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
      present(controller, completion: completion)
    }

    private func present(
      _ controller: UIDocumentPickerViewController,
      completion: @escaping RufletMethodCompletion
    ) {
      guard let presenter = RufletWindow.topViewController() else {
        return completion(.failure(RufletServiceError.unavailable("No window to present from")))
      }
      pending = completion
      controller.delegate = self
      presenter.present(controller, animated: true)
    }
  #else
    private func pickFiles(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      completion(.failure(RufletServiceError.unavailable("No file picker on this platform")))
    }
    private func saveFile(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      completion(.failure(RufletServiceError.unavailable("No file picker on this platform")))
    }
    private func pickDirectory(
      _ call: RufletMethodCall, completion: @escaping RufletMethodCompletion
    ) {
      completion(.failure(RufletServiceError.unavailable("No file picker on this platform")))
    }
  #endif
}

#if canImport(UIKit)
  extension FilePickerService: UIDocumentPickerDelegate {
    public nonisolated func documentPicker(
      _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
    ) {
      Task { @MainActor in
        let completion = pending
        pending = nil
        completion?(.success(describe(urls)))
      }
    }

    public nonisolated func documentPickerWasCancelled(
      _ controller: UIDocumentPickerViewController
    ) {
      Task { @MainActor in
        let completion = pending
        pending = nil
        completion?(.success(.null))
      }
    }
  }
#endif

/// `Share` — the system share sheet.
@MainActor
public final class ShareService: RufletService {
  public static let wireType = "Share"

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    var items: [Any] = []

    switch call.name {
    case "share_text":
      if let text = call.argument("text")?.stringValue { items.append(text) }
    case "share_uri":
      if let raw = call.argument("uri")?.stringValue, let url = URL(string: raw) {
        items.append(url)
      }
    case "share_files":
      for file in call.argument("files")?.arrayValue ?? [] {
        if let path = file["path"]?.stringValue ?? file.stringValue {
          items.append(URL(fileURLWithPath: path))
        }
      }
      if let text = call.argument("text")?.stringValue { items.append(text) }
    default:
      return completion(
        .failure(RufletServiceError.unsupportedMethod(type: "Share", method: call.name)))
    }

    guard !items.isEmpty else {
      return completion(.failure(RufletServiceError.invalidArguments("Nothing to share")))
    }

    #if canImport(UIKit)
      guard let presenter = RufletWindow.topViewController() else {
        return completion(.failure(RufletServiceError.unavailable("No window to present from")))
      }
      let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
      // An iPad needs an anchor or the popover cannot be positioned.
      sheet.popoverPresentationController?.sourceView = presenter.view
      sheet.popoverPresentationController?.sourceRect = CGRect(
        x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
      sheet.completionWithItemsHandler = { activity, completed, _, error in
        Task { @MainActor in
          if let error {
            completion(.failure(RufletServiceError.failed(error.localizedDescription)))
          } else {
            completion(.success(.map([
              "status": .string(completed ? "success" : "dismissed"),
              "raw": .string(activity?.rawValue ?? "")
            ])))
          }
        }
      }
      presenter.present(sheet, animated: true)
    #elseif canImport(AppKit)
      guard let view = NSApp.keyWindow?.contentView else {
        return completion(.failure(RufletServiceError.unavailable("No window to present from")))
      }
      let picker = NSSharingServicePicker(items: items)
      picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
      completion(.success(.map([
        "status": .string("success"),
        "raw": .string("")
      ])))
    #else
      completion(.failure(RufletServiceError.unavailable("No share sheet on this platform")))
    #endif
  }
}

/// Finds a view controller to present from.
///
/// Services such as the share sheet and the document picker are UIKit modals,
/// so they need somewhere to appear even though the rest of the engine is
/// SwiftUI.
public enum RufletWindow {
  #if canImport(UIKit)
    @MainActor
    public static func topViewController() -> UIViewController? {
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
      var controller = window?.rootViewController
      while let presented = controller?.presentedViewController {
        controller = presented
      }
      return controller
    }
  #endif
}
