# PNG source materials

All 501 component textures use PNG. Conversion preserves decoded RGBA pixels exactly; transparent images keep their alpha channel. Source texture import UIDs and settings are retained. Story graphs, animation references, component manifests, runtime fallbacks, editor filters and exporters now use PNG.

The component exporters create trimmed, deduplicated PNG parts. No source WebP files or obsolete WebP import metadata remain. `convert_webp_to_png.py` is a reusable migration helper with atomic writes, pixel comparison and collision checks.

Apply this incremental patch after `zombie_episode3_components.patch`. Let Godot finish importing resources before rebuilding the APK. Scene IDs and save format remain unchanged.
