# ruflet_local_auth

Biometric and device-credential authentication for Ruflet apps, backed by the
[`local_auth`](https://pub.dev/packages/local_auth) plugin. It is a standard
Ruflet Flutter extension: the public library exports `Extension`, and
`createService()` handles the `LocalAuthentication` service type, mirroring
Flet's `flet-local-auth`.

## Use from Ruby

Declare the capability, which selects this package for the generated client:

```yaml
# services.yaml
services:
  - biometrics:
      description: Unlock your notes with Face ID.
```

`extensions: [local_auth]` in `ruflet.yaml` works too and uses a default
Face ID description.

```ruby
page.local_auth.authenticate(
  localized_reason: "Unlock your notes",
  on_result: ->(ok, error) { page.update(status, value: error || (ok ? "Unlocked" : "Try again")) }
)
```

## Invoke methods

| Method | Args | Result |
| --- | --- | --- |
| `authenticate` | `localized_reason` (required, non-blank; Flet's `reason` is accepted), `biometric_only` (`false`), `sensitive_transaction` (`true`), `persist_across_backgrounding` (`false`), `android_messages` (`sign_in_title`, `sign_in_hint`, `cancel_button`), `ios_messages` / `macos_messages` (`cancel_button`, `localized_fallback_title`) | `true` on success, `false` when the user failed the challenge |
| `can_check_biometrics` | none | `bool` |
| `is_device_supported` | none | `bool` |
| `get_available_biometrics` | none | list of `face`, `fingerprint`, `iris`, `strong`, `weak` |
| `stop_authentication` | none | `bool` |

Failures reach Ruby as the invoke's error:

```text
LocalAuthentication.authenticate failed [user_canceled]: The user canceled authentication.
```

The bracketed code is the snake_case `LocalAuthExceptionCode` name
(`user_canceled`, `no_biometrics_enrolled`, `temporary_lockout`, ...) or a
`PlatformException` code as the platform reported it. A missing reason is an
`ArgumentError` that never reaches the platform, and an unknown method fails at
once. On Linux and the web, which local_auth does not implement, the service
registers no handler, so every invoke fails fast with the core's
`UnsupportedError`.

## Platform setup

- iOS: `NSFaceIDUsageDescription` in `Info.plist`. The Ruflet CLI writes it
  from the `biometrics` service description.
- Android: the activity must be a `FragmentActivity`; the Ruflet CLI makes the
  generated client's `MainActivity` extend `FlutterFragmentActivity` while
  this extension is selected. `USE_BIOMETRIC` comes from the plugin's manifest.
- macOS and Windows need no extra configuration.

## Development

```sh
flutter analyze
flutter test
```

Tests replace `LocalAuthPlatform.instance` with a Dart fake, so no platform
channel is used.
