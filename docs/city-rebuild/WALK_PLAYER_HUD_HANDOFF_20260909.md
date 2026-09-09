# Player dossier and authoritative weapon transfers — 2026-09-09

## Implemented

- `walk_player_hud.mjs`, `walk_hud_shell.mjs`, `walk_hud_controller.mjs`: left dossier in the world/walk gateway; existing money, HP, level, clock, status, faction, inventory, newspaper, missions, empires and gang controls are reused, not simulated a second time.
- `world_walk_hud_data.mjs` under assets is the normalization/dispatch boundary; root file is a compatibility re-export. Lazy assets import works with the existing static-server allowlist.
- `walk_portraits.mjs` photographs actual 3D rigs. Hero appearance updates the real male/female model and its portrait; boss portraits use source render IDs and looks. Cached, sequential portrait generation; no continuous secondary scene.
- Existing windows stop walking, firing and camera input. The native gang DOM is temporarily moved into a drawer, preserving its buttons/listeners, then restored exactly.
- Weapon and fist thumbnails use existing game geometry. Shared styles now reach the gateway ShadowRoot; desktop legacy sticks/weapon bar are hidden only under the walk HUD marker.
- Authenticated network gateway G/E connects to the production transfer endpoints described in `WORLD_WEAPON_TRANSFERS_HANDOFF.md`. Only actual firearm inventory is transferable; grants/special items retain source actions. Picking up never equips, cancels reload or changes the held weapon. Network Q persists exact item IDs through server equip.
- HTTP retry uses the same receipt ID, uncertain replies reconcile before another equip/transfer, ground polls reject stale replies, and expiration uses server time. No optimistic local grant on server failure.

## Verification and limits

- CPU tests cover real male/female GLBs, portrait ownership/cache/disposal, source closures, HUD actions, source DOM restoration, ShadowRoot style lifecycle, 14 weapon IDs, retry/races, expiry, and the actual source pickup callback preserving the current reload deadline and magazine.
- Production transfer tests: 10 scenarios including authentication/cross-actor rejection, simultaneous pickup, repeat requests, expiry/reset and ammo conservation; existing authoritative-ammo suite: 18 pass. Tests use temporary databases and guard the bot import's legacy token-file write.
- LIVE local gateway: dossier and actual matching hero portrait visible; all 19 boss images populated; inventory and gang open original controls; movement remained unchanged while inventory open; no observed JS errors. This is a local preview, not a claim of real account/backend validation.
- `localhost:18538` is static preview. Its `_LOCAL_PREVIEW` intentionally disables authoritative ammo/network transfers; `/coop_api.json` is absent. No real server restart, deployment or inventory mutation was performed. Production API must be running and authenticated before multiplayer G/E can be LIVE verified.
- Server currently validates exterior ground only. Client explicitly blocks transfers on upper floors/interiors rather than placing an elevated item at street level. A real server-owned floor/elevation contract is still needed.
- Full face-geometry variants, hats beyond supported appearance accessories and armor cosmetics are not a completed character-creator migration. Existing incompatible wound mesh anchors prevent a destructive appearance swap; they are not silently erased.
- `/walk` standalone remains a visual test scene. Full source data uses `/world.html?render=3d&renderer=walk`, preserving existing authentication query parameters; no invented account/UID is added by the connector link.

## Concurrent ownership

Keep narrow patches in `world.html` and `walk_preview.mjs`; NPC/melee/gallery, landscape and vehicle owners are working concurrently.

## Status, membership and menu parity follow-up — 2026-09-09

- Added `walk_status_dialog.mjs`: current source role/faction, exact dollar balance, HP and the same actual hero portrait as the HUD. Updates while open; role-only actions disappear when permission is lost. Known civilian without a gang says so explicitly. Leader is not mislabeled as original founder: permanent gangs support leadership transfer and do not expose a founder field.
- Source HUD snapshot now includes the full permanent roster, including offline players, current leadership and per-row kick permissions. Existing load/snapshot notifications refresh the open native gang modal and roster. Player, NPC and boss portrait IDs are separately namespaced.
- Fixed backend temporary-party kick authorization (creator only, same party, no self-kick; self-leave remains), per-recipient role after an accepted permanent-gang invitation, and full membership notification/runtime refresh after a permanent-gang kick.
- Opening the new gang drawer does NOT add a state GET: the legacy GET can implicitly create a gang for an owned headquarters. Existing world synchronization remains authoritative. No new network mutation is attached to merely opening the drawer.
- All 16 HUD actions and 13 static main-menu buttons execute original world functions. Role/capability guards, confirmation routes, three profile slots, volume and vibration handlers are tested through actual extracted source bindings. Character cards now support Enter/Space without activating nested delete controls.
- Nine original window surfaces receive scoped graphite/burgundy/brass materials, legible text, focus and scrolling. A LIVE stacking defect was fixed: fixed `#stage` trapped source dialogs beneath the body HUD/minimap; walk-only `position:absolute;z-index:auto` retains the 1280×720 viewport bounds and source DOM but removes that unwanted stacking context. Default world styling is not changed.
- A real early-boot TDZ regression was found and fixed: the roster helper must not read the later `_mafiaState` before initialization. Family lookup is opt-in only from the fully initialized HUD snapshot.

### Follow-up verification

- PASS: `test_world_walk_hud_data.mjs`; asset tests `test_walk_hud_controller`, `test_walk_hud_shell`, `test_walk_hud_native_styles`, `test_walk_player_hud`, `test_walk_status_dialog`, `test_walk_menu_actions_parity`, `test_walk_hud_status_membership`, `test_world_walk_hud_bridge` (all `.mjs`). Six world inline scripts parse. Exact integer-string balances survive repeated normalization.
- PASS: `python -m unittest test_custom_gang_permissions_hud -v` (4/4 actual-source AST + temporary SQLite tests). Agent also ran these with the existing 10 weapon-transfer tests: 14/14 pass. No bot import, real database, token write, server start/restart or deployment in these gang tests.
- LIVE static preview: status and original role guide; inventory/status/business tabs; gang drawer; missions; newspaper; main menu/settings; empires-to-boss dossier. Final inventory screenshot and DOM hit tests confirm modal is above both HUD and minimap. Fist thumbnail visible. Final status shows `0 $`, civilian/no gang, matching hero portrait; Escape restores focus, movement lock returns to false. No new JS errors after the corrected reload; log history retains the earlier fixed TDZ errors.
- Limits: no authenticated production account was used. Real join/kick, purchases, account creation/deletion, exit and service employment were not exercised live; their relevant dispatch/permissions were checked with stubs or temporary DBs. News and online empire economics report unavailable server in local preview. Main-menu hero preview remains original world rendering; this follow-up changes materials/controls, not that character renderer. Artist14 independently owns the empire/boss layout and portrait upgrade.

## Latest car-name decision (supersedes real marques)

User explicitly changed the request to FICTIONAL names in a 1990s American-mafia setting. All 13 walk fleet display names are now: Kingswell, Brooklyn SX, Easton S, Brooklyn LX, Bellhaven V8, Ravelli GT, Blackridge, Union Van, Ironvale, Metroline 90, Patrol LX, Union Medic, Ironvale F. No real marque names in this new catalogue. Only labels changed; model IDs, geometry, hashes, physics and ownership were preserved. `test_vehicle_prompt_names.mjs` verifies the actual E-entry prompt uses each exact model name and seat, and locks this fictional catalogue against accidental reversion. Vehicle owner was notified of the superseding request.
