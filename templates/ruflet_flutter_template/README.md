# Ruflet Flutter Template

This template is used by the Ruflet build pipeline to produce self-contained or
server-driven Flutter clients.

## Entry Points

- `lib/main.self.dart` starts the embedded Ruby runtime and bundled `assets/main.rb`.
- `lib/main.server.dart` connects to an external Ruflet backend.
- `RUFLET_BACKEND_URL` overrides the backend URL for a server-driven client.

Run the template directly while developing the build pipeline:

```bash
flutter pub get
flutter run -t lib/main.self.dart
flutter run -t lib/main.server.dart \
  --dart-define=RUFLET_BACKEND_URL=http://127.0.0.1:8550
```

Application developers normally build through the Ruflet CLI:

```bash
bundle exec ruflet build apk --self
bundle exec ruflet build ios --self
bundle exec ruflet build apk
bundle exec ruflet build ios
bundle exec ruflet build ios --experimental
bundle exec ruflet build macos --experimental
```

`--self` packages the Ruby runtime and application with the native client.
Without it, the client connects to a separately running Ruflet backend.
`--experimental` is retained for compatibility with existing Apple build
scripts. It uses the same Ruflet Flutter renderer as an ordinary build and does
not add a Swift rendering engine.

Linux WebView builds require WebKitGTK 4.1 development files. On Debian or
Ubuntu install them with `sudo apt install libwebkit2gtk-4.1-dev`.

## Bootstrap hooks

`lib/main.self.dart` and `lib/main.server.dart` run two ordered startup hook
lists: `rufletPreRunAppHooks` are awaited one at a time just before `runApp`,
and `rufletPostFirstFrameHooks` run after the first frame. A hook that throws is
reported through `FlutterError.reportError` and the app still starts.

Both entrypoints declare the two lists empty, between the
`// --RUFLET_BOOTSTRAP_HOOKS_START--` and `// --RUFLET_BOOTSTRAP_HOOKS_END--`
markers, and import nothing the template does not ship. With empty lists they
skip the hooks entirely, so they build with every ruflet gem, including the
released ones that refresh `lib/main*.dart` in an existing client file by file.

Build features add hooks in the ruflet gem (`Ruflet::CLI::ClientBootstrap`),
never in `lib/main*.dart`. Only while a feature adds hooks does `ruflet build`
write them to `lib/ruflet_bootstrap.g.dart`, import that file and empty the
marked block. Do not add that file to this template.
`tool/conformance/test_bootstrap_hooks_contract.rb` pins the markers, the empty
lists and the hook points.

## Conditional extensions and services

The Flutter packages under `ruflet_packages/` are the local source catalog for
this template. During a build, the Ruflet CLI keeps the core `ruflet` package and
only the optional packages and registrations declared by the developer
application:

```yaml
# ruflet.yaml
extensions:
  - charts
  - map
  - rive
```

Native capabilities and their permission descriptions are declared separately:

```yaml
# services.yaml
services:
  - microphone:
      description: Record voice notes.
  - location:
      description: Show the current location.
```

The same selection rules apply to self-contained and server-driven clients.
Ruflet also replaces its Android permissions, iOS/macOS usage descriptions,
and macOS sandbox service entitlements from
the current `services:` declarations, rather than retaining template defaults
or permissions from an earlier build.
