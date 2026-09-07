# Updating the local Flet engine

The core package is reproduced from a clean Flet Git commit, plus the reviewed
embedded-transport overlay in `flet_transport_overlay.json`. Extension packages,
host code, and protocol/Swift conformance inventories are not synchronized here.

From the template root:

```sh
ruby tool/sync_flet_source.rb --source /path/to/flet --ref COMMIT
ruby tool/sync_flet_source.rb --source /path/to/flet --ref COMMIT --check
ruby tool/conformance/test_flet_source_integrity.rb
ruby tool/test_sync_flet_source.rb
```

`FLET_UPSTREAM_ROOT` can replace `--source`. Without a source argument or that
environment variable, `--check` verifies the vendored inventory offline.
The compatibility `generate_flet_source_integrity.rb` entrypoint delegates to
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
from the source commit, including its local dependency forks.

Every changed or removed existing package file is copied into a temporary backup
directory whose path is printed. The previous manifest and template pubspec are
also saved there. Inspect the resulting diff, run the Flet tests (especially the
in-process transport suite), then commit the managed files and the version-2
`conformance/flet_source_integrity.json` together. Its source commit, blob IDs,
content hashes and explicit overlay classifications provide reproducible
provenance without checking in developer caches.
