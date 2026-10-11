# Original Flash tests

All five tests are playable from the Tests selector. Episodes and tests have
independent results; launching a test does not replace the saved episode.
The last completed result is stored in `Quest.test_results` using the existing
atomic save/backup mechanism. In-progress tests are session-only, as in Flash.

| Test | Questions | Logic |
| --- | --- | --- |
| I. «Киношный» апокалипсис | 16 nodes, 1–7 questions per path | Yes/no branches; original outcomes 12–28 |
| II. Всегда готов | 9 scored + 1 unscored | Explicit editorial risk points; original outcome thresholds 29–32 |
| III. Эксперт по выживанию | 15 | Percentage from a maximum of 88 points; random applicable recommendation |
| IV. Эра мертвецов | 9 | Starts at 35 points; clamp to 0–100; 12 durations and cinematic analogues |
| V. Оружейник | 14 | Percentage from a maximum of 41 points; random applicable recommendation |

Content: `data/tests.json`. Translations: `locales/tests.csv` (`key,ru,en`).
Russian text is original; English cells are left empty and use Russian fallback.
UI labels are in the same table; existing selector names/descriptions remain in
`locales/ui.csv`. Test answers keep their original IDs, including mixed-width
layouts with seven or eight answers. Select an answer and then press Continue;
Restart starts the current test again and Menu returns to the main menu.

Source: `data/flash_catalog.json`, `TestStartMov.as` and `ResultBad.as`.
Rebuild content with `python3 tools/build_tests_content.py` and art with
`python3 tools/build_tests_art.py ORIGINAL.zip`. New controls use the project's
torn-edge shader and original navigation icons. Results reuse the common metal
popup, Regular 400 text and original result entrance animation.

## Test II scoring correction

The original button-index scoring (including the missing `Choose4` case) has
been replaced with explicit points per answer. Only confirmation awards points;
selection history never affects the score. Question 10 remains playable, with
`scored: false` and zero points for every answer. It still completes the test.

Points are an editorial assessment of risk in the fictional scenario, not a
validated survival or medical assessment. Lower is better. The source wording
and verdicts are retained; the broader factual/text audit is outside this fix.
The bite question has no low-risk answer among the existing choices. Scores
must not be interpreted as instructions for treating real bites.

| Question | Points in displayed answer order |
| --- | --- |
| 1. Temporary shelter | 2, 1, 2, 3, 2, 0, 2, 3 |
| 2. Permanent shelter | 2, 3, 2, 0, 1, 2, 2, 1 |
| 3. Weapon | 2, 1, 0, 1, 2, 2, 3, 1 |
| 4. Bitten companion | 2, 3, 3, 2 |
| 5. Group leader | 1, 1, 2, 1, 1, 3, 2, 1 |
| 6. Nearby military patrol | 1, 1, 3, 2, 2, 1, 2, 0 |
| 7. Food and water | 2, 2, 1, 1, 3, 1, 0 |
| 8. Food choice | 2, 0, 2, 0, 1, 1, 3, 2 |
| 9. Item choice | 0, 1, 1, 0, 2, 2, 1, 3 |
| 10. Knowledge self-assessment | 0, 0, 0, 0 (unscored) |

The reachable total is 3–27. Original thresholds are unchanged: below 6 is
excellent (29), below 16 is okay (30), below 26 is poor (31), otherwise terrible
(32). All four verdicts remain reachable. `tools/build_tests_content.py` applies
these overrides on rebuild, preserving original answer IDs and ordering.

Validation: `python3 tools/quiz_source_test.py` and Godot headless
`--script tools/quiz_content_test.gd`. The checks cover every question/answer,
all seventeen branching outcomes, min/max scoring, layout, real selector
dispatch, last-result persistence and preservation of episode progress.
