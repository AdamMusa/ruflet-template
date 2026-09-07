# Ruflet patches to flutter_markdown_plus 1.0.12

Upstream: https://github.com/foresightmobile/flutter_markdown_plus, BSD-style license
retained in LICENSE.

Code-block and horizontal-table scrollbars dispatch to separate Material and
Cupertino renderers. The explicit styleSheetTheme selects the renderer, with
platform selection retained for the platform setting. The default stays Material.

Selectable display text uses SelectableRegion and Text.rich on Cupertino,
preserving rich spans, links, intrinsic dimensions and exact selection offsets.
Its toolbar uses Cupertino controls. SelectionChangedCause is null because the
region API does not expose that value. The optional cupertinoContextMenuBuilder
accepts SelectableRegionState; the original editable-text contextMenuBuilder
continues to apply to the Material SelectableText renderer.

Default checkboxes also dispatch to platform artwork, with caller-supplied
checkboxBuilder overrides retained. Ruflet uses selectable=false and
its own outer selection region, while these adapters also support direct users
of the dependency's selectable=true public API.
