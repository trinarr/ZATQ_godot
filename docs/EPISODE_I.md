# Episode I: Бегство из Нью-Тауна

Episode I is playable from waking up through every original result. All former
city-route boundary IDs continue into real gameplay, preserving existing saves.
The base resolution remains 1600 × 960 with uniform UI scaling and safe-area
handling from the preceding patch.

## Added routes

- Main street: all four actions, running through the horde, hiring a car to the
  office, hiring a car out of town, or backing away to the shop window.
- Abandoned farm: both entry texts, quiet exploration, continuing onward, and
  the three stopped pages of the noisy encounter followed by the fatal chase.
- Country road and forest: both village entry texts, the cellar shelter and
  diary, marauders, becoming lost, the choice of direction, and the forest attack.
- Taxi: meeting Ben, the checkpoint, accepting/refusing his offer, his house,
  weapons and diary. The late taxi attempt correctly returns to the bite route.
- Dorvud: both arrival texts, the shop, both floors, the fatal fall or shelter,
  and all diary pages.

## Original results

Survival results: ResultBad(6), ResultBad(77), ResultBad(78).
Death results: ResultBad(1–5), ResultBad(7–11).
The three survival results are distinct even though their short result text is
identical in Flash. Their preceding narrative and diary pages remain distinct.

Episode selection displays wins, deaths, and unique survival endings found.
A completed run is counted once; resuming its result screen does not increment
statistics. Starting over preserves lifetime statistics. Version-1 saves remain
compatible; new statistics are optional additional fields.

## Source and validation

`data/episode1_routes.json` records original classes, timeline frames and
nested frame overrides. `data/episode1_visuals.json` records exported source
symbols, loaded photographs, and transparent control silhouettes. The artwork
is reused where pixel-identical exports occur. `tools/build_episode1_art.py`
rebuilds the included PNGs from the original ZIP.

The route test plays all 13 results from `wake`, checks every choice with both
key and car flags, saved legacy boundaries, diary pause/resume, persistence,
and silhouette hit detection. Existing opening/UI/scaling/city/safe-area checks
also run. Desktop screenshots cover a 2048 × 920 window. Actual Android
hardware was not available.

Flash timeline motion is adapted to static narrative pages and native Godot
cutscene fades. This is a complete story/choice/result port of Episode I;
frame-by-frame reproduction of Adobe Flash animation is not included.
Later episodes, quizzes and external achievement services remain outside this
patch's scope.

## Компонентная графика

Первый эпизод теперь использует слои из `episode1_components.json`.
Подробности и команды пересборки — в [EPISODE_I_COMPONENTS.md](EPISODE_I_COMPONENTS.md).
Старые PNG из визуальных манифестов остаются справочными именами источников.
