import 'package:flutter/widgets.dart';

import '../models/control.dart';
import 'enums.dart';
import 'misc.dart';
import 'numbers.dart';

/// Layout of a Ruby `list_section`, shared by the Material and Cupertino
/// renderers. `insetGrouped` is the Ruflet default (rounded rows inset from
/// the screen edges, like iOS Settings); `base` is edge to edge.
enum ListSectionVariant { base, insetGrouped }

ListSectionVariant parseListSectionVariant(String? value,
    [ListSectionVariant defaultValue = ListSectionVariant.insetGrouped]) {
  return parseEnum(
      ListSectionVariant.values, value?.replaceAll("_", ""), defaultValue)!;
}

extension ListSectionParsers on Control {
  ListSectionVariant getListSectionVariant(String propertyName) =>
      parseListSectionVariant(getString(propertyName));

  /// Ruby may send `anti_alias` or `antiAlias`.
  Clip? getSectionClipBehavior(String propertyName, [Clip? defaultValue]) =>
      parseClip(getString(propertyName)?.replaceAll("_", ""), defaultValue);
}
