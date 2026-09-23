# Building shadow culling default audit — 23 September 2026

Source default changes from opt-in to enabled, with
`buildingshadowcull=0` as the independent rollback. The historical
`buildingshadowcull=1` URL remains compatible.

The optimization only rejects a building draw from the directional sun shadow
pass when the complete conservative swept sphere misses the current rendered
camera frustum. Main rendering, scene visibility and `castShadow` remain
unchanged. Unsupported materials, animated or custom shadow paths, stale batch
bounds, nonstandard shadow cameras, manual shadow updates, other scenes and
other lights fail open to the original draw.

Focused CPU/actual-Three checks cover 76,320 sampled swept-volume points,
multiple building bounds and camera poses, day/evening/night intensities,
hidden and layer-filtered hierarchies, detach/reparent and owner mutations,
fallback InstancedMesh and stale BatchedMesh fail-open paths, manual-update
transitions, building opt-out, disposal/rebuild and exact full-map restoration.
The previously recorded frozen-scene ABBA remains the LIVE
evidence: shadow calls 2554 to 1477, total calls 7315 to 6238 and GPU p50 about
96.97 to 91.40 ms at one daytime view. Broader LIVE views remain useful for
performance characterization, but the source proof does not depend on that
specific camera or sun intensity.
