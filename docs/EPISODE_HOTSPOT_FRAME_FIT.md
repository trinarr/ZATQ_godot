# Full episode frame and hotspot bounds

Apply `zombie_episode123_hotspot_frame_fit.patch` after
`zombie_episode123_death_pause_lock.patch`.

## Cause and audit

The report shows `forest_lost` (`ep1_forest_lost`, original `ForestRun` frame 9).
Its two Flash arrows are inside the original 800×480 stage:

| Choice | Original bounds |
| --- | --- |
| Toward Dorvud | x=480.5, y=419.5, width=196.5, height=54.5 |
| Toward the forest horde | x=277.5, y=334.5, width=152.5, height=85.5 |

The viewport's composed artwork used cover scaling, `max(width/1600,height/960)`.
On a wide display this enlarged the scene beyond the safe area's height and
cropped both arrows and their click zones. On narrow displays it cropped the
horizontal edges. Disabling clipping alone could not expose content outside the
physical viewport and would also draw into the camera/notch area.

The first three episodes' explicitly authored choice, QTE target and timed-target
rectangles fit inside the Flash stage. Their original coordinates need no
individual repositioning. The same viewport transform affected composed art,
MovieClip layers, interactive highlights and world hit zones throughout these
three episodes.

## Change

Composed episode art now uses uniform fit scaling,
`min(width/1600,height/960)`, centered within the safe area. This preserves the
complete original frame on wide and narrow screens. Black space remains around
the frame where the aspect ratio differs; the scene is not stretched.

World interactions retain the exact same transform as the artwork. Captions,
pause controls and modals retain their existing safe-area layout. Decorative
background fill still uses its existing covered TextureRect; safe-area clipping
remains active so nothing draws into a cutout. No per-scene coordinates, textures,
mask contours, animations or shader parameters are changed.

## Validation

`tools/episode_hotspot_bounds_test.gd` checks the complete stage, authored target
bounds and representative instantiated controls from all three episodes at
2048×922, 2400×1080, 1280×960 and 1600×960, with and without safe-area insets:
2128 checks, including 1816 target/layout combinations, no failures.

Existing world alignment (250 checks) and TV control/input (149 checks) tests pass.
A Compatibility/OpenGL render at the reported 2048×922 size with a 106-pixel
left inset shows both forest arrows in full; a real input event on the lower
arrow enters `dorvud_entry_1`. Android rendering was not run in this environment.
