# John web story

The source is `assets/ZombieApocalypse.swf` in `ZombieApocalypseWE.zip`.
The second SWF copy is identical. The bundled XFL and 514 ActionScript files
belong to the main mobile game; they are not the source of this web story.
The actual SWF contains 51 scripts and two independently selectable parts.

Godot publishes one bonus episode, ID 101, named «ВЕБ-ЭПИЗОД 1. ДЖОН».
It begins with the prologue and continues into the escape without returning to
selection. Main-story Episode VI remains independent. Legacy part-two saves
(ID 102) migrate to 101; statistics are combined and scene IDs stay unchanged.
The existing selector slot (frame 5, previously episode 0) now launches 101.
Its original gas-mask preview and description are retained. No new card is
appended; temporary exported John selector parts are removed during unify().

## Original routes and unfinished branches

| Source | Implemented response | Other responses |
| --- | --- | --- |
| Part 1, frame 7, NewItem(1) | 2: examine the soldier -> frame 8 | 1 and 3 return to frame 7 |
| Part 2, frame 4, NewItem(2) | 1: return -> frame 5 | 2 and 3 return to frame 4 |
| Part 2, frame 7, NewItem(3) | 2: approach elevator -> frame 8 | 1 returns to frame 7 |
| Part 2, frame 10, NewItem(4) | 1: take suit -> frame 11 | 2 returns to frame 10 |
| Part 2, frame 11, NewItem(5) | 2: release infected -> frame 12 | 1 and 3 return to frame 11 |

These eight responses reproduce the original handlers, which close NewItem
without advancing MCity. They remain playable returns, not invented deaths,
endings or missing-node redirects. The choices carry `unfinished: true` for
future authoring.

Alex's DlgArr[0] enables only answer 1; DlgArr[1] enables only answer 2. All
original answer captions remain visible in their original slots. Disabled
answers are blocked in both the UI and Quest.choose(). Answer 2 gives the note
and resumes Part 1 at frame 9. At the user's request, frame 11 now continues
on click into Part 2 frame 1. The remaining unfinished branches are unchanged.

Part 2 frame 3 gives the laser cutter (Weapons frame 3 in Flash); the note uses
Weapons frame 2. The empty first weapon frame is deliberately skipped. Frame 8
waits at its first key, plays keys 2..9 on click, then advances on End. Part 2
ends with exactly ResultBad(1), whose source Summer(0) reports survival. Its
text and single ending statistic belong only to the bonus story.

## Components and animation

The 38 scene/modal states use the common narrative layer, item popup, player
dialog, result screen, pause menu and 19 fps timeline player. Text remains in
`locales/episode101.csv`; English falls back to the source
Russian. The console's original Lucida Console glyphs are extracted from the
SWF, with authored line breaks. Console borders and arrows are native geometry.
All scene textures are PNG primitives, deduplicated with preceding episodes.

The source symbol/bitmap IDs are offset by 10000 during export to prevent
collisions with main-game blur replacements and special source symbols. Audio
is namespaced `john_` so identically named effects from another build cannot
replace these source recordings.

`input_ready_frame` separates the original End event from a background loop.
The soldier scene accepts input at authored key 6 while its blinking continues;
the dark-room scene accepts it at key 5. The new input_ready signal follows the
existing timeline clock and suspension, rather than an independent wall timer.

The CSV importer must use `compress=0`: the localization loader enumerates
Translation keys, which OptimizedTranslation cannot provide. This is enforced
by the builder and tested in a PCK without source CSV, matching device runtime.

## Rebuild and checks

```
python3 tools/build_john_episode.py ZombieApocalypseWE.zip --ffdec /path/to/ffdec.jar
godot --headless --path . --script res://tools/john_episode_test.gd
python3 tools/verify_locales.py
godot --headless --path . --script res://tools/john_export_localization_test.gd -- /tmp/john_locale.pck
cd /tmp && godot --headless --main-pack /tmp/john_locale.pck
```

The builder decompiles the actual SWF with JPEXS, exports XFL, extracts fonts,
then uses the existing component and animation exporters. Generated files ship
with the patch; Java/JPEXS and Inkscape are not required by the game.

Validation: all 38 states load; the full authored escape path reaches its
original result; eight unfinished choices retain their return routes; disabled
answers and input readiness are checked; both pickup sprites load. Common menu
and Episode II/III animation regressions are also exercised. Software OpenGL
captures cover console text, Alex, pickups, scenes and the result screen.

## Shared eye animation

Part 1 frame 11 opens the eyes over the ceiling in 16 source keys. Symbols
10373/10371 reuse EyeClosure and the exact shared eye_lid pixels (identical
to web Bitmap 10369). MovieClip positions and disappearance at key 15 remain
authored. Bitmap 10367 is replaced by sharp Bitmap 10374 plus one cached
Gaussian blur (sigma 2.5), blended smoothly from full blur to sharp across
keys 0..14. Both original background slots share the same cache target, so
the source swap at key 11 cannot introduce a jump.

The web story already reuses NarrativeLayer/NarrativeBlock, PauseMenu,
PlayerDialog with DialogAnswerButton, ItemPopup, ResultPopup/MetalPopup,
TornTextButton/TornIconButton, shader text shadows, episode selection and
EpisodeTimeline. Further useful extraction would be the console report
frame (three matching screens) and a standard full-screen continue hit
area with input-after-intro gating; neither needs a separate web UI system.

## Caption masks and input

Part 2 frames 1 and 9 use Symbol 10183 as a mask layer, not white art.
Its ten original rectangle poses are exported as caption_mask tracks. Native
text and its shader shadow clip to the same transformed rectangle; label
pooling clears the materials and resize reapplies current mask geometry.

Frame 3's red door/bag clips blink in an independent 19-frame loop. They
do not form an exit animation: the original MovieClip click handler opens
AddItem(2) immediately. The imported 256-frame pulse-based outro is discarded,
so a single tap reaches the laser popup without the former 13.5 second delay.
Flash accepts the entire MovieClip as the click target; the broad original
continue area is retained, covering both red elements.
