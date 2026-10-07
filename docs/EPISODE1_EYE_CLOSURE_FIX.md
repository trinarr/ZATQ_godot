# Episode I: eye closure

Apply after `zombie_episode23_movieclip_animations.patch`.

`ep1_mainstreet_attack` retains the complete soft eyelid bitmaps from Flash
symbols 327 and 325, including the pixels outside the initial stage. Previously
the stage crop moved with each eyelid and exposed the background along the top.
The animation exporter uses an expanded viewport for these two moving symbols;
all authored positions and the original 19 fps timing remain unchanged.

The background stays sharp through frame 19. The existing cached blurred image
is blended from 0 to 1 over frames 19–33, synchronized with eyelid closure.
The blend updates between authored frames and stops while paused. The held
closed pose keeps full blur. Blur is still calculated once and reused.

Validation: `tools/episode1_eye_closure_test.gd`, the existing blur fade and
Episode I animation tests, and rendered Compatibility/OpenGL frames 18, 19, 24,
28 and 33. The final frame is fully black, with no exposed screen-edge strips.
