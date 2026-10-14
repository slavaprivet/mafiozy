# Receiver V2 — независимая проверка root, 27 сентября 2026

Проверен отдельный tools-only кандидат
`tools/godot/map_editor_landmark_receiver_v2`; production, исходный V1,
браузерный захват, исходные пиксели и единственная игровая сцена не изменялись.

Root прочитал receive.mjs и повторил все три suites последовательно:

- test_receiver.mjs: 44 PASS, отказ до записи, канонический TAR одинаков с
  браузерным parser, сервер закрыт.
- test_actual_capture.mjs: 100 PASS, 87 исходных файлов / 43 изображения;
  TAR 61 689 344 байта, SHA256
  `89746082370fc7e7418239292db64b809ca1f334c001649730da22f393bda8a3`.
  Успех в `outputs/landmark-receiver-actual-proof-he9gxa/landmark-canvas-capture-cw3XSo`;
  контролируемая ошибка записи оставила явно частичный
  `outputs/landmark-receiver-actual-proof-he9gxa/landmark-canvas-capture-amv80R`,
  без успешного storage receipt. Поздняя порча отказала без каталога вывода.
- test_connection_cleanup.mjs: 7 PASS; отказ закрывает keep-alive соединение,
  прогрессирующее неполное тело ограничено native timeout; сервер закрыт.

Всего **151 PASS**, exit0, allStoredHashesExact=true. Проверен receive SHA256
`3a3ad2d506c4bc02d30e2b88f0dbfed5a543e2340a85ba1e8b95bfb7dda7fb81`.
Canonical receipt pin сохранён:
`614c65a7a209946125dbc5fcd0632bb575df66cdf080cf6d083d300b914f4a32`.

Это допускает V2 как tools-only преемник локального протокола доставки
именно проверенного захвата при неизменных host-owned каталогах и trusted
Node realm. Не является общей защитой localhost, crash-atomic публикацией,
проверкой шрифтов, GPU/sampler/IBL, FPS или разрешением игровых владельцев.
Никаких ready/production flags не повышено; фактическое сохранение карты
пользователем и main-интеграция редактора остаются отдельными требованиями.
