# Static render cull updates — 2026-09-09

Static render batches now calculate distance once per placed object, shared by
all its mesh members. Per-member visibility/matrices are written only when the
decision changes; unchanged InstancedMesh fallback buffers stay clean.
The 220 m caller threshold and 250 ms caller cadence are unchanged, as are the
comparison, source raycasts, geometry, materials and hidden-proxy exclusion.

Validation: exact visible slots and instance transforms against the former
distance rule across 240 updates for both BatchedMesh and InstancedMesh paths,
including threshold boundaries, stationary focus, movement, range changes and
no-focus reset. Test scene: 20 placements x 10 parts; previous 48000 writes,
new 1020 writes per path; distance evaluations 4780 instead of 47800.
These are operation counts, not a full-game FPS measurement.
Existing real-GLB batching/15 hidden collision proxy tests pass.

Browser discovery still fails after resetting the CUA session with
`Unable to load browser request-header policy`. Visual QA remains pending;
user tab was not closed or refreshed. Reload required to load the new module.
