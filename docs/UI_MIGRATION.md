# Интерфейсы Flash, этап 2

Источник — восстановленные XFL и AS из предоставленного ZIP, включая встроенные шрифты SWF.

| Flash-класс / символ | Использование в Godot |
|---|---|
| FonMov / 150 | Оригинальный фон меню и селекторов |
| MenuMov / 118 + LogoMov / 132 | Меню, логотип, звук и достижения |
| EpisodesMov / 212, вложенный 211 | Карточки 7 эпизодов и 5 тестов; описания из EpisodesMov.as |
| InfoMov / 147 | Справка |
| PauseMov / 83 | Пауза, возврат, перезапуск, звук, меню и выход |
| PauseBut / 88 | Левая кнопка паузы |
| Episode1 / 2882 | Оригинальная геометрия сюжетных экранов начала эпизода |
| NewItem / 100, вложенный 99 | Металлическая панель выбора транспорта и подтверждения |
| AddItem / 276, вложенный 274 | Окно получения ключей Subaru |
| Font 2508 / Font 2511 | Caveat Medium (OFL; replaces Segoe Script and B52 Regular) |
| Font 1 / Font 2 / Font 2836 | Oswald Medium with shader edge chips (OFL; replaces 28 Days Later Cyr) / Oswald Medium (OFL; replaces GraffitiC1) / DSEG7 Classic Regular (OFL; replaces DS Crystal) |

Ресурсы графики хранятся как PNG 2× в assets/flash_ui. Управление, динамические надписи и состояние остаются нативными Godot Control/Button/Label. Скрипты tools/build_flash_ui.py, render_flash_ui.py и extract_flash_fonts.py позволяют повторить извлечение. Они не исполняют ActionScript и не загружаются игрой.

Сюжетные анимации Flash ещё не воспроизведены целиком: используются выбранные ключевые кадры. Карточки неперенесённых разделов дают доступ к интерфейсу, но не объявляются работающими эпизодами или тестами. Результаты тестов, вопросы и другие сюжетные интерфейсы будут подключаться вместе с соответствующими игровыми ветками.

### Readable distressed titles

Font 1 now uses the existing SIL OFL Oswald Medium. `ShaderText.distressed`
enables static, sparse chips only near glyph edges; body text remains clean.
`shaders/text_edge_chips.gdshaderinc` controls density (seed threshold), chip
radius and edge depth. `_sync_edge_chips()` in `shader_text.gd` weakens wear
at small font sizes. The shadow pass and animated caption mask use the same
pattern. Button captions retain single-line width/height fitting.

### Stable narrative panels

NarrativeBlock uses NARRATIVE_FONT_SIZE = 24 (48 px at the 1600x960 base
resolution), allows wrapping and never shrinks story captions. Old size,
minimum and single-line fitting settings no longer affect narration.
Bottom panels keep their lower edge and grow upwards; upper panels keep
their upper edge and grow downwards. Text and band reserve the same lower
padding. Long passages may occupy most of the frame and should be split in
the graph when editing the story. Existing hard line breaks are preserved.
Terminal screen labels and distressed headings preserve their own sizes.
The complete inventory of hard breaks is in NARRATIVE_LINE_BREAKS.md.
