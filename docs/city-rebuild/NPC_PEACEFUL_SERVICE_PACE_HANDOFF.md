# Peaceful services and junkyard workers — 2026-09-10

Live parent inspection identified `junkyard_worker_3` at 4.6 m/s. Its source position uses `_npcTimedWalkRoute` directly, so the earlier resident-ID adjustment did not apply. This is a distinct confirmed cause from renderer stuttering under load.

The shared humanoid peaceful pace constant in `world.html` is now **1.8 m/s**. `_npcPacedSpeed` and `_npcTimedWalkRoute` consequently cover ordinary services, junkyard workers, peaceful police, prison escort, shoppers and ordinary empire movement. Explicit running branches retain **7.8 m/s**. The actual player `hero_posture.mjs` remains unchanged at 4.6/7.8 m/s. Resident fear/routine modifiers cannot exceed 1.8 outside the separate emergency running states; fatigue, injury and slow archetypes remain.

Existing callers of the helper were inspected as humanoid movement, including stretcher phase durations, which are calculated from the slower approach/return speed rather than moving faster to meet a fixed deadline. No car/dog/projectile speed or server combat change.

PASS: `test_npc_hero_pace.mjs` (now including timed worker route sampling at 3 FPS as well as 30/60/144), `test_service_npc_hero_pace.mjs`, `test_civilian_frame_pace.mjs`, `test_remaining_npc_pace.mjs`, `test_police_backup_navigation.mjs`. Expected peaceful NPC bounds were updated to distinguish them from the player's default movement. Measured ordinary resident speeds remain 0.688–1.797 m/s depending on archetype.

This does not solve GPU load or guarantee smooth display at 3 FPS. Parent/weapon agent own render workload reduction. Wet agent owns water-egress query amplification; no duplicate changes to those helpers were made here.
