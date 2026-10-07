# Episode II and III MovieClip playback

The common `episode_timeline.gd` now loads each episode's layer and native
caption catalogs. It retains the source 19 fps, per-frame transforms, layer
order, visibility, color transforms and alpha. Identical pixels reuse existing
component textures, including shared artwork from Episode I.

Generate from the original archive:

```
python tools/build_episode23_animations.py ORIGINAL.zip
python tools/episode23_animations_source_test.py /path/to/LIBRARY
godot --headless --path . --script tools/episode23_animations_test.gd
```

Scene segments follow the selected MovieClip stops. Automatic cutscenes use
the complete scene span and transition at the authored final frame, including
the 126-frame roof movie and the 37-frame Episode III opening sequence.
Intermediate click stops in that opening follow the existing Godot automatic
cutscene route; this patch restores visuals without adding new story nodes.

QTEs use one layer timeline driven by their persisted activity elapsed time.
They do not restart a scene every time its frame changes. The branch QTE
holds frame zero until the player's answer, like the existing game rules.
The original native hit regions, required taps and target windows remain
under `qte_rules.gd`; decorative QTE badges ignore input and use localization.
The original child frame override is clamped to its own length so a shorter
nested clip retains its final image instead of becoming empty.

Native captions and their description bands move/fade together. Translated
labels resolve to the same source track through the existing locale tables. Shared item,
dialog and result popups use the already extracted Flash entrance tracks in
all three episodes. Pause retains the exact scene player and QTE clock.

A clip with no authored exit keys holds its final intro frame. Its nested
children must not restart when the scene is dismissed.

Same-clip story variants skip the preceding outro: the next intro contains
that transition, so it must run only once. Blur metadata, where present, uses
the existing once-per-texture cache rather than per-frame blur calculations.

No extra Flash filter nodes were found in the selected Episode II/III clips.
Authored effects are represented by layer changes, transforms and colors.
Two Episode II MovieClips (`e2_hall_6`, `e2_main_11`) contain only an End timer,
so their intentionally empty visual track retains the authored duration.
