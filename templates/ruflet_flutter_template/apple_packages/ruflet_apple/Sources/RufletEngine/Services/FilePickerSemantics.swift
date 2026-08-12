import Foundation
import RufletProtocol

/// Source-driven value semantics for Flet's `FilePicker` service. UI panels
/// remain platform-native; these types keep their arguments and wire payloads
/// independent of AppKit/UIKit.
public struct FilePickerConfiguration: Equatable {
  public enum FileType: String, Equatable {
    case any, media, image, video, audio, custom
  }

  public let dialogTitle: String?
  public let initialDirectory: URL?
  public let fileType: FileType
  public let allowedExtensions: [String]
  public let allowMultiple: Bool
  public let withData: Bool
  public let fileName: String?
  public let sourceBytes: [UInt8]?

  public init(_ call: RufletMethodCall) {
    dialogTitle = call.argument("dialog_title")?.stringValue
    if let path = call.argument("initial_directory")?.stringValue, !path.isEmpty {
      initialDirectory = URL(fileURLWithPath: path, isDirectory: true)
    } else {
      initialDirectory = nil
    }
    allowedExtensions = (call.argument("allowed_extensions")?.arrayValue ?? [])
      .compactMap(\.stringValue)
      .map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
    fileType = allowedExtensions.isEmpty
      ? FileType(rawValue: call.argument("file_type")?.stringValue?.lowercased() ?? "any") ?? .any
      : .custom
    allowMultiple = call.argument("allow_multiple")?.boolValue ?? false
    withData = call.argument("with_data")?.boolValue ?? false
    fileName = call.argument("file_name")?.stringValue
    sourceBytes = call.argument("src_bytes")?.binaryValue
      ?? call.argument("src_bytes")?.arrayValue?.compactMap { value in
        guard let byte = value.intValue, (0...255).contains(byte) else { return nil }
        return UInt8(byte)
      }
  }
}

public struct FilePickerFile: Equatable {
  public let id: Int
  public let name: String
  public let path: String?
  public let size: Int64
  public let bytes: [UInt8]?

  public var wireValue: RufletValue {
    .map([
      "id": .int(Int64(id)),
      "name": .string(name),
      "path": path.map(RufletValue.string) ?? .null,
      "size": .int(size),
      "bytes": bytes.map(RufletValue.binary) ?? .null,
    ])
  }
}

public struct FilePickerUploadRequest: Equatable {
  public let id: Int?
  public let name: String?
  public let uploadURL: String
  public let method: String

  public init?(_ value: RufletValue) {
    guard let uploadURL = value["upload_url"]?.stringValue, !uploadURL.isEmpty else { return nil }
    id = value["id"]?.intValue
    name = value["name"]?.stringValue
    self.uploadURL = uploadURL
    method = value["method"]?.stringValue ?? "PUT"
  }

  public func resolvedURL(relativeTo pageURL: URL?) -> URL? {
    guard let parsed = URL(string: uploadURL) else { return nil }
    if parsed.scheme != nil { return parsed }
    guard let pageURL else { return nil }
    var components = URLComponents()
    components.scheme = pageURL.scheme
    components.host = pageURL.host
    components.port = pageURL.port
    components.path = parsed.path
    components.query = parsed.query
    return components.url
  }
}

extension RufletValue {
  fileprivate var binaryValue: [UInt8]? {
    guard case .binary(let bytes) = self else { return nil }
    return bytes
  }
}

/// One streamed upload. The delegate reports Flet's approximately ten-percent
/// progress cadence and owns its session so cancellation is deterministic.
final class FilePickerUploadOperation: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
  typealias Progress = @Sendable (Double) -> Void
  typealias Completion = @Sendable (Int?, Data, Error?) -> Void

  private let progress: Progress
  private let completion: Completion
  private var responseData = Data()
  private var nextProgress = 0.1
  private var session: URLSession?
  private var task: URLSessionUploadTask?

  init(progress: @escaping Progress, completion: @escaping Completion) {
    self.progress = progress
    self.completion = completion
  }

  func start(request: URLRequest, source: URL) {
    let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    self.session = session
    let task = session.uploadTask(with: request, fromFile: source)
    self.task = task
    task.resume()
  }

  func cancel() { task?.cancel() }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
    totalBytesSent: Int64, totalBytesExpectedToSend: Int64
  ) {
    guard totalBytesExpectedToSend > 0 else { return }
    let value = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
    if value >= nextProgress, value < 1 {
      while nextProgress <= value { nextProgress += 0.1 }
      progress(value)
    }
  }

  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data
  ) {
    responseData.append(data)
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
  ) {
    completion((task.response as? HTTPURLResponse)?.statusCode, responseData, error)
    session.finishTasksAndInvalidate()
    self.session = nil
    self.task = nil
  }
}
