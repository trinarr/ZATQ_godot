# Локализация репортажа из Дорвуда

Пятый канал использует `scenes/ui/TVDorwood.tscn`: фон `assets/flash_ui/tv/dorwood_nqc.png` без трёх титров и отдельные Label. Остальные элементы изображения, включая NQC и LIVE, сохранены.

| Ключ locales/tv.csv | ru | en |
| --- | --- | --- |
| tv.dorwood.breaking | ЭКСТРЕННЫЙ ВЫПУСК | BREAKING NEWS |
| tv.dorwood.headline | 20 жертв массовой стрельбы | Report of 20 Victims in Mass Shooting |
| tv.dorwood.location | ДОРВУД | DORWOOD |

Использован существующий DejaVu Sans Bold; длинный заголовок вписывается уменьшением кегля. Плашки сохраняют прежнюю геометрию; надписи масштабируются с кадром и обновляются при смене языка. Нарративное описание канала не изменено. Порядок каналов, быстрый фейд и сейвы сохраняются.

## Очистка фона

Встроенный imagegen. Промт: Use case: text-localization. Remove ONLY BREAKING NEWS from the narrow top red stripe, Report of 20 Victims in Mass Shooting from its white headline rectangle, and DORWOOD below. Restore red stripe, white rectangle and dark red banner with original textures, completely blank for Godot text. Preserve NQC white/silver squares and black letters, LIVE, people, vehicles, camera angle, light, colors, brushwork, framing, aspect ratio and resolution. No substitute text, watermark or extra people.
