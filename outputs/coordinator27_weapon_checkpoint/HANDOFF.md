# Weapon checkpoint — actual48 read-only slice

**Implemented, native functional PASS87; NOT production/restore acceptance.**

checkpoint.gd is real GDScript, tested against unchanged486 source pins of accepted48 (base SHA51484885ce069970cecb234b7c016d5cc7e3b5611c3422ddeaa915a0d9c712b7). game is an isolated exact copy; no production script, pointer, user save, credentials, browser storage or database was modified/read. QA/module live outside the game source tree and are launched by explicit external script.

## Implemented boundary

- capture(scene) synchronously observes real weapon/inventory/cargo/transport/player owners on the main thread, without awaits or scene writes. It checks pending transfer/shot/RPG/C4/transport state, captures inventory and item UID maps together with cargo revision/generation and ground records, then rereads owners/state and rejects a changed capture.
- DTO retains exact itemUID versus weaponId versus dropUID, actor/session/vehicle life references, fire state, serials, local destruction receipts, cargo capacity/geometry, monotonic clock and source/catalog hashes. No RID, native owner instance ID or opaque token becomes serialized authority. Existing itemUID strings happen to include their historical instance-derived component; they remain opaque original IDs and are never reminted.
- validate/encode/decode enforce the whole document, unique UID partition, identity maps, finite source ammo/sequence including integer-valued floats, exact schema/owner keys, capacity, geometry and expiry. Canonical wire uses explicit binary64 tags for fractional values; integer-valued numbers canonicalize to integers. No equality epsilon tolerates altered clock/position values.
- plan(document,current_document) produces only a same-local-observation reconciliation plan. Different session/life/revision/state, pending transactions and claimed server authority are rejected. Every accepted plan has restore_authorized=false, effects_applied=0, server_grants=0. No apply/adopt/load API exists.

## Actual native evidence

runs/import01/RUN.json: import PASS,10.383s,exit0/stderr0.

runs/native03/RESULT.json and RUN.json: **87 checks PASS**,9.839s,exit0/stderr0. All486 base/stage pins and helper/runner/engine pins verified before/after.

Loaded ordinary48 main with all three original NPC, native player, attached camera, vehicle and cargo. Real source APIs equipped TT, dropped it to ground, picked it up and opened the rear door; F/G engine input opened the actual trunk window and stored TT; native window take returned it. One declared player setup placement at real rear access uses a current floor ray. No vehicle/NPC/HP/shape edits, fake cargo items or direct ownership setters.

Five actual exports: initial.json, ground.json, picked_up.json, cargo.json, taken.json. All retain14 unique itemUIDs and896 finite cartridges. Original TT UID traverses owned→ground→owned→cargo→owned. Each phase checks unchanged live inventory/UID/ammo/cargo/player position/life/epoch/NPC identities and HP before/after capture, codec and plan. Transfer APIs themselves deliberately move the item; checkpoint does not.

Negatives: duplicate UID within owned and across owned/cargo; missing actor/UID/cargo owner; unsupported schema; cross-session; stale actor/vehicle life and cargo revision; pending transactions; forged server authority; nonfinite/fractional invalid ammo; malformed host state; cargo alias/capacity/geometry; expired ground clock; truncated/duplicate-key JSON; invalid/NaN float tags. A real inventory reservation blocks capture without cancelling it; its original owner then cancels the issued token.

native01 is preserved FAIL: decimal JSON reserialization changed ground document canonical bytes. native02 verified explicit float wire with78 checks. native03 adds malformed-form negatives and passes87. Frozen helper copies are retained per run.

## Cost and limitations

Five native03 capture observations:4274/4357/5376/4881/4342µs on the scheduler's restricted two-CPU headless lane. These are event-boundary observations, **not** matched frame-time/FPS, percentiles, save/load pause acceptance or full performance benchmark. Do not put synchronous capture in a per-frame loop.

First supported domain: current48's one local vehicle, on-foot actor, settled weapon transfers and no active projectile or planted/in-progress C4. Destroyed cargo/nonempty destruction receipt require further reconciliation; exporter fails closed for them. This does not migrate NPC HP/death, player health, service ownership, banking/economy or full world saves.

Capture reads exact48 internal serial/tombstone/pending fields alongside public snapshots. Production should expose equivalent narrow read-only owner methods reviewed by root/transport/weapons owners; this prototype does not patch them.

Fractional float wire is tested on locked Windows Godot4.7.2; cross-platform adoption is not claimed. Actual cross-restart adoption needs trusted provenance, fresh runtime capabilities, clock reconciliation and owner reconstruction. Server ACK comes only from a trusted service adapter; JSON plan grants nothing. Output files are private QA artifacts, not new user save slots.

## Reproduce

python -B outputs/coordinator27_weapon_checkpoint/runner.py run --label FRESH_LABEL

Runner acquires scheduler headless/read lease, registers only its child, enforces85s watchdog plus65s fixture deadline, preserves user game/editor and pins source/helper/engine bytes. Import/staging use write leases. Own children exited; final inventory retained. EVIDENCE_FREEZE.json pins sources/proofs excluding generated game cache.
