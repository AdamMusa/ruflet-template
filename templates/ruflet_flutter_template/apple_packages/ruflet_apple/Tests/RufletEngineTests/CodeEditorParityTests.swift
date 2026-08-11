import XCTest
@testable import RufletUI

final class CodeEditorParityTests: XCTestCase {
  func testFoldProjectionPreservesSourceAndCanBeRemovedLosslessly() {
    let source = "def greet\n  puts 'hello'\nend\ngreet"
    let region = CodeFoldProjection.blockRegion(in: source, startingAt: 0)

    XCTAssertEqual(region, CodeFoldRegion(startLine: 0, endLine: 2))
    XCTAssertEqual(
      CodeFoldProjection.project(source, folding: [region!]),
      "def greet  …\ngreet")
    XCTAssertEqual(CodeFoldProjection.project(source, folding: []), source)
  }

  func testImportFoldingGroupsConsecutiveImports() {
    let source = "require 'json'\nrequire 'date'\n\nputs Date.today"
    XCTAssertEqual(
      CodeFoldProjection.importRegions(in: source),
      [CodeFoldRegion(startLine: 0, endLine: 1)])
  }

  func testLeadingCommentFoldMatchesFletCommandScope() {
    let source = "# frozen_string_literal: true\n# Copyright Ruflet\n\nrequire 'ruflet'"
    XCTAssertEqual(
      CodeFoldProjection.leadingCommentRegion(in: source),
      CodeFoldRegion(startLine: 0, endLine: 1))
  }
}
