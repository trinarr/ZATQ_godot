# Runtime optimization of Episodes I–III

Incremental change after `zombie_episode123_hotspot_frame_fit.patch` (local baseline `1645a9b`).

## Changes

- `EpisodeTimeline` applies transforms, visibility, color transforms, child order and caption tracks once per authored MovieClip frame/phase. Blur strength still updates at rendering frequency. Restarting a phase invalidates the pose; newly attached captions are initialized immediately. Caption anchor inverses are calculated once on binding.
- `ShaderText` no longer polls in `_process`. Geometry, theme, translation, visibility, draw and tree events schedule shadow synchronization. Plain `label.text = ...` and the shadow offset setter remain supported. Shader shadows retain the same glyph layout and shared material.
- `NarrativeBlock` owns the original label and optional black band. `NarrativeLayer` reuses blocks between screens. Opening narration, city descriptions, multi-block narration and activity descriptions use this component. Labels/bands remain siblings in their original screen/world coordinate spaces so Flash tracks retain their original pivots. Font fitting has a bounded 256-entry cache, including text, font, bounds and fitting rules.
- Main retains the screen and world-interaction containers. Disposable scene art, activities, controls and popups still leave the tree at every normal transition. Persistent caption and pause nodes are parked outside the visible screen, then reused. Animation and death-pause locks reset on transition; modal input guards remain active. Item/result overlays retain their origin screen as before.
- The pause button atlas and alpha bounds are calculated once. Decompressed raster hit masks are also reused; dynamic highlight masks already had their own cache.
- `Quest.current()` has a bounded 16-node localized view cache. Locale/translation notifications, flag changes and source-node changes invalidate views. Presentation consumers treat views as read-only. Duplicate result lookups and repeated set/add lookups are reduced.
- Unchanged save snapshots do not rewrite the same save paths. Changed snapshots retain the existing temporary-file/flush/backup/rename transaction. Activity initialization saves once after all QTE fields have been initialized. Essential state changes remain synchronous; this change does not defer progress writes to a future timer.
- Episode-wide blur prewarming is removed. Only used scene parts request a one-shot bake. The four-entry blur cache evicts least-recently-used completed targets that have no living bound material; active scenes may temporarily exceed this budget. A returned sharp fallback remains valid while baking. An evicted blur may be baked again on a later revisit.
- Nearby scene texture paths are requested in the background. At most four loader tasks and twelve retained textures are allowed; the retention estimate is capped at 16 MiB of RGBA pixels. Existing scene loading remains the fallback. The dummy headless renderer bypasses texture prefetch. At teardown, task handles are collected and released.

## Verification

`tools/runtime_optimization_test.gd` verifies shell/pause/text identity across actual story transitions, modal guards, idle and text-only shadow updates, same-frame pose reuse with continuous blur, view invalidation, atomic save reload, single complete QTE initialization save and safe blur-cache eviction. It passes 45 checks under both headless and OpenGL rendering.

OpenGL blur pixel checks pass: 18 checks, including retained pixels, one-shot rendering, sharp fallback, intermediate fade and exact sharp endpoint. The OpenGL modal/shadow regression passes 22 checks.

Regression coverage includes original animation poses in all three episodes, eye closure, lift doors, death-pause policy, component screens, localized captions, QTE routes, world/hitbox alignment and item/result overlays. Tests run on Godot 4.6.1; the project declares Godot 4.7.

Some older tests already fail unchanged on baseline: `pause_menu_test.gd` sends only a mouse press although dismissal now requires a full gesture; `item_popup_test.gd` expects superseded description coordinates; `story_graph_test.gd` compares legacy node data predating animation/pause updates (33 mismatches); `city_routes_test.gd` times out on baseline as well. These existing assertions/data were not changed by this patch.

No Android FPS claim is made. Headless tests validate behavior and operation counts, while OpenGL tests validate rendered resources. Device profiling is still needed to quantify frame-time and memory improvements.
