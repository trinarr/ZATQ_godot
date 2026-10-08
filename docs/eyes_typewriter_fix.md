# Eye opening and John title reveal

- Shared eyelid playback starts a 0.35-second smoothstep alpha fade at 70% of the actual opening travel. Original lid poses continue moving; beyond their former endpoint, both lids continue along their travel vectors until opacity is zero. Blur intervals stay unchanged. The autonomous component follows the same overlapping motion/fade behavior. Closing lids fade into their initial open pose over 0.12 seconds and retain their opaque closed pose.
- John titles `john2_1` and `john2_9` use Label character visibility after shaping, at 28 characters/second. Full text wrapping stays fixed; the shadow reveals the same characters. The intro holds its last scenery frame until the complete localized text is revealed, and the outro retains the full title.
- The titles use a safe stage rectangle `[40,379,720,82]` instead of starting outside the left edge. Export tools preserve both the rectangle and native reveal configuration.
- Pooled narrative blocks reset character visibility before displaying ordinary descriptions.

Validation: `tools/eyes_typewriter_test.gd` passes 793 checks; `tools/caption_entrances_test.gd` passes 156 checks. OpenGL Compatibility rendering verified partial and complete titles in an isolated SubViewport. Full episode playthrough on Android was not performed.

The initial eye/typewriter patch follows the ECG mask fix. The motion/fade refinement applies after `zombie_eyes_fade_typewriter_fix.patch`.
