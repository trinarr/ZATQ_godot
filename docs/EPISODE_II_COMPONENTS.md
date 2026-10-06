# Episode II: Flash components

All 122 runtime screens use separate artwork, native text/dimmers, pause and interactive controls. Backgrounds are reconstructed from original XFL leaf display lists, including loaded photographs and authored frame/override selection. Empty final animation frames intentionally remain black.

`data/episode2_components.json` contains 76 named groups. `data/episode2_brushes.json` contains shader button geometry. Shared textures are trimmed, lossless PNG and deduplicated by RGBA pixel hash, including reuse of Episode I resources. Original cropped alpha masks remain for the two arrow branches.

Pickup backdrops also use components. Result panels and decision templates reuse Episode I groups. Scene IDs, graph links, translations and save data are unchanged.

## Rebuild

Run `python tools/build_episode2_components.py original.zip`, or the existing `build_episode2_content.py` entry point. The localized UI exporter skips migrated composites. Replaced episode images and unused historical exports are removed; live hit masks are retained.

## Validation

`episode2_components_test.py` checks complete screen coverage, texture hashes, native panels, cross-episode reuse and cleanup. `episode2_components_test.gd` exercises every screen with three ammunition/companion states. Existing episode route, save, UI and regression checks remain applicable.

Apply this incremental patch after `zombie_episode1_components_fixed.zip` (which follows `zombie_menu_components.patch`). Let Godot import the resources before rebuilding APK.
