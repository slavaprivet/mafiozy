# Facing at walls and cars — 2026-09-09

User reported that walking close to a car or building left the hero facing
sideways and requested being able to stand facing the obstacle.

Cause: `walk_preview.mjs:moveHeroOnFoot` took facing from collision-resolved
displacement, only when movement succeeded. Sliding turned the hero parallel
to the obstacle; full blockage prevented correcting that orientation.

The adapter now takes facing from the requested nonzero horizontal delta.
Collision resolution, actual displacement, camera translation and the `moved`
animation flag are unchanged. Zero input preserves facing. Existing combat,
vehicle transition and dropkick facing overrides retain their precedence.
No hero/artist14 module was edited.

Validation: `test_walk_facing.mjs` exercises the actual production adapter
against rotated walls and both sides of rotated cars, checks blocked turning,
diagonal sliding, release, collision clearance and camera displacement.
It passes, as do walk_motion, surface_motion and walk syntax checks.
HTTP at port 18538 serves the modified code. Live browser validation remains
pending: browser discovery failed twice with
`Unable to load browser request-header policy`. The user tab was not closed
or refreshed; a page refresh is needed to load the modified JavaScript.
