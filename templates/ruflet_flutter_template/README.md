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

Both entrypoints run the ordered hook lists in `lib/ruflet_bootstrap.g.dart`:
`rufletPreRunAppHooks` are awaited one at a time just before `runApp`, and
`rufletPostFirstFrameHooks` run after the first frame. A hook that throws is
reported through `FlutterError.reportError` and the app still starts.

`ruflet build` rewrites that file on every build (`Ruflet::CLI::ClientBootstrap`
in the ruflet gem); build features add their hooks there, never in
`lib/main*.dart`. The copy in this template is exactly what the CLI writes when
no feature adds a hook, and with both lists empty the entrypoints skip the hooks
entirely. Keep the two in step:
`tool/conformance/test_bootstrap_hooks_contract.rb` pins the shipped file and
the hook points.

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
