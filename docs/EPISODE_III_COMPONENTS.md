# Episode III: Flash components

All 131 runtime screens and every QTE timeline frame use the original XFL leaf display lists. `data/episode3_components.json` records textures, native ColorRects, stacking order and source paths. `data/episode3_brushes.json` records shader brush geometry. Bitmap parts use lossless WebP, are trimmed and deduplicated by RGBA pixel hash, including identical textures from Episodes I and II.

Native text, pause, dialogue choices, code entry, ammunition and pickup buttons remain independent controls. Animated QTE backgrounds now select component groups using the original `animation_frames` list at its original rate. Timer, hit windows, branch behavior and save state are unchanged. Black animation frames are represented by empty groups.

Replaced composites and unused historical exports are removed. Scene IDs, graph links, localization keys and save format are unchanged.

## Rebuild and validation

Run `python tools/build_episode3_components.py original.zip`. The content-generation and localized-UI exporters also use component output. The canonical graph is never overwritten by the component exporter.

Run `episode3_components_test.py` for screen/frame coverage, texture hashes, reuse and cleanup. `episode3_components_test.gd` exercises all screens with three inventory states and every QTE frame. Existing Episode III tests cover routes, dialogue, code, hit windows, pause/resume and saves.

Apply after the patch in `zombie_episode2_components.zip`. Godot must finish resource import before rebuilding the APK.
