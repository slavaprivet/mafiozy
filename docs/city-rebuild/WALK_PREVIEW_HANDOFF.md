# Actual 3D placement preview — not the main game

URL: http://127.0.0.1:18538/walk (same single browser tab as the rebuild monitor).

This scene loads the authored GLBs, checks each loaded file's bytes and SHA256,
and applies the generated transforms. The live browser reported 236 objects:
72 buildings of 19 types and 164 decor instances. The ground comes from the
native 200×180 placement grid, with the artist's extracted
`MAT_CLAY_ASPHALT_CLEAN` material. Roads are batched rather than per-cell GLBs.

Controls: Orbit mouse/zoom; toggle WASD walk, Shift faster; select an asset type
to inspect it. The walk camera checks the native walkable mask and placement
collider polygons. This is an exterior inspection camera, not the game's
character controller or a proof that every door can be entered.

Source files: `tools/city_rebuild_walk.html`,
`assets/maps/city_rebuild_v1/walk_preview.mjs`, `tools/city_rebuild_monitor.py`.
The loopback server exposes only the monitor, walk page, snapshot and scoped
asset paths; it has no write endpoints, game socket or database connection.
Templates are shared and distant objects are culled. Keep just one browser tab.

## Deliberately incomplete

- No economy, authoritative gameplay, NPCs, vehicles, train or interiors here.
- No main push or production migration was performed for this rebuild.
- Police remains a protected reservation pending an actual game-host snapshot;
  its old game scene is untouched. Bridge road surfaces are topology, not proof
  that authored large bridge meshes have been installed.
- The available miniature bridge models do not span the proposed large crossings.
- Existing bank/business identities remain in the migration ledger; visual
  building placement does not activate those economic records.
- Fire station footprint still needs a larger suitable parcel.
- Some new materials/models await user visual acceptance. Technical tests do
  not imply that the entire city has reached the art reference.

## Artist13 playable preview hero

The accepted male GLB is now connected to this isolated map through
`hero_walk.mjs` and `walk_motion.mjs`, with a following camera, WASD movement,
Shift running, rest-relative locomotion and radius-aware obstacle checks.
Source GLB SHA256:
`8130dfb1f7eb91bff31e932feef1717672070a6767ccc726d7cb1ee23133fd00`.
Its geometry is unchanged, uniformly scaled to 1.9 metres. The actual GLB/rest
hierarchy/idle-recovery tests and wall/water/sliding tests pass. The browser
shows the character and reports `data-hero-walk` loaded, with no console errors
on initial verification. Combat, weapon handling and interiors are NOT integrated.

The next integration step is a coordinated fresh game bootstrap with both
client and isolated server anchors, actual police geometry, building entrances,
road routing and actor initialization. Do not hot-overlay this grid over the
old city or treat this standalone renderer as completed game integration.
