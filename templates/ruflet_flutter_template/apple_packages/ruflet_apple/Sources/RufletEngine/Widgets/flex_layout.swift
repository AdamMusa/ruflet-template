import SwiftUI

/// Per-child flex parent data, the SwiftUI counterpart of Flutter's
/// `FlexParentData` attached by `Expanded`/`Flexible`.
@available(macOS 13.0, iOS 16.0, *)
struct RufletFlexParentDataKey: LayoutValueKey {
  static let defaultValue: RufletExpansionContract? = nil
}

/// Single-pass port of Flutter's `RenderFlex.performLayout`.
///
/// The measurement-feedback stack this replaces published child sizes through a
/// `PreferenceKey` into `@State` and re-laid-out with the result, so SwiftUI
/// needed several passes to converge — and nested Rows/Columns multiplied those
/// passes. `RenderFlex` instead measures non-flex children once, divides the
/// remainder among the flex children and places everything, in one pass. Doing
/// the same here removes the feedback loop entirely.
@available(macOS 13.0, iOS 16.0, *)
struct RufletFlexLayout: Layout {
  let axis: Axis
  let spacing: CGFloat
  let mainAxisAlignment: RufletMainAxisAlignment
  let crossAxisStretch: Bool
  let crossAxisAlignment: RufletFlexCrossAlignment
  /// Flutter's `MainAxisSize.min`.
  let tight: Bool

  struct Cache {
    var sizes: [CGSize] = []
    var proposal: ProposedViewSize = .unspecified
  }

  func makeCache(subviews: Subviews) -> Cache { Cache() }

  func updateCache(_ cache: inout Cache, subviews: Subviews) { cache = Cache() }

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) -> CGSize {
    if ProcessInfo.processInfo.environment["RUFLET_GEOMETRY_TRACE"] == "1" {
      print("FLEXPASS \(axis) n=\(subviews.count)")
    }
    let sizes = measure(proposal: proposal, subviews: subviews)
    cache.sizes = sizes
    cache.proposal = proposal

    let content = contentExtent(sizes)
    let cross = sizes.map(crossExtent).max() ?? 0

    let mainAvailable = mainProposal(proposal)
    let main: CGFloat
    if tight || mainAvailable == nil {
      main = content
    } else {
      // Flutter's MainAxisSize.max fills the incoming constraint.
      main = max(content, mainAvailable!)
    }
    let crossAvailable = crossProposal(proposal)
    let resolvedCross = crossAxisStretch ? max(cross, crossAvailable ?? cross) : cross
    return axis == .horizontal
      ? CGSize(width: main, height: resolvedCross)
      : CGSize(width: resolvedCross, height: main)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) {
    let sizes: [CGSize]
    if cache.sizes.count == subviews.count, cache.proposal == proposal {
      sizes = cache.sizes
    } else {
      sizes = measure(proposal: proposal, subviews: subviews)
    }

    let mainBounds = axis == .horizontal ? bounds.width : bounds.height
    let crossBounds = axis == .horizontal ? bounds.height : bounds.width
    let distribution = rufletMainAxisDistribution(
      alignment: mainAxisAlignment,
      availableExtent: mainBounds,
      occupiedExtent: contentExtent(sizes),
      childCount: subviews.count)

    var cursor = distribution.edgeInset
    for index in subviews.indices {
      let size = sizes[index]
      let cross = crossOffset(for: size, within: crossBounds)
      let origin =
        axis == .horizontal
        ? CGPoint(x: bounds.minX + cursor, y: bounds.minY + cross)
        : CGPoint(x: bounds.minX + cross, y: bounds.minY + cursor)
      subviews[index].place(
        at: origin,
        anchor: .topLeading,
        proposal: ProposedViewSize(size))
      cursor += mainExtent(size)
      if index < subviews.count - 1 {
        cursor += spacing + distribution.additionalGap
      }
    }
  }

  // MARK: - Flutter's two-phase measurement

  private func measure(proposal: ProposedViewSize, subviews: Subviews) -> [CGSize] {
    var sizes = [CGSize](repeating: .zero, count: subviews.count)
    let crossAvailable = crossProposal(proposal)

    // Phase 1: non-flex children get an unbounded main axis, exactly as
    // `RenderFlex` gives them `BoxConstraints(maxHeight:)` for a horizontal
    // flex. They take their intrinsic extent and never compress.
    var totalFlex = 0
    var fixedExtent: CGFloat = 0
    for index in subviews.indices {
      let contract = subviews[index][RufletFlexParentDataKey.self]
      if let contract, contract.flex > 0 {
        totalFlex += contract.flex
        continue
      }
      let size = measureSubview(
        subviews[index],
        main: nil,
        crossMaximum: crossAvailable)
      sizes[index] = size
      fixedExtent += mainExtent(size)
    }

    guard totalFlex > 0 else { return sizes }

    // Phase 2: divide the remainder by flex factor and hand each flex child a
    // tight main-axis constraint (loose for `expand_loose`, i.e. `Flexible`).
    let gaps = spacing * CGFloat(max(subviews.count - 1, 0))
    let available = mainProposal(proposal) ?? 0
    let remaining = max(available - fixedExtent - gaps, 0)
    for index in subviews.indices {
      guard let contract = subviews[index][RufletFlexParentDataKey.self], contract.flex > 0
      else { continue }
      let share = remaining * CGFloat(contract.flex) / CGFloat(totalFlex)
      let measured = measureSubview(
        subviews[index],
        main: share,
        crossMaximum: crossAvailable)
      // `Flexible` may end up smaller than its share; `Expanded` is exact.
      let main = contract.loose ? min(mainExtent(measured), share) : share
      sizes[index] =
        axis == .horizontal
        ? CGSize(width: main, height: measured.height)
        : CGSize(width: measured.width, height: main)
    }
    return sizes
  }

  /// SwiftUI proposals are ideal sizes, while Flutter gives a non-stretched
  /// Flex child a loose `0...maxCross` constraint. Passing `maxCross` as the
  /// ideal size made nested Columns treat every Button as full-width even
  /// though the wire did not request `horizontal_alignment: stretch`.
  ///
  /// Measure intrinsically first for the loose case and constrain only an
  /// actually oversized child. A stretched child receives and occupies the
  /// exact cross extent, matching `CrossAxisAlignment.stretch`.
  private func measureSubview(
    _ subview: LayoutSubview,
    main: CGFloat?,
    crossMaximum: CGFloat?
  ) -> CGSize {
    if crossAxisStretch {
      let measured = subview.sizeThatFits(childProposal(main: main, cross: crossMaximum))
      guard let crossMaximum, crossMaximum.isFinite else { return measured }
      return replacingCrossExtent(in: measured, with: max(crossMaximum, 0))
    }

    let intrinsic = subview.sizeThatFits(childProposal(main: main, cross: nil))
    guard let crossMaximum, crossMaximum.isFinite,
      crossExtent(intrinsic) > max(crossMaximum, 0)
    else { return intrinsic }
    let constrained = subview.sizeThatFits(
      childProposal(main: main, cross: max(crossMaximum, 0)))
    return replacingCrossExtent(
      in: constrained,
      with: min(crossExtent(constrained), max(crossMaximum, 0)))
  }

  private func childProposal(main: CGFloat?, cross: CGFloat?) -> ProposedViewSize {
    return axis == .horizontal
      ? ProposedViewSize(width: main, height: cross)
      : ProposedViewSize(width: cross, height: main)
  }

  private func replacingCrossExtent(in size: CGSize, with cross: CGFloat) -> CGSize {
    axis == .horizontal
      ? CGSize(width: size.width, height: cross)
      : CGSize(width: cross, height: size.height)
  }

  private func contentExtent(_ sizes: [CGSize]) -> CGFloat {
    let gaps = spacing * CGFloat(max(sizes.count - 1, 0))
    return sizes.reduce(CGFloat.zero) { $0 + mainExtent($1) } + gaps
  }

  private func mainExtent(_ size: CGSize) -> CGFloat {
    axis == .horizontal ? size.width : size.height
  }

  private func crossExtent(_ size: CGSize) -> CGFloat {
    axis == .horizontal ? size.height : size.width
  }

  private func mainProposal(_ proposal: ProposedViewSize) -> CGFloat? {
    axis == .horizontal ? proposal.width : proposal.height
  }

  private func crossProposal(_ proposal: ProposedViewSize) -> CGFloat? {
    axis == .horizontal ? proposal.height : proposal.width
  }

  private func crossOffset(for size: CGSize, within bounds: CGFloat) -> CGFloat {
    guard !crossAxisStretch else { return 0 }
    let free = max(bounds - crossExtent(size), 0)
    switch crossAxisAlignment {
    case .start: return 0
    case .center: return free / 2
    case .end: return free
    }
  }
}

enum RufletFlexCrossAlignment {
  case start
  case center
  case end
}
