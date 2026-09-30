# Current23h NPC RPG recipient proposal

Prepared only; no shared runtime, generic physics, sever files, Git, GPU or owner messages changed. Base is frozen candidate16, whose NPC owner/lifecycle remain accepted23g (`0a3e311d…` / `80f7a0cb…`). `RECEIPT.json` guards complete hashes; `PROPOSAL.patch` contains two narrow overlays; gate `e6f94752…` is copied byte-exact from Artist's reviewed packet.

## Composition APIs

Recipient methods: `bind_native_rpg_gate(gate:RefCounted)->bool`, `accept_native_rpg_blast(gate:RefCounted,ticket:RefCounted)->Dictionary`; existing `current_damage_context()->Dictionary` stays unchanged. Binding requires the exact preloaded RpgGate script, current resident/weapon ownership and membership in the gate's exact three recipients. Arbitrary RefCounted or subclass/mock gates are not accepted.

Root configures `Gate.new().configure(weapons, population.residents, population.hit_owners, Callable(population.hit_owners[0], "current_damage_context"))`. Preserve the already existing original shared accepted-shot registry; do not supply constant critical/marksman values. Root hooks remain Artist's `before_ammo_commit` → actual one-round inventory settlement → actual Flight commit → `after_ammo_commit` → existing accepted-shot signal, synchronously. Flight's only native query calls `gate.native_query`; native impact calls `gate.native_impact` before cosmetics, including range-end. Dispose gate before weapon effects/recipients.

The recipient consumes only an opaque ticket during the authentic gate's busy callback. It rechecks gate epoch/disposal/live identity, captured binding/token and current recipient after ticket validation and again before physical publication. It passes the proved source hit through existing HP adapter. Lifecycle changes one RPG admission guard only; lethal anatomical-head guards remain unchanged. No caller damage dictionary or cosmetic explosion grants HP.

## Physical and visual scope

Existing user-tuned horizontal `HitImpulse.blast` uses actual target/epicentre horizontal separation. **Epicentre is never an anatomical contact.** The physical reference is the actual target anchor. Initial transition gives the entire requested J uniformly through existing mass-partitioned ragdoll start. Point share is exactly zero and the nearest-segment API is skipped. Existing bullet point, head, blood, marks and foot code remain intact; medical initial J retains the 75 N·s cap.

No invented RPG bullet hole or skin blood mark is emitted. Existing source bleeding/medical/final state still runs through the HP lifecycle. No detached limb or generic body/sever merge is included.

**Explicit incomplete physical case:** an already ACTIVE medical body accepts a true RPG finisher and confirms final death on the same physical body, but the accepted body's public API does not offer an owner-reviewed mass-distributed active blast operation. The returned `blast_physical.status` is `HOLD_active_uniform_port_or_activation_rejected`, `applied=false`; no corpse restart or full450Ns nearest-part substitute occurs. The native test verifies this limitation. Whole RPG physical acceptance must not be claimed until that owner-reviewed port exists. Source/social/server authority also remains the existing local-new-session scope.

## Native proof

`native02/RESULT.json`: **135 checks PASS / 0 errors**, 9.186 seconds, Godot4.7.2 headless. Uses actual main and all three original rigs, authentic gate, actual Fire/Inventory/muzzle/Flight/native ray, original current HP/physics owners. The test supplies the two intended Flight callbacks and manually performs real source-plan/ammo/Flight commits; it is explicitly **not** root's final ordinary-input integration test. Clinical survival RNG is seeded; HP is not set directly.

- First final blast: three final deaths, 16 original parts each. Measured mass-weighted incremental momentum matches each requested uniform J within0.05N·s; no point event or fake bullet mark.
- First medical blast: three HP1 survivors, medical state and 75N·s cap retained, conserved mass-partitioned impulse.
- Real R reload, second native blast at the actual fallen anchor: source final-death receipt, same body, explicit ACTIVE uniform-force HOLD, no fake new J/restart.
- Arbitrary gate, counterfeit opaque ticket, rebind, impact replay rejected; disposal inside live damage-context callback prevents all HP/force.

`native01` retains earlier84PASS evidence and exact prior test copy. Native02 supersedes it. Existing ordinary owner methods other than `dispose` and `_publish_physical` are byte-identical after newline normalization; this is recorded in receipt. Both changed methods retain existing behavior outside the admitted blast branch. This static preservation is not a substitute for root's final ordinary-head/foot/GPU/performance integration regression.

The proposed owner is `407f2650fbc2db7a2e4437e4907cd533c9103c7473cfacfd8d9260f60c7390c5`; lifecycle `3d7c8fab1d4c9632669702c3e7479ff5ec85301fc1c7aeb45dc4bf40f1ac8e88`; gate `e6f94752f9609aee3d7674c58280e7016f89cebf58c68ab85462b730b4b7aebe`.
