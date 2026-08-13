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
Reviewed maps, places, and amenity concepts live in
`maps_places_overrides.json`.
Reviewed Apple device, display, connectivity, storage, keyboard, and peripheral
concepts live in `device_hardware_overrides.json`.
Reviewed social, community, health, weather, recreation, and activity concepts
with direct floor-safe Apple equivalents live in
`social_activities_overrides.json`.
Reviewed photography, image adjustment, panorama, filter, and visual-media
concepts live in `image_media_overrides.json`.
Reviewed documents, assignments, clipboard, text formatting, and editor-view
concepts live in `text_editor_overrides.json`.
Reviewed home, room, furniture, appliance, climate, and household concepts with
direct deployment-floor Apple equivalents live in
`home_household_overrides.json`.
Reviewed call direction/status, contacts, inbox, presentation, messaging, and
communication concepts live in `communication_overrides.json`.
Reviewed currency, payments, shopping, financial, and business-data concepts
live in `business_commerce_overrides.json`.
Reviewed travel amenities and route concepts not owned by the primary
navigation/transit family live in `travel_amenity_overrides.json`.
Reviewed audio, video, captions, hearing, playback, streaming, and media-library
concepts live in `audio_video_overrides.json`.
Reviewed do-not-disturb, event, error, security, update, and notification-status
concepts live in `notification_status_overrides.json`.
Reviewed clipboard, file rename, content feed, policy, report, unread, and
workspace-state concepts live in `file_content_overrides.json`.
Reviewed assessment, source/class authoring, filter, resizing, privacy, rule,
and other platform-neutral interface actions with direct Apple equivalents
live in `interface_action_overrides.json`.

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
