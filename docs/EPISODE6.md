Episode VI — «Рассвет»
======================

Источник: оригинальные Episode6, RoadToBoats, WakeUpNoLeg, AfterDialog,
WithoutLeg, TwoDaysPrison, SideMilitaryBase и DialogMov(6–8) из XFL/ActionScript.
Существующая карточка VI запускает эпизод; дополнительных входов не создано.

202 состояния, 88 анимированных сцен, 104 нарративных блока, три диалога.
Сохранены все 24 сюжетных результата: 137–161, кроме 150 (отдельный оружейный
тест). Победные результаты 151/160 дают две белые галочки. Финал не предлагает
переход к несуществующему седьмому эпизоду.

Переиспользованы NarrativeLayer, PlayerDialog, ItemPopup, ResultPopup,
PauseMenu, TornTextButton/TornIconButton, EpisodeTimeline, QTE и EyeClosure.
Тексты вынесены в locales/episode6.csv, импорт без компрессии сохраняет
доступность переводов в APK/PCK без исходного CSV. Арт — отдельные PNG-части;
общие рамки, кнопки, портретные подложки и веки не дублируются.

Пробуждение использует резкий Bitmap 328 вместо подготовленного Bitmap 321:
общий кеш блюра рассчитывается однократно, степень смешивания уменьшается
вместе с раскрытием век. Все смещения, альфа-фейды и тайминги берутся из XFL.
Автоматическая атака Элис выполняется без дополнительного клика и блокирует
паузу. Переходы к результатам используют общую защиту ввода попапов.

Неочевидные оригинальные правила:
- Спасение человека в столовой и вмешательство в драку в тюрьме могут убить
  Джека; пропуск QTE — отдельный, иногда благоприятный исход.
- Цели TapMov живут 13 кадров при 19 fps. Требуются отдельные попадания
  в разные циклы, позиции и прогресс сохраняются при паузе/загрузке.
- Стрельба на берегу дает 33 кадра; случайно требуются 2–3 нажатия.
- Кухонные SimpleButton невидимы: черные формы HIT не выводятся в игре,
  используются только их исходные области нажатия.
- Все варианты крови на полу, лабораторных анализов, плена и боезапаса
  сохраняют собственные тексты и исходные назначения диалоговых ответов.

Повторный экспорт (перестройка контента перезаписывает ручные правки графа):
```
python tools/build_episode6_content.py ORIGINAL.zip --force
python tools/build_episode6_components.py ORIGINAL.zip
python tools/build_episode23_animations.py ORIGINAL.zip --episode 6
python tools/build_episode6_walkthroughs.py
```

Проверки:
```
python tools/verify_content.py
python tools/verify_locales.py
python tools/episode6_source_test.py ORIGINAL_LIBRARY_DIRECTORY --archive ORIGINAL.zip
godot --headless --path . --script tools/episode6_test.gd
godot --headless --path . --script tools/episode6_export_localization_test.gd -- /tmp/episode6_locale.pck
# Затем запуск PCK из каталога вне исходников:
godot --headless --main-pack /tmp/episode6_locale.pck
```

Патч применяется после zombie_john_masks_and_interaction.patch:
```
git apply --check zombie_episode6.patch
git apply zombie_episode6.patch
```
Откройте проект в Godot и дождитесь импорта новых PNG, аудио и переводов перед
сборкой APK.
