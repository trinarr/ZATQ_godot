# Dynamic UI decorations

`data/ui_decorations.json` holds the original torn contours and feathered alpha
bands for the popup strips, Episode I answers, John square button, four pause
shadows and main menu backplates. `vector_decoration.gd` rasterizes each shape
once using Godot's SVG renderer and shares the generated texture across instances.
The decorations ignore mouse input. Authored coordinates and timeline transforms
remain unchanged. No PNG files or per-frame blur passes are required for them.

Episode III's red `e3_opening_8` and black `e3_kill_6` vignettes use
`soft_vignette.gd`, including static fallback frames. Episode VI now also uses
that component for the shared Episode V vignette whose PNG had already been
removed. MovieClip animation still controls opacity.

After component/animation export, `python3 tools/build_ui_decorations.py`
converts the reviewed shapes and retires their PNGs. It is idempotent and uses
existing definitions when original textures are no longer available. The
component and animation exporters invoke it automatically.

Resource audit: `python3 tools/audit_resources.py` covers all episode animation
catalogs, graph art, dynamic highlight masks, shared keypad sounds and John fonts.
Locale audit: `python3 tools/audit_unused_locales.py` reports unused rows;
`--remove` removes them. Editable migration data remains a localization root.

This cleanup removes 41 PNGs and their import sidecars, and 15 unused locale rows.
PNG source files decrease by 25,076,897 bytes; contour data adds 575,018 bytes.
The net artwork reduction is approximately 23.37 MiB. This is a source-resource
measurement, not an APK size or device-memory benchmark.
