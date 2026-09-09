# Source-world shots and exact contact receipts — Artist14

2026-09-09. Shared `world.html`, `mafiozi_bot.py`. This is the single existing world runtime; no additional health, ammunition, NPC AI, inventory or socket runtime was added.

## Renderer API

`Mafiozi3DBridge.getWalkWeaponOptions()` returns `{options:[{id,sourceId,label,count}],state}` from the actual `weaponsForPick()`. `id` is the artist canonical ID where a direct presentation alias exists; `sourceId` retains the original inventory class. Source pistol/heavy/gold/smg/rifle become tt_pistol/deagle/golden_colt/uzi/ak74. Other source IDs remain unchanged.

`selectWalkWeapon(id)` validates those options and invokes the existing source picker handler. Exact source matches take precedence over aliases; unknown IDs never become a free pistol. `none`, null, fists and unarmed select the actual unarmed option. `reloadWalkWeapon()` invokes `reloadCurrentWeapon(true)`. Both return `{accepted,state}`.

`fireWalkShot({angle,muzzleR,muzzleC,resolveContact})` invokes the original `fire()`, including ownership, ammo, shared cooldown, witnesses, walls, damage and network routes. `resolveContact({angle,range,weapon})` runs **after existing source spread**, with range in grid tiles. It must raycast actual final posed skin and scene occlusion and return null or `{npcId,point:{x,y,z},normal:{x,y,z},zone}`. Point is actual native walk world coordinates (4.1 units/tile), not author-bone coordinates. A precomputed `contact` is also accepted only if it still aligns with the final shot direction. Muzzle r/c is grid space, validated near the player.

Result: `{accepted,shotId,angle,range,contactAccepted,confirmed,state}`. `accepted` is trigger admission by the existing source clocks. It is **not** proof of damage or remote server ammo acceptance. A physical miss still fires and follows the existing source miss/environment route. All existing NPC candidate/cone/ray branches admit only the validated contacted native source entity; the former 2D radius cannot hit a crouched/prone body that the 3D ray missed. Ordinary world/canvas fire has no contact filter.

## Exact injury event

Listen for `window` event `artist14:confirmed-hit`. Detail is `{confirmed:true,source:'world',kind:'bullet',shotId,npcId,targetId,weapon,damage,point,normal,zone,fatal,at}`. It preserves the original actual point and normalized normal, and deduplicates by shot. Pending contacts expire after 15 seconds.

The renderer must defer that listener with `queueMicrotask` and pass the event through `worldWalkCombat.resolveConfirmedReceipt(event)` before `npcPopulation.receive`. The source-local ACK can occur synchronously inside `fireWalkShot`, before its returned shotId is available to the renderer. New `npc_contact_anchor.mjs` captures the original skinned mesh path/identity, triangle indices and barycentric weights. The combat adapter stores that local anchor by accepted shotId, then evaluates current `getVertexPosition()` on receipt. This keeps a delayed HTTP/WS wound on the same patch of a moving/crouching body; it never projects the stale original world position onto a different limb. Missing/replaced/invisible actors, invalid topology, duplicate ACKs and receipts older than 15 seconds return null. Pending storage has a 512-shot cap and a dispose method. No anchor goes over the network or authorizes damage.

Local NPC, city cop, beach, bank, ordinary interior and empire fighter receipts come from accepted source damage branches. Field/HQ empire boss receipts come after actual HTTP hit success. Cop, aggro, Michael guard, major guard and convoy receipts require successful server damage event **with matching own shooter_uid, native target and shot_id**. Claim/ammo replies and HP snapshots never create these injuries.

Server scope: `_attach_world_hit_shot_id` annotates only validated successful existing events. Original damage/ownership/cooldown routes are intact. Convoy's existing `player_shot` trace carries `confirmed_hit` and exact accepted damage metadata from the damage branch; a miss trace never carries a confirmed receipt. No server-supplied contact point is invented.

## Prone and startup

The existing authorizer now permits prone firearms, retaining death/cuffs/downed/stun/ownership/cadence checks. Prone grenade/molotov routes retain their prior restriction. Client prone exception is scoped to an active walk bridge shot; source stance is not falsified. The legacy 25-second canvas fallback skips `renderer=walk`; the dedicated host owns startup readiness/failure.

Restart the Python server to activate new server receipts and prone firearm admission. Parent owns that live rollout and final browser test.

## Validation and practical limits

- PASS `node test_world_walk_shots.mjs`: source syntax; physical miss and native target filtering; spread callback; exact point/normal; damage ACK identity/dedupe; actual picker/reload delegation and legacy isolation.
- PASS `python -B test_world_hit_shot_receipts.py`: real extracted receipt helper/convoy damage; range/wall/dead/observer/weapon misses; type/length/claim/replay/shooter/target checks.
- PASS `python -B test_world_weapon_authority.py`: existing damage/alias/ownership/cadence plus all authored prone firearms; death/cuffs/downed/stun/unowned rejection.
- PASS `node test_world_walk_gateway.mjs`.
- PASS `node assets/maps/city_rebuild_v1/test_npc_contact_anchor.mjs`: real male/female posed skin; movement, rotation, nonuniform scale and crouch; current triangle membership; local synchronous ACK microtask and delayed HTTP/WS ACK; identity, expiry, rejection and dedupe.
- PASS existing `test_npc_contact_ray.mjs` and `test_world_walk_combat.mjs` after anchor integration.
- Existing `test_npc_field_weapon_auth.py` fails a static string assertion requiring `_authorize_weapon_shot` inside the HTTP handler. That unchanged handler delegates `claim_player_weapon_fire`; its preceding behavioral checks passed. No unrelated handler/test authority rewrite was made.

The current contact contract represents one first NPC ray contact. Original shotgun spread, penetration and RPG splash still use source mechanics, but there is no separate 3D contact array for every pellet/penetrated body/blast wound yet. Do not advertise those as fully reconstructed 3D wound locations. Static catalogue-only actors without any existing damage handler remain non-authoritative; no fabricated damage was added. PvP is not enabled through the NPC-only walk contact contract. Parent owns the renderer ray/input hooks and live validation.
