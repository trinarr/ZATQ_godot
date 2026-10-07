Episode V — «Смерть в воздухе»
=============================

The original Episode5, UpperDeck, HideInTheEnd, RestArea, InsideTheSector and
EndsUnder timelines are represented by the canonical visual graph. Alice's
story starts independently; documents and body armor reset on a new run.

Runtime content includes 186 scenes/dialogue states, 103 authored animated
views and results 114–136. Results 124, 130, 133 and 136 survive; 136 shares the
original Summer14 ending with 133, so the selector displays three check marks.

All narrative and dialogue text lives in `locales/episode5.csv`. Existing
narrative, dialog, item, result, pause, glow and timeline components are reused.
The keypad preserves the digits printed on the original artwork; its twelve
hit regions are exported from the original SimpleButton HIT state.

Reusable activity extensions:

- `random_values` generates a value once per run and optionally a spaced copy;
  `{Variable}` tokens insert it after localization. The pilot's original code
  generation and document-dependent answers are preserved.
- `target_cycles`, `cycle_seconds`, `target_areas`, `target_size` generate QTE
  windows once and save their positions. One hit is accepted per cycle.
  `prompt_offsets` retains the original 13-frame badge movement.
- `qte_mode: ratchet` stores its frame and fractional clock. A click moves the
  lock back five frames; it advances again at 19 fps. Three quick clicks open
  it; cumulative clicks separated by long delays cannot bypass the lock.
- `EpisodeTimeline.apply_variable_frame()` selects independent authored
  MovieClip poses, retaining one texture rather than rasterizing every frame.
- `shared/code_keypad.gd` accepts saved state, a code, hit regions and a pause
  callback. It emits completion, sound and indicator events without knowing
  the quest graph. Three wrong submissions fail; successful input plays the
  original green indication before opening the cabin.

State, attempts, password, QTE positions and clocks survive pause/save/load.
The fatal shooting animation disables pause; popups use the existing input
barrier and configured current-scene backgrounds.

Rebuild from the original archive (content rebuild overwrites authored edits):

```
python tools/build_episode5_content.py ORIGINAL.zip --force
python tools/build_episode5_components.py ORIGINAL.zip
python tools/build_episode23_animations.py ORIGINAL.zip --episode 5
python tools/build_episode5_walkthroughs.py
```

Validation:

```
python tools/verify_content.py
python tools/verify_locales.py
python tools/episode5_source_test.py ORIGINAL_LIBRARY_DIRECTORY
godot --headless --path . --script tools/episode5_test.gd
```

Install the incremental patch after `zombie_episode2_explosion_transition_fix.patch`:

```
git apply --check zombie_episode5.patch
git apply zombie_episode5.patch
```

Open the project in Godot once to import the new PNG/audio resources and locale.
