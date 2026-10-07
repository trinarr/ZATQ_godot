# Pause during committed death animations: episodes I–III

Apply `zombie_episode123_death_pause_lock.patch` after
`zombie_shared_eye_closure.patch`.

## Flash audit

The original scripts remove `Main.PauseControl` and set `StageState = 10`
when a fatal sequence becomes irreversible. `MainTimeline.CheckKeypress` only
opens pause in state 4; state 10 has no Back-key action. Removing the visual
button alone would not reproduce that keyboard restriction in Godot.

| Episode | Original trigger | Godot scenes covered |
| --- | --- | --- |
| I | `MovCityAuto.MovClickFunc`, frame 5 | `car_fatal` |
| I | `IntoTheOffice.MovClickFunc`, frame 6, child frame 10 | `office_fatal` |
| I | `MovBoom.OnMovLoad`, retained through its subsequent frames | `roof_explosion`, `door_explosion`, `door_blast`, `door_blast_inner`, `explosion_flash` |
| I | `OldFarmMov.MovClickFunc`, frame 5, child frame 30 | `farm_chase` |
| I | `PerMov.But1MouseClick`, before going to frame 17 | `mainstreet_run`, `mainstreet_attack` |
| II | `ToTheKilling.MovClickFunc`, frame 5 | `e2_hall_6` |
| II | `NewItem.But1Click`, case 22, before `ToMain` frame 11 | `e2_main_11` |
| II | `LiftCall.MovClickFunc`, frame 2 | `e2_lift_3`, `e2_lift_3_v2` |
| II | `ZombieAttackKill.MovClickFunc` | `e2_attack_2` |
| II | `MovBoom.OnMovLoad`, type 3 | `e2_boom_4`, `e2_boom_5` |
| III | `Episode3.MovClickFunc`, frame 13 | `e3_opening_14` |
| III | `NewItem.But1Click`, case 24, before `MCity` frame 17 | `e3_opening_17` |
| III | `NewItem.But1Click`, case 25, knife branch before `NextJohn` frame 8 | `e3_john_8` |
| III | `WithJohn.Checker`, frame 13, no knife | `e3_john_15` |

`Episode3.onTimerComplete` also removes pause when the frame-11 branch timer
expires. Godot now plays the already exported fatal MovieClip tail from frame 1 before
entering `e3_result_51`, instead of skipping directly to the result. It hides the
QTE targets and locks pause immediately; the finished activity no longer seeks
the death timeline. The live QTE remains pausable until timeout or a completed
choice. `failure_animation_choice: 2` selects this outcome in the scene data.

Three additional committed fatal animations did not explicitly remove the button
in their own Flash handlers: `e2_roof_6`, the zero-ammunition branch of
`e2_roof_8`, and `e3_john_12`. They are locked too to apply the requested rule
consistently whenever a fatal animation is already running. On `e2_roof_8`,
pause remains available if `BulletsNumber >= 1` and the character can survive.

`e3_john_13` retains pause until its authored End event resolves the knife branch:
with a knife it proceeds to a normal scene, without one it enters the locked
`e3_john_15`. Ordinary transitions, infection/bite progression and live QTEs are
not globally classified as death animations.

## Godot behavior

Rules are stored in the canonical visual graphs (`data/story_graphs/episode*.json`):

- `pause_allowed: false` on a scene blocks pause for its whole duration, including
  when restoring or rebuilding that scene.
- `pause_allowed: false` on a choice locks the previous screen immediately,
  before its outgoing MovieClip animation completes.
- `pause_disabled_when` uses normal Quest conditions for conditional fatality.
  For example: `{"BulletsNumber":{"max":0}}`.

`Main._can_pause()` is shared by pause-button creation and `_show_pause()`.
The guard runs before suspending a timeline, stopping a timer or stopping sounds.
Thus button callbacks, Back/Escape and application-deactivation notifications
cannot open a pause popup or stop a committed fatal sequence. Result screens
also reject pause. The operating system may still suspend the application itself;
this rule concerns the in-game pause popup.

The transient outgoing-animation lock belongs to the current screen and clears
with its replacement. Ordinary pause/resume behavior remains available elsewhere.
No persistent global "dead" flag is introduced.

## Validation

`tools/episode_pause_policy_test.gd` verifies all 23 unconditional fatal scenes,
conditional roof outcomes, button availability, direct/keyboard/background entry
points, fatal animation completion, ordinary/QTE pause, transition locking and
lock reset. Episode I gameplay and episode II/III animation/component regression
tests cover existing routes and pause/resume behavior.
