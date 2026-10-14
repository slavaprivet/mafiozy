# WALK map editor — special anchor audit (2026-09-23)

## Status and scope

This audit covers the three authored bank shells and the three native detention
sites which are intentionally locked in the map editor. It is a source/runtime
dependency audit and an isolated migration-contract implementation; it does not
change `walk_preview.mjs`, `world.html`, the backend, or current editor lock
classification.

**Decision: keep all six records locked.** Their visual transforms cannot be
published losslessly by the ordinary authored-building commit path. A preview is
not a commit. Unlock is allowed only after the complete consumer inventory below
has a trusted rebuilt receipt bound to one atomic plan digest.

## Exact inventory

### Banks

The authoritative authored file contains exactly three bank shells:
`buildings_placement.v1.json:13144`, `:13512`, and `:13880`. All three have a
stable `gameplayId` but still declare `gameplayActive: false`.

| Authored ID | Stable gameplay ID | Authored entry RC | Authored road probe RC | Legacy `BANKS` RC | Ledger planned RC |
|---|---|---:|---:|---:|---:|
| `REBUILD-bank:small` | `bank:small` | `[32, 54.743902]` | `[32, 56.243902]` | `[5, 15]` | `[86, 30]` |
| `REBUILD-bank:medium` | `bank:medium` | `[156.5, 42.475610]` | `[156.5, 44.225610]` | `[15, 55]` | `[92, 132]` |
| `REBUILD-bank:large` | `bank:large` | `[159.707317, 51.5]` | `[163.207317, 51.5]` | `[55, 35]` | `[60, 69]` |

These are three different coordinate systems, not rounding drift:

- the active legacy registry is `world.html:6073-6078`;
- the rebuild ledger has `binding: null`, all seven acceptance checks false and
  `awaiting_binding_and_live_checks` for `bank:small`, `bank:medium`, and
  `bank:large` (`docs/city-rebuild/rebuild-ledger.generated.json:18-141`);
- the rendered authored shells expose their own derived entry, road probe,
  footprint and collision geometry, and are explicitly inactive.

Therefore `gameplayId` proves identity only. It does not prove that the legacy
robbery runtime has been rebound to the rendered shell.

### Detention sites

The native source contains exactly three records and the destination registry
contains exactly the same three stable identities:

| Authored ID | Destination ID | Road stop RC | Handoff RC | Intake RC | Release RC |
|---|---|---:|---:|---:|---:|
| `REBUILD-DETENTION-southside` | `detention:southside` | `[105.365854, 156.004878]` | `[104.780488, 156.004878]` | `[102.682927, 156.004878]` | `[103.912195, 155.595122]` |
| `REBUILD-DETENTION-chinatown` | `detention:chinatown` | `[88.004878, 4.621951]` | `[88.004878, 5.219512]` | `[88.004878, 7.317073]` | `[87.595122, 6.087805]` |
| `REBUILD-DETENTION-iron_harbor` | `detention:iron_harbor` | `[152.597561, 65.995122]` | `[153.219512, 65.995122]` | `[155.317073, 65.995122]` | `[154.087805, 66.404878]` |

The source anchors are not limited to a building transform. Each record owns
`footprint`, `entryCorridor`, `stopFootprint`, `stopLane`, collision polygons and
collision rectangles (`detention_native_sites.v1.json:32-71`, `:261-300`,
`:490-529`). The published registry marks the corresponding destinations
`nativeReady: true` (`detention_destinations.v1.json:5-74`).

## Bank dependency inventory

The following consumers must be rebuilt together. This list is represented by
`WALK_MAP_BANK_ANCHOR_CONSUMERS` in the isolated compiler.

| Consumer | Exact dependency / evidence |
|---|---|
| `legacy-bank-registry` | `BANKS` owns stable ID, old `r/c`, size, bags, guards, reward and police delay (`world.html:6073-6078`). |
| `map-bank-tile-reservation` | Map construction reserves a legacy 3x3 area around each `BANKS` record (`world.html:6342-6350`). |
| `bank-interaction-entry-exit` | `_bankInteractionAnchor`, distance, authored-door registry, `_bankDoorCoord`, enter and exit all depend on exterior bank coordinates (`world.html:9802`, `:20865-20891`, `:66201`, `:66474-66476`). |
| `bank-van-zone` | Robbery van zone is derived from `bank.r + 4`, `bank.c + 1` (`world.html:58561-58563`). |
| `bank-snitch-exit` | Snitch exterior placement uses legacy bank `r/c` (`world.html:66906-66915`). |
| `bank-police-dispatch` | Client response cars spawn around legacy bank coordinates (`world.html:14720`). |
| `bridge-bank-snapshot` | The 3D/world bridge exports the legacy `BANKS` registry (`world.html:70971`). |
| `bank-native-shell-entry-collision` | Authored entry/profile code derives physical room, partitions, vault point and bank collision from the shell-local profiles (`building_entry_profiles.mjs:107-109`, `:129`, `:237-240`, `:278`). |
| `bank-interior` | Active robbery state, guards/civilians and room transitions are keyed by stable bank ID and use an independent local interior coordinate system (`world.html:23999-24024`, `:66368-66449`, `:66924-66940`). |
| `bank-vault` | Native shell planning uses `bankLayout`/`bankRoomProfile`; the active `_bankInt` vault/bags flow is separate and must keep the same bank ID (`interior_bank_room_plan.mjs:11-85`, `world.html:66368-66449`). |
| `bank-door` | `bankDoorProfile` is a shell-local contract while exterior entry/exit are world anchors; both must be validated (`building_entry_profiles.mjs:107-109`, `world.html:66201`). |
| `bank-guard-civilian-state` | Guard/civilian state and cooldowns are keyed by bank identity, not a scene object (`world.html:23999-24014`). |
| `server-bank-robbery` | Server robbery state and rewards are keyed by `small/medium/large` (`mafiozi_bot.py:34045-34205`). |
| `server-bank-police-spawn` | Server police spawn has a second hard-coded old-coordinate table (`mafiozi_bot.py:34456-34463`). |
| `bank-safe-policy` | A native bank vault intentionally does not register a generic interior safe (`building_interior_design.mjs:56-61`); the safe manifest contains no bank building IDs. |
| `bank-property-delivery-policy` | Loot may be delivered to an owned apartment or business, but the bank itself is not an apartment/business property. Ownership and stolen-bag updates are external targets and must remain stable (`mafiozi_bot.py:34218-34250`, `:34385-34446`). |

The existing `gameplay_migration.mjs` can produce detached bank/business/POI
remaps (`:57-150`), but it is not a publication receipt and does not resolve the
three-way bank coordinate divergence above.

## Detention dependency inventory

The following consumers must be rebuilt together. This list is represented by
`WALK_MAP_DETENTION_ANCHOR_CONSUMERS` in the isolated compiler.

| Consumer | Exact dependency / evidence |
|---|---|
| `detention-native-source` | Owns transform, footprint, corridor, stop rectangles, collision and stable IDs. |
| `detention-destination-registry-client` | Browser loads only `nativeReady: true` destinations having stop/handoff/intake/release (`world.html:15652-15655`). |
| `detention-destination-registry-server` | Server independently loads the same registry and accepts only native-ready records (`police_convoy.py:11-27`). |
| `detention-road-stop-pose` | Pose is derived from `stopFootprint`, yaw and detention-specific kerb inset (`detention_road_stop_pose.mjs:8-24`). |
| `detention-entry-runtime` | Physical doors, room, collision bodies and moving gate derive from the native record (`detention_native_sites.mjs:151-315`; `building_window_integration.mjs:8,37`). |
| `npc-detention-access` | Door lookup is by `detentionId`/instance ID and validates the live transform/proximity (`npc_detention_access.mjs:5-16`). |
| `police-response-bays` | Police response bays derive around the detention stop while excluding custody points (`world.html:14735-14765`). |
| `police-convoy-route-booking` | Client selects a native stop, walks the handoff/intake sequence and opens/closes physical detention doors (`world.html:15667-15672`, `:15811`, `:15905-15925`, `:15992`, `:16060`); server validates stop/intake/booking (`police_convoy.py:192-220`, `:258-270`). |
| `police-intake-spawn` | Station officers orient/spawn from handoff/intake (`world.html:15010-15016`, `:15905-15925`). |
| `player-jail-respawn` | Jailed reconnect and jail bounds use the destination intake (`mafiozi_bot.py:17102-17107`, `:18515-18516`). |
| `road-walk-vehicle-navigation` | Service destinations/routes consume stop footprints and service access (`city_road_destinations.mjs:5`, `city_road_navigation.mjs:14,27`, `city_service_access_plan.mjs:43`); the walk worker snapshot also copies detention stop/yaw (`walk_preview.mjs:317,528`). |

`detentionDestination()` already defines the exact local-to-world relationship
for stop/handoff/intake/release (`detention_native_sites.mjs:19-26`). The isolated
compiler reuses that function after transforming every world-space rectangle and
collision polygon. Its output deliberately has `nativeReady: false` until an
atomic receipt exists.

## Isolated migration contract

`walk_map_editor_special_anchor_migration.mjs` implements a pure, detached
contract only:

1. `prepareWalkMapBankAnchorBinding()` verifies the stable bank crosswalk and
   preserves `bankLayout`, `bankRoomProfile` and `bankDoorProfile` byte-
   semantically. It exports explicit exterior entry, road, footprint and
   collision anchors while preserving economy/identity and the safe/property
   policies.
2. `migrateWalkMapDetentionAnchors()` supports horizontal movement and cardinal
   rotation at the authored scale. It migrates footprint, corridor,
   `stopFootprint`, `stopLane`, every collision polygon/rectangle and regenerates
   the destination with `nativeReady: false`. Scale, height and non-cardinal yaw
   are rejected because their navigation/collision semantics are not proven.
3. `auditWalkMapSpecialAnchorCoverage()` requires exact `3 + 3 + 3` record
   counts, stable crosswalks, and a revision-bearing ready state for every
   consumer in this document.
4. `createWalkMapSpecialAnchorMigrationPlan()` requires all six records and the
   revisions of five authoritative sources: buildings, detention sites,
   detention destinations, browser bank registry and server bank config. A plan
   is always `readyForCommit: false` and `previewIsCommit: false`.
5. `validateWalkMapSpecialAnchorReceipt()` accepts only a rollback-capable,
   SHA-256 plan-bound full-rebuild receipt. Every consumer must acknowledge
   `rebuilt`; every artifact must acknowledge `published` with a revision.

No function mutates its input or writes a source file.

## Required atomic full-rebuild transaction

1. Freeze and digest the five authoritative source revisions listed above.
2. Resolve the exact six stable IDs and explicitly choose the bank exterior
   authority. The current legacy, ledger-planned and rendered-shell anchors must
   not be mixed.
3. Derive all building geometry first. Then derive every bank exterior consumer
   and every detention stop/handoff/intake/release/service/collision consumer.
4. Validate protection, topology, overlap, roads, pedestrian/vehicle routes,
   parking, doors, entry/exit, vault flow, robbery flow, custody convoy, booking,
   reconnect spawn and client/server parity.
5. Stage all five artifacts and rebuild all browser, walk and server registries
   against the same plan digest.
6. Obtain one receipt listing every required consumer and artifact revision.
   Only then may the editor document and scene/registries swap atomically.
7. On prepare, validation, publish, rebuild or swap failure, restore the editor
   document, scene transforms, all registries and all source revisions. A staged
   destination remains non-native and a preview transform is never accepted as
   the authoritative commit.

## Unlock acceptance checklist

- Exact inventory is still 3 banks, 3 detention sites, 3 detention destinations.
- Bank exterior authority is explicitly selected and the other two coordinate
  sets are migrated or retired with a recorded compatibility decision.
- Each bank opens from its rendered door, exits to the same door, shows the
  correct interior/vault/guards/bags, preserves reward/delay, spawns response
  police at the moved bank, and delivers loot only to the selected external
  property/business target.
- Each detention has a reachable road stop and collision-free stop lane; convoy,
  doors, handoff, receiver, intake, booking, release and jailed reconnect all
  use the same stable destination ID and rebuilt coordinates.
- Pedestrian, NPC, vehicle, service and parking navigation pass for every site.
- Client registry, walk scene and server report identical plan digest/source
  revisions.
- Forced failure at prepare, publish, rebuild and final swap restores document,
  scene, registries and files; reloading the game shows the pre-transaction map.
- Receipt validation passes; only then may the six editor locks be removed.

## Current blockers

1. No trusted consumer inventory or atomic rebuild executor currently produces
   the required revision-bearing acknowledgements.
2. Bank exterior authority is unresolved: legacy runtime, rebuild ledger and
   rendered shells disagree materially.
3. Server bank police spawn remains hard-coded separately from the browser.
4. Detention publication spans two JSON sources plus client and server loaders;
   ordinary building commit cannot update them atomically.
5. No LIVE end-to-end failure/rollback proof exists for the six-record set.

Until those blockers are closed, the correct editor behavior is visible but
locked records with a protected/full-rebuild reason.
