# Episode I MovieClip playback

Apply `zombie_episode1_movieclip_animations.patch` after
`zombie_mainstreet_description_style.patch`.

Source: the supplied `air.zombieapocalypsethequest-1006002.zip`, expanded XFL
and its ActionScript routing. Playback uses the original 19 fps and discrete
keyframes, including the original overshoots; there are no guessed easing curves.

## Coverage

59 animated scenery sets cover the opening, television, lift, car and foot
routes, office, subway, farm, forest, taxi, Dorvud, bite and explosion scenes.
Static screens keep their existing component layouts. Named semantic variants
resume the next segment of the same MovieClip, rather than replaying its start.

Effects exported from individual display-list elements:

- alpha fades, including the opening and the layered bite sequence;
- translations, zoom/scaling and brightness changes;
- additive RGB transforms (white flash), authored fade-to-black keys;
- appearance/disappearance and replacement of individual symbols;
- the two 20-frame passes of PerMov's running sequence before its attack clip;
- original End/Next timing instead of generic full-screen fade substitutes.

Seven native caption timelines preserve moving/fading farm and forest paragraphs,
the disappearing lift description and the main street's arriving text. Text
continues to use locales, native labels and the shared shader shadow. Its stable
placement remains in the safe UI area.

The shared item, dialogue and result panels use AddItem / NewItem / ResultBad
entrance offsets (the metal body moves; fixed headers and input-blocking shade
stay in place). PauseMov's existing six-frame slide now also uses its authored
button alpha keys. Television channel changes play the original remote movement,
without replaying television switch-on; switching off finishes its four keys.
The lift button plays its own press frames during lift closing. Answer plates
use Symbol 97's four hover tint keys; their labels stay stationary.

The reachable Episode I XFL clips have DropShadowFilter on text, already handled
by the common text-shadow shader. No authored BlurFilter, GlowFilter or
ColorMatrixFilter was found in this episode's reachable display-list elements;
none is invented. Red interaction glow remains the existing dynamic contour and
shader blink, without adding translucent red PNG assets.

## Runtime and input

`episode_timeline.gd` creates a display list from shared component textures and
applies each frame's matrices and color transforms. Pixel art is not duplicated
for every animation frame. The shader implements Flash's RGB multiplier/offset
and alpha separately.

While an exit plays, duplicate gestures and underlying actions are blocked. The
scene change commits once, at the last frame. Pause freezes the current player;
resume continues that same player and any pending transition. Cutscenes complete
on their authored final key. Other episodes retain their existing cutscene logic.
Restored item/result and decision backdrops use their stable final frame.

## Regeneration and validation

```
python3 tools/build_episode1_animations.py ORIGINAL.zip
python3 tools/build_episode1_text_animations.py /path/to/XFL/LIBRARY
python3 tools/build_episode1_ui_animations.py /path/to/XFL/LIBRARY
python3 tools/episode1_animations_source_test.py /path/to/XFL/LIBRARY
```

The source test compares popup and remote offsets, opening alpha and key cutscene
lengths against XFL. Godot's `episode1_animations_test.gd` samples every exported
frame and exercises exit timing, duplicate input, pause/resume, native paragraph
alpha and the fixed popup header. Mainstreet, television, world alignment, modal,
result and full episode route tests cover integration. These checks run headless;
visual playback on Android still needs device review.
