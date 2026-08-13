import Foundation
import RufletProtocol

@MainActor
public final class StoragePaths: RufletInvokableService {
  private let fileManager = FileManager.default

  public override func invoke(
    _ name: String,
    arguments: [String: RufletValue]
  ) async throws -> RufletValue? {
    switch name {
    case "get_application_cache_directory": return .string(try directory(.cachesDirectory).path)
    case "get_application_documents_directory": return .string(try directory(.documentDirectory).path)
    case "get_application_support_directory": return .string(try directory(.applicationSupportDirectory).path)
    case "get_downloads_directory":
      return fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first.map { .string($0.path) } ?? .null
    case "get_library_directory": return .string(try directory(.libraryDirectory).path)
    case "get_temporary_directory": return .string(fileManager.temporaryDirectory.path)
    case "get_console_log_filename":
      return .string(try directory(.cachesDirectory).appendingPathComponent("console.log").path)
    // Pinned path_provider exposes these methods on every platform and returns
    // null outside Android. They are valid Flet methods on Apple too; treating
    // them as unknown breaks the invoke contract.
    case "get_external_cache_directories", "get_external_storage_directories",
      "get_external_storage_directory":
      return .null
    default: throw RufletServiceError.unknownMethod(service: "StoragePaths", method: name)
    }
  }

  private func directory(_ directory: FileManager.SearchPathDirectory) throws -> URL {
    guard let url = fileManager.urls(for: directory, in: .userDomainMask).first else {
      throw RufletServiceError.unavailable("Directory \(directory.rawValue)")
    }
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
