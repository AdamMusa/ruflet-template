# Cupertino code editor renderer

The UI files here are a renderer fork of `flutter_code_editor` 0.3.5,
distributed under its Apache-2.0 license in LICENSE. They retain the pinned upstream
controller, highlighting, folding, search and autocomplete algorithms. The
upstream Material field remains the Material renderer.

The Cupertino fork uses CupertinoTextField for editing, Cupertino buttons for
search options and navigation, plain gesture handling for completion rows, and
Cupertino colors for overlays. It does not mount Material, Theme, TextField,
InkWell or ToggleButtons widgets. Imports of upstream controller implementation
libraries intentionally match the pinned dependency; upgrading it requires
running the renderer interaction tests, including search and completion overlays.
