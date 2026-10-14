# Переводимое оформление «MAX 24»

Сцена `scenes/ui/TVVestnik.tscn` объединяет фон `assets/flash_ui/tv/hazmat_vestnik.png` без запечённых надписей и семь отдельных `Label`, а также два `ColorRect` для логотипа. Применяется на третьем канале телевизора. Персонажи, окружение, композиция, физические маркировки на костюмах и значения котировки сохранены.

Переводы находятся в `locales/tv.csv` (`tv.vestnik.*`): `MAX` в обеих локалях, суффикс `24`, новость о Тамбовской области, «ММВБ» / `MICEX`. Время исправлено на `8:03`. Значения котировки остались `1333,49` и `-1,26%`; в английской локали используются десятичные точки. Текст меняется при переключении языка. Другие сюжетные описания и строки не изменены.

Шрифты DejaVu Sans и DejaVu Sans Bold поставляются вместе с лицензией. Положение и размеры текста заданы в `scripts/ui/tv_vestnik.gd`; длинный перевод уменьшается до доступной ширины. Сцена сохраняет пропорции 16:9 и не перехватывает тапы.

## Промт очистки фона

Фон отредактирован встроенным imagegen:

Use case: text-localization. Edit the attached painted TV news frame for Zombie Apocalypse: The Quest. This is preparation of a text-free broadcast background for separate translated Godot Label layers. Remove ONLY the broadcast-overlay lettering and numbers: in the top right remove ALL white letters ВЕСТНИК and ТВ, preserving the existing blue rectangular panel and adjacent red square in exactly the same places and sizes, EMPTY. On the entire white headline strip near bottom remove ALL the Russian sentence, leave the white/gray textured horizontal strip intact and completely empty. In the entire black ticker strip at the very bottom remove ALL time, lettering and numerical data: 13:46, ММВБ, 1333,49, -1,26%. Preserve its black/charcoal textured strip and its column separator lines intact and empty. Do not add replacement wording or numbers anywhere. No ghost letters, no newly invented logos. Preserve the scene above the bands as closely as possible: exact three workers and individual faces, positions, yellow-green hazmat suits, black respirators, industrial pipes, equipment, blue rusty machinery, painting brushwork, light, colors, perspective and framing. Physical markings printed on the suits/equipment belong to the scene and must remain unchanged. Do not erase these physical markings. Only change the overlay text regions specified, not scene people or objects. Same landscape aspect ratio, same composition and scale. Output an opaque PNG background, no watermark.

## Компактная плашка MAX

Синяя плашка — отдельный `BrandPanel` шириной 132 px; `SuffixPanel` остаётся справа. Обе ноды масштабируются вместе с текстами и не перехватывают тапы. В PNG цветных блоков больше нет.

Последняя очистка фона выполнена встроенным imagegen по промту:

> Use case: precise-object-edit. Remove ONLY the small blank blue rectangle and adjoining red square at top right, reconstruct the dark industrial wall behind them seamlessly. Leave NO logo panels or text. Preserve all people, faces, masks, suits, machinery, lighting, brushwork, framing, bottom blank white headline strip and black ticker with separators. No new text, objects or people; same aspect ratio and resolution. The logo is separately drawn by Godot code.
