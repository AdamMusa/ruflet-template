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
```

`--self` packages the Ruby runtime and application with the native client.
Without it, the client connects to a separately running Ruflet backend.

Linux WebView builds require WebKitGTK 4.1 development files. On Debian or
Ubuntu install them with `sudo apt install libwebkit2gtk-4.1-dev`.

## Conditional extensions and services

The Flutter packages under `flet_packages/` are the local source catalog for
this template. During a build, the Ruflet CLI keeps the core `flet` package and
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
Ruflet also replaces its Android permissions and iOS usage descriptions from
the current `services:` declarations, rather than retaining template defaults
or permissions from an earlier build.
