# Walk ground blood — 20 September 2026

The existing source exports bloodFx, but Walk previously ignored it. Added
world_blood_marks.mjs and narrow walk_preview snapshot/update/dispose hooks.
One pooled InstancedMesh and material, at most48 marks, source lifetime and
source coordinates preserved. No impactFx bursts or HP-derived body wounds.
Unstable snapshot IDs do not replay marks; missing/expired rows disappear.

Six CPU tests pass;48 marks update p50 .006ms,p95 .020–.025ms (not whole-sceneFPS).
LIVE normal pistol hit: resident60→36HP, visible ground blood by injured NPC.
Exact body drips are separately implemented in Artist14Surface.

Limits: legacy source marks lack floor/space. Interior, water and building
footprint marks without trusted elevation are skipped. NPC-on-NPC damage
provides source ground traces, but no exact body contact receipt in several
legacy paths; body bursts/anchored wounds are not fabricated from HP differences.
