# AGENT_SYNC — указатель

Общая память двух чатов (проект «Мафиози») лежит здесь:

```
C:\Users\Слава\Documents\deepseek-harness\default-workspace\AGENT_SYNC.md
```

Читать перед любой работой в этом пакете; записи добавлять в журнал там же.
Коротко: один прогон Godot за раз, чужие PID не убивать, чужие зоны не править,
правки — с бэкапом в `patches/`.

Зоны: **чат 1** — метки/голова (`npc_postmortem_bullet_marks.gd`, `npc_head_zone.gd`,
`npc_marks_new.gd`, `bench/*`); **чат 2** — город (`scripts/city/runtime/*`,
`npc_city_*.gd`, `npc_daily_*.gd`, `hospital/*`, `bank_geometry/*`, `shop/*`,
`scenes/main_city.tscn`, `assets/npc_city/*`, `data/city_block.json`).
