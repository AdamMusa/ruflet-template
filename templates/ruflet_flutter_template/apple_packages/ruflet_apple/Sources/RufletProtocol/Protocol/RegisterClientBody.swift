public struct RufletRegisterClientRequestBody: Equatable, Sendable {
  public let sessionID: String?
  public let pageName: String
  public let page: [String: RufletValue]

  public init(sessionID: String?, pageName: String, page: [String: RufletValue]) {
    self.sessionID = sessionID
    self.pageName = pageName
    self.page = page
  }

  public var value: RufletValue {
    [
      "session_id": sessionID.map(RufletValue.string) ?? .null,
      "page_name": .string(pageName),
      "page": .map(page),
    ]
  }
}

public struct RufletRegisterClientResponseBody: Equatable, Sendable {
  public let sessionID: String?
  public let pagePatch: [String: RufletValue]
  public let error: String?

  public init(value: RufletValue) throws {
    guard let map = value.map else { throw RufletProtocolError.invalidMessage }
    if let sessionID = map["session_id"], !sessionID.isNull {
      guard let text = sessionID.text else {
        throw RufletProtocolError.invalidField("session_id")
      }
      self.sessionID = text
    } else {
      self.sessionID = nil
    }
    guard let pagePatch = map["page_patch"]?.map else {
      throw RufletProtocolError.missingField("page_patch")
    }
    self.pagePatch = pagePatch
    if let error = map["error"], !error.isNull {
      guard let text = error.text else {
        throw RufletProtocolError.invalidField("error")
      }
      self.error = text
    } else {
      self.error = nil
    }
  }
}
