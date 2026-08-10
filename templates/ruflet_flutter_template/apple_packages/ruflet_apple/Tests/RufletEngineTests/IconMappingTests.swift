import XCTest

@testable import RufletUI

final class IconMappingTests: XCTestCase {
  func testCodepointDescriptorPreservesIconFamily() {
    XCTAssertEqual(
      MaterialIconNames.descriptor(forCodepoint: MaterialIconNames.firstCodepoint)?.family,
      .material)
    XCTAssertEqual(
      MaterialIconNames.descriptor(forCodepoint: MaterialIconNames.cupertinoFirstCodepoint)?.family,
      .cupertino)
  }

  func testCupertinoNamesResolveToNativeSymbols() {
    XCTAssertEqual(IconMapping.symbol(forCupertinoName: "ADD"), "plus")
    XCTAssertEqual(IconMapping.symbol(forCupertinoName: "SETTINGS"), "gearshape")
    XCTAssertEqual(IconMapping.symbol(forCupertinoName: "PERSON_CIRCLE"), "person.crop.circle")
  }

  func testUnknownCupertinoIconRemainsVisible() {
    XCTAssertEqual(
      IconMapping.symbol(forCupertinoName: "AN_ICON_THAT_CANNOT_EXIST"),
      "questionmark.square.dashed")
  }
}
