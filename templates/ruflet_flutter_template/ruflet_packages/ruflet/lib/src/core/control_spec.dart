/// The declared contract of one Ruflet control: every key Ruby can send,
/// every event Ruby can subscribe to and every method Ruby can invoke, and
/// which native skins must honor each of them.
///
/// Pure data on purpose: the contract test (`test/architecture/
/// control_core_contract_test.dart`) compares it with Ruby's KEYWORDS and
/// scans the skins against it, and [ControlSpec.toJson] keeps it reusable by
/// other renderers.
library;

import 'package:flutter/foundation.dart';

/// A native design language that renders a control.
enum Skin { material, cupertino }

/// The default for [PropSpec.skins] and [EventSpec.skins].
const Set<Skin> kBothSkins = {Skin.material, Skin.cupertino};

/// How a wire value is parsed. Drives the `PropReader` call that reads the key
/// and the sample value the contract test sends for it.
enum PropType {
  boolean,
  integer,
  number,
  string,
  color,
  stateColor,
  stateNumber,
  stateIcon,
  stateBorderSide,
  textStyle,
  edgeInsets,
  borderRadius,
  outlinedBorder,
  alignment,
  duration,
  animation,
  enumName,
  icon,
  image,
  mouseCursor,
  widget,
  textOrWidget,
  iconOrWidget,
  widgets,
  raw,
}

/// Who turns a parsed prop into widgets.
enum PropConsumer {
  /// Every skin in [PropSpec.skins] passes the value to its native widget.
  skins,

  /// The shared core applies it for both designs (label composition,
  /// scale-to-fit...); skins never reference it.
  core,
}

/// Who fires an event.
enum EventSource {
  /// Fired by core code only (value commits, focus/blur, hover, lifecycle),
  /// so the designs cannot drift.
  core,

  /// Originates in a native gesture (tap, long press inside an ink well or a
  /// Cupertino tile). The core exposes a callback getter named
  /// [EventSpec.field] and every skin in [EventSpec.skins] must wire it.
  skin,
}

/// How the core host applies the common Ruby layout keywords.
enum LayoutWrap {
  /// `LayoutControl`: size, position, transforms, margin, badge, tooltip...
  layout,

  /// `BaseControl`: opacity, tooltip, rtl and expand only.
  base,

  /// Nothing; the control has no common layout keywords.
  none,
}

@immutable
class PropSpec {
  const PropSpec(this.key, this.type, this.field,
      {this.skins = kBothSkins,
      this.reason,
      this.consumer = PropConsumer.skins});

  /// The Ruby keyword, exact spelling. It is also the wire key.
  final String key;
  final PropType type;

  /// The getter on the control's props class that carries the parsed value.
  final String field;

  /// The skins that must consume [field].
  final Set<Skin> skins;

  /// Why only some skins consume it. Required when [skins] is not both.
  final String? reason;

  /// Whether the skins or the shared core consume [field]. Declared, not
  /// inferred: the contract test checks the core really references it and
  /// that no skin does.
  final PropConsumer consumer;

  Map<String, Object?> toJson() => {
        'key': key,
        'type': type.name,
        'field': field,
        'skins': _skinNames(skins),
        if (reason != null) 'reason': reason,
        if (consumer == PropConsumer.core) 'consumer': 'core',
      };
}

@immutable
class EventSpec {
  const EventSpec(this.name,
      {this.source = EventSource.skin,
      this.field,
      this.skins = kBothSkins,
      this.reason,
      this.whileDisabled = false});

  /// The wire event name; Ruby subscribes with `on_<name>`.
  final String name;
  final EventSource source;

  /// The core callback getter that skins wire ([EventSource.skin] only).
  final String? field;
  final Set<Skin> skins;
  final String? reason;

  /// Whether the event still fires while the control is disabled.
  final bool whileDisabled;

  Map<String, Object?> toJson() => {
        'name': name,
        'source': source.name,
        if (field != null) 'field': field,
        'skins': _skinNames(skins),
        if (reason != null) 'reason': reason,
        if (whileDisabled) 'while_disabled': true,
      };
}

@immutable
class MethodSpec {
  const MethodSpec(this.name, {this.args = const [], this.port = false});

  /// The method name Ruby passes to `page.invoke(control, name, ...)`.
  final String name;
  final List<String> args;

  /// Implemented by a skin through a port interface (a native controller).
  final bool port;

  Map<String, Object?> toJson() => {
        'name': name,
        if (args.isNotEmpty) 'args': args,
        if (port) 'port': true,
      };
}

@immutable
class ControlSpec {
  const ControlSpec({
    required this.wireType,
    required this.props,
    this.events = const [],
    this.methods = const [],
    this.layout = LayoutWrap.layout,
    this.ownedLayoutKeys = const {},
    this.sharedLayoutKeys = const {},
    this.children = const {},
  });

  final String wireType;
  final List<PropSpec> props;
  final List<EventSpec> events;
  final List<MethodSpec> methods;
  final LayoutWrap layout;

  /// Common layout keys the core applies itself instead of the layout
  /// wrapper (declared in [props]); the wrapper skips them.
  final Set<String> ownedLayoutKeys;

  /// Common layout keys the core also reads for its own logic (declared in
  /// [props]) while the layout wrapper still applies them, e.g. a toggle that
  /// scales its native widget to the `width`/`height` the wrapper sizes.
  final Set<String> sharedLayoutKeys;

  /// Typed child lists: slot name to the child type's spec.
  final Map<String, ControlSpec> children;

  PropSpec? prop(String key) {
    for (final prop in props) {
      if (prop.key == key) return prop;
    }
    return null;
  }

  EventSpec? event(String name) {
    for (final event in events) {
      if (event.name == name) return event;
    }
    return null;
  }

  bool declaresMethod(String name) => methods.any((m) => m.name == name);

  Map<String, Object?> toJson() => {
        'wire_type': wireType,
        'layout': layout.name,
        'props': [for (final prop in props) prop.toJson()],
        'events': [for (final event in events) event.toJson()],
        'methods': [for (final method in methods) method.toJson()],
        if (ownedLayoutKeys.isNotEmpty)
          'owned_layout_keys': ownedLayoutKeys.toList()..sort(),
        if (sharedLayoutKeys.isNotEmpty)
          'shared_layout_keys': sharedLayoutKeys.toList()..sort(),
        if (children.isNotEmpty)
          'children': {
            for (final entry in children.entries)
              entry.key: entry.value.toJson()
          },
      };
}

List<String> _skinNames(Set<Skin> skins) => [
      for (final skin in Skin.values)
        if (skins.contains(skin)) skin.name
    ];
