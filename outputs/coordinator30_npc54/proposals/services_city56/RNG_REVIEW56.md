# Индивидуальность RNG: read-only аудит56

В `scripts/shop/npc_economy_visit28.gd` configure сначала вызывает `_rng.randomize()`. Только при явном `--city-sandbox-seed=` устанавливается `_rng.seed = int(value) + int(_token.life_generation)`, без source_id. Поэтому perf seed53 делает первый roll и roam offsets одинаковыми у всех жителей одного поколения. Это воспроизводимость теста с коррелированными потоками, а не потеря индивидуального source_id.

`release55/ASSEMBLY.json` и services actual10_01/diag02 не передают этот флаг. Ordinary56 должен также обходиться без него. Предлагаемое отдельное улучшение будущего seeded QA: смешать run seed, стабильный source_id и life generation; сохранить воспроизводимость и различие потоков. Production не изменён. Root выполняет финальный perf с ordinary RNG.
