import Foundation
import RufletProtocol

public enum RufletFileType: String, CaseIterable, RufletStringEnum {
  case any
  case media
  case image
  case video
  case audio
  case custom
}

public struct FilePickerFile: Sendable, Equatable {
  public let id: Int
  public let name: String
  public let path: String?
  public let size: Int64
  public let bytes: Data?

  public init(id: Int, name: String, path: String?, size: Int64, bytes: Data?) {
    self.id = id
    self.name = name
    self.path = path
    self.size = size
    self.bytes = bytes
  }

  public var value: RufletValue {
    [
      "id": .int(Int64(id)), "name": .string(name),
      "path": path.map(RufletValue.string) ?? .null, "size": .int(size),
      "bytes": bytes.map(RufletValue.binary) ?? .null,
    ]
  }
}

public struct FilePickerResultEvent: Sendable, Equatable {
  public let path: String?
  public let files: [FilePickerFile]?

  public init(path: String?, files: [FilePickerFile]?) {
    self.path = path
    self.files = files
  }

  public var value: RufletValue {
    [
      "path": path.map(RufletValue.string) ?? .null,
      "files": files.map { .array($0.map(\.value)) } ?? .null,
    ]
  }
}

public struct FilePickerUploadFile: Sendable, Equatable {
  public let id: Int?
  public let name: String?
  public let uploadURL: URL
  public let method: String
}

public struct FilePickerUploadProgressEvent: Sendable, Equatable {
  public let name: String
  public let progress: Double?
  public let error: String?

  public var value: RufletValue {
    [
      "file_name": .string(name),
      "progress": progress.map(RufletValue.double) ?? .null,
      "error": error.map(RufletValue.string) ?? .null,
    ]
  }
}

public func parseFileType(
  _ value: String?, _ defaultValue: RufletFileType? = nil
) -> RufletFileType? {
  parseEnum(RufletFileType.self, value, defaultValue)
}

public extension RufletControl {
  func fileType(
    _ propertyName: String, default defaultValue: RufletFileType? = nil
  ) -> RufletFileType? {
    parseFileType(string(propertyName), defaultValue)
  }
}
