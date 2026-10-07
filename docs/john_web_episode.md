# John web story

The source is `assets/ZombieApocalypse.swf` in `ZombieApocalypseWE.zip`.
The second SWF copy is identical. The bundled XFL and 514 ActionScript files
belong to the main mobile game; they are not the source of this web story.
The actual SWF contains 51 scripts and two independently selectable parts.

Godot reserves bonus IDs 101 (John: Prologue) and 102 (John: Escape), keeping
main-story Episode VI and existing saves/statistics independent. Both entries
are discovered through the existing story-graph metadata. Their previews reuse
scene textures; menu art and controls reuse the common selector components.

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
and resumes Part 1 at frame 9. Part 1 frame 11 has no click listener or outgoing
route in the source, so it remains a final tableau; the second part is started
from the episode selector as in the web build.

Part 2 frame 3 gives the laser cutter (Weapons frame 3 in Flash); the note uses
Weapons frame 2. The empty first weapon frame is deliberately skipped. Frame 8
waits at its first key, plays keys 2..9 on click, then advances on End. Part 2
ends with exactly ResultBad(1), whose source Summer(0) reports survival. Its
text and single ending statistic belong only to the bonus story.

## Components and animation

The 38 scene/modal states use the common narrative layer, item popup, player
dialog, result screen, pause menu and 19 fps timeline player. Text remains in
`locales/episode101.csv` and `episode102.csv`; English falls back to the source
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

## Rebuild and checks

```
python3 tools/build_john_episode.py ZombieApocalypseWE.zip --ffdec /path/to/ffdec.jar
godot --headless --path . --script res://tools/john_episode_test.gd
python3 tools/verify_locales.py
```

The builder decompiles the actual SWF with JPEXS, exports XFL, extracts fonts,
then uses the existing component and animation exporters. Generated files ship
with the patch; Java/JPEXS and Inkscape are not required by the game.

Validation: all 38 states load; the full authored escape path reaches its
original result; eight unfinished choices retain their return routes; disabled
answers and input readiness are checked; both pickup sprites load. Common menu
and Episode II/III animation regressions are also exercised. Software OpenGL
captures cover console text, Alex, pickups, scenes and the result screen.
