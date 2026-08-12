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
  #if canImport(UIKit)
    private enum PendingOperation { case files(withData: Bool), directory, save(temp: URL) }
    private var pendingOperation: PendingOperation?
  #endif
  private var selectedURLs: [URL] = []
  private var activeUploads: [UUID: FilePickerUploadOperation] = [:]
  private var eventNode: ControlNode?
  private var eventContext: RufletServiceContext?

  public override init() {
    super.init()
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    eventNode = node
    eventContext = context
    switch call.name {
    case "pick_files":
      pickFiles(call, completion: completion)
    case "save_file":
      saveFile(call, completion: completion)
    case "get_directory_path":
      pickDirectory(call, completion: completion)
    case "upload":
      upload(call, node: node, context: context, completion: completion)
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

  /// `result` is Ruflet's DSL extension. Method return values remain byte-for-
  /// byte compatible with Flet's service.
  private func reportResult(_ value: RufletValue) {
    guard let eventNode, let eventContext, eventNode.handlesEvent("result") else { return }
    eventContext.emitEvent(eventNode.id, "result", value)
  }

  private func describe(_ urls: [URL], withData: Bool) -> RufletValue {
    .array(
      urls.enumerated().map { index, url in
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return FilePickerFile(
          id: index, name: url.lastPathComponent, path: url.path, size: Int64(size),
          bytes: withData ? (try? Data(contentsOf: url)).map(Array.init) : nil
        ).wireValue
      })
  }

  private func resultEvent(path: String?, files: RufletValue?) -> RufletValue {
    .map([
      "path": path.map(RufletValue.string) ?? .null,
      "files": files ?? .null,
    ])
  }

  #if canImport(UniformTypeIdentifiers)
    private func contentTypes(_ configuration: FilePickerConfiguration) -> [UTType] {
      if configuration.fileType == .custom {
        return configuration.allowedExtensions.compactMap { UTType(filenameExtension: $0) }
      }
      switch configuration.fileType {
      case .any, .custom: return [.item]
      case .media: return [.image, .movie]
      case .image: return [.image]
      case .video: return [.movie]
      case .audio: return [.audio]
      }
    }
  #endif

  #if canImport(AppKit)
    private func pickFiles(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      let configuration = FilePickerConfiguration(call)
      let panel = NSOpenPanel()
      panel.canChooseFiles = true
      panel.canChooseDirectories = false
      panel.allowsMultipleSelection = configuration.allowMultiple
      panel.title = configuration.dialogTitle ?? ""
      panel.directoryURL = configuration.initialDirectory
      panel.allowedContentTypes = contentTypes(configuration)

      panel.begin { response in
        Task { @MainActor in
          self.selectedURLs = response == .OK ? panel.urls : []
          let files = response == .OK
            ? self.describe(panel.urls, withData: configuration.withData) : .array([])
          self.reportResult(self.resultEvent(path: nil, files: files))
          completion(.success(files))
        }
      }
    }

    private func saveFile(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      let configuration = FilePickerConfiguration(call)
      let panel = NSSavePanel()
      panel.nameFieldStringValue = configuration.fileName ?? ""
      panel.title = configuration.dialogTitle ?? ""
      panel.directoryURL = configuration.initialDirectory
      panel.allowedContentTypes = contentTypes(configuration)

      panel.begin { response in
        Task { @MainActor in
          let path = response == .OK ? panel.url?.path : nil
          self.reportResult(self.resultEvent(path: path, files: nil))
          completion(.success(path.map(RufletValue.string) ?? .null))
        }
      }
    }

    private func pickDirectory(
      _ call: RufletMethodCall, completion: @escaping RufletMethodCompletion
    ) {
      let panel = NSOpenPanel()
      let configuration = FilePickerConfiguration(call)
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.title = configuration.dialogTitle ?? ""
      panel.directoryURL = configuration.initialDirectory

      panel.begin { response in
        Task { @MainActor in
          let path = response == .OK ? panel.urls.first?.path : nil
          self.reportResult(self.resultEvent(path: path, files: nil))
          completion(.success(path.map(RufletValue.string) ?? .null))
        }
      }
    }

  #elseif canImport(UIKit)
    private func pickFiles(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      let configuration = FilePickerConfiguration(call)
      let controller = UIDocumentPickerViewController(
        forOpeningContentTypes: contentTypes(configuration))
      controller.allowsMultipleSelection = configuration.allowMultiple
      present(controller, operation: .files(withData: configuration.withData), completion: completion)
    }

    private func saveFile(_ call: RufletMethodCall, completion: @escaping RufletMethodCompletion) {
      let configuration = FilePickerConfiguration(call)
      guard let bytes = configuration.sourceBytes else {
        return completion(.failure(RufletServiceError.invalidArguments(
          "\"src_bytes\" is required when saving a file on Web, Android and iOS.")))
      }
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ruflet-file-picker", isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appendingPathComponent(configuration.fileName ?? "new-file")
        try Data(bytes).write(to: source, options: .atomic)
        let controller = UIDocumentPickerViewController(forExporting: [source], asCopy: true)
        present(controller, operation: .save(temp: source), completion: completion)
      } catch {
        completion(.failure(RufletServiceError.failed(error.localizedDescription)))
      }
    }

    private func pickDirectory(
      _ call: RufletMethodCall, completion: @escaping RufletMethodCompletion
    ) {
      let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
      present(controller, operation: .directory, completion: completion)
    }

    private func present(
      _ controller: UIDocumentPickerViewController,
      operation: PendingOperation,
      completion: @escaping RufletMethodCompletion
    ) {
      guard let presenter = RufletWindow.topViewController() else {
        return completion(.failure(RufletServiceError.unavailable("No window to present from")))
      }
      pending = completion
      pendingOperation = operation
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

  private func upload(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    let requests = call.argument("files")?.arrayValue ?? []
    guard !requests.isEmpty else {
      return completion(.success(.null))
    }
    let uploads = requests.compactMap(FilePickerUploadRequest.init)
    let pageURL = ["page_uri", "page_url", "url", "uri"]
      .compactMap { context.store.page?.string($0) }
      .compactMap(URL.init(string:)).first
    uploadNext(uploads, index: 0, pageURL: pageURL)
    completion(.success(.null))
  }

  private func uploadNext(_ requests: [FilePickerUploadRequest], index: Int, pageURL: URL?) {
    guard requests.indices.contains(index) else { return }
    let request = requests[index]
    let id = request.id
    let name = request.name
    let source: URL? = {
      if let id, selectedURLs.indices.contains(id) { return selectedURLs[id] }
      return selectedURLs.first { $0.lastPathComponent == name }
    }()
    guard let source else {
      emitUpload(name: name ?? "", progress: nil, error: "Selected file was not found")
      return uploadNext(requests, index: index + 1, pageURL: pageURL)
    }
    guard let destination = request.resolvedURL(relativeTo: pageURL) else {
      emitUpload(name: source.lastPathComponent, progress: nil,
        error: "Relative upload_url requires a backend page URI")
      return uploadNext(requests, index: index + 1, pageURL: pageURL)
    }

    var urlRequest = URLRequest(url: destination)
    urlRequest.httpMethod = request.method
    emitUpload(name: source.lastPathComponent, progress: 0, error: nil)
    let accessed = source.startAccessingSecurityScopedResource()
    let token = UUID()
    let operation = FilePickerUploadOperation(
      progress: { [weak self] progress in
        Task { @MainActor in self?.emitUpload(
          name: source.lastPathComponent, progress: progress, error: nil) }
      },
      completion: { [weak self] status, body, error in
        if accessed { source.stopAccessingSecurityScopedResource() }
        Task { @MainActor in
          guard let self else { return }
          self.activeUploads[token] = nil
          if let error {
            self.emitUpload(name: source.lastPathComponent, progress: nil,
              error: error.localizedDescription)
          } else if !(200...204).contains(status ?? 0) {
            let suffix = String(data: body, encoding: .utf8).flatMap { $0.isEmpty ? nil : ": \($0)" } ?? ""
            self.emitUpload(name: source.lastPathComponent, progress: nil,
              error: "Upload endpoint returned code \(status ?? 0)\(suffix)")
            // Flet removes a selected file after every completed HTTP response,
            // including a non-success response.
            self.selectedURLs.removeAll { $0 == source }
          } else {
            self.emitUpload(name: source.lastPathComponent, progress: 1, error: nil)
            self.selectedURLs.removeAll { $0 == source }
          }
          self.uploadNext(requests, index: index + 1, pageURL: pageURL)
        }
      })
    activeUploads[token] = operation
    operation.start(request: urlRequest, source: source)
  }

  private func emitUpload(name: String, progress: Double?, error: String?) {
    guard let eventNode, eventNode.handlesEvent("upload"), let eventContext else { return }
    eventContext.emitEvent(eventNode.id, "upload", .map([
      "file_name": .string(name),
      "progress": progress.map(RufletValue.double) ?? .null,
      "error": error.map(RufletValue.string) ?? .null
    ]))
  }
}

#if canImport(UIKit)
  extension FilePickerService: UIDocumentPickerDelegate {
    public nonisolated func documentPicker(
      _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
    ) {
      Task { @MainActor in
        let completion = pending
        pending = nil
        let operation = pendingOperation
        pendingOperation = nil
        switch operation {
        case .files(let withData):
          selectedURLs = urls
          let files = describe(urls, withData: withData)
          reportResult(resultEvent(path: nil, files: files))
          completion?(.success(files))
        case .directory:
          let path = urls.first?.path
          reportResult(resultEvent(path: path, files: nil))
          completion?(.success(path.map(RufletValue.string) ?? .null))
        case .save(let temp):
          try? FileManager.default.removeItem(at: temp)
          let path = urls.first?.path
          reportResult(resultEvent(path: path, files: nil))
          completion?(.success(path.map(RufletValue.string) ?? .null))
        case nil:
          completion?(.success(.null))
        }
      }
    }

    public nonisolated func documentPickerWasCancelled(
      _ controller: UIDocumentPickerViewController
    ) {
      Task { @MainActor in
        let completion = pending
        pending = nil
        let operation = pendingOperation
        pendingOperation = nil
        switch operation {
        case .files:
          selectedURLs = []
          reportResult(resultEvent(path: nil, files: .array([])))
          completion?(.success(.array([])))
        case .save(let temp):
          try? FileManager.default.removeItem(at: temp)
          reportResult(resultEvent(path: nil, files: nil))
          completion?(.success(.null))
        case .directory:
          reportResult(resultEvent(path: nil, files: nil))
          completion?(.success(.null))
        case nil:
          completion?(.success(.null))
        }
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
