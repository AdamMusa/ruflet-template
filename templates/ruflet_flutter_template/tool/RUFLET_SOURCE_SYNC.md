# Updating the local Ruflet engine

The core package is reproduced from `packages/flet` in a clean upstream Flet Git
commit. `ruflet_namespace.rb` transforms package paths, imports, symbols and wire
names into Ruflet, then applies the reviewed embedded-transport overlay in
`ruflet_transport_overlay.json`. Licenses, copyright notices and real upstream
URLs are preserved; existing Ruflet names and Leaflet are not double-renamed.
Extension packages,
host code, and protocol/Swift conformance inventories are not synchronized here.

From the template root:

```sh
ruby tool/sync_ruflet_source.rb --source /path/to/flet-checkout --ref COMMIT
ruby tool/sync_ruflet_source.rb --source /path/to/flet-checkout --ref COMMIT --check
ruby tool/conformance/test_ruflet_source_integrity.rb
ruby tool/test_sync_ruflet_source.rb
ruby tool/test_ruflet_namespace.rb
```

`RUFLET_UPSTREAM_ROOT` can replace `--source`. Without a source argument or that
environment variable, `--check` verifies the vendored inventory offline.
The compatibility `generate_ruflet_source_integrity.rb` entrypoint delegates to
this same operation; it no longer pins an unrelated historical release.

The first migration from the old inventory additionally requires `--initialize`.
Subsequent syncs refuse local source drift, even with that flag: commit or restore
the intended changes in their source of truth first. Sync reads tracked blobs
from the requested commit, never generated output or uncommitted source files.
It includes Dart sources/tests, vendor packages, binary assets/fonts, licenses,
and package metadata; generated caches, build outputs and lockfiles are excluded.

The four transport injection points have exact, single-match anchors. Changed
anchors require review, not fuzzy patching. The standalone in-process channel and
its test remain template-owned and must match the reviewed hashes before sync.
The tool updates only the source-ref comment in the template root pubspec, leaving
dependencies and other user settings untouched. The package's own pubspec comes
from the source commit with the reviewed namespace transformation, including its
local dependency forks. The resulting engine is `package:ruflet/ruflet.dart`.

Every changed or removed existing package file is copied into a temporary backup
directory whose path is printed. The previous manifest and template pubspec are
also saved there. Inspect the resulting diff, run the Ruflet tests (especially the
in-process transport suite), then commit the managed files and the version-3
`conformance/ruflet_source_integrity.json` together. Its source commit, blob IDs,
original source paths, namespace recipe checksum, content hashes, and explicit
exact/namespaced/overlay classifications provide reproducible
provenance without checking in developer caches.
