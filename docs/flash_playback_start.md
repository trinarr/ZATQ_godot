# Flash playback start timing

The source document and runtime both use 19 FPS. The abrupt entrances were
caused by adding a whole Godot frame delta to a newly created MovieClip: that
delta included work completed before its initial pose was drawn.

A graphical reproduction with a 350 ms synchronous scene-build delay showed
these first presented poses on the original player:

`2, 5, 5, 5, 5, 5, 6, 6`

With the presentation clock, the same reproduction showed:

`0, 0, 0, 0, 0, 0, 1, 1`

`flash_playback_clock.gd` waits for `RenderingServer.frame_post_draw` and records
its time. The first process step counts only time since that draw; later steps
use the ordinary scaled delta. Every intro/outro gets a new boundary. No global
FPS limit, speed multiplier or authored frame changes are involved. Menu panels,
logo and popup entrance players share the same fix. Headless simulations use the
next process boundary because the dummy renderer emits no draw signal.

The regression test `tools/flash_playback_clock_test.gd` runs headless and with
the Compatibility renderer. It checks a delayed scene build, first drawn pose,
19 FPS progression, outro restart, suspension and disposal. Existing manual pose
tests explicitly acknowledge presentation before supplying synthetic deltas.
Menu timing tests measure playback after presentation, excluding cold setup.

Validated: clock regression (10 headless / 11 graphical checks), Episode II/III
animation poses (12,003), blur fade (57), eye closure (121), lift animation (70),
menu animation (94), shared menus (392), decision dismissal (1,078).

The all-episode resource sweep in `episode1_animations_test.gd` reports the same
226 failures before and after this change on baseline `2437e46`: Episode VI
references a previously deleted Episode V vignette. That separate resource fix
was included in `zombie_dynamic_ui_cleanup.patch`; it is not a timing regression.
