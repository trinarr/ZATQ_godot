# Переводимые титры новостного сюжета

`scenes/ui/TVNews.tscn` применяется к четвертому каналу `tv/news_anchor.png`. Четыре подписи выводятся отдельными Label с DejaVu Sans Bold; оформление остальных логотипов и котировки сохранено.

| Ключ в locales/tv.csv | Русский | Английский |
| --- | --- | --- |
| tv.news.developing | Развитие событий | Developing Story |
| tv.news.headline | Запрет жестоких видеоигр не принят | Violent video game law struck down |
| tv.news.subtitle | Защита детей против свободы слова | Protecting kids vs. free speech rights |
| tv.news.discussion | Примите участие в обсуждении в Twitter | Join the conversation on Twitter |

Реальный хештег и фрагмент имени пользователя Twitter удалены. Смена языка обновляет подписи на уже открытом канале. Тексты вписываются в исходные полосы на холсте 1536×864 и масштабируются вместе с фоном. Нарративное описание канала не изменено.

## Быстрый фейд

`Television.show_channel` затемняет только телевизионный сигнал за 0,08 с, заменяет кадр и номер канала, затем проявляет сигнал за 0,10 с. `channel_shown` синхронизирует стандартную нарративную панель с моментом замены. Повторный тап во время перехода не пропускает каналы. Пауза останавливает фейд; загрузка открывает сохраненный канал сразу, без перехода. Камера и гостиная не затемняются.

## Очистка изображения

Встроенный imagegen; итоговый ресурс `assets/flash_ui/tv/news_anchor.png`.

Промт: Use case: text-localization. Make lower-third blank for separate translated Godot Label text. Remove ONLY DEVELOPING STORY from its white banner, VIOLENT VIDEO GAME LAW STRUCK DOWN and Protecting kids vs. free speech rights from the blue panel, and Join the conversation on Twitter: #sitroom from the bottom white strip. Remove partial handle @Wol; retain Twitter word and bird. Preserve existing ZQ NEWS logos, LIVE, S&P green triangle 11.65, newsroom, anchor, lighting, brushwork, perspective, aspect ratio and framing. Leave panels and borders intact and blank; no substitute text.

«Развитие событий» и основной заголовок выводятся капсом на обоих языках; подзаголовок и приглашение к обсуждению сохраняют исходный регистр. Белые подписи имеют чёрную тень (смещение 2 px на базовом холсте, масштабируется). Отдельный `TwitterHandle` показывает `@TRIN` справа от птицы, без реального хештега. Локализационные строки и нарративы не переформулированы.
