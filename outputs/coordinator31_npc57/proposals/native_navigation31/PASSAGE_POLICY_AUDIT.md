# Doorway NPC passage contract audit

Three independent controls exist: business room/service authority, door traversal
permission, and native/body-query/avoidance collision policy. The concurrent portal
patch changes only traversal permission for a geometrically supported real doorway.
Room slots, cashier/medic ownership, payment and physical completion stay separate.

Current native passage ignores only collected live NPC bodies with collision_layer
exactly1. It includes active residents and staff, never player, walls or door bodies.
The same admitted centre-zone members provide native symmetric exceptions, query
RID exclusions and avoidance's same-zone ignore. Native exceptions owned by this
service are removed on zone exit, layer change/death, free and scene exit. Existing
external exceptions retain their ownership flags. Layer512 debris/corpses are not
passage peers; hit rays do not use these RID exclusions.

Two finite-scope holes remain, separate from the portal queue correction:

1. Centre-zone boundary. The depth limit is3.3m. Two.36m-radius NPCs can contact
   while one centre is just inside and the other centre is still outside. Example
   at the compact doorz3.5: insidez6.5, outsidez7.22; their capsules touch before
   the outside centre reaches the zone endz6.8. No native pair is granted and
   avoidance still sees a conflict, even though a query at a future inside point
   can exclude the inner peer. Removing exceptions as centres leave while capsules
   still overlap can also trigger native separation. This is source-derived; a
   dedicated native boundary reproduction is still required.
2. Member33 remains a known actor but receives no body-zone/native permissions,
   while query_exclusions can exclude admitted32. The earlier isolated
   services31_extended/overflow_consistency patch corrects that disagreement only;
   it does not authorize larger crowds. Current10 residents+12staff cannot exceed32.

Simply padding the centre zone moves the boundary and does not remove the first
counterexample. A proposed follow-up policy, not implemented in this package:

- Keep the measured door zone as the initiating area. Grant an NPC pair when both
  are current zone members, or when one is a member and the other's live capsule
  is within a short contact allowance of it, with overlapping vertical spans.
  Use actual capsule dimensions and one native-step allowance, not an unlimited
  radial ignore or all-world NPC collision disable.
- Retain a granted pair while its capsules still overlap/contact, even if their
  centres just left the zone. Retire it when separated, or immediately on death,
  free, invalid identity or closed/retired venue. This avoids removing a native
  exception in the middle of an overlap. The allowance does not propagate from a
  fringe body to a third body: at least one original zone member must initiate it.
- Store explicit per-body pair permissions, rather than pretending the fringe body
  belongs to every nearby door. Native exceptions and avoidance consume the same
  current pair identities. Physical planning evaluates the same geometric predicate
  at its prospective capsule location; sweeps need the closest relevant point on
  their segment. Current live native movement remains the final collision guard.
- Preserve player/world/door/debris masks and hit queries. First test boundary
  inbound/outbound, both bodies leaving while overlapped, intersecting door zones,
  closed door, corpse/respawn, unrelated outsider, and ownership cleanup. Then test
  contact discovery cost with10+12 and overflow explicitly; do not raise caps to
  hide missing permissions or claim30+ acceptance from this audit.

This additional policy needs native evidence and root approval for integration.
The smaller concurrent-portal correction already has a matched native PASS/FAIL
pair and can be reviewed independently. The roaming resident in a door leaf's swing
is a separate physical-door issue owned by the QA route/door agent.
