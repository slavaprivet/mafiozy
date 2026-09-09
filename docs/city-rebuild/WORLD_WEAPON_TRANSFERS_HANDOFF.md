# Authoritative weapon transfers — 2026-09-09

Implemented `weapon_transfers.py`, new persistent tables initialized by `init_db`,
and narrow `mafiozi_bot.py` HTTP/factory/cache hooks. Existing source inventory,
equipment, ammunition, actor-binding middleware and WorldSim remain owners.
No user database, credentials, player balances or live inventory were changed
by development/tests. No live server was restarted by this agent.

## Contract

- `GET /inv/{uid}/weapon-ground`: `{ok, server_now, ttl_seconds:300, drops}`.
- `POST /inv/{uid}/weapon-drop`: `{request_id, item_id?}`. `item_id`, when
  provided, must equal the currently equipped original catalog ID in SQLite.
- `POST /inv/{uid}/weapon-pickup`: `{request_id, drop_id}`.
- Existing authenticated `/inv/` middleware binds the URL character to the
  request's verified identity. No UID/authentication is accepted in JSON.
- Success transfers return `{ok, action, drop|pickup, equipped_weapon,
  combat_version, inventory:[{id,qty}], weapon_classes, ammo_state, server_now}`.
- Drop shape: `{drop_id,item_id,weapon_key,magazine,r,c,elevation,space,layer,
  created_at,expires_at}`. Timestamps are server epoch **seconds**; coordinates
  `r/c` are original world cells, not metres. Native scale is 4.1 m/cell.
- `request_id` must remain identical across retries of the same logical action;
  unique across new presses. Reuse with another action/target returns
  `request_conflict`. Replays return the original receipt plus CURRENT equipped
  weapon/ammo/inventory snapshot, so they do not restore stale selection.

`bot.weapon_transfer_service(world)` allows a local host to inject its existing
WorldSim. Host must retain its existing authenticated routes and persistent DB;
never invent an account/query identity. After a transfer call
`bot.mirror_weapon_transfer(world, uid, result)` to refresh the existing firing
ownership cache. It ignores obsolete transfer-state versions. Production HTTP
handlers already call it. This agent did not edit `_preview_ws_server.py`.

## Lifetime / ammo / ownership

The new drop receives `expires_at=server_now+300`. At and after that instant it
is unavailable, omitted from ground lists and deleted by the next ground-list
or successful transfer transaction. Expired rows cannot be picked up, including
after process restart. Pickup+new drop creates a NEW drop ID and full new timer;
replaying an old request cannot refresh the old timer or mint an item.

SQLite `BEGIN IMMEDIATE` serializes two competing pickups, duplicate requests,
equip/damage and inventory changes. Storage failure rolls the whole transfer
back. Nearby lists are bounded to 256 records/100 m; live drops are capped at
64 per owner and 2048 total. Transfer receipts persist for replay safety.

Shared reserve remains in the dropping player's pockets. Existing source ammo
magazines are keyed by family (e.g. AK74/M16 share `rifle`). The LAST owned
weapon in that family carries its magazine; dropping another copy carries zero
and leaves the shared magazine with the remaining gun. Pickup with no existing
family restores that magazine without equipping; if the recipient already has
the family or an existing loaded/reloading slot, carried rounds enter reserve
instead. Current magazine/reload/selection are unchanged. If that reserve is
full the entire pickup is rejected, without lost rounds/items. Outgoing reload
is cancelled only for the dropped family and never consumes reserve. Cooldown
is carried and merged with `MAX`, not reset. Actor movement/health are rechecked
after acquiring the writer lock.

`ensure_owner_entry_loadout` previously restored the owner's entire arsenal
on EVERY inventory fetch, which would duplicate drops. Intentional drops now
persist a per-owner/item suppression; only that item's automatic restoration
is skipped. Other owner loadout/cash behavior is unchanged. Explicit future
shop purchases/pickups still work. Source-granted (non-inventory) family/reward
weapons and non-firearm catalog entries are not converted into transferable
items by this feature.

## Geometry limitation — do not conceal it

Current production WorldSim tracks accepted x/y cells, interiors and transport,
but has NO validated walk floor/elevation API. The default adapter supports
EXTERIOR GROUND ONLY, rejects source interiors and explicit non-ground layers,
and uses accepted WorldSim position+LOS+2.2 m range. It ignores all HTTP position,
height and layer fields. Root must gate transfers on elevated walk floors so
an upper-floor object is not accidentally dropped at street level. The service
supports injected server-validated `{r,c,elevation,space,layer}` later, and checks
same space/layer and vertical distance. Do not trust client height as a shortcut.

## Tests

- `python -B test_weapon_transfers.py`: PASS 10 tests. Includes actual production
  HTTP closures/middleware compiled by AST into an aiohttp test server, missing
  auth/cross-actor rejection, ignored HTTP coordinates, 12 duplicate drops,
  two-player pickup race, TTL/reset/replay, ammo conservation/held reload,
  full-reserve rollback, storage rollback and actual owner-restoration guard.
- Existing `test_server_authoritative_ammo`: PASS 18 tests via a guarded import
  harness. The old bot import writes an env test token to `.bot-token`; the
  harness intercepted ONLY `.bot-token` writes into `io.StringIO`. Its legacy
  log says “copied” even though no real token file was written. Do not run the
  existing env-token tests unguarded against this shared repository.
- Live client/preview endpoint registration remains root-owned; these server
  tests do not constitute full authenticated browser acceptance.
