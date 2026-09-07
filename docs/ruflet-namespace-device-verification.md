# Ruflet namespace: physical iPhone verification

Verified on 2026-09-07 with the local Ruflet Explorer application, Flutter 3.41.2,
and the paired iPhone 16 named Liveview. Application source was not changed.

## Build and installation

The template namespace feature is commit `5cbd01a`. The Ruflet CLI's local-package
validation is commit `f056ca7e`, and the Ruby DSL regression is `204f97ed`.

```sh
RUFLET_TEMPLATE_ROOT=/Users/macbookpro/Documents/Izeesoft/FlutterApp/ruflet-template \
  bundle exec ruflet build ios --self
```

The signed physical-device release built successfully and was installed and
launched as `com.izeesoft.rufletexplorer`. The user explicitly selected default
`--self` (mruby) for this rendering check after the full CRuby distribution was
found to be absent. This result is not a CRuby build or benchmark.

Pub's actual package configuration resolved the engine and all 17 selected
extensions under the generated client's `ruflet_packages/`. The CLI verified
21 local packages including the three transitive vendor forks. No `flet` or
`flet_*` package resolved. Unselected optional extensions were pruned.

The ordinary Flutter renderer was built. Experimental Apple builds now use this
same renderer and do not contain a separate Swift rendering engine.
Its platform policy selects Cupertino on iOS and Material on Android; this run
does not constitute an Android device test or visual verification of every screen.

## In-process transport

The packaged Apple autostart supplies `RUFLET_RUNTIME_TRANSPORT=in_process` and
returns `inprocess://embedded`. The Flutter self entrypoint selects
`RufletInProcessBackendChannel` with `sendToRuby`, `receiveFromRuby`, and
`closeBridge`. The native archive contains both the queue bridge and the Ruby
in-process connection implementation. The legacy method name `serverUrl()` is
not evidence of an HTTP or WebSocket listener.

No new runtime error file appeared after device launch. The data container still
contained a `server.port` file last modified on August 26, before this installation;
it was left untouched. No live socket census was performed, so this report does
not claim that application services or remote-content controls never use networking.

## Regression results

| Check | Result |
| --- | --- |
| Renamed engine | 593 tests passed; `lib` / `test` analysis has no issues |
| Eight renamed extension packages | 28 tests passed |
| Template package catalog and `RufletApp` dispatch | 2 tests passed |
| Namespace rewrite / source sync / integrity | 5 / 14 / 2 tests passed |
| Ruby `RufletApp` control | 8 tests passed, 17 assertions |
| Apple / cross-platform autostart contracts | 4 / 6 tests passed |
| Ruby in-process connection / transport selection | 6 / 2 tests passed |

`Ruflet.ruflet_app(...)` emits the `RufletApp` wire type and the renamed engine
dispatches it to `RufletAppControl`. This nested-app control is distinct from
the root `RufletApp` widget which hosts this self-contained application.

Existing unrelated native-host, Rails, server, and application edits were not
included in the feature commits. Those working-tree changes remain with their owner.
