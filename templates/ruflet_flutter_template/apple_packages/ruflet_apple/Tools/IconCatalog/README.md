# Material wire identities on Apple

`material_icons.json` is part of Flet's cross-platform wire protocol. It is
not permission to render Google's Material icon font on iOS or macOS.

`generate_material_to_apple.py` expands all 8,825 pinned Flet identities into
`Sources/RufletEngine/Resources/IconCatalog/material_to_apple.json`. Every
entry names either a bundled Flutter Cupertino glyph or an SF Symbol available
at both package deployment floors (iOS 15.0 and macOS 13.1). SF Symbols are
selected only from Apple's public CoreGlyphs catalog. Private names and symbols
with Apple product-usage restrictions are excluded from automatic matching.
There is no Material-font target, placeholder target, or runtime fuzzy fallback
in the generated resource.

Reviewed concepts are split into disjoint semantic-family files so a corpus
change is auditable rather than a screen-specific patch. The navigation and
transit family lives in `navigation_travel_overrides.json`; the generator
rejects duplicate concepts across reviewed files. Platform-neutral action
concepts live in `action_overrides.json`.

The 8,825 identities contain 2,235 concepts because Flet carries Outlined,
Rounded, and Sharp Material variants. The generator records the collapsed
concept on every entry and tests that variants do not change meaning.

Run:

```sh
python3 Tools/IconCatalog/generate_material_to_apple.py
python3 -m unittest Tools/IconCatalog/test_generate_material_to_apple.py
python3 Tools/IconCatalog/generate_material_to_apple.py --check
```

The generated audit distinguishes reviewed overrides, exact Apple-name
matches, and semantic rankings. `low_confidence_concepts` is deliberately
checked in: corpus completeness is not the same as semantic review, and a weak
mapping must remain visible until a human assigns a better native equivalent
in `overrides.json`.

`material_semantics.json` is a snapshot of tags/categories from Google's
official Material Symbols metadata endpoint, reduced to the pinned Flet
concepts. It is an audit/scoring input only; no Google artwork is bundled.
