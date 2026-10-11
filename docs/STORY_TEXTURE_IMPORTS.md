# Story texture import settings

Large opaque story textures in `assets/flash_ui/episode*_components` and
`episode*_animation_parts` use Godot Lossy compression at quality 0.85,
without mipmaps. Source files remain PNG; Godot stores the imported texture
using lossy WebP compression. This reduces build storage, not GPU memory.

Transparent layers, small sprites, shared UI, dialog/item panels, masks and
eye lids are excluded. Dimensions, import UIDs, animation geometry, project
renderer and Android architectures remain unchanged. No global Lossy default
is set because it would also affect newly imported UI and mask resources.

Author normal full-screen art at 1600 x 960. Panoramas and zoomed art may need
larger dimensions; do not force a size limit on them. A maximum-size import
limit is deliberately not applied by this patch.

After replacing/exporting story PNGs, run:

```bash
python tools/configure_story_texture_imports.py
python tools/configure_story_texture_imports.py --check
```

Pillow is required. If new textures have no `.import` file, open the project
in Godot first, then rerun the command. Reopen/refocus Godot afterwards and
wait for texture reimport before exporting Android.

The script is conservative: it processes only opaque images at least
640 x 360 in the named story folders and leaves other import options intact.
Inspect dark gradients, fine branches and water at game scale before release;
raise quality or restore Lossless for individual images if needed. Compare
release APK sizes using the same export configuration. No APK size reduction
is claimed without performing an export.
