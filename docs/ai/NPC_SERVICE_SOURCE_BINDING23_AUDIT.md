# Stationary source binding — read-only activation audit23

No world/Walk edits. Locations checked in shared world.html after main4d4cd84;
line numbers can shift under other owners. Root owns activation ranges.

1. Do NOT reuse _cashier or _uniqueNpc/_said/_invulnerable. _cashier excludes
   _npcLifeEligible18126 and therefore _npcCanWitnessEvent18144, and changes
   medical-downing8939. _uniqueNpc/_said branch18547 explicitly restores huge HP
   and clears fear/death. These violate the user's living vulnerable employee.
2. Use separate stationary-service employment metadata on ordinary spawnNpc
   source actor. spawnNpc8731 gives unique resident_<serial> identity and normal
   HP/archetype/appearance. Preserve resident_ prefix for normal witness eligibility.
3. _isRespawnableResident9735 must exclude stationary employees from ambient
   _respawnResidentImmediately10827 / _scheduleResidentRespawn10817, which
   schedules a different door/new citizen immediately. Their own confirmed death
   drives exact60s same-building closed-backroom replacement. Medical downing
   remains owned by existing EMS until an actual confirmed death.
4. Separate stable employment ID from unique source-body ID. _threeNpcEntityId
   69487 uses explicit npc.id directly; npc_population.mjs110 deduplicates rows by
   ID. Reusing dead body's source ID would hide one of corpse/replacement and mix
   saved wounds/pose. Keep old corpse in existing cleanup; create fresh unique
   source-body ID for every generation. Host maps stable employment slot+generation
   to that source body, presents stable employeeId to isolated lifecycle views and
   verifies receipt against BOTH employment/generation and actual source body ID.
   Precise movement host.identity can expose stable employment identity while
   actor.id retains its unique resident body ID. Never rename existing corpse.
5. Normal agenda/visits use _isRespawnableResident and will naturally be excluded;
   generic wander/social/help still require a scoped service-control check. Keep
   witness/panic/custody/medical branches active and higher priority. Do not add
   unconditional early continue at18535 before those owners run. Calm-only
   station executor should consume movement before generic wander, with a current
   lease/generation token rechecked after collision/floor queries.
6. _npcSimulationDelta18468 already treats active visits and danger as important.
   Avoid marking every peaceful seller globally important. Reuse bounded existing
   cadence; tested precise movement supports3Hz. Limit seller lookup to its station,
   cached building/generation maps and active service visits, no per-NPC scene scan.
7. Geometry/door source collision registration, shadow invalidation and actual
   camera/occlusion/occupancy spawn approval remain Walk owner's responsibilities.
   Closed leaf does not certify a room hidden through windows or roof reveal.

These are integration constraints found in actual code, not completed source
activation. Existing isolated tests do not represent unique source-body identity
or renderer/corpse coexistence; that needs an actual source+renderer acceptance.
