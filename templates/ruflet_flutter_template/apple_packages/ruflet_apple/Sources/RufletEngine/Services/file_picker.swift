import Foundation
import RufletProtocol
#if os(iOS)
import UIKit
import UniformTypeIdentifiers
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

private struct RufletPickedFile {
  let id: Int
  let url: URL
  let name: String
  let size: Int64
  let bytes: Data?

  var value: RufletValue {
    [
      "id": .int(Int64(id)),
      "name": .string(name),
      "path": .string(url.path),
      "size": .int(size),
      "bytes": bytes.map(RufletValue.binary) ?? .null,
    ]
  }
}

@MainActor
public final class FilePickerService: RufletInvokableService {
  private var files: [RufletPickedFile]?

  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    switch name {
    case "upload":
      if let specifications = arguments["files"]?.array, files != nil {
        Task { @MainActor [weak self] in await self?.uploadFiles(specifications) }
      }
      return nil
    case "pick_files":
      let selected = try await pickFiles(arguments)
      let withData = arguments["with_data"]?.bool ?? false
      files = try selected.enumerated().map { index, url in
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey])
        return RufletPickedFile(
          id: index, url: url, name: values.name ?? url.lastPathComponent,
          size: Int64(values.fileSize ?? 0), bytes: withData ? try Data(contentsOf: url) : nil)
      }
      return .array(files?.map(\.value) ?? [])
    case "save_file": return try await saveFile(arguments).map { .string($0.path) } ?? .null
    case "get_directory_path": return try await pickDirectory(arguments).map { .string($0.path) } ?? .null
    default: throw RufletServiceError.unknownMethod(service: "FilePicker", method: name)
    }
  }

  private func pickFiles(_ arguments: [String: RufletValue]) async throws -> [URL] {
    let extensions = serviceStringArray(arguments["allowed_extensions"]) ?? []
    #if os(iOS)
    let types = extensions.compactMap { UTType(filenameExtension: $0) }
    let picker = UIDocumentPickerViewController(
      forOpeningContentTypes: types.isEmpty ? [.data] : types,
      asCopy: false)
    picker.allowsMultipleSelection = arguments["allow_multiple"]?.bool ?? false
    return try await presentDocumentPicker(picker)
    #elseif os(macOS)
    let panel = NSOpenPanel()
    panel.title = arguments["dialog_title"]?.text ?? ""
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = arguments["allow_multiple"]?.bool ?? false
    if !extensions.isEmpty { panel.allowedContentTypes = extensions.compactMap { UTType(filenameExtension: $0) } }
    if let initial = arguments["initial_directory"]?.text { panel.directoryURL = URL(fileURLWithPath: initial) }
    return await panel.begin() == .OK ? panel.urls : []
    #endif
  }

  private func saveFile(_ arguments: [String: RufletValue]) async throws -> URL? {
    #if os(iOS)
    guard let bytes = arguments["src_bytes"]?.serviceData else {
      throw RufletServiceError.missingArgument("src_bytes")
    }
    let fileName = arguments["file_name"]?.text ?? "new-file"
    let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    try bytes.write(to: temporaryURL, options: .atomic)
    defer { try? FileManager.default.removeItem(at: temporaryURL) }
    let picker = UIDocumentPickerViewController(forExporting: [temporaryURL], asCopy: true)
    return try await presentDocumentPicker(picker).first
    #elseif os(macOS)
    let panel = NSSavePanel()
    panel.title = arguments["dialog_title"]?.text ?? ""
    panel.nameFieldStringValue = arguments["file_name"]?.text ?? ""
    if let initial = arguments["initial_directory"]?.text { panel.directoryURL = URL(fileURLWithPath: initial) }
    guard await panel.begin() == .OK, let url = panel.url else { return nil }
    if let bytes = arguments["src_bytes"]?.serviceData { try bytes.write(to: url, options: .atomic) }
    return url
    #endif
  }

  private func pickDirectory(_ arguments: [String: RufletValue]) async throws -> URL? {
    #if os(iOS)
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
    return try await presentDocumentPicker(picker).first
    #elseif os(macOS)
    let panel = NSOpenPanel()
    panel.title = arguments["dialog_title"]?.text ?? ""
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    if let initial = arguments["initial_directory"]?.text { panel.directoryURL = URL(fileURLWithPath: initial) }
    return await panel.begin() == .OK ? panel.url : nil
    #endif
  }

  private func uploadFiles(_ specifications: [RufletValue]) async {
    guard var selectedFiles = files else { return }
    for specification in specifications {
      guard let map = specification.map,
            let uploadURL = map["upload_url"]?.text,
            let url = fullUploadURL(uploadURL),
            let method = map["method"]?.text else { continue }
      let requestedID = map["id"]?.integer
      let requestedName = map["name"]?.text
      guard let index = selectedFiles.firstIndex(where: {
        (requestedID != nil && $0.id == requestedID) || $0.name == requestedName
      }) else { continue }
      let file = selectedFiles[index]
      do {
        sendProgress(file.name, progress: 0, error: nil)
        var request = URLRequest(url: url)
        request.httpMethod = method
        let accessing = file.url.startAccessingSecurityScopedResource()
        let data = try file.bytes ?? Data(contentsOf: file.url)
        if accessing { file.url.stopAccessingSecurityScopedResource() }
        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, (200 ... 204).contains(http.statusCode) else {
          throw RufletServiceError.unavailable("Upload endpoint returned an unsuccessful status")
        }
        sendProgress(file.name, progress: 1, error: nil)
        selectedFiles.remove(at: index)
      } catch {
        sendProgress(file.name, progress: nil, error: String(describing: error))
      }
    }
    files = selectedFiles
  }

  private func sendProgress(_ name: String, progress: Double?, error: String?) {
    control.triggerEvent("upload", data: [
      "file_name": .string(name),
      "progress": progress.map(RufletValue.double) ?? .null,
      "error": error.map(RufletValue.string) ?? .null,
    ])
  }

  private func fullUploadURL(_ value: String) -> URL? {
    guard let parsed = URL(string: value), parsed.host == nil else { return URL(string: value) }
    guard let page = control.backend.pageURI,
          var parts = URLComponents(url: page, resolvingAgainstBaseURL: false),
          let relative = URLComponents(string: value) else { return nil }
    parts.path = relative.path
    parts.query = relative.query
    parts.fragment = nil
    return parts.url
  }
}

#if os(iOS)
@MainActor
private final class RufletDocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
  var completion: CheckedContinuation<[URL], Error>?
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    completion?.resume(returning: urls)
    completion = nil
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    completion?.resume(returning: [])
    completion = nil
  }
}

@MainActor
private var activeDocumentPickerDelegates: [ObjectIdentifier: RufletDocumentPickerDelegate] = [:]

@MainActor
private func presentDocumentPicker(_ picker: UIDocumentPickerViewController) async throws -> [URL] {
  let delegate = RufletDocumentPickerDelegate()
  let identifier = ObjectIdentifier(picker)
  activeDocumentPickerDelegates[identifier] = delegate
  picker.delegate = delegate
  return try await withCheckedThrowingContinuation { continuation in
    delegate.completion = continuation
    do { try servicePresentationController().present(picker, animated: true) }
    catch {
      activeDocumentPickerDelegates.removeValue(forKey: identifier)
      continuation.resume(throwing: error)
    }
  }.also { _ in activeDocumentPickerDelegates.removeValue(forKey: identifier) }
}

private extension Array {
  func also(_ action: (Self) -> Void) -> Self { action(self); return self }
}
#endif
