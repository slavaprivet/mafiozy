# Один world runtime с новым renderer walk

2026-09-09. URL: `world.html?render=3d&renderer=walk` с существующими параметрами авторизации. Gateway не добавляет uid/fixture/WS и не меняет сервер.

В world.html старый script startup заменён взаимно исключающим selector: renderer=walk + render=3d импортирует world_walk_host.mjs, остальные режимы импортируют прежний three_preview.js с исходным version URL. Gameplay flag render=3d сохранён для тюрьмы/коллизий/банка. Добавлен importmap prefix three/addons/ для нового walk module; версия Three180 общая.

world_walk_host.mjs загружает tools/city_rebuild_walk.html, удаляет ВСЕ script из разобранного HTML, переносит только разметку/стили в ShadowRoot. Контейнер добавляется внутри существующего stage на z-index1; body и существующие HUD/chat/dialogue не удаляются. Ссылка `window.MafioziWalkShell` — непосредственно ShadowRoot с getElementById/querySelector. Затем импортируется assets/maps/city_rebuild_v1/walk_preview.mjs. Повторный mount использует единственный promise. Если старый threePreview уже существует, новый renderer не запускается. Ошибка импорта удаляет shell и снимает three-mode, возвращая основной Canvas update/render; выводится сообщение об ошибке.

stage.three-mode сохраняет существующую world AI simulation30Hz, отключая только её Canvas drawing; никакого второго update/NPC AI/frame/WS для source gameplay не создано. Сам walk_preview остаётся владельцем своего visual renderer, и его адаптацию к source runtime выполняет основной владелец задачи.

## Bridge

`Mafiozi3DBridge.syncWalkPlayer({r,c,ang,walking,stance})` допускается только в режиме gateway. Возвращает `{ok,locked,reason,state}`. r/c в прежних клетках world; ang в прежней системе угла. Сначала root должен разрешить движение по новой authored геометрии, затем вызвать bridge. Bridge проверяет finite/map bounds и source locks: dead, custody/jail, transport/driving/bus/jetski, interior/building/bank/major, chat/game menu. При lock исходная позиция не меняется; новый renderer обязан принять `state` и прекратить свободное перемещение. Это не серверная проверка читов и не новый маршрут authoritative movement.

При успешной синхронизации обновляются существующие player r/c/ang/walking, обнуляются старые vr/vc, _keyState directions и joyL. Стойка меняется только через действующий `_playerStanceAllowed`. Источник продолжает networking, NPC scanning, interaction logic и source receipts. `getWorldClock()` возвращает `{now:performance.now(),epochNow:Date.now(),renderer}` для согласования исходных timestamp.

Существующие legacy обработчики WASD/стрелки/Ctrl/Z, Space/R и witnessE получают ранний выход только для gameplay keys gateway. Event propagation не блокируется — новые walk handlers получают те же клавиши. Enter/Escape и старые chat/dialogue handlers сохранены. Renderer обязан дополнительно уважать typing/focus/dialogue locks, включая ShadowDOM composedPath.

## Проверки и оставшаяся работа

`node test_world_walk_gateway.mjs` PASS: реальный selector выбирает ровно один module; legacy/canvas ветки сохраняются; bridge отказывает по всем11 lock flags, неверным координатам и внеgateway; действительные r/c и stance проходят; oldkeys очищены; Enter/Escape не перехватываются; host загружается и импортируется один раз, scripts из shell удалены. DOM-часть использует контролируемый mock, не браузер.

`node test_npc_incoming_threat_and_traffic.js`, `python -B test_npc_life_system.py`, `python -B test_npc_social_pair_budget.py` PASS после подключения gateway.

Root должен завершить walk hooks: `$` через MafioziWalkShell, player sync/locked state adoption, source NPC snapshots, source input/weapon/fire/interaction admission, initial spawn и source interior/transport mapping. Пока это не сделано, наличие gateway не означает готовую полную игровую миграцию. Нужен живой прогон одного WebGL canvas/одного existing WS, NPC поведения, HUD/чатов, серверной смерти/задержания и входа в интерьер. Синтетический DOM test не подтверждает авторизованную сессию или all-NPC визуальную приёмку.
