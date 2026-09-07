# Updating the local Ruflet engine

All 20 owned packages are copied exactly from `packages/` in a clean
`ruflet-engine` Git commit. The engine owns its renderers and in-process
transport together. No Flet namespace rewriting or template-only transport
patching happens during synchronization. Preserve upstream copyright notices,
licenses, fonts, and vendored assets. Application and platform host code are
outside this engine sync tool's write scope.

From the template root:

```sh
ruby tool/sync_ruflet_source.rb --source /path/to/ruflet-engine --ref COMMIT
ruby tool/sync_ruflet_source.rb --source /path/to/ruflet-engine --ref COMMIT --check
ruby tool/conformance/test_ruflet_source_integrity.rb
ruby tool/test_sync_ruflet_source.rb
```

`RUFLET_ENGINE_ROOT` can replace `--source`. Without a source argument or that
environment variable, `--check` verifies the vendored inventory offline.
The compatibility `generate_ruflet_source_integrity.rb` entrypoint delegates to
this same operation; it no longer pins an unrelated historical release.

The first migration from the old inventory additionally requires `--initialize`.
Subsequent syncs refuse local source drift, even with that flag: commit or restore
the intended changes in their source of truth first. Sync reads tracked blobs
from the requested commit, never generated output or uncommitted source files.
It includes Dart sources/tests, vendor packages, binary assets/fonts, licenses,
and package metadata; generated caches, build outputs and lockfiles are excluded.

The tool updates only the source-ref comment in the template root pubspec, leaving
dependencies and other user settings untouched. The package's own pubspec comes
unchanged from the source commit, including its
local dependency forks. The resulting engine is `package:ruflet/ruflet.dart`.

Every changed or removed existing package file is copied into a temporary backup
directory whose path is printed. The previous manifest and template pubspec are
also saved there. Inspect the resulting diff, run the Ruflet tests (especially the
in-process transport suite), then commit the managed files and the version-5
`conformance/ruflet_source_integrity.json` together. Its source commit, blob IDs,
source paths, executable modes, and identical source/destination hashes provide reproducible
provenance without checking in developer caches. The retired namespace transform
and transport overlay remain recoverable from Git history.
