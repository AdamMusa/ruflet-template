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
  scrollbars. Shared parsing uses the typed, design-neutral `FletStyleTheme`.
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
ruby tool/sync_flet_source.rb --check
ruby tool/test_sync_flet_source.rb
ruby tool/conformance/test_flet_source_integrity.rb
cd flet_packages/flet
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

Run extension tests in each package under `flet_packages`: `flet_code_editor`,
`flet_color_pickers`, `flet_datatable2`, `flet_video`, `flet_map`, `flet_charts`,
`flet_spinkit`, and `flet_ads`. Run vendored Markdown and math tests inside their
own package directories too; the engine's test command does not discover them.

The source repository also retains a simulator smoke-test harness. It exercises
the real canonical Page/View tree with both Cupertino and Material rendering:
counter events, text editing, checkbox changes, tabs, dialog open/close, scrolling,
and navigation-bar geometry. This is more than a screenshot of isolated widgets.

See [the source sync guide](../templates/ruflet_flutter_template/tool/FLET_SOURCE_SYNC.md)
for exact-commit synchronization, transport overlay preservation, and drift checks.

## Scope of the evidence

The separation is in Flet-owned renderers and the identified dependency UI paths.
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
