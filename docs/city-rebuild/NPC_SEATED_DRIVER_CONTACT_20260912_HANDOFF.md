# Seated driver bullet contact — 12 September 2026

Root requested a CPU audit before rescue LIVE. Production change is limited to
`npc_contact_ray.mjs`; `world_walk_combat` and vehicle/glass ownership are unchanged.

`test_npc_seated_driver_contact.mjs` loads the actual `police_interceptor.glb` and
both canonical male/female hero GLBs. It uses `createNpcActor`,
`createNpcTrafficVehicleBinding`, actual `npc_vehicle_pose`, and the same body/door
render batches as source traffic. The car is translated and rotated by 0.7 radians.

Verified:

- Five head heights for each sex: intact own-side glass stops contact; an opened
  window passes a physical head hit.
- Without calling `glass.prepare`, the first real `glass.hit` discovers that pane.
  After the existing 85ms fracture phase, degenerate glass triangles no longer
  block the head ray. Prior registration is therefore not required for bullet
  breakage. Existing blast-wide enumeration may have separate preparation needs.
- Four chest heights per sex: `Door_outer_skin_front_left` remains a metal blocker
  after its window breaks. The same rays without the car demonstrably hit body
  skin, so these are actual occlusion tests rather than empty rays.
- Seat binding intentionally retains the source authority root while moving the
  visual skin to the real seat. A fixture with that source root seven metres away
  reproduced a false miss in the old broadphase despite the unchanged head position.
  This test failed before the fix and passes afterward.

The broadphase now uses the actual head bone position with the existing generous
three-metre body radius. Only the Bone identity is cached in a WeakMap; each query
reads its current world transform. Non-rig objects retain the previous root-centre
fallback. Skin intersections, triangle anchors, crouch/prone misses, HP admission
and all glass/metal obstruction checks are unchanged.

Paired CPU test in the same loaded GLB fixture, alternating versions after five
warmups, fifteen measured queries each (milliseconds per accepted contact):

| Model | Old broadphase p50 / p95 | Current p50 / p95 |
| --- | --- | --- |
| Male | 4.166 / 4.438 | 4.189 / 4.749 |
| Female | 5.263 / 6.334 | 5.031 / 6.311 |

These numbers mainly reflect the existing skinned triangle raycast. They do not
establish an FPS improvement or loaded-scene performance acceptance. No new work
is scheduled per animation frame; the change is inside accepted contact queries.

Also passed: existing real-GLB `test_npc_contact_ray.mjs` (standing head/body,
crouch/prone high misses, hidden/wall/range/world transform), aim convergence,
contact anchors and actual source physical shot admission suites.

LIVE limits: no GPU browser was opened. This verifies physical contact, not an
authenticated server driver's HP/death ownership. Root owns the actual source
traffic/crew binding and fire → accepted HP → driver-stop LIVE sequence.
