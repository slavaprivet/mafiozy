# Contact blood and bounded wound drips — 20 September 2026

Shared hero/NPC surface changes:

- `hero_artist14_surface.mjs`: ordinary/heavy confirmed hit bursts 20/32 particles (previously 10/18), helper integration, optional snapshot payload, inexpensive `bleedingStats()`.
- `artist14/wound_bleeding.mjs`: at most four active wound emitters, 8 seconds ordinary / 12 seconds heavy, aggregate maximum ten drops per second. Low initial downward velocity. Existing 112-instance pool and its one draw are reused; no new ground decals, health loss or death-reaction changes.
- `test_wound_bleeding19.mjs`: actual male and female GLB regression.

## Contact attachment

When the accepted receipt carries `npc_contact_ray`'s exact triangle anchor, identity and contact position are checked once. Each drip evaluates that triangle's three posed vertices and barycentric weights. No per-drop raycast or full skeleton update. Existing host bone matrices supply the current pose. Direct mesh/face contacts are also accepted.

Without a skin anchor, the exact received contact point is converted to the named or nearest skeleton segment's bone-local coordinates. The emitter is never moved to a nose, bone centre, or remembered world-space point. The body anchor follows walking, rotation and death pose.

Restore uses a local mesh path and geometry signature rather than old actor/mesh UUIDs, or a bone name and local point. The complete bleed payload is validated before the surface reset; old snapshots without `bleed` remain valid. Restoring never replays the burst. Elapsed offscreen time ages remaining bleed duration.

Blocked/unconfirmed/no-contact receipts create no bleed. A death lifecycle receipt without a hit point adds no wound; an existing wound can finish its bounded duration during death. Hidden actors do not emit or accumulate catch-up work. A large root teleport clears old airborne contact particles; later drops originate at the wound's new pose/location.

## Diagnostics and checks

`surface.bleedingStats()` returns `{activeWounds, emittedDrops}` without serializing wounds or geometry. `emittedDrops` is reset on reset/restore; it is not damage authority.

Passed:

- Actual male/female exact triangle origin under root motion, rotation and chest deformation; bone-local melee point under head rotation.
- 20/32 burst counts and unchanged 112-instance pool; receipt dedupe; four-wound and aggregate rate caps; finite duration.
- New-UUID restore onto a moved actor, atomic invalid payload refusal, old payload compatibility, death continuation, culling, teleport, reset/disposal.
- Existing `test_npc_hit_surface_contract.mjs` and `test_npc_surface_state.mjs` (using the offline test setup); module syntax checks.

The helper's 600 update calls measured 1.80 ms male / 1.35 ms female CPU total in the actual GLB test. This is a bounded CPU check, not a whole-scene frame-time or FPS comparison. Root owns the existing browser's real-shot LIVE test and performance observation. No additional browser/GPU session was opened.

## LIVE 20 сентября, текущая Walk-сцена18538

URL: world.html?direct=1&previewcity=1&render=3d&renderer=walk&npcqa=1&npctransportqa=1&perfqa=1&npccombatqa=1
Одна существующая вкладка; режим PvP. Через обычную систему пули/урона
контрольный resident_306 получил24 урона:60→36HP, осталсяжив.
Подтверждённая точка контакта x167.52156,y1.10566,z154.66253.
DOM npc-combat-session: woundGroups1, bleedingWounds1, bloodDrops1→11,
bloodParticles1. На screenshot видны красные ground marks под раненым.
Капли не менялиHP дополнительно. CPU actualmale/female origin/restore testsPASS.

Для воспроизводимости исправлен только local npccombatqa fire handler:
клик по кнопке releaseControls сбрасывал aim и камера уходила передпулей.
Теперь fire заново устанавливает тот же показанный прицел, затем передаёт
triggerPressed обычной системе. Spread/contact/HP не подменены.
FPS A/B всейсцены не проводился; параллельные задачи/CPUнагрузка менялись.
Разлёт частей тела и coverage NPC↔NPC exactbodycontact этойпроверкой не доказаны.
