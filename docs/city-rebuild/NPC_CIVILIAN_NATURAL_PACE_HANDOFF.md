# Ordinary civilian pace — 2026-09-10

Follow-up to the user's report that residents still move extremely fast in `world.html?direct=1&previewcity=1&npcqa=1&npcbuild=2&render=3d&renderer=walk`.

## Cause and narrow correction

The previous cap matched the hero's **4.6 m/s** default movement. That is 16.56 km/h, inappropriate for a resident's ordinary walk. Archetype source values of 0.9–1.65 tiles/s become 3.69–6.765 m/s at the native 4.1 scale, so many healthy civilians constantly hit that jogging ceiling. Previous maximum-speed tests accepted this and therefore did not establish natural ambient walking.

`_npcEffectiveSpeed` now distinguishes actual `resident_` actors from bosses and other NPCs. Their ordinary base is scaled by 0.4 and capped at 1.8 m/s, retaining the slower archetypes. Existing fatigue, injury and crawling reductions still apply. Fear/routine urgency can raise walking to 2.2 m/s. Explicit panic, snitch and combat pursuit paths retain their existing running admission. Hero speed, other humanoid types, server combat, water/navigation and renderer files are unchanged.

## Source time-path audit

`frame` takes `(performance.now()-prevT)/1000` once per admitted frame and caps a long frame at 0.1 s. No `previewcity` or `direct` time multiplier was found. `_tickWorldLife` call sites in passenger, driver, bus and normal player branches are exclusive by their returns. Native snapshot conversion is 4.1. No clock-speed correction was justified by this source audit.

`test_civilian_frame_pace.mjs` executes the actual source `frame` function and actual ordinary resident displacement branch, using a controlled wall clock and unobstructed route. It isolates unrelated city/DOM systems rather than claiming a live full-city run. Ten real seconds at display rates 30/60/144 FPS all stay within the new bounds; accumulated source dt never exceeds elapsed time.

At simulated 60 Hz display (source rate admission as currently implemented):

| Archetype source speed | Metres per wall second |
|---|---:|
| 0.42 | 0.688 |
| 0.62 | 1.015 |
| 0.90 | 1.474 |
| 1.20 | 1.797 |
| 1.65 | 1.797 |

Hero ordinary/run ceilings remain 4.6/7.8 m/s. The same test against the saved baseline fails with **ambient walking 4.600 m/s at 30 FPS, speed=1.2**.

Also passing: `test_npc_hero_pace.mjs`, `test_remaining_npc_pace.mjs`, `test_npc_witness_reactions.mjs`, `test_murder_witness_observation.mjs`. Parent owns live verification and renderer clock investigation; this fix does not claim that every fast-looking on-screen actor was identified as an ordinary resident.
