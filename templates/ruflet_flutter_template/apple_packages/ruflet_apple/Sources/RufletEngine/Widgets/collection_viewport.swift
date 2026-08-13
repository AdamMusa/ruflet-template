import SwiftUI

/// Shared native interpretation of the viewport fields passed by Flet's
/// `ListView` and `GridView` constructors.
///
/// SwiftUI does not expose Flutter's pixel-valued `cacheExtent` knob. Grouping
/// adjacent lazy children by the number of estimated item extents makes the
/// requested cache window executable: when SwiftUI asks for the next lazy
/// group, the complete native window is constructed together. Eager controls
/// continue to construct every child immediately.
@MainActor
struct RufletCollectionViewportConfiguration: Equatable {
  let buildsOnDemand: Bool
  let cacheExtent: CGFloat?
  let semanticChildCount: Int?

  init(control: RufletControl) {
    buildsOnDemand = control.boolean("build_controls_on_demand", default: true)
    cacheExtent = control.number("cache_extent").map { CGFloat(max($0, 0)) }
    semanticChildCount = control.integer("semantic_child_count").map { max($0, 0) }
  }

  func prefetchGroupSize(estimatedItemExtent: CGFloat) -> Int {
    guard buildsOnDemand,
      let cacheExtent,
      cacheExtent > 0,
      estimatedItemExtent > 0
    else { return 1 }
    return max(Int(ceil(cacheExtent / estimatedItemExtent)) + 1, 1)
  }

  func resolvedSemanticChildCount(actualCount: Int) -> Int {
    semanticChildCount ?? actualCount
  }
}

/// VoiceOver has no `semanticChildCount` API equivalent. Exposing the value on
/// the native collection container preserves the information without
/// replacing the accessibility of its individual children.
struct RufletCollectionSemanticsModifier: ViewModifier {
  let childCount: Int

  func body(content: Content) -> some View {
    content
      .accessibilityElement(children: .contain)
      .accessibilityValue(Text("\(childCount) items"))
  }
}

extension Array {
  func rufletChunked(count: Int) -> [[Element]] {
    guard count > 0, !isEmpty else { return isEmpty ? [] : [self] }
    return stride(from: 0, to: self.count, by: count).map {
      Array(self[$0..<Swift.min($0 + count, self.count)])
    }
  }
}
