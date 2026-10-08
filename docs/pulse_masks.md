# ECG masks

The affected scenes are `e2_hospital_4` and `john2_12`. Original XFL `Symbol
2335` and the freshly decompiled John's SWF `Symbol 10282` contain three mask
layers, each followed by its own masked waveform layer. The upper window is
rotated by approximately −1.95 degrees. The lower windows are axis aligned.
These layers are masks, not black overlays to be drawn on top of the monitor.

Previously the display-list exporter ignored `layerType="mask"` and
`parentLayerIndex`. Its flattened output painted mask rectangles and allowed
the moving waveform strips to escape the monitor. Pulse masks now retain their
original local geometry and full reference matrix as invisible `mask` parts.
Each strip references only its own mask. `flash_art_mask.gd` maps image UV into
mask space; the existing color/blur shader discards pixels outside the window.
The same transform handles rotation, parent motion and device scaling. No
additional mask PNG, offscreen viewport or per-frame blur is needed.

The original hospital animation stops at key 14 when the patient dies. John's
independent monitor MovieClip has a 32-frame loop with waveform layers present
for its first 15 keys, then a gap. Its exported 255-frame horizon previously
became a one-shot animation. Its source 32-frame cycle now continues after the
intro. Existing frame matrices, colors, captions and scene transitions remain
unchanged; only the mask metadata and John's `intro_loop` change.

The exporter hook uses the source mask geometry rather than the previously
rasterized axis-aligned bounding box, which would lose the upper window's
rotation. Shared static resources are retained where existing component catalogs
still reference them.

Validation: `tools/pulse_masks_test.gd` checks both scene catalogs and UV mapping,
the hospital stop, and John's playback beyond the export horizon. With an OpenGL
renderer it also checks transparent renders of isolated waveforms against the
original mask rectangles: curves stay visible inside and leave no pixels outside.

```sh
godot --headless --path . --script tools/pulse_masks_test.gd
godot --path . --rendering-method gl_compatibility --script tools/pulse_masks_test.gd
```
