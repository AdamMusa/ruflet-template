import RufletEngine
import RufletProtocol
import SwiftUI
@testable import RufletUI
import XCTest

/// The display family — Icon, CircleAvatar, the two progress indicators and
/// Markdown — against the widgets Flet builds.
final class DisplayParityTests: XCTestCase {
  func testExplicitImageSizeConstrainsOmittedFit() {
    XCTAssertTrue(RufletImageLayoutSemantics.constrainsOmittedFit(hasExplicitSize: true))
    XCTAssertFalse(RufletImageLayoutSemantics.constrainsOmittedFit(hasExplicitSize: false))
  }

  private func node(_ type: String, _ props: [String: RufletValue] = [:]) -> ControlNode {
    ControlNode(id: 1, type: type, props: props)
  }

  // MARK: - Text and TextSpan

  func testTextSpanDocumentFlattensNestedSpansAndKeepsDeepestRanges() {
    let parent = ControlNode(
      id: 2, type: "TextSpan",
      props: ["text": .string("parent "), "spans": .array([.controlRef(3)])])
    let child = ControlNode(id: 3, type: "TextSpan", props: ["text": .string("child")])
    let nodes = [2: parent, 3: child]

    let document = RufletRichTextDocument(
      value: "root ", spanIDs: [2], resolve: { nodes[$0] })

    XCTAssertEqual(document.string, "root parent child")
    XCTAssertEqual(document.runs.map(\.node.id), [2, 3])
    XCTAssertEqual(document.runs[0].range, NSRange(location: 5, length: 12))
    XCTAssertEqual(document.runs[1].range, NSRange(location: 12, length: 5))
    XCTAssertEqual(document.deepestRun(at: 13)?.node.id, 3)
  }

  func testTextSpanLinksUsePrivateNativeURLsThatRoundTripTheirControlID() {
    let url = RufletSpanLink.url(for: 42)
    XCTAssertEqual(url.scheme, "ruflet-text-span")
    XCTAssertEqual(RufletSpanLink.id(from: url), 42)
    XCTAssertNil(RufletSpanLink.id(from: URL(string: "https://example.test")!))
  }

  func testTextSpanStylesInheritRootAndParentTypography() {
    let parent = ControlNode(
      id: 2, type: "TextSpan",
      props: [
        "style": .map(["size": .double(30)]),
        "spans": .array([.controlRef(3)]),
      ])
    let child = ControlNode(
      id: 3, type: "TextSpan",
      props: ["text": .string("child"), "style": .map(["weight": .string("bold")])])
    let nodes = [2: parent, 3: child]
    let document = RufletRichTextDocument(
      value: "", spanIDs: [2], resolve: { nodes[$0] })
    let root = RufletTextStyle.forText(node: node("Text"))

    let childStyle = document.runs.first { $0.node.id == 3 }?.resolvedStyle(inheriting: root)
    XCTAssertEqual(childStyle?.size, 30)
    XCTAssertEqual(childStyle?.weight, .bold)
    XCTAssertEqual(childStyle?.materialThemeMetric?.size, 14)
  }

  func testTextSpanSemanticsLabelsAndSpellOutInheritanceMatchFlutter() {
    let parent = ControlNode(
      id: 2, type: "TextSpan",
      props: [
        "text": .string("PIN "), "semantics_label": .string("security code "),
        "spell_out": .bool(true), "spans": .array([.controlRef(3), .controlRef(4)]),
      ])
    let inherited = ControlNode(id: 3, type: "TextSpan", props: ["text": .string("12")])
    let cleared = ControlNode(
      id: 4, type: "TextSpan",
      props: ["text": .string(" ok"), "spell_out": .bool(false)])
    let nodes = [2: parent, 3: inherited, 4: cleared]
    let document = RufletRichTextDocument(
      value: "Root ", spanIDs: [2], resolve: { nodes[$0] })

    XCTAssertEqual(document.semanticString, "Root security code 12 ok")
    XCTAssertEqual(document.accessibilityLabel(rootLabel: nil), "Root security code 12 ok")
    XCTAssertEqual(document.accessibilityLabel(rootLabel: "All content"), "All content")
    XCTAssertTrue(document.runs.first { $0.node.id == 3 }?.spellsOutCharacters == true)
    XCTAssertTrue(document.runs.first { $0.node.id == 4 }?.spellsOutCharacters == false)
  }

  func testTextWithoutAlternativeSemanticsPreservesNativeAccessibility() {
    let span = ControlNode(id: 2, type: "TextSpan", props: ["text": .string("world")])
    let document = RufletRichTextDocument(
      value: "hello ", spanIDs: [2], resolve: { _ in span })
    XCTAssertNil(document.accessibilityLabel(rootLabel: nil))
    XCTAssertEqual(document.accessibilityLabel(rootLabel: ""), "")
  }

  func testTextPresentationKeepsNoWrapSeparateFromMaxLines() {
    let plain = RufletTextPresentation(node: node(
      "Text", ["no_wrap": .bool(true), "overflow": .string("visible")]))
    XCTAssertTrue(plain.usesUnwrappedLayout)
    XCTAssertNil(plain.maxLines)
    XCTAssertEqual(plain.overflow, .visible)

    let selectable = RufletTextPresentation(node: node(
      "Text",
      [
        "selectable": .bool(true), "no_wrap": .bool(true),
        "max_lines": .int(2), "overflow": .string("ellipsis"),
      ]))
    XCTAssertFalse(selectable.usesUnwrappedLayout)
    XCTAssertEqual(selectable.maxLines, 2)
    XCTAssertEqual(selectable.overflow, .ellipsis)
  }

  func testTextPresentationUsesFletClipDefault() {
    let presentation = RufletTextPresentation(node: node("Text"))
    XCTAssertFalse(presentation.selectable)
    XCTAssertFalse(presentation.noWrap)
    XCTAssertEqual(presentation.overflow, .clip)
  }

  func testTextSelectionPayloadMatchesPinnedFletMap() {
    XCTAssertEqual(
      RufletRichTextDocument.textSelectionData(
        rootValue: "root", range: NSRange(location: 2, length: 3), cause: "longPress"),
      .map([
        "selected_text": .string("root"),
        "cause": .string("longPress"),
        "selection": .map([
          "base_offset": .int(2), "extent_offset": .int(5),
          "affinity": .string("downstream"), "directional": .bool(false),
        ]),
      ]))
  }

  func testMarkdownSelectionPayloadIncludesFlutterMarkdownSelectionFlags() {
    XCTAssertEqual(
      RufletRichTextDocument.markdownSelectionData(
        source: "hello world", range: NSRange(location: 6, length: 5), cause: "drag"),
      .map([
        "text": .string("world"),
        "cause": .string("drag"),
        "selection": .map([
          "start": .int(6), "end": .int(11), "selection": .string("world"),
          "base_offset": .int(6), "extent_offset": .int(11),
          "affinity": .string("downstream"), "directional": .bool(false),
          "collapsed": .bool(false), "valid": .bool(true), "normalized": .bool(true),
        ]),
      ]))
  }

  // MARK: - Image

  func testImageResolvesBinaryAndDataURISourcesBeforeURLs() {
    XCTAssertEqual(
      RufletImageSource(node: node("Image", ["src": .binary([0x89, 0x50])])),
      .binary(Data([0x89, 0x50])))
    XCTAssertEqual(
      RufletImageSource(node: node("Image", ["src": .string("data:text/plain;base64,SGk=")])),
      .binary(Data("Hi".utf8)))
    XCTAssertEqual(
      RufletImageSource(node: node("Image", ["src": .string("data:text/plain,hello%20world")])),
      .binary(Data("hello world".utf8)))
  }

  func testImageDistinguishesNetworkAndPackagedSources() {
    XCTAssertEqual(
      RufletImageSource(node: node("Image", ["src": .string("https://example.test/a.png")])),
      .remote(URL(string: "https://example.test/a.png")!))
    XCTAssertEqual(
      RufletImageSource(node: node("Image", ["src": .string("images/a.png")])),
      .asset("images/a.png"))
    XCTAssertEqual(RufletImageSource(node: node("Image")), .missing)
    XCTAssertEqual(
      RufletImageSource(node: node("Image", ["src": .null])), .missing)
  }

  /// `ResolvedAssetSource.from` tries an unadorned string as Base64 after it
  /// has ruled out a URL and an asset-looking path. Ruflet's Ruby transport
  /// uses this form for byte-backed images as well as the legacy src_base64
  /// property.
  func testImageResolvesTrimmedRawBase64WithoutMistakingAssetPaths() {
    XCTAssertEqual(
      RufletImageSource(node: node("Image", ["src": .string("  SGk=\n")])),
      .binary(Data("Hi".utf8)))
    XCTAssertEqual(
      RufletImageSource(node: node("Image", ["src": .string("avatar.png")])),
      .asset("avatar.png"))
    XCTAssertEqual(
      RufletImageSource(node: node("Image", ["src": .string("avatar")])),
      .asset("avatar"))
    XCTAssertEqual(
      RufletImageSource(node: node("Image", ["src": .string("   ")])),
      .empty)
    XCTAssertEqual(
      RufletImageSource(node: node("Image", ["src": .binary([])])),
      .empty)
    XCTAssertEqual(
      RufletImageSource(node: node("Image", ["src": .map(["bad": .bool(true)])])),
      .invalid("{bad: true} is not a supported source type."))
  }

  func testImageResolvesInlineSVGAsDocumentBytes() {
    let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M0 0\"/></svg>"
    XCTAssertEqual(
      RufletImageSource(node: node("Image", ["src": .string(svg)])),
      .binary(Data(svg.utf8)))
  }

  func testImagePresentationUsesFletConstructorDefaults() {
    let presentation = RufletImagePresentation(node: node("Image"))

    XCTAssertEqual(presentation.repeatMode, .noRepeat)
    XCTAssertEqual(presentation.filterQuality, "medium")
    XCTAssertEqual(presentation.interpolation, .medium)
    XCTAssertFalse(presentation.antiAlias)
    XCTAssertFalse(presentation.gaplessPlayback)
    XCTAssertEqual(presentation.fadeInDuration, 0.25, accuracy: 0.0001)
    XCTAssertEqual(presentation.fadeInCurve, "easeinout")
    XCTAssertEqual(presentation.fadeOutDuration, 0.15, accuracy: 0.0001)
    XCTAssertEqual(presentation.fadeOutCurve, "easeout")
  }

  func testImagePresentationConsumesRepeatQualityAndAnimationForms() {
    let presentation = RufletImagePresentation(node: node(
      "Image",
      [
        "repeat": .string("repeat_x"),
        "filter_quality": .string("high"),
        "anti_alias": .bool(true),
        "gapless_playback": .bool(true),
        "fit": .string("cover"),
        "placeholder_fit": .string("fitHeight"),
        "cache_width": .int(320),
        "cache_height": .int(180),
        "fade_in_animation": .bool(true),
        "placeholder_fade_out_animation": .map([
          "duration": .int(300), "curve": .string("bounceOut"),
        ]),
      ]))

    XCTAssertEqual(presentation.repeatMode, .repeatX)
    XCTAssertEqual(presentation.interpolation, .high)
    XCTAssertTrue(presentation.antiAlias)
    XCTAssertTrue(presentation.gaplessPlayback)
    XCTAssertEqual(presentation.fit, "cover")
    XCTAssertEqual(presentation.placeholderFit, "fitHeight")
    XCTAssertEqual(presentation.cacheWidth, 320)
    XCTAssertEqual(presentation.cacheHeight, 180)
    XCTAssertEqual(presentation.fadeInDuration, 1, accuracy: 0.0001)
    XCTAssertEqual(presentation.fadeInCurve, "linear")
    XCTAssertEqual(presentation.fadeOutDuration, 0.3, accuracy: 0.0001)
    XCTAssertEqual(presentation.fadeOutCurve, "bounceout")

    let numeric = RufletImagePresentation(node: node(
      "Image", ["fade_in_animation": .int(500)]))
    XCTAssertEqual(numeric.fadeInDuration, 0.5, accuracy: 0.0001)
    XCTAssertEqual(numeric.fadeInCurve, "linear")
  }

  func testImagePlaceholderFitFallsBackToThePrimaryFit() {
    let presentation = RufletImagePresentation(
      node: node("Image", ["fit": .string("scaleDown")]))
    XCTAssertEqual(presentation.fit, "scaleDown")
    XCTAssertEqual(presentation.placeholderFit, "scaleDown")
  }

  func testImageAndMarkdownRelativeAssetsFollowTheirDistinctFletBases() {
    let page = URL(string: "https://example.test/app/session")!
    XCTAssertEqual(
      RufletImageAssetURL.imageAsset("images/cat.png", relativeTo: page)?.absoluteString,
      "https://example.test/app/session/images/cat.png")
    XCTAssertEqual(
      RufletImageAssetURL.markdownAsset("images/cat.png", relativeTo: page)?.absoluteString,
      "https://example.test/images/cat.png")
    XCTAssertEqual(
      RufletImageAssetURL.imageAsset(
        "images/cat.png", relativeTo: URL(string: "wss://example.test/ws"))?.absoluteString,
      "https://example.test/images/cat.png")
    XCTAssertNil(
      RufletImageAssetURL.imageAsset(
        "images/cat.png", relativeTo: URL(string: "file:///tmp/project")))
  }

  func testInlineSVGDetectionUsesTheNativeVectorRendererBoundary() {
    XCTAssertTrue(RufletSVGDocument.isSVG(Data("<?xml?><svg viewBox='0 0 1 1'/>".utf8)))
    XCTAssertFalse(RufletSVGDocument.isSVG(Data([0x89, 0x50, 0x4E, 0x47])))
  }

  // MARK: - Icon

  /// Flutter only multiplies the icon by the text scaler when it was asked to,
  /// so the same glyph is a fixed 24pt otherwise.
  func testIconAppliesTheTextScalerOnlyWhenAskedTo() {
    let plain = RufletIconGlyph(node: node("Icon"))
    XCTAssertEqual(plain.size, 24)
    XCTAssertEqual(plain.scaledSize(textScale: 2), 24)

    let scaling = RufletIconGlyph(
      node: node("Icon", ["size": .double(20), "apply_text_scaling": .bool(true)]))
    XCTAssertEqual(scaling.scaledSize(textScale: 1.5), 30)
  }

  func testIconUsesSourceExactEventlessAccessibilityContract() {
    XCTAssertEqual(ControlRegistry.descriptor(for: "Icon")?.supportedEvents, [])
    XCTAssertNil(ControlRegistry.descriptor(for: "Icon")?.supportedMethods.first)

    let labelled = RufletIconGlyph(
      node: node("Icon", ["semantics_label": .string("Add item")]))
    XCTAssertEqual(labelled.semanticsLabel, "Add item")
    XCTAssertNil(RufletIconGlyph(node: node("Icon")).semanticsLabel)
  }

  /// Material's FILL axis is continuous but SF Symbols only has the outlined
  /// and filled cuts, so the midpoint is where the glyph swaps.
  func testIconFillAxisResolvesToTheFilledVariantPastTheMidpoint() {
    XCTAssertFalse(RufletIconGlyph(node: node("Icon")).isFilled)
    XCTAssertFalse(RufletIconGlyph(node: node("Icon", ["fill": .double(0.25)])).isFilled)
    XCTAssertTrue(RufletIconGlyph(node: node("Icon", ["fill": .double(0.5)])).isFilled)
    XCTAssertTrue(RufletIconGlyph(node: node("Icon", ["fill": .double(1)])).isFilled)
  }

  func testIconWeightAxisMapsOntoTheNamedFontWeights() {
    XCTAssertNil(RufletIconGlyph(node: node("Icon")).symbolWeight)
    XCTAssertEqual(
      RufletIconGlyph(node: node("Icon", ["weight": .double(400)])).symbolWeight, .regular)
    XCTAssertEqual(
      RufletIconGlyph(node: node("Icon", ["weight": .double(700)])).symbolWeight, .bold)
    XCTAssertEqual(
      RufletIconGlyph(node: node("Icon", ["weight": .double(100)])).symbolWeight, .ultraLight)
  }

  /// GRAD adjusts the same stroke as wght, only more finely, and Apple has no
  /// separate axis for it — so a grade moves the resolved weight one step and
  /// can stand on its own with Flutter's 400 as the starting point.
  func testIconGradeNudgesTheResolvedWeightInEitherDirection() {
    let heavier = RufletIconGlyph(
      node: node("Icon", ["weight": .double(400), "grade": .double(200)]))
    XCTAssertEqual(heavier.symbolWeight, .medium)

    let lighter = RufletIconGlyph(
      node: node("Icon", ["weight": .double(400), "grade": .double(-25)]))
    XCTAssertEqual(lighter.symbolWeight, .light)

    let gradeOnly = RufletIconGlyph(node: node("Icon", ["grade": .double(200)]))
    XCTAssertEqual(gradeOnly.symbolWeight, .medium)
  }

  func testIconWeightLadderClampsAtBothEnds() {
    XCTAssertEqual(
      RufletIconGlyph(node: node("Icon", ["weight": .double(1)])).symbolWeight, .ultraLight)
    XCTAssertEqual(
      RufletIconGlyph(node: node("Icon", ["weight": .double(1000)])).symbolWeight, .black)
  }

  // MARK: - CircleAvatar

  /// Flutter treats "no radius at all" as its own case: the avatar is a fixed
  /// 40pt circle rather than one free to grow to its parent.
  func testAvatarWithoutAnyRadiusIsFixedAtFortyPoints() {
    let diameter = RufletCircleAvatarDiameter(node: node("CircleAvatar"))
    XCTAssertEqual(diameter.minimum, 40)
    XCTAssertEqual(diameter.maximum, 40)
  }

  func testAvatarRadiusIsShorthandForBothBounds() {
    let diameter = RufletCircleAvatarDiameter(
      node: node("CircleAvatar", ["radius": .double(12)]))
    XCTAssertEqual(diameter.minimum, 24)
    XCTAssertEqual(diameter.maximum, 24)
  }

  /// `_defaultMaxRadius` is infinity, which SwiftUI has no bound for, so a lone
  /// minimum leaves the avatar unbounded instead of pinning it.
  func testAvatarMinimumOnItsOwnLeavesTheMaximumUnbounded() {
    let floored = RufletCircleAvatarDiameter(
      node: node("CircleAvatar", ["min_radius": .double(8)]))
    XCTAssertEqual(floored.minimum, 16)
    XCTAssertNil(floored.maximum)

    // `_defaultMinRadius` is zero, so a lone maximum floors at nothing.
    let capped = RufletCircleAvatarDiameter(
      node: node("CircleAvatar", ["max_radius": .double(30)]))
    XCTAssertEqual(capped.minimum, 0)
    XCTAssertEqual(capped.maximum, 60)
  }

  func testAvatarResolvesPinnedFlutterThemeRoles() {
    let omitted = node("CircleAvatar")
    let omittedAppearance = RufletCircleAvatarAppearance(node: omitted)
    XCTAssertEqual(omittedAppearance.backgroundColorToken, "primarycontainer")
    XCTAssertEqual(omittedAppearance.foregroundColorToken, "onprimarycontainer")

    let explicit = RufletCircleAvatarAppearance(node: node(
      "CircleAvatar", ["bgcolor": .string("red"), "color": .string("white")]))
    XCTAssertEqual(explicit.backgroundColorToken, "red")
    XCTAssertEqual(explicit.foregroundColorToken, "white")
  }

  func testImageTintIsExplicitOnly() {
    XCTAssertNil(RufletImagePresentation(node: node("Image")).explicitColorToken)
    XCTAssertNil(
      RufletImagePresentation(node: node("Image", ["color": .string("  ")]))
        .explicitColorToken)
    XCTAssertEqual(
      RufletImagePresentation(node: node("Image", ["color": .string("blue")]))
        .explicitColorToken,
      "blue")
  }

  /// CircleAvatar calls the same Flet image-provider resolver twice. These
  /// are intentionally not URL-only properties: either slot can receive raw
  /// bytes, Base64, a file/network URL, or a packaged asset path.
  func testAvatarImageSlotsUseTheSharedFletSourceResolver() {
    let sources = RufletCircleAvatarImageSources(
      node: node(
        "CircleAvatar",
        [
          "background_image_src": .binary([0x89, 0x50]),
          "foreground_image_src": .string("SGk="),
        ]))
    XCTAssertEqual(sources.background, .binary(Data([0x89, 0x50])))
    XCTAssertEqual(sources.foreground, .binary(Data("Hi".utf8)))

    let locators = RufletCircleAvatarImageSources(
      node: node(
        "CircleAvatar",
        [
          "background_image_src": .string("avatars/background.png"),
          "foreground_image_src": .string("file:///tmp/foreground.png"),
        ]))
    XCTAssertEqual(locators.background, .asset("avatars/background.png"))
    XCTAssertEqual(locators.foreground, .remote(URL(fileURLWithPath: "/tmp/foreground.png")))
  }

  func testAvatarMissingImageSlotsStayMissingInsteadOfRenderingPlaceholders() {
    let sources = RufletCircleAvatarImageSources(node: node("CircleAvatar"))
    XCTAssertEqual(sources.background, .missing)
    XCTAssertEqual(sources.foreground, .missing)
  }

  // MARK: - ProgressBar

  /// Flutter's `year2023` still defaults to true, and it drops the gap, the
  /// radius and the stop dot before the painter ever sees them.
  func testProgressBarKeepsTheTwentyTwentyThreeShapeUnlessAskedOtherwise() {
    let legacy = RufletLinearProgressMetrics(node: node("ProgressBar", ["value": .double(0.5)]))
    XCTAssertEqual(legacy.height, 4)
    XCTAssertEqual(legacy.cornerRadius, 0)
    XCTAssertNil(legacy.trackGap)
    XCTAssertNil(legacy.resolvedStopIndicatorRadius)

    let revised = RufletLinearProgressMetrics(
      node: node("ProgressBar", ["value": .double(0.5), "year_2023": .bool(false)]))
    XCTAssertEqual(revised.cornerRadius, 2)
    XCTAssertEqual(revised.trackGap, 4)
    XCTAssertEqual(revised.resolvedStopIndicatorRadius, 2)
  }

  /// A 2023 bar ignores a gap it was handed, because Flutter never forwards it.
  func testProgressBarIgnoresTwentyTwentyFourMeasurementsOnTheOldShape() {
    let metrics = RufletLinearProgressMetrics(
      node: node(
        "ProgressBar",
        ["value": .double(0.5), "track_gap": .double(10), "stop_indicator_radius": .double(6)]))
    XCTAssertEqual(metrics.effectiveTrackGap, 0)
    XCTAssertNil(metrics.resolvedStopIndicatorRadius)
  }

  func testProgressBarHeightAndRadiusComeFromTheWireWhenSupplied() {
    let metrics = RufletLinearProgressMetrics(
      node: node("ProgressBar", ["bar_height": .double(12), "border_radius": .double(6)]))
    XCTAssertEqual(metrics.height, 12)
    XCTAssertEqual(metrics.cornerRadius, 6)
  }

  /// The gap is a seam between the active bar and what is left of the track,
  /// so it closes when there is nothing on one side of it.
  func testProgressBarGapClosesWhenIndeterminateOrComplete() {
    func metrics(_ props: [String: RufletValue]) -> RufletLinearProgressMetrics {
      var all = props
      all["year_2023"] = .bool(false)
      return RufletLinearProgressMetrics(node: node("ProgressBar", all))
    }

    XCTAssertEqual(metrics(["value": .double(0.5)]).effectiveTrackGap, 4)
    XCTAssertEqual(metrics(["value": .double(1)]).effectiveTrackGap, 0)
    XCTAssertEqual(metrics([:]).effectiveTrackGap, 0)
  }

  func testProgressBarSplitsTheTrackAtTheValuePlusTheGap() {
    let metrics = RufletLinearProgressMetrics(
      node: node("ProgressBar", ["value": .double(0.25), "year_2023": .bool(false)]))
    XCTAssertEqual(metrics.activeWidth(in: 200), 50)
    XCTAssertEqual(metrics.trackOrigin(in: 200), 54)

    let legacy = RufletLinearProgressMetrics(
      node: node("ProgressBar", ["value": .double(0.25)]))
    XCTAssertEqual(legacy.trackOrigin(in: 200), 0)
  }

  /// Flutter clamps the dot to half the bar's height and centres it that far in
  /// from the trailing edge, whatever radius was asked for.
  func testProgressBarStopIndicatorIsClampedToHalfTheBarHeight() {
    let metrics = RufletLinearProgressMetrics(
      node: node(
        "ProgressBar",
        [
          "value": .double(0.4), "year_2023": .bool(false),
          "bar_height": .double(4), "stop_indicator_radius": .double(9)
        ]))
    XCTAssertEqual(metrics.resolvedStopIndicatorRadius, 2)
    XCTAssertEqual(metrics.stopIndicatorCentre(in: 100), 98)
  }

  func testProgressBarValueIsClampedToTheUnitRange() {
    XCTAssertEqual(
      RufletLinearProgressMetrics(node: node("ProgressBar", ["value": .double(4)])).value, 1)
    XCTAssertEqual(
      RufletLinearProgressMetrics(node: node("ProgressBar", ["value": .double(-4)])).value, 0)
    XCTAssertNil(RufletLinearProgressMetrics(node: node("ProgressBar")).value)
  }

  func testProgressBarStopIndicatorUsesThePrimaryRoleUnlessColoured() {
    XCTAssertEqual(
      RufletThemeDefaults.resolvedDisplayColorToken(
        for: node("ProgressBar"), property: "stop_indicator_color"),
      "primary")
    XCTAssertEqual(
      RufletThemeDefaults.resolvedDisplayColorToken(
        for: node("ProgressBar", ["stop_indicator_color": .string("green")]),
        property: "stop_indicator_color"),
      "green")
  }

  // MARK: - ProgressRing

  /// The two shapes differ in more than their ends: the 2024 ring is larger and
  /// draws its stroke inside the box rather than across its edge.
  func testProgressRingSwapsSizeAndStrokeAlignmentWithTheYearFlag() {
    let legacy = RufletCircularProgressMetrics(node: node("ProgressRing"))
    XCTAssertEqual(legacy.diameter, 36)
    XCTAssertEqual(legacy.strokeAlign, 0)
    XCTAssertEqual(legacy.strokeWidth, 4)
    XCTAssertNil(legacy.padding)

    let revised = RufletCircularProgressMetrics(
      node: node("ProgressRing", ["year2023": .bool(false)]))
    XCTAssertEqual(revised.diameter, 40)
    XCTAssertEqual(revised.strokeAlign, -1)
    XCTAssertNotNil(revised.padding)
  }

  func testProgressRingStrokeInsetFollowsTheAlignAxis() {
    let inside = RufletCircularProgressMetrics(
      node: node("ProgressRing", ["stroke_align": .double(-1), "stroke_width": .double(8)]))
    XCTAssertEqual(inside.strokeInset, 4)

    let centred = RufletCircularProgressMetrics(
      node: node("ProgressRing", ["stroke_align": .double(0), "stroke_width": .double(8)]))
    XCTAssertEqual(centred.strokeInset, 0)
  }

  /// With no cap of its own the 2023 ring squares off while it spins and butts
  /// while it is determinate; the 2024 ring is round either way.
  func testProgressRingCapsFollowTheShapeUnlessOneWasNamed() {
    XCTAssertEqual(RufletCircularProgressMetrics(node: node("ProgressRing")).strokeCap, .square)
    XCTAssertEqual(
      RufletCircularProgressMetrics(node: node("ProgressRing", ["value": .double(0.5)]))
        .strokeCap,
      .butt)
    XCTAssertEqual(
      RufletCircularProgressMetrics(node: node("ProgressRing", ["year2023": .bool(false)]))
        .strokeCap,
      .round)
    XCTAssertEqual(
      RufletCircularProgressMetrics(
        node: node("ProgressRing", ["stroke_cap": .string("round")])).strokeCap,
      .round)
  }

  func testStrokeCapParsesFlutterSpellings() {
    XCTAssertEqual(RufletStrokeCap("butt")?.lineCap, .butt)
    XCTAssertEqual(RufletStrokeCap("Round")?.lineCap, .round)
    XCTAssertEqual(RufletStrokeCap("square")?.lineCap, .square)
    XCTAssertNil(RufletStrokeCap(nil))
    XCTAssertNil(RufletStrokeCap("bevel"))
  }

  /// The 2023 ring has no track at all, and the 2024 one only shows one while
  /// it is determinate — but an explicit `bgcolor` always paints it.
  func testProgressRingTrackAppearsOnlyWhereFlutterPaintsOne() {
    XCTAssertNil(RufletCircularProgressMetrics(node: node("ProgressRing")).trackArc)
    XCTAssertNil(
      RufletCircularProgressMetrics(
        node: node("ProgressRing", ["year2023": .bool(false)])).trackArc)
    let determinate = node("ProgressRing", ["year2023": .bool(false), "value": .double(0.5)])
    XCTAssertNotNil(RufletCircularProgressMetrics(node: determinate).trackArc)
    XCTAssertNotNil(
      RufletCircularProgressMetrics(
        node: node("ProgressRing", ["bgcolor": .string("grey")])).trackArc)
  }

  /// Flutter measures the gap in points and converts it against the arc's
  /// radius, leaving the same angular gap at each end of the active arc.
  func testProgressRingTrackIsInsetByTheGapAtBothEnds() {
    let metrics = RufletCircularProgressMetrics(
      node: node("ProgressRing", ["year2023": .bool(false), "value": .double(0.5)]))
    // A 40pt box with a 4pt stroke drawn inside gives an 18pt arc radius, so
    // the 4pt gap plus the stroke is (4 + 4) / 18 radians.
    let expected = (4 + 4) / 18.0 / (2 * Double.pi)
    XCTAssertEqual(Double(metrics.gapTurns), expected, accuracy: 0.0001)

    let track = metrics.trackArc
    XCTAssertEqual(Double(track?.from ?? 0), 0.5 + expected, accuracy: 0.0001)
    XCTAssertEqual(Double(track?.to ?? 0), 1 - expected, accuracy: 0.0001)
  }

  /// A ring that is nearly full leaves no room for a track between the gaps.
  func testProgressRingTrackDisappearsWhenTheGapsMeet() {
    let metrics = RufletCircularProgressMetrics(
      node: node("ProgressRing", ["year2023": .bool(false), "value": .double(0.99)]))
    XCTAssertNil(metrics.trackArc)
  }

  func testProgressRingSizeConstraintsSupplyTheDiameterFlutterWouldEnforce() {
    let constrained = RufletCircularProgressMetrics(
      node: node(
        "ProgressRing",
        ["size_constraints": .map(["min_width": .double(64), "min_height": .double(64)])]))
    XCTAssertEqual(constrained.diameter, 64)

    // Flet wraps the indicator in a SizedBox, whose tight width wins over the
    // widget's own minimum.
    let sized = RufletCircularProgressMetrics(
      node: node(
        "ProgressRing",
        [
          "width": .double(24),
          "size_constraints": .map(["min_width": .double(64)])
        ]))
    XCTAssertEqual(sized.diameter, 24)
  }

  // MARK: - Progress semantics

  /// Flutter spells a determinate indicator's value out as a percentage and
  /// lets `semantics_value` replace it outright.
  func testProgressSpokenValueIsThePercentageUnlessOneWasGiven() {
    XCTAssertEqual(
      RufletProgressSemantics.spokenValue(node("ProgressBar", ["value": .double(0.256)])),
      "26")
    XCTAssertEqual(
      RufletProgressSemantics.spokenValue(
        node("ProgressBar", ["value": .double(0.5), "semantics_value": .double(42)])), "42.0")
    XCTAssertNil(RufletProgressSemantics.spokenValue(node("ProgressRing")))
  }

  // MARK: - Markdown extension sets

  func testMarkdownExtensionSetsCarryTheSyntaxesTheirPresetsShipWith() {
    XCTAssertEqual(RufletMarkdownExtensionSet(nil), .none)
    XCTAssertEqual(RufletMarkdownExtensionSet("commonMark"), .commonMark)
    XCTAssertEqual(RufletMarkdownExtensionSet("github_web"), .gitHubWeb)
    XCTAssertEqual(RufletMarkdownExtensionSet("gitHubFlavored"), .gitHubFlavored)

    XCTAssertFalse(RufletMarkdownExtensionSet.none.allowsFencedCode)
    XCTAssertTrue(RufletMarkdownExtensionSet.commonMark.allowsFencedCode)
    XCTAssertFalse(RufletMarkdownExtensionSet.commonMark.allowsGitHubSyntaxes)
    XCTAssertTrue(RufletMarkdownExtensionSet.gitHubWeb.allowsGitHubSyntaxes)
  }

  // MARK: - Markdown parsing

  private func blocks(
    _ source: String,
    extensions: RufletMarkdownExtensionSet = .gitHubWeb,
    softLineBreak: Bool = false
  ) -> [RufletMarkdownDocument.Block] {
    RufletMarkdownDocument.parse(source, extensions: extensions, softLineBreak: softLineBreak)
  }

  func testMarkdownHeadingsRulesAndParagraphsSplitIntoBlocks() {
    XCTAssertEqual(
      blocks("## Title\n\nBody text\n\n---"),
      [.heading(level: 2, text: "Title"), .paragraph(text: "Body text"), .rule])
  }

  /// A run of hashes without a space after it is not a heading in CommonMark.
  func testMarkdownHashesWithoutASpaceAreOrdinaryText() {
    XCTAssertEqual(blocks("#Title"), [.paragraph(text: "#Title")])
    XCTAssertEqual(blocks("####### Seven"), [.paragraph(text: "####### Seven")])
  }

  /// `FencedCodeBlockSyntax` only ships with the presets above `none`, so the
  /// same source is three lines of prose without it.
  func testMarkdownFencedCodeNeedsAnExtensionSetThatShipsIt() {
    let source = "```dart\nvoid main() {}\n```"
    XCTAssertEqual(
      blocks(source, extensions: .commonMark),
      [.code(language: "dart", source: "void main() {}")])
    XCTAssertEqual(
      blocks(source, extensions: .none),
      [.paragraph(text: "```dart void main() {} ```")])
  }

  /// CommonMark folds a single newline into a space; `soft_line_break` asks for
  /// it to break the line instead.
  func testMarkdownSoftLineBreakDecidesHowALoneNewlineReads() {
    XCTAssertEqual(blocks("one\ntwo"), [.paragraph(text: "one two")])
    XCTAssertEqual(
      blocks("one\ntwo", softLineBreak: true), [.paragraph(text: "one\ntwo")])
  }

  func testMarkdownListsCarryTheirMarkerAndNesting() {
    XCTAssertEqual(
      blocks("- one\n  - two\n1. three"),
      [
        .listItem(marker: "\u{2022}", text: "one", depth: 0),
        .listItem(marker: "\u{2022}", text: "two", depth: 1),
        .listItem(marker: "1.", text: "three", depth: 0)
      ])
  }

  func testMarkdownTaskListsRequireTheGitHubExtensionSets() {
    XCTAssertEqual(
      blocks("- [x] shipped\n1. [ ] queued", extensions: .gitHubFlavored),
      [
        .taskListItem(marker: "\u{2022}", text: "shipped", depth: 0, checked: true),
        .taskListItem(marker: "1.", text: "queued", depth: 0, checked: false),
      ])
    XCTAssertEqual(
      blocks("- [x] shipped", extensions: .commonMark),
      [.listItem(marker: "\u{2022}", text: "[x] shipped", depth: 0)])
  }

  func testMarkdownQuotesJoinAcrossConsecutiveLines() {
    XCTAssertEqual(blocks("> one\n> two"), [.quote(text: "one two")])
  }

  /// `TableSyntax` arrives with the GitHub presets, and the divider row is what
  /// tells a table apart from a paragraph containing pipes.
  func testMarkdownTablesNeedAGitHubExtensionSetAndADividerRow() {
    let source = "| a | b |\n| --- | --- |\n| 1 | 2 |"
    XCTAssertEqual(blocks(source), [.table(rows: [["a", "b"], ["1", "2"]])])
    // Without TableSyntax the three lines are one run of prose.
    XCTAssertEqual(
      blocks(source, extensions: .commonMark),
      [.paragraph(text: "| a | b | | --- | --- | | 1 | 2 |")])
    XCTAssertEqual(blocks("| a | b |"), [.paragraph(text: "| a | b |")])
  }

  /// A `Text` cannot carry an image run, so only a paragraph that is nothing
  /// but an image becomes one — which is where `image_error_content` lands.
  func testMarkdownImageOnItsOwnBecomesAnImageBlock() {
    XCTAssertEqual(
      blocks("![a cat](https://example.com/cat.png)"),
      [.image(source: "https://example.com/cat.png", alternate: "a cat")])
    XCTAssertEqual(
      blocks("look: ![a cat](https://example.com/cat.png)"),
      [.paragraph(text: "look: ![a cat](https://example.com/cat.png)")])
  }

  func testMarkdownDisplayMathsIsCollectedOnOneLineOrSeveral() {
    XCTAssertEqual(blocks("$$x^2$$"), [.latex(source: "x^2")])
    XCTAssertEqual(blocks("$$\nx^2\n$$"), [.latex(source: "x^2")])
  }

  // MARK: - Markdown inline preparation

  /// Foundation's parser understands strikethrough whether or not the source
  /// asked for GitHub's syntaxes, so the tildes are escaped when it did not.
  func testMarkdownStrikethroughIsEscapedAwayOutsideTheGitHubPresets() {
    XCTAssertEqual(
      RufletMarkdownInline.prepare("~~gone~~", extensions: .commonMark), "\\~\\~gone\\~\\~")
    XCTAssertEqual(
      RufletMarkdownInline.prepare("~~gone~~", extensions: .gitHubWeb), "~~gone~~")
  }

  func testMarkdownAutolinksRewriteBareURLsIntoLinkSpans() {
    XCTAssertEqual(
      RufletMarkdownInline.linkify("see https://example.com now"),
      "see [https://example.com](https://example.com) now")
  }

  /// A URL already inside a link span must not be wrapped a second time.
  func testMarkdownAutolinksLeaveExistingLinksAlone() {
    let source = "[home](https://example.com)"
    XCTAssertEqual(RufletMarkdownInline.linkify(source), source)
  }

  func testMarkdownAutoFollowTargetNeverSuppressesNativeLaunch() {
    XCTAssertFalse(RufletMarkdownLinkBehavior.follows(automatically: false, target: "_blank"))
    for target in [nil, "_blank", "_self", "_parent", "_top"] as [String?] {
      XCTAssertTrue(RufletMarkdownLinkBehavior.follows(automatically: true, target: target))
    }
  }

  // MARK: - Markdown code theme

  /// flutter_highlight's theme map is not vendored, so a named theme resolves
  /// only if its `root` is one of the pinned ones — and an unknown name gives
  /// no theme at all, exactly as Flutter's parser does.
  func testMarkdownCodeThemeResolvesPinnedNamesAndIgnoresTheRest() {
    XCTAssertEqual(
      RufletThemeDefaults.markdownCodeThemeRoot(named: "GitHub")?.background, "#ffffff")
    XCTAssertEqual(
      RufletThemeDefaults.markdownCodeThemeRoot(named: "atom_one_dark")?.foreground, "#abb2bf")
    XCTAssertNil(RufletThemeDefaults.markdownCodeThemeRoot(named: "nord"))

    let named = RufletMarkdownCodeTheme(value: .string("monokai-sublime"))
    XCTAssertNotNil(named.background)
    XCTAssertNil(RufletMarkdownCodeTheme(value: .string("nord")).background)
    XCTAssertNil(RufletMarkdownCodeTheme(value: nil).background)
  }

  func testMarkdownCodeThemeAlsoAcceptsATokenMap() {
    let theme = RufletMarkdownCodeTheme(
      value: .map(["root": .map(["color": .string("white"), "bgcolor": .string("black")])]))
    XCTAssertNotNil(theme.foreground)
    XCTAssertNotNil(theme.background)
  }

  // MARK: - Markdown style sheet

  /// `MarkdownStyleSheet.fromTheme` supplies these when Ruby sent no sheet, and
  /// an explicit sheet replaces them one key at a time.
  func testMarkdownStyleSheetFallsBackToTheFlutterThemeSheet() {
    let plain = RufletMarkdownStyleSheet(node: node("Markdown"))
    XCTAssertEqual(plain.blockSpacing, 8)
    XCTAssertEqual(plain.listIndent, 24)
    XCTAssertEqual(plain.ruleThickness, 5)
    XCTAssertEqual(plain.codeFontSize, 14 * 0.85)

    let styled = RufletMarkdownStyleSheet(
      node: node(
        "Markdown",
        ["md_style_sheet": .map(["block_spacing": .double(2), "list_indent": .double(40)])]))
    XCTAssertEqual(styled.blockSpacing, 2)
    XCTAssertEqual(styled.listIndent, 40)
  }

  /// `LatexElementBuilder` scales the formula's own text style, so the factor
  /// multiplies whatever size `latex_style` asked for.
  func testMarkdownLatexScaleFactorMultipliesTheLatexTextSize() {
    let plain = RufletMarkdownStyleSheet(node: node("Markdown"))
    XCTAssertEqual(plain.latexFontSize, 14)

    let scaled = RufletMarkdownStyleSheet(
      node: node(
        "Markdown",
        [
          "latex_style": .map(["size": .double(20)]),
          "latex_scale_factor": .double(1.5)
        ]))
    XCTAssertEqual(scaled.latexFontSize, 30)
  }

  func testMarkdownCodeStyleSheetOwnsTheCodeBlockPadding() {
    let sheet = RufletMarkdownStyleSheet(
      node: node(
        "Markdown",
        ["code_style_sheet": .map(["codeblock_padding": .double(20)])]))
    XCTAssertEqual(sheet.codeBlockPadding.leading, 20)

    XCTAssertEqual(RufletMarkdownStyleSheet(node: node("Markdown")).codeBlockPadding.leading, 8)
  }

  func testMarkdownStyleSheetConsumesEveryBlockPaddingAndAlignmentFamily() {
    let sheet = RufletMarkdownStyleSheet(
      node: node(
        "Markdown",
        [
          "md_style_sheet": .map([
            "p_padding": .double(3),
            "h2_padding": .map(["left": .double(7)]),
            "list_bullet_padding": .map(["right": .double(9)]),
            "text_alignment": .string("center"),
            "h2_alignment": .string("end"),
            "blockquote_alignment": .string("center"),
            "codeblock_alignment": .string("end"),
            "ordered_list_alignment": .string("center"),
            "unordered_list_alignment": .string("end"),
            "table_head_text_align": .string("right"),
          ])
        ]))

    XCTAssertEqual(sheet.paragraphPadding.leading, 3)
    XCTAssertEqual(sheet.headingPadding(2).leading, 7)
    XCTAssertEqual(sheet.listBulletPadding.trailing, 9)
    XCTAssertEqual(sheet.paragraphAlignment, .center)
    XCTAssertEqual(sheet.headingAlignment(2), .trailing)
    XCTAssertEqual(sheet.blockquoteAlignment, .center)
    XCTAssertEqual(sheet.codeBlockAlignment, .trailing)
    XCTAssertEqual(sheet.orderedListAlignment, .center)
    XCTAssertEqual(sheet.unorderedListAlignment, .trailing)
    XCTAssertEqual(sheet.tableHeadTextAlignment, .trailing)
  }

  func testMarkdownStyleSheetKeepsPinnedInlineStyleDefaultsAndOverrides() {
    let defaults = RufletMarkdownStyleSheet(node: node("Markdown"))
    XCTAssertTrue(defaults.emphasis.italic)
    XCTAssertEqual(defaults.strong.weight, .bold)
    XCTAssertTrue(defaults.deletion.decoration.contains(.lineThrough))
    XCTAssertEqual(defaults.inlineCode.fontFamily, "monospace")
    XCTAssertNotNil(defaults.checkbox.color)

    let explicit = RufletMarkdownStyleSheet(
      node: node(
        "Markdown",
        [
          "md_style_sheet": .map([
            "em_text_style": .map(["size": .double(19)]),
            "strong_text_style": .map(["weight": .string("w900")]),
            "del_text_style": .map(["color": .string("red")]),
            "a_text_style": .map(["size": .double(18)]),
          ])
        ]))
    XCTAssertEqual(explicit.emphasis.size, 19)
    XCTAssertEqual(explicit.strong.weight, .black)
    XCTAssertNotNil(explicit.deletion.color)
    XCTAssertEqual(explicit.link.size, 18)
  }

  // MARK: - Markdown document flags

  /// All three arrive from the generated Flet contract, so an omitted value has
  /// to read as MarkdownBody's own default rather than as false.
  func testMarkdownLayoutFlagsKeepTheirFletDefaults() {
    let omitted = RufletMarkdownDocument(node: node("Markdown"))
    XCTAssertTrue(omitted.fitsContent)
    XCTAssertTrue(omitted.shrinksWrap)

    let stretched = RufletMarkdownDocument(
      node: node("Markdown", ["fit_content": .bool(false), "shrink_wrap": .bool(false)]))
    XCTAssertFalse(stretched.fitsContent)
    XCTAssertFalse(stretched.shrinksWrap)
  }

  func testMarkdownDocumentReadsItsExtensionSetOffTheWire() {
    XCTAssertEqual(RufletMarkdownDocument(node: node("Markdown")).extensions, .none)
    XCTAssertEqual(
      RufletMarkdownDocument(
        node: node("Markdown", ["extension_set": .string("gitHubWeb")])).extensions,
      .gitHubWeb)
  }
}
