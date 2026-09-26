# Приёмка исходной точки и первого Godot preview

26 сентября 2026. Проверены документы S00_BASELINE, PREVIEW_BLOCK_CONTRACT, PREVIEW_PLAYER_CONTRACT, S00_MATERIAL_PARITY_AUDIT и полученные полные поля этапов S00–S15 Астра10. Это проверка доказательств, не новый игровой прогон.

| Gate | Имеющееся доказательство | Оставшаяся проверка |
|---|---|---|
| S00 source lock | 711 записей ZIP перечитаны; base3612 и working World9f5/Walk e80 разделены; SHA и provenance сохранены | Фактический полный host snapshot после построения мира, включая generated geometry и source actors |
| S00 feature parity | source owners и candidate statuses отделены в S00_BASELINE | Полный machine-readable feature ledger, offline/online authority matrix, golden scenarios для каждой механики |
| S00 baseline perf | Аппаратура сообщена, маленький debug probe явно ограничен | Сопоставимый тяжёлый Walk маршрут, actual trace, прогрев/камера/настройки/население/транспорт |
| S01 native preview | Root сообщил работающую видимую сцену Godot4.7.2; исходный квартал опубликован fcfed | Windows standalone export, engine/templates lock, trace ON/OFF overhead; не считать editor/debug delta release результатом |
| S02 asset excerpt | Хеши ресурсов, stable placement IDs, метрические transforms, hide helpers; exporter byte checks | Полный asset/map manifest, generated interiors/doors/windows, safe save store и ID persistence |
| S03 player preview | 16 actual headless physics assertions;7 hero meshes/8338 colors, no character scale | Procedural gait в реализации root, независимая проверка реального рига и стоп; stair/traversal/action arbitration и визуальный прогон |
| S04 quarter |8 реальных зданий/8 фонарей; geometry/material audit | Входы/интерьеры/двери100циклов, оконная видимость/picking/collisions, день/ночь, performance reserve общей сцены |

Ни один из S00–S04 не объявляется полностью ACCEPTED по этим документам. Первый наглядный preview разрешён позднейшим поручением пользователя, но не закрывает gates предыдущих этапов. Предварительные CPU/GPU бюджеты плана остаются требованиями, а не измеренными результатами.

## Пакеты на следующий интеграционный шаг

1. Root player-subagent: preview_locomotion.gd; Astra11 только независимый rig/rest/foot review после завершения текущего combat proposal. Не импортировать альтернативный motor/root motion.
2. Root city-subagent: source surface materials; Astra6 выдаёт конкретный audit actual surfaces/linear-sRGB, сохраняяGLB и качество. Не применять глобальный generic shader.
3. Astra1: wall-frame recorder + warmup/event-spikes/metric availability. Null для unavailableGPUms; неподвижный1280×720probe не gameplay benchmark.
4. Astra4/2/5: stockroom/door schema, employee lifecycle и regression tests. Только pilot-first; all-buildings coverage требует проверенных индивидуальных интерьеров.
5. Astra10: оставшиеся gate_contract/36checks полным текстом;20kprefix доступен в astra21_ASTRA10_RECEIVED_PARTIAL.md, исходныйZIP пока локально не получен.

Для каждого входящего файла: сохранить точные байты/SHA, проверить source baseline/deps/interface, выполнить применимый локальный тест безGPU, передать root код+отчёт+пределы. Неприменённый proposal не называется перенесённой механикой. Скриншот чужого sandbox и CPU doubles не заменяют actual rig или общий живой прогон.
