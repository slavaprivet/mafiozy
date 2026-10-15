# Door opening recovery31

Targeted native recovery and lifecycle checks pass. This is not final full-scene
acceptance. Root owns integration, F5, release and Git. All edits are confined to
this proposal; exact release57 and its1200-second raw evidence remain unchanged.

Actual cause: release57_1200_01 stdout's last SHOP-002 door event is frame23062,
opening fraction0.692, sweep_body:npc_resident_9. Resident2 holds its supported
exit stage for865.507s; resident8 queues810.235s. Resident9 continues roaming
within x[-137.799927,-136.987045], z[161.726227,162.253036] until terminal.
Its sampled path is421.86m within this0.968m diagonal box. ACTUAL_CAUSE31.json
preserves source hashes and all863 relevant native actor samples. The new root
spatial observer catches this treadmill independently of cumulative movement.

Integrate exactly the three entries of PATCH.json against their base pins:

- scripts/hospital/npc_door_clearance31.gd: temporary native retreat for a roaming
  actor explicitly reported as the live door's own sweep blocker. The supported
  stage remains on its original side, outside the measured whole leaf arc and
  within2.4m request range. Search, movement and idle are separately reported.
- scripts/hospital/npc_simple_hospital.gd: invokes recovery for roam only, keeps
  original target/legs/guide, resumes through the normal local replan, and retires
  helper state on begin/cancel/attention. Every helper step calls the ordinary
  RoamWait/publish path without a second native hold or move.
- scripts/city/runtime/npc_city_clone_door_swing.gd: remembers explicit opening
  intent even when a real open request is refused; a later close revokes it.
  Helper stops immediately on revocation. It never commands or bypasses a leaf.

All movement uses the existing physical route. Floor/world/door/player collision
is unchanged; only the existing passage policy exempts pairs of NPCs. Invalidated
bodies stop without restarting the old goal. Lost door owners retire recovery.
Recovery is bounded to6s: an actual player obstruction gives blocked, never a
fake successful passage. Unavailable safe stages do not grant permission.

Eight native cases in runs/*_final03 share the exact current three source pins:
partial opening; fully closed refused-open; attention pause/resume; cancel/new
route; close-intent revocation; persistent player obstruction; retired body; and
13s prior planning plus3s of real blocked-door waiting. The last case completes
the original goal in6.717s with planning13197ms and motion_idle0, retaining prior
budgets without misclassifying idle time. Every run archives HARNESS.zip and
1130 before/after source pins, uses the current scheduler read Lease/own-child
watchdog, and reports no source/harness drift or stderr.

The short direct-goal baseline reproduces the actual blocked sweep and confirms
native pair exceptions, but can clear on its own. It does not reproduce the exact
long-running navigation waypoint loop. This limitation is explicit in ACCEPTANCE.
The required next step is root's merged1200 native natural soak with spatial gate
and all-service regression. No FPS claim is made alongside the user game.

Godot_addons31 independently reviewed the final three scripts read-only. Its P2
about elapsed planning accounting was repaired and covered by watch_final03.
Historical setup failures and earlier snapshots remain in runs; final acceptance
names only the exact final03 receipts. DOOR_OPENING31_SOURCE.zip contains only
three production scripts and PATCH.json, not a game copy or duplicate raw logs.
