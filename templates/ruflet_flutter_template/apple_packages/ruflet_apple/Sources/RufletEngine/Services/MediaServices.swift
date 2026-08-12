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
    eventNode = node
    eventContext = context
    let requests = call.argument("files")?.arrayValue ?? []
    // Flet starts uploads only after pick_files populated its private selection.
    guard !requests.isEmpty, !selectedURLs.isEmpty else {
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
      // Pinned Flet only logs a descriptor that no longer matches the current
      // selection; it does not synthesize an upload failure event.
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
            self.emitUpload(name: source.lastPathComponent, progress: nil,
              error: Self.uploadHTTPError(status: status ?? 0, body: body))
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
    eventContext.emitEvent(eventNode.id, "upload", Self.uploadEvent(
      name: name, progress: progress, error: error))
  }

  static func uploadEvent(name: String, progress: Double?, error: String?) -> RufletValue {
    .map([
      "file_name": .string(name),
      "progress": progress.map(RufletValue.double) ?? .null,
      "error": error.map(RufletValue.string) ?? .null
    ])
  }

  static func uploadHTTPError(status: Int, body: Data) -> String {
    let responseBody = String(data: body, encoding: .utf8) ?? ""
    return "Upload endpoint returned code \(status): \(responseBody)"
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
          completion?(.success(files))
        case .directory:
          let path = urls.first?.path
          completion?(.success(path.map(RufletValue.string) ?? .null))
        case .save(let temp):
          try? FileManager.default.removeItem(at: temp)
          let path = urls.first?.path
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
          completion?(.success(.array([])))
        case .save(let temp):
          try? FileManager.default.removeItem(at: temp)
          completion?(.success(.null))
        case .directory:
          completion?(.success(.null))
        case nil:
          completion?(.success(.null))
        }
      }
    }
  }
#endif

/// `Share` — the system share sheet.
public struct FletShareFile: Equatable {
  public let path: String?
  public let data: [UInt8]?
  public let mimeType: String?
  public let name: String
  public let fileNameOverride: String
}

public struct FletShareRequest: Equatable {
  public let method: String
  public let text: String?
  public let uri: String?
  public let files: [FletShareFile]
  public let title: String?
  public let subject: String?
  public let previewThumbnail: FletShareFile?
  public let position: CGRect?
  public let excludedCupertinoActivities: [String]
  public let downloadFallbackEnabled: Bool
  public let mailToFallbackEnabled: Bool
}

public enum FletShareSemantics {
  public static func request(_ call: RufletMethodCall) throws -> FletShareRequest {
    guard ["share_text", "share_uri", "share_files"].contains(call.name) else {
      throw RufletServiceError.unsupportedMethod(type: "Share", method: call.name)
    }
    let text = call.argument("text").flatMap(strictString)
    let uri = call.argument("uri").flatMap(strictString)
    let files: [FletShareFile]
    if call.name == "share_files" {
      guard let values = call.argument("files")?.arrayValue, !values.isEmpty else {
        throw RufletServiceError.invalidArguments("files cannot be empty")
      }
      files = try values.map(parseFile)
    } else {
      files = []
    }
    if call.name == "share_text", text == nil {
      throw RufletServiceError.invalidArguments("text is required")
    }
    if call.name == "share_uri", uri == nil {
      throw RufletServiceError.invalidArguments("uri is required")
    }
    return FletShareRequest(
      method: call.name,
      text: text,
      uri: uri,
      files: files,
      title: call.argument("title").flatMap(strictString),
      subject: call.argument("subject").flatMap(strictString),
      previewThumbnail: try call.argument("preview_thumbnail").map(parseFile),
      position: parseRect(call.argument("share_position_origin")),
      excludedCupertinoActivities:
        call.argument("excluded_cupertino_activities")?.arrayValue?
        .compactMap(strictString) ?? [],
      downloadFallbackEnabled: call.argument("download_fallback_enabled")?.boolValue ?? true,
      mailToFallbackEnabled: call.argument("mail_to_fallback_enabled")?.boolValue ?? true)
  }

  public static func result(status: String, raw: String) -> RufletValue {
    .map(["status": .string(status), "raw": .string(raw)])
  }

  private static func strictString(_ value: RufletValue) -> String? {
    guard case .string(let value) = value else { return nil }
    return value
  }

  private static func parseFile(_ value: RufletValue) throws -> FletShareFile {
    guard let map = value.mapValue else {
      throw RufletServiceError.invalidArguments("share files must be file maps")
    }
    let path = map["path"].flatMap(strictString)
    let explicitName = map["name"].flatMap(strictString)
    let mimeType = map["mime_type"].flatMap(strictString)
    if let path {
      let candidate = explicitName ?? URL(fileURLWithPath: path).lastPathComponent
      let name = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedExplicitName = explicitName?.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
      let override = trimmedExplicitName?.isEmpty == false
        ? trimmedExplicitName!
        : (trimmedPath.isEmpty ? "shared_file" : URL(fileURLWithPath: trimmedPath).lastPathComponent)
      return FletShareFile(
        path: path, data: nil, mimeType: mimeType,
        name: name.isEmpty ? "shared_file" : name,
        fileNameOverride: override.isEmpty ? "shared_file" : override)
    }
    if let bytes = FletCoreServiceSemantics.imageBytes(map["data"]) {
      let name = explicitName?.isEmpty == false ? explicitName! : "shared_file"
      let trimmed = explicitName?.trimmingCharacters(in: .whitespacesAndNewlines)
      return FletShareFile(
        path: nil, data: bytes, mimeType: mimeType,
        name: name,
        fileNameOverride: trimmed?.isEmpty == false ? trimmed! : "shared_file")
    }
    throw RufletServiceError.invalidArguments("share file requires path or data")
  }

  private static func parseRect(_ value: RufletValue?) -> CGRect? {
    guard let map = value?.mapValue else { return nil }
    return CGRect(
      x: map["x"]?.doubleValue ?? 0,
      y: map["y"]?.doubleValue ?? 0,
      width: map["width"]?.doubleValue ?? 0,
      height: map["height"]?.doubleValue ?? 0)
  }

  #if canImport(UIKit)
    static func activityType(_ value: String) -> UIActivity.ActivityType? {
      switch value {
      case "postToFacebook": return .postToFacebook
      case "postToTwitter": return .postToTwitter
      case "postToWeibo": return .postToWeibo
      case "message": return .message
      case "mail": return .mail
      case "print": return .print
      case "copyToPasteboard": return .copyToPasteboard
      case "assignToContact": return .assignToContact
      case "saveToCameraRoll": return .saveToCameraRoll
      case "addToReadingList": return .addToReadingList
      case "postToFlickr": return .postToFlickr
      case "postToVimeo": return .postToVimeo
      case "postToTencentWeibo": return .postToTencentWeibo
      case "airDrop": return .airDrop
      case "openInIBooks": return .openInIBooks
      case "markupAsPDF": return .markupAsPDF
      default: return nil
      }
    }
  #endif
}

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
    let request: FletShareRequest
    do {
      request = try FletShareSemantics.request(call)
    } catch {
      return completion(.failure(error))
    }

    let prepared: (items: [Any], temporaryDirectory: URL?)
    do {
      prepared = try prepareItems(request)
    } catch {
      return completion(.failure(error))
    }

    #if canImport(UIKit)
      guard let presenter = RufletWindow.topViewController() else {
        return completion(.failure(RufletServiceError.unavailable("No window to present from")))
      }
      let sheet = UIActivityViewController(
        activityItems: prepared.items, applicationActivities: nil)
      sheet.title = request.title
      if let subject = request.subject { sheet.setValue(subject, forKey: "subject") }
      sheet.excludedActivityTypes = request.excludedCupertinoActivities.compactMap(
        FletShareSemantics.activityType)
      // An iPad needs an anchor or the popover cannot be positioned.
      sheet.popoverPresentationController?.sourceView = presenter.view
      sheet.popoverPresentationController?.sourceRect = request.position ?? CGRect(
        x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
      sheet.completionWithItemsHandler = { activity, completed, _, error in
        Task { @MainActor in
          if let directory = prepared.temporaryDirectory {
            try? FileManager.default.removeItem(at: directory)
          }
          if let error {
            completion(.failure(RufletServiceError.failed(error.localizedDescription)))
          } else {
            completion(.success(FletShareSemantics.result(
              status: completed ? "success" : "dismissed",
              raw: activity?.rawValue ?? "")))
          }
        }
      }
      presenter.present(sheet, animated: true)
    #elseif canImport(AppKit)
      guard let view = NSApp.keyWindow?.contentView else {
        return completion(.failure(RufletServiceError.unavailable("No window to present from")))
      }
      let picker = NSSharingServicePicker(items: prepared.items)
      picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
      completion(.success(FletShareSemantics.result(status: "unavailable", raw: "")))
    #else
      completion(.failure(RufletServiceError.unavailable("No share sheet on this platform")))
    #endif
  }

  private func prepareItems(_ request: FletShareRequest) throws
    -> (items: [Any], temporaryDirectory: URL?)
  {
    var items: [Any] = []
    if let text = request.text { items.append(text) }
    if let uri = request.uri {
      guard let url = URL(string: uri) else {
        throw RufletServiceError.invalidArguments("uri is invalid")
      }
      items.append(url)
    }
    var temporaryDirectory: URL?
    for file in request.files {
      if let path = file.path {
        items.append(URL(fileURLWithPath: path))
      } else if let bytes = file.data {
        #if canImport(UIKit)
          let identifier: String
          #if canImport(UniformTypeIdentifiers)
            identifier = file.mimeType.flatMap { UTType(mimeType: $0) }?.identifier
              ?? UTType.data.identifier
          #else
            identifier = "public.data"
          #endif
          let provider = NSItemProvider(item: Data(bytes) as NSData, typeIdentifier: identifier)
          provider.suggestedName = file.fileNameOverride
          items.append(provider)
        #else
          if temporaryDirectory == nil {
            let directory = FileManager.default.temporaryDirectory
              .appendingPathComponent("ruflet-share-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(
              at: directory, withIntermediateDirectories: true)
            temporaryDirectory = directory
          }
          let url = temporaryDirectory!.appendingPathComponent(file.fileNameOverride)
          try Data(bytes).write(to: url, options: .atomic)
          items.append(url)
        #endif
      }
    }
    guard !items.isEmpty else {
      throw RufletServiceError.invalidArguments("Nothing to share")
    }
    return (items, temporaryDirectory)
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
