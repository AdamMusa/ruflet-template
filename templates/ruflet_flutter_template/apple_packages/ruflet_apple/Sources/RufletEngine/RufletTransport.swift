import Foundation

/// A byte pipe to the Ruflet runtime.
///
/// Abstracted so the session can be driven by a socket pair in tests, and so a
/// host that already owns a connection (a Rails app embedding the engine, say)
/// can hand one over instead of opening another.
public protocol RufletTransport: AnyObject {
  var delegate: RufletTransportDelegate? { get set }
  func connect()
  func send(_ data: Data)
  func disconnect()
}

public protocol RufletTransportDelegate: AnyObject {
  func transportDidOpen(_ transport: RufletTransport)
  func transport(_ transport: RufletTransport, didReceive data: Data)
  func transport(_ transport: RufletTransport, didCloseWith error: Error?)
}

/// Binary WebSocket client for `ws://host:port/ws`, the endpoint
/// `Ruflet::Server` accepts.
public final class WebSocketTransport: NSObject, RufletTransport {
  public weak var delegate: RufletTransportDelegate?

  private let url: URL
  private let queue = DispatchQueue(label: "com.izeesoft.ruflet.websocket")
  private var session: URLSession?
  private var task: URLSessionWebSocketTask?
  private var isClosed = false

  public init(url: URL) {
    self.url = url
    super.init()
  }

  /// Builds the endpoint URL from a runtime port, matching the banner
  /// `Ruflet::Server` prints: `ws://127.0.0.1:<port>/ws`.
  public static func endpoint(host: String = "127.0.0.1", port: Int) -> URL {
    URL(string: "ws://\(host):\(port)/ws")!
  }

  public func connect() {
    queue.async { [weak self] in
      guard let self, self.task == nil else { return }
      self.isClosed = false
      let configuration = URLSessionConfiguration.default
      configuration.timeoutIntervalForRequest = 30
      let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
      let task = session.webSocketTask(with: self.url)
      self.session = session
      self.task = task
      task.resume()
      self.receiveNext()
    }
  }

  public func send(_ data: Data) {
    queue.async { [weak self] in
      guard let self, let task = self.task, !self.isClosed else { return }
      task.send(.data(data)) { [weak self] error in
        guard let self, let error else { return }
        self.close(with: error)
      }
    }
  }

  public func disconnect() {
    queue.async { [weak self] in
      guard let self else { return }
      self.close(with: nil)
    }
  }

  private func receiveNext() {
    guard let task else { return }
    task.receive { [weak self] result in
      guard let self else { return }
      switch result {
      case .success(let message):
        switch message {
        case .data(let data):
          self.delegate?.transport(self, didReceive: data)
        case .string(let text):
          // The runtime only ever sends binary frames; a text frame means
          // something upstream of Ruflet is answering, so surface the bytes
          // rather than dropping them silently.
          self.delegate?.transport(self, didReceive: Data(text.utf8))
        @unknown default:
          break
        }
        self.queue.async { self.receiveNext() }
      case .failure(let error):
        self.queue.async { self.close(with: error) }
      }
    }
  }

  private func close(with error: Error?) {
    guard !isClosed else { return }
    isClosed = true
    task?.cancel(with: .goingAway, reason: nil)
    task = nil
    session?.invalidateAndCancel()
    session = nil
    delegate?.transport(self, didCloseWith: error)
  }
}

extension WebSocketTransport: URLSessionWebSocketDelegate {
  public func urlSession(
    _ session: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didOpenWithProtocol protocol: String?
  ) {
    delegate?.transportDidOpen(self)
  }

  public func urlSession(
    _ session: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
    reason: Data?
  ) {
    queue.async { [weak self] in self?.close(with: nil) }
  }
}
