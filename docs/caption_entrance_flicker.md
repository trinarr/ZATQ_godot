# Caption entrance flicker

The exported text tracks sometimes started fully opaque before resetting to zero
and beginning their real entrance fade. For example, `e2_hall_4` had alpha
`1, 1, 0, 0.328125, 0.66015625, 1`. Its prefix is now
`0, 0, 0, 0.328125, 0.66015625, 1`.

78 caption tracks were corrected: Episode II 1, III 2, IV 15, V 33, VI 26,
and John 1. Episode I has no matching tracks and its catalog is unchanged.
Only the opaque prefix alpha is changed: frame counts, matrices, colors other
than alpha, anchors, fade keys and outro tracks remain identical.

`tools/normalize_caption_entrances.py` handles the narrow pattern of an opaque
intro prefix followed by zero and a complete monotonic fade through intermediate
opacity back to one. Ordinary entrances, fading exits and opaque/hidden flashes
are left alone. QTE tracks are excluded. Both animation exporters invoke the
normalizer so a rebuild preserves the fix. The command accepts `--check` for
read-only verification and can be run repeatedly without additional changes.

Validation: five Python regressions cover unchanged intentional effects, missing
records, independent text, idempotence and runtime catalogs; 156 Godot checks
verify captions and their bands across six representative scenes. Comparison
against the baseline catalogs confirmed that only prefix alpha changed in the
78 matching tracks. `verify_locales.py` passes.

This patch follows `zombie_flash_animation_start_clock.patch`; it only changes
caption data and exporter/test files and does not duplicate the clock fix.
