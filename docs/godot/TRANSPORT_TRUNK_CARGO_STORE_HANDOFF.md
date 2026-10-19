# Transport trunk cargo store candidate

## 30 September numeric fire-state fix for Root candidate02

The earlier store rejected valid items after firing because the reviewed Godot `Fire.step` produces an integral `float` sequence. A completed reload likewise produces integral `float` magazine/reserve values. The current store accepts both int and float representations only when finite, exactly whole, and within the source inventory bounds: magazine `0..profile.magazineSize`, reserve `0..9999`, sequence `0..9007199254740991`. It preserves the original numeric variants and the exact ammunition values. The profile dependency is `weapon_fire_profiles.gd` SHA `8a062c7a0c7e9e7db1a1b98c2ae524bdf8d66390b24070aa4e62f4e2dcd1ea4a`; unknown/mismatched weapon IDs reject. Fractional, nonfinite, negative and unsafe numbers reject. Cargo/vehicle ownership and geometry logic did not change.

Actual Godot 4.7.2 safe runner: **5384/5384 PASS**. The test executes source `Fire.step` firing and `Inventory` export through Store for all 14 IDs, plus completed source reload producing whole-float ammo and boundary/invalid inputs. The source Fire reload early-return can leave a negative cooldown, which `Inventory` rejects; Root owns and now clamps that already-expired cooldown at its inventory boundary. This test applies the same cooldown clamp before its reload transfer check without modifying any ammunition. Root's actual-main reload and live path remain required. The isolated 100-item transaction cost measured p50/p95 `1091.5/3061 us`, versus previous `1130/3292 us`; these runs do not establish full-city FPS. Runtime SHA `007e935a06253510db21fbf84a8ead3fd92239dc06a69943ed2833a297309afe`, test SHA `6d7778b97b85b66d2701866ad3cbe228a8af15914d19e57facc71a6b865f8e2b`. Root22 received this urgent fix before document freeze.

This additive candidate owns only data held inside an authenticated physical trunk. It does not own input, prompts, inventory, item rendering, weapon rules, lid motion, damage, pickups, corpse movement, Root authority, or LIVE wiring. The JavaScript trunk source supplies the physical opening and bounds rules but has no persistent storage or capacity system. The latest user policy is capacity 100, model-volume-derived costs where one of each of all 14 weapons totals 100, arbitrary weapon support, and a future exclusive corpse record. The earlier `ak74=15` example is superseded and is not enforced here.

## Pinned inputs

- `vehicle_trunk.mjs` SHA `91d8575b2f52ca10b43bfe73d4a004ec4ebfef7b066835c8d1ed1a46239f5fb0`
- `test_vehicle_trunk.mjs` SHA `49efb2d3240e5263a5dd55aff691934be4955d022d0a58369531840a63dd1b0c`
- `weapon_inventory.mjs` SHA `1c675610bcde2c40a0ef8deb74118ea085968b4bec7538ce8784f5d9ddb405de`
- `hero_weapon_fire.mjs` SHA `ae1a5b821b621cd2b0699c2f403a66f6f9f4de2bdbb5534a798d5dec2f95e4d8`
- native cargo admission SHA `ddc78bc1c7f0dc34e393c90a344dd4b27d004bf41cd85f452122483e863d48bc`
- native cargo evidence SHA `a6e235b1b56c332f6a5a5b2283e3ad6d045876c46dc28b32fffed207db875a2e`
- native compartments controller SHA `99ee5fcd0b07cb9b918f90280d30ee3f462ab54537c0073f2b079e25d14ca9df`
- exported compartment descriptors SHA `423c09c28b0fbeac819e1d1b351087cdf2e05790254bb9e8371d4e1a2c1cbd51`

The 13 exported profiles retain their real cargo volumes. The smallest tested envelopes include hatchback `1.17 x .53 x .41 m` and compact/taxi `1.22 x .43 x .61 m`; bus is approximately `1.74 x 1.58 x 4 m`. The store calls the frozen evidence and admission providers and never substitutes a virtual chest.

## API and transaction seam

`configure(vehicle_root, vehicle_id, life_generation, evidence_provider, compartments)` requires exact native provider scripts, the same compartments instance, matching vehicle metadata, and a visual root currently inside that vehicle. This ancestry is checked again during every active preflight.

- `prepare_store(item, capacity_units, model_aabb, evidence_revision, generation, revision)`
- `prepare_take(uid, evidence_revision, generation, revision)`
- `prepare_destroy(event_uid, generation, revision)`
- `validate_pending(token, kind, generation, revision, evidence_revision)`
- `commit_store`, `commit_take`, and `commit_destroy` consume both the original token and the opaque validation seal
- `cancel(token)` abandons a reservation without moving ownership
- `destroy_once(event_uid, generation)` only replays an already committed destruction receipt
- `summary(generation)` returns bounded HUD scalars; `snapshot(generation)` performs defensive deep copies and is for event/debug boundaries only

Only one reservation exists at a time. Store/take validation resamples the current physical evidence and compares its full fingerprint. It requires the authenticated trunk target to remain open, visible lid evidence, opening amount at least `.85`, a floor and a valid physical volume. Closing the target immediately disables both interactions even while the lid remains visually high. Detached-lid operation is intentionally unsupported.

Validation emits a local seal after all external sampling. Every new validation attempt revokes the previous seal before checking any external boundary, and a repeated pending destruction request also revokes it; therefore a failed revalidation cannot leave an older commit capability alive. Root then validates inventory last and performs both paired commits synchronously, with no callback, `await`, provider call or other mutable boundary between validation and commit. `evidence_revision` is a Root-supplied transaction fence; the current evidence provider does not expose its own revision. A sealed commit deliberately performs local token/generation/revision checks only. Root must never retain a seal across frames.

Destruction is also two phase. `prepare_destroy` copies the stable records but leaves ownership in the trunk while Root reserves every ground pickup, physical position and model. `commit_destroy` clears ownership exactly once. After commit, replay of the same event uses only the live vehicle root identity and generation, so it stays idempotent even after explosion removes the visual. A different event or reincarnated root cannot obtain the receipt.

## Data and physical rules

Weapon records use canonical `uid`, preserve the `itemUID` alias, `weaponId`, and a defensive plain-data `fireState`. Nested Object, Resource, Callable, RID, cycles, non-string dictionary keys, nonfinite values, excessive depth/nodes or payloads over 64 KiB reject. The store checks source numeric fire-state bounds and known weapon identity; the authoritative Root inventory remains responsible for ownership, UID and the actual equipped item.

Every weapon requires explicit positive `capacity_units`; the store has no weapon-specific constants. Root's exact-bound catalog derives all 14 costs from actual model volume, assigns larger models more points, and must prove that the complete set totals 100. A future corpse record requires 100 units and excludes all other cargo, but this component does not move or render a corpse. Root must authenticate both the catalog cost and scaled actual model AABB before calling `prepare_store`; the pure store deliberately cannot distinguish a truthful catalog value from a caller-authored one. Until that bridge/catalog transaction is accepted with loaded-scene evidence, this package is **CANDIDATE / DO NOT ADOPT**.

Placement is deterministic inside the current source-derived volume. Stored AABBs never overlap and retain at least 5 mm separation. Godot's float32 `Vector3` rounded an exact `.005` frontier below five millimetres for actual compact-sedan AK/pistol bounds; the candidate now moves new frontiers outward by another `.00001 m` while retaining the strict 5 mm overlap test. This is conservative and does not loosen collision fidelity.

## Verification and cost

Godot 4.7.2 safe runner passes 5,384 checks. Coverage includes the real compartments/evidence scripts, physical opening/closing gates, source Fire/Inventory numeric transfer for all 14 IDs, positive catalog-supplied units without an AK special case, cross-vehicle configure and later reparent rejection, failed-revalidation seal revocation, generation and revision failure, UID uniqueness, plain-data rejection, defensive receipts, cancellation, sealed validation, store/take ownership, corpse exclusivity, two-phase destruction, post-commit replay after visual free, actual scaled AK-to-pistol float32 packing, 100 pairwise non-overlapping slots, and source SHA guards.

Quiet sequential isolated costs from the accepted author run:

- 10,000 empty prepare/cancel calls: block-mean p50 `120.019 us`, nearest-rank p95 `126.082 us`
- 100-item prepare/validate/commit: p50 `1119.5 us`, p95 `3029 us`, max `3352 us`
- `summary` with 100 items: `24 us`
- full 100-item snapshot serialization size: `72,272 bytes`
- 100-item destroy prepare / validate / commit: `1017 / 21 / 1163 us`

The populated benchmark uses 100 synthetic 3 cm boxes to exercise the policy limit and worst deep-copy/slot frontier, not real weapon packing. The actual regression covers the bridge-reported scaled AK and pistol AABBs. The 14-model authoritative catalog, mixed-model maximum packing, loaded-scene frame time and LIVE FPS have not been accepted here. HUD must use `summary`, not `snapshot` per frame.

The previous external Root bridge receipt used the superseded fixed/example cost policy and is withdrawn from this package. New evidence must pin the model-volume catalog, confirm all 14 costs sum to 100, place the actual scaled models without overlap, and measure the full bridge path. Isolated fixture evidence still cannot replace main/UI/GPU/FPS acceptance.

## Root integration dependency

Root owns the Russian prompts and input: show `G «Погрузить»` only for authenticated open trunk and a prepared model/item; show `E «Взять»` only when aiming a stored private model. Root prepares the renderer and model reservation before inventory/cargo ownership commits. Destruction reserves a distinct physical ground destination and pickup for every returned record before committing. No callback may occur during paired commits. This helper does not itself prove inventory authority, renderer success, model SHA/scale, ground placement, pickup creation or loaded-scene performance.
