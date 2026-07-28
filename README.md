<h1 align="center">Ruflet Template</h1>

<p align="center">
  <strong>The native shell every Ruflet app is built from.</strong>
</p>

<p align="center">
  <a href="https://github.com/AdamMusa/ruflet">Ruflet</a> ·
  <a href="https://github.com/AdamMusa/ruflet_explorer">Ruflet Explorer</a>
</p>

---

## What this is

Every application you ship with Ruflet is built from this template. When you run
`ruflet build <target>`, the CLI copies this Flutter project into your project's
`build/client`, applies your `ruflet.yaml` and `services.yaml` — app name, bundle
identifier, icons, splash screens, permissions, extensions — and hands it to
Flutter.

Your Ruby stays in your repository. This is the shell it renders through, and it
is the only Dart in the pipeline. **Ruflet Explorer, the demo apps, and anything
you distribute all come out of this same project.**

You never edit this repository to build an app. It is a dependency, resolved for
you at build time.

## Every platform, one project

```
android/   ios/   macos/   windows/   linux/   web/
```

Nothing here is platform-specific to your code — the Ruby runs identically on all
six. The per-platform directories exist so the build has real native projects to
sign, package, and generate icons and splash screens into.

## Three entrypoints

The CLI picks one for you based on how you build:

| Entrypoint | Chosen by | What it does |
| --- | --- | --- |
| `lib/main.self.dart` | `ruflet build <target> --self` | Starts an embedded Ruby VM, extracts your project from the app's assets, and runs it locally. No server. |
| `lib/main.server.dart` | `ruflet build <target>` | Connects to a Ruby backend and renders what it sends. Takes the server URL from the launcher's argument, or resolves the origin it was served from on web. |
| `lib/main.dart` | development | The connection client used while iterating. |

Mobile apps are normally built `--self` so they run standalone. Desktop and web
clients are server-driven: they are told which server to open at launch, so no
address is baked in.

## Bundled extensions

`flet_packages/` carries the Flet Flutter extension packages a Ruflet app can
switch on from `ruflet.yaml`:

`flet` · `flet_ads` · `flet_audio` · `flet_audio_recorder` · `flet_camera` ·
`flet_charts` · `flet_code_editor` · `flet_color_pickers` · `flet_datatable2` ·
`flet_flashlight` · `flet_geolocator` · `flet_lottie` · `flet_map` ·
`flet_permission_handler` · `flet_rive` · `flet_secure_storage` · `flet_spinkit` ·
`flet_video` · `flet_webview` · `ruflet_qrcode_scanner`

Listing an extension in `ruflet.yaml` adds its package and registration to the
generated client. Leaving it out strips both, so an app only carries what it uses.

```yaml
extensions:
  - charts
  - map
  - qrcode_scanner
```

`ruflet_qrcode_scanner` is first-party and shows the pattern: an ordinary Flet
extension package, backed by `mobile_scanner`, exposed to Ruby as
`qrcode_scanner(...)`.

## How the CLI finds this repository

In order:

1. `RUFLET_TEMPLATE_ROOT`, if set
2. a `ruflet-template` checkout beside the `ruflet` repository
3. the cache in `~/.ruflet/templates`, cloned from here on first use

Set `RUFLET_TEMPLATE_ROOT` when working on the template itself, or in CI, so the
build uses your checkout instead of the cached copy.

```bash
RUFLET_TEMPLATE_ROOT=/path/to/ruflet-template ruflet build macos
```

## Working on the template

Changes here reach every Ruflet app, so treat it as shared ground. Delete the
cache after editing, or the CLI will keep using the copy it already has:

```bash
rm -rf ~/.ruflet/templates/ruflet_flutter_template
```

The extension packages are normal Flutter packages and are tested as such:

```bash
cd templates/ruflet_flutter_template/flet_packages/ruflet_qrcode_scanner
flutter test
```

## Credit

The rendering engine and wire protocol are [Flet](https://github.com/flet-dev/flet)'s
work — which is why a Flet extension package drops in here unchanged. Ruflet would
not exist without it.

## License

Distributed as part of [Ruflet](https://github.com/AdamMusa/ruflet), under its
MIT license. The bundled `flet_packages/` keep the licenses of their upstream
projects.
