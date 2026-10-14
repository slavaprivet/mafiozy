# Full source placement batch coordinator

New `godot/mafiozi_walk/scripts/npc_visual/npc_placement_batch.gd`, SHA256 **de585a3b87ed254c81c320b6b84af2ee1750bb5321d4563784047d71929f133a**. It calls the existing accepted `npc_initial_placement.gd` **7450d532ccf12e85eb04411c1d676faad43427fac472b44befa8ef10a667106a**; neither solver nor BODY helper was edited. Main/population/scene integration remains Root-owned.

## API and ownership

```gdscript
configure(context_bytes: PackedByteArray, trust: Dictionary,
    source_body_pass: Callable, current_lease: Callable,
    clock_ms: Callable, owners: Dictionary) -> Dictionary
step() -> Dictionary
state() -> Dictionary
candidates() -> Array[Dictionary]
placement_receipt() -> Dictionary
validate_candidate(candidate: Dictionary, raw_id: String, generation: int) -> bool
dispose() -> void
```

`trust` is the unchanged solver trust (context/source/session/phase/provider/interior_state); extra aggregate revision fields are privately retained and passed to `current_lease`. BODY has the existing five-argument helper signature `(object_key,kind,raw,r,c) -> bool/null`. Pass the configured real `npc_source_body_query.body_pass`, backed by current real primitives. No default passability callback, relaxed road policy or fallback for UNKNOWN exists here.

`current_lease(private_trust_copy) -> strict bool` is the external source owner's aggregate current proof. It must establish the captured full source population/lifecycle/geometry/access/interior/provider context remains valid, and invalidate when any dependency relevant to that captured solve changes. It is checked before/after every slice, before/after candidate publication and before/after exact candidate validation. It must not return true after invalidating its own claimed conditions. Receipt labels are not geometry/authority proof.

`owners` contains only the **actual target subset**, e.g. the existing three `Queue.Owner` instances keyed by `resident_72`, `resident_169`, `resident_252`. No 326 fake life owners or physical actors are manufactured. Each key must match a real full-context raw ID; owner identity/generation are captured and rechecked, death invalidates. The aggregate lease separately proves the other source objects used by spacing have not changed. A source event for an unowned actor may be inspected after COMPLETE but cannot pass `validate_candidate` for physical admission.

The pinned full context contains **326 unique String raw IDs**, verified from actual bytes. Their `object_key` values remain aliases, never new source identities. The wrapper retains their exact source pool role and eligibility, with full source float64 positions owned by the real solver. No birth initialization, RNG, server snapshot, raw HP or immutable birth coordinates are rerun/changed.

## Batch completion and admission

Call `step()` once per allowed host scheduling opportunity. It invokes first `solver.step(128,4.0)`, then `solver.step(96,2.0)`, using the supplied monotonic millisecond clock. Those are source check/time slice parameters, **not a guaranteed total wall-time cap** for provider calls plus coordinator validation/publication.

`step()` returns only small status/count/stats diagnostics, never its partial events. All **326 spacing objects** participate in the actual solver; **306 eligible events** are expected, with 20 source-skipped rows retained in spacing. COMPLETE requires solver done, zero pending/unresolved/exhausted, expected checked/skipped totals and exactly one event per eligible source object. Each collected event's identity, role, coordinates and provenance is validated. The copied solver results are retained privately without a redundant second deep clone. Outward publication deep-copies them.

FAULT, reentry, callback/lifetime failure, revoked lease or UNRESOLVED suppress the entire private collection, including earlier successful slices. No retry/reset/resume API recreates an old solve. Recreate only from a newly admitted source context/lease. Source partial-work statistics remain truthful even when all events are suppressed. Explicit dispose during a callback is deferred until the active public call finishes, and prevents publication.

After COMPLETE:

```gdscript
host.bind_placement_source(batch.placement_receipt(), Callable(batch, "validate_candidate"))
for event in batch.candidates():
    if actual_target_owners.has(event.raw_id):
        host.admit_candidate(event, actual_target_owners[event.raw_id].life_generation)
```

Validation requires the exact delivered typed event (including commands and provider fields), exact full-context alias→raw-ID/role mapping, an actual target owner, current generation and the aggregate lease. All source events retain `physical_admission=false`. Diagnostic source route-clear command names are never executed by this module. Host support/corner/overlap/appearance/current-life checks remain mandatory; no source placement event itself authorizes a body spawn.

This is the pinned **offline NEW_SESSION, before server snapshot/native resolver** source boundary. Native representation of an already captured source actor is not a new source birth. Root must define which captured source dependencies/revisions remain unchanged during native admissions; the wrapper does not invent live revision semantics or a provider on its behalf.

## Verification

`scripts/tests/test_npc_placement_batch.gd`: **1,583 checks PASS**, clean `outputs/coordinator21_npc_placement_batch/run.log`, final SHA above. Real full context `a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c` is loaded from the accepted full startup artifact; no three-row crop substitutes for it. The test replays the original JS **765 ordered BODY queries**, exact 128/96 scheduling and all 306 final relocated coordinates at float64 precision. It verifies publication withholding, exact identity/provenance/life, deep copies, missing proof, later slice failures, death, reentry/dispose, callback disappearance, clock reversal and permanent lease revocation.

UNRESOLVED suppression is tested using the **real solver**, but its search radii are shortened explicitly inside that fixture to reach exhaustion quickly. This proves terminal-result handling, not another exhaustive maximum-radius source oracle. BODY answers for successful parity/flow tests are expressly TEST_ONLY; they do not prove real full-world geometry.

`outputs/coordinator21_npc_placement_batch/actual_main.gd`: **18 checks PASS** on final batch bytes. Actual full solver→batch validator→existing native host loads all three real cached actors, proves native support/overlap, preserves IDs/descriptors, prevents duplicates and invalidates on revoked aggregate lease. Complete 306 test events are retained in `TEST_ONLY_complete_events.json`, explicitly labelled **NOT_SOURCE_GEOMETRY_ACCEPTANCE**. These original-point fixture locations must never be copied into production as solved source placements.

`body_unknown.gd`: actual BODY helper **bd4948eca5a4e71dec7a7482da05b7f0bc2f046e091965d82069241c8e144e74** before/after matches. With a deliberately missing required native primitive, it reports `primitive_proof_missing:native_nav`; the real solver faults and batch publishes no events. This proves genuine unknown propagation across the actual helper seam, without a fake boolean provider.

## CPU cost and limits

Configure parses/verifies full input during **loading**; observed samples are about 36–51 ms. It must not be inserted into a normal gameplay frame. A real-clock TEST_ONLY complete 306-point solve took **13.326 ms over 4 slices** in one run; real BODY geometry cost is additional and not measured by that fixture.

`profile.json` uses alternating identical full-context before/after runs (2 warmup +8 measured per variant). The only baseline difference is a redundant coordinator deep copy of every already-private solver event. Slice p50/p95: **4.476/6.774 ms before**, **4.141/5.771 ms after**; 24 mixed 128/96/82-event slice samples each. Publication p50 1.197/1.303 ms and configure p50 40.383/42.253 ms varied without algorithm changes, showing the limits of this small run. The clock is held constant there solely to compare equal query work; those slice times are not a live 2/4 ms cap or a whole-scene FPS result.

No GPU run, production provider completion, all-326 physical NPC population, autonomous behavior or LIVE performance acceptance is claimed. Real primitive/provider integration and aggregate lifecycle proof remain required before runtime admission.
