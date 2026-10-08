# Animation raster viewports

The Flash document runs at 19 fps on an 800 × 480 stage. Previously each
animated primitive was rasterized through that stage-sized export viewport.
Moving or zooming the cropped raster then exposed missing pixels. In particular,
`ep1_dorvud_street` moved an 800-pixel crop by −615 pixels, although its original
`ZombieDorvudOverlook.jpg` is 1415 × 480.

`animation_viewport.py` computes the pixels needed across the primitive's source
poses, including intro, outro and variable-controlled tracks. It maps the stage
back into reference-pose coordinates and intersects it with source geometry.
The exporter retains that overscan at the existing 2× pixel scale. Playback
matrices, colors, frame counts, story variables and the 19 fps rate are unchanged.
The adaptive canvas clips animated scenery to its 1600 × 960 Flash frame, after
fitting it to the device. World controls are outside this visual clip. Static
components retain their existing clipping behavior.

## Audit

All 479 exported animated scenes in episodes 1–6 and John were examined against
their original source display lists. This includes 593 ordinary texture parts;
panels already have full rectangles, and shared eyelids/highlights have their
own geometry. 35 cropped primitives in 32 scenes were repaired. Some fixes
restore only 0.5–2 pixels lost at moving edges. Major overscan examples include
the Episode I Dorvud panorama, Episode III creature reveal, Episode V aircraft
panorama (all four variants), and John's laboratory/chase scenes.

| Episode | Scenes checked | Texture parts checked | Parts repaired |
| --- | ---: | ---: | ---: |
| 1 | 68 | 104 | 3 |
| 2 | 33 | 61 | 5 |
| 3 | 72 | 87 | 8 |
| 4 | 93 | 96 | 5 |
| 5 | 103 | 110 | 4 |
| 6 | 88 | 100 | 5 |
| John | 22 | 35 | 5 |

`animation_viewport_audit.json` records every replaced rect/texture and its source.
Replaced crops were deleted only if no live catalog or code still referenced
them. Shared static crops remain where used. The repair uses the original game
archive and, for John, a fresh JPEXS export of the playable SWF with symbol IDs
normalized by the existing John importer, rather than the stale bundled XFL.

## Reproduction

```sh
python tools/repair_animation_viewports.py ORIGINAL.zip --episodes 1 2 3 4 5 6
python tools/repair_animation_viewports.py ORIGINAL.zip --check
PYTHONPATH=tools python -m unittest tools/test_animation_viewport.py
godot --headless --path . --script tools/panorama_test.gd
godot --headless --path . --script tools/safe_area_test.gd
```

The repair changes only texture paths and reference rectangles in existing
catalogs, preserving later changes to timeline tracks and part metadata. For
John, use the normalized archive returned by `build_john_episode.prepare` and
`--episodes 101`. The regular animation exporters also retain overscan, so a
subsequent content rebuild does not reintroduce the crop.
