# Shared eye closure (episodes I–III)

Apply `zombie_shared_eye_closure.patch` after `zombie_episode1_eye_closure_fix.patch`.

## Source audit

The original Bitmap 323 is used by the upper/lower eyelid symbols 327/325.
Their five active callers in the first three Godot episodes are:

| Episode | Scene | Original clip | Motion |
| --- | --- | --- | --- |
| I | `ep1_mainstreet_attack` | 2544 | Close, frames 19–33 |
| III | `e3_opening_4` | 1898 | Open, frames 0–14 |
| III | `e3_opening_16` | 1997 | Close, frames 0–12 |
| III | `e3_north_5` | 1754 | Close, frames 0–12 |
| III | `e3_north_11` | 1783 | Open, frames 0–14 |

Episode II has no instances of these source eyelids. A sixth source clip, 334,
is referenced by `WakeUpNoLeg` (412), outside the current first-three-episode
scene plans. The first episode's opening wake-up scene uses a photograph alpha
fade (2795), not that eyelid clip; its existing fade remains intact.

## Runtime

`EyeClosure` (`scripts/ui/eye_closure.gd`) owns two lids sharing one PNG:
`assets/flash_ui/shared_components/eye_lid.png`. The lower lid flips the same
texture vertically. Full off-stage pixels are retained. One copied opaque row
and copied side columns extend the original bounds to cover fractional and
one-pixel offsets at fully closed poses, without moving the soft edges.

`EpisodeTimeline` feeds the original authored matrices, colors and visibility to
this component. The component has no independent clock during MovieClip playback;
seeking, pause and the original 19 fps positions keep their existing behavior.

Blur progression is scene metadata (`eye_blur.frames`, `eye_blur.closing`), not a
hard-coded scene name in the timeline. The first episode's cached blur still
increases during closure. In III, prepared blurred bitmaps 1776/1891 are replaced
with sharp 1781/1893 and a cached blur with sigma 2.5 px. Blur fades to zero over
opening frames 0–14. Both authored background slots bind the same sharp/blur
pair so their replacement cannot cause a jump. The 2.5 px sigma approximates
these graphics-editor images; it is not a pixel-exact recreation of their baked
quantization. The hand-to-zombie and grille-to-black image changes in the other
two scenes remain authored content, not mistaken blur variants.

Unused eyelid crops and the two retired blurred animation exports are removed.
Other referenced art remains available.

## New scene without a MovieClip

Coordinates match the project's 1600×960 stage; scale the parent for another size.

```gdscript
const EYE_CLOSURE = preload("res://scripts/ui/eye_closure.gd")
var eyes = EYE_CLOSURE.new()
add_child(eyes) # Add above scene art, below UI that should remain visible.
eyes.configure_default()
eyes.set_closure(0.0) # 0 = open; 1 = closed.
eyes.animate_closure(1.0, 0.7)
await eyes.finished
eyes.animate_closure(0.0, 0.7)
```

`set_closure()` can also be driven by a scene's own AnimationPlayer. It does not
create a blur target: use the existing `BlurTextureCache` for a background and
set its material's `blur_strength` to the same closure value. Reuse the same
material through an opening/closing sequence; no per-frame blur calculation.

Exporters recognize the source eyelid symbols and produce the native shared
parts automatically. `tools/migrate_eye_closure.py LIBRARY` updates existing
catalogs without changing their authored frame rows.

## Validation

`tools/eye_closure_components_test.gd` checks all five callers, screen-edge
coverage, shared texture identity, both blur directions, held final poses and
standalone animation. Existing episode tests and XFL pose/color/caption comparisons
also pass. Compatibility/OpenGL renders were inspected at opening/intermediate/
closed poses. Android rendering was not run in this environment.
