# Platform renderer separation

Ruflet's Flutter engine uses one Ruby control protocol with independent Material
and Cupertino renderers. This applies to apps generated from this template, not
just to an example app. Rebuild an existing generated client to adopt changes.

## Contract

- Canonical Ruby calls such as `button`, `text_field`, `tabs`, and `alert_dialog`
  emit one control type. Legacy design-specific Ruby names remain aliases, not
  a second protocol.
- iOS and macOS select Cupertino; Android, Windows, and Linux select Material.
  Page/view design overrides select the renderer explicitly. The effective
  target platform also controls platform-sensitive selection and theme behavior.
- Neutral control entrypoints choose one lazy renderer. Each renderer owns its
  theme, application shell, navigation, overlays, input chrome, selection, and
  scrollbars. Shared parsing uses the typed, design-neutral `RufletStyleTheme`.
  Cupertino does not construct a Material theme to interpret the Ruby DSL.
- Embedded startup, loading, and error screens use the same renderer selection.
  The template's in-process transport overlay is preserved independently from
  engine source synchronization. Renderer selection does not select a Ruby VM.
- Services and protocol/state helpers remain design-neutral. Static icon tables
  retain both wire icon families; icon data is not another widget renderer.

## Locally maintained dependencies

The source engine vendors Markdown and math packages to separate their native
scrollbars, selection, selection menus, and error rendering. The template also
contains local code-editor and color-picker UI forks, a native DataTable2
implementation, and a media-kit-video fork. Map attribution, chart styling,
video controls, and SpinKit's heart rendering have separate or neutral paths.
Keep their license files and runtime assets when synchronizing or packaging.

## Verification

From the template's `templates/ruflet_flutter_template` directory:

```sh
ruby tool/sync_ruflet_source.rb --check
ruby tool/test_sync_ruflet_source.rb
ruby tool/conformance/test_ruflet_source_integrity.rb
cd ruflet_packages/ruflet
flutter test
flutter analyze lib test
```

The engine test suite includes:

- An automatically checked registry matrix: 95 canonical control fixtures on
  five target platforms (475 mount checks), rejecting error placeholders and
  opposite-design widget chrome.
- A conservative source dependency audit following owned imports, exports,
  conditional alternatives, and registry cycles. Only proven opposite lazy
  branches and structurally validated static icon data are excluded. Adversarial
  fixtures test the audit itself.
- Focused native theme, input, button, dialog, page layout, navigation gesture,
  scrollbar, loading, startup, and error-state regressions.

Run extension tests in each package under `ruflet_packages`: `ruflet_code_editor`,
`ruflet_color_pickers`, `ruflet_datatable2`, `ruflet_video`, `ruflet_map`, `ruflet_charts`,
`ruflet_spinkit`, and `ruflet_ads`. Run vendored Markdown and math tests inside their
own package directories too; the engine's test command does not discover them.

The source repository also retains a simulator smoke-test harness. It exercises
the real canonical Page/View tree with both Cupertino and Material rendering:
counter events, text editing, checkbox changes, tabs, dialog open/close, scrolling,
and navigation-bar geometry. This is more than a screenshot of isolated widgets.

See [the source sync guide](../templates/ruflet_flutter_template/tool/RUFLET_SOURCE_SYNC.md)
for exact-commit synchronization, transport overlay preservation, and drift checks.

## Verified local revision

Source commit `7cce34b72837bc4a3e8518bb24e10c530c91c29b` was first mirrored by
template commit `58fe4bc`. The current distribution transforms that source into
the Ruflet package namespace before applying four transport overlays and two
preserved template-only transport files. Its version-3 inventory records original
paths and hashes alongside transformed hashes and the namespace recipe checksum.
The historical test results below predate the namespace change; rerun the checks
above when changing the engine.
The obsolete Material-to-Cupertino theme adapter was removed; its previous
implementation remains recoverable from Git history.

| Check | Result |
| --- | --- |
| Source engine tests | 591 passed, including the 475-case platform matrix |
| Mirrored template engine tests | 593 passed, including the preserved in-process channel |
| Owned engine `lib/test` analysis | No issues in source or template |
| Eight extension packages | 28 tests passed; no analyzer errors or warnings |
| Vendored Markdown / math | 3 / 5 tests passed |
| Full Ruby core suite | 609 tests, 3,690 assertions, no failures/errors/skips |
| Template source integrity / sync safety | 2 / 14 tests passed |
| Fresh iOS simulator harness | Both renderer passes completed; seven screenshots reviewed |
| Embedded template entrypoint with local runtime | Analysis and compilation smoke test passed |

The fresh simulator run used the existing iPhone 17 Pro Max, iOS 26.0, with
Flutter 3.41.2 / Dart 3.11.0. Extension and dependency packages still have
informational upstream/internal-import/deprecation lints; the table does not
describe them as entirely lint-free.

There is a separate, pre-existing publication mismatch: published `ruby_runtime`
0.0.14 lacks `sendToRuby`, `receiveFromRuby`, and `closeBridge`, already required
by the embedded template before this renderer work. The local runtime provides
them; the CLI's local-runtime selection tests pass. A raw template resolving only
the published runtime is therefore not equivalent to the verified local build
path. No runtime release was published as part of this task.

## Scope of the evidence

The separation is in Ruflet-owned renderers and the identified dependency UI paths.
It does not remove Flutter's own internal compatibility code from the SDK, prove
that the other design system is absent from the compiled binary, or imply a
measured bundle-size reduction. Both design systems remain available for explicit
page overrides.

Five-platform widget tests are not five native-device runs. The simulator smoke
test checks iOS plus a Material override on iOS, not an Android emulator or desktop
integration run. Hardware services and real media playback require their own
device tests. No new CRuby/mruby memory or launch-time benchmark is claimed by
these rendering tests. The experimental Swift renderer is a separate pipeline
and is not replaced by this Flutter-engine work.
