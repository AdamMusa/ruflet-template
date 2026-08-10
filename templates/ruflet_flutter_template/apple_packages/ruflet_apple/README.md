# RufletApple

A native Ruflet engine for iOS and macOS, written in Swift.

It is a peer of the Flutter engine, not a layer on top of it: it speaks the same
Ruflet wire protocol over the same socket, so the same Ruby application runs
against either without renderer-specific flags or platform-specific code.

```
Ruby app
   ↓
Ruflet runtime
   ↓
Ruflet protocol  (MessagePack over ws://…/ws)
   ↓
┌──────────────────┬──────────────────────┐
Flet engine        Ruflet Apple engine
Flutter            Swift · SwiftUI
other platforms    iOS + macOS
```

No Flutter, no native extensions, no embedding native controls inside Flutter.

## Which engine renders what

The two engines are peers, and the choice is made by the platform, not by the
application: iOS and macOS render through this Swift package, and Android, web,
Linux and Windows render through the Flutter (Flet) engine, which is the only
one that reaches them.

Nothing in Ruby changes for either. The split lives in the app shell — an
`ios/` or `macos/` runner hosting `RufletAppView`, while the other platforms
keep their Flutter runner — so it is settled at compile time by which runner is
being built, with no flag to set and no branch to take at runtime.

## Using it

```swift
import RufletApple
import SwiftUI

@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      // Boots the mruby VM from the Ruby project in the app bundle, then
      // connects to the port it publishes.
      RufletAppView()
    }
  }
}
```

An app that uses sensors, location or the camera links those modules and names
them:

```swift
import RufletApple
import RufletMedia
import RufletMotion

RufletAppView(services: [RufletMedia.self, RufletMotion.self])
```

That is the whole template app. Three other entry points exist:

```swift
// Attach to a `ruflet run` server during development.
RufletAppView(serverURL: URL(string: "ws://127.0.0.1:8550/ws")!)

// Name the packaged project explicitly.
RufletAppView(embeddedProject: .init(projectRoot: path))

// Drive the session yourself and render into your own hierarchy.
let session = RufletSession(serverURL: url)
ControlView(id: RufletWireID.page, axis: .vertical)
  .environmentObject(session.store)
  .environment(\.rufletEvents, .connected(to: session))
```

### The embedded VM

VM startup stays on the native side, exactly as it is for the Flutter engine.
`EmbeddedRuntime` calls the same four `ruflet_vm_*` entry points from
`ruby_runtime/desktop/ruflet_vm_host.h` and waits for the runtime to publish its
port into `RUFLET_RUNTIME_PORT_FILE`.

The symbols are resolved with `dlsym` rather than linked, because the VM ships
as an XCFramework on iOS and a static archive on macOS. Link whichever your
target needs:

| Platform | Link |
|----------|------|
| iOS | `ruby_runtime/ios/Frameworks/RufletVM.xcframework` |
| macOS | `ruby_runtime/macos/Frameworks/libruflet_vm.a` |

The package itself stays a pure Swift package that builds anywhere. If nothing
is linked, `RufletAppView` says so on screen instead of showing a blank window.

Package the Ruby project as a bundle resource — the directory holding `main.rb`.
When a bundle carries more than one, name it in `Info.plist` under
`RufletEmbeddedProject`.

## Layout

| Target | What it is |
|--------|------------|
| `RufletProtocol` | `RufletValue`, the MessagePack codec, actions, frames, patches. No UI, no I/O. |
| `RufletEngine` | The control model, the store, the session, the transport, the embedded runtime, and every ungated service. |
| `RufletUI` | The SwiftUI renderer: `ControlRegistry`, `ControlView`, and one view per control. |
| `RufletApple` | Umbrella that re-exports the three above — what an app links. |
| `RufletMotion`, `RufletLocation`, `RufletMedia` | Optional service modules, linked on demand. |

### How the protocol becomes a tree

`ControlStore` keeps a flat `[Int: ControlNode]` keyed by wire id. Nested
controls are not stored inline: while materializing a patch the store replaces
each nested control map with a `.controlRef(id)`, so a parent's props hold ids.

That gives three things the renderer depends on:

- **Patch by id is O(1)** — which is how `Ruflet::Page` addresses every update.
- **Identity survives a re-send** — a full view patch replaces a node's props
  but not the node, so SwiftUI keeps scroll positions and focus.
- **Removal works** — nothing on the wire says "delete control 137"; a parent
  simply comes back with a shorter `controls` list, so the store sweeps from
  the page for reachability after every message.

### Events

```
SwiftUI  →  RufletEventSink  →  RufletSession  →  control_event  →  Ruby handler
```

A control reports an event only when Ruby declared a handler for it
(`Ruflet::Control` replaces the block with `on_click => true` on the wire), so
an unlistened gesture costs nothing.

Value-carrying controls write locally first and then report, so a `Switch`
tracks the finger while Ruby catches up. `Page#dispatch_event` applies the same
value to its own control before running the handler, so the two sides agree
without a second round trip — and if the handler decides otherwise, its patch
wins.

### Control methods

Ruflet controls carry imperative methods alongside their props: `video.play`,
`map.move_to`, `search_bar.focus`, `screenshot.capture`,
`interactive_viewer.zoom`. Those cannot be answered from the node — only the
mounted view owns the player, the map camera, the focus state — so a view
registers a handler on `ControlCommandBus` while it is on screen and drops it
on the way out.

The session tries services first, the bus second, and replies with a named
error when neither claims a call. A control that has been navigated away from
therefore fails cleanly instead of hanging a Ruby thread until its timeout.

### Services, and what your app links

All 24 of Ruflet's page services are implemented against the platform APIs, but
they are not all in the same module. Linking CoreMotion, CoreLocation or
AVFoundation capture is what makes iOS demand a usage string and what App Store
review flags — so an app that never asks Ruby for the camera should not carry
the camera code at all. What you do not link is not in the binary.

| Module | Services | Framework it pulls in |
|--------|----------|-----------------------|
| `RufletApple` (always) | clipboard, shared preferences, secure storage, storage paths, URL launcher, haptics, wakelock, semantics, battery, connectivity, permissions, screen brightness, file picker, share, page methods | none that Apple gates |
| `RufletMotion` | accelerometer, user accelerometer, gyroscope, magnetometer, barometer, shake detector | CoreMotion — `NSMotionUsageDescription` |
| `RufletLocation` | geolocator | CoreLocation — `NSLocationWhenInUseUsageDescription` |
| `RufletMedia` | audio, audio recorder, camera (and its preview control), flashlight | AVFoundation capture — `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` |

`PermissionHandler` stays in the core and asks whichever modules are linked, so
a permission nothing can answer reports `granted` — which is the truth for
anything the OS does not gate.

Asking Ruby for a service whose module is absent replies with the name of the
module to add, rather than a bare failure. Every `invoke_control_method` is
answered either way: `Page#invoke` blocks a Ruby thread on every call, so
silence would hang the application until its timeout.

Nothing here depends on Flutter. The package imports no Flutter module, links
no Flutter framework, and registers no Flutter plugin.

## Adding a control

One case in the right family plus its view:

```swift
// Sources/RufletUI/Families/DisplayFamily.swift
case "MyControl":
  return AnyView(MyControlView(node: node))
```

The shared property vocabulary (`visible`, `opacity`, `expand`, `tooltip`,
`padding`, `margin`, `rotate`, `scale`, `offset`, `disabled`, `rtl`, …) is
applied by `rufletCommon` around every control, so a new view implements only
what makes it that control.

A host can also register a type at runtime, mirroring Ruby's
`ControlFactory::EXTENSION_CLASS_MAP`:

```swift
ControlRegistry.register("MyExtension") { node, axis in AnyView(…) }
```

## Generated files

Two tables are generated from `ruflet_core` so they cannot drift:

```bash
ruby tools/generate_apple_icon_table.rb        # codepoint → Material icon name
ruby tools/generate_apple_coverage_fixture.rb  # every wire type, for the tests
```

Ruflet serializes icons as an index into the gem's `icons.json` rather than a
font codepoint, so the first table is what lets the engine recover a name and
map it to an SF Symbol.

## Testing

```bash
swift test
```

The suite covers the codec against byte fixtures captured from
`Ruflet::WireCodec`, the store's patch/update/removal semantics, the session's
five actions, renderer coverage for every wire type, and offscreen rendering.

`LiveRuntimeTests` starts a real `Ruflet::Server` and drives a full round trip —
handshake, view patch, event, handler patch. It skips itself when Ruby or the
sibling packages are unavailable.

The snapshot tests rasterise the tree and assert something was actually drawn.
That is deliberately weak as an assertion and strong as a smoke test: a
renderer can resolve every control type and still paint nothing. Set
`RUFLET_SNAPSHOT_DIR` to keep the images and look at them.

```bash
RUFLET_SNAPSHOT_DIR=/tmp/snaps swift test --filter Snapshot
```

Two caveats worth knowing before you read a snapshot: `Toggle` and `Slider` are
AppKit-backed and render as a yellow placeholder under `ImageRenderer` on macOS
— plain SwiftUI does the same, so it says nothing about the engine. And the
routing tests live on the Ruby side, in `packages/ruflet/test`.

## Requirements

iOS 15, macOS 12, Swift 5.9.
