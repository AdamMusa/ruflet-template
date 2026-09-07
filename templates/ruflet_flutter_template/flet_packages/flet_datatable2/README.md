# DataTable2 renderers

The existing `DataTable2` wire control selects a renderer using the page's
effective platform. Material keeps the pinned `data_table_2` implementation.
Cupertino owns a widget table with Cupertino checkboxes and scrollbars, with no
Material table, theme or ink widgets in its tree.

The Cupertino renderer supports fixed heading/data rows and left columns,
synchronized horizontal and vertical scrolling, column size ratios and explicit
widths, custom row heights, sorting, row selection and select-all, empty content,
row/cell gestures, keyboard activation, numeric alignment, edit indicators,
state colors, decorations, borders and checkbox styling. Cell tap, double-tap
and long-press events also trigger the corresponding subscribed row event, as
the upstream DataTable2 does.

Widget tests exercise the unchanged wire entrypoint on both platforms, event
payloads, pinned scrolling panes, empty content and native-only descendants.
