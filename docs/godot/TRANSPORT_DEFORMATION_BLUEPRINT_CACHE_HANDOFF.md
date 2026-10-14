# Immutable deformation preparation cache

Frozen additive preparation-only component. Not integrated into deformation
adapter, main or LIVE. Author54+independent parent54 actual Godot checks PASS.

Files/SHA are in TRANSPORT_DEFORMATION_BLUEPRINT_CACHE_MANIFEST.json.
API acquire(visual, body, exact_profile, provenance); required provenance fields
source_sha256, visual_manifest_sha256, asset_generation. Optional configure_limits
before first acquisition; clear/stats/dispose. Returns unique prepared ArrayMeshes,
mutable copied surface buffers and data-only profile/provenance receipts.

Exact mesh-array fingerprints, canonical source labels, local hierarchy frame,
full profile and provenance bind admission. Byte-identical imported instances may
share only immutable blueprints; their materials come from the current instance.
Bound instance mesh replacement, in-place edits, frame/profile/generation changes
reject. Source LEFT-cell boundary retained. Original geometry is never mutated.

Default admission bounds:16entries,128MiB estimated retained blueprint packed/string
payload,4096live mesh-node bindings. Limit failures reject without eviction, content
removal or partial entry/binding publication. Dead WeakRefs release binding slots
only. Configure bounds once before valid acquisition:1..256entries,1B..1GiB payload,
1..65536bindings. Clear explicitly releases cached state; returned caller meshes
remain caller-owned. Allocator/Dictionary overhead, temporary construction and
per-instance ArrayMeshes/mutable buffers are NOT included in payload estimate.

Actual compact_sedan121meshes/726759prepared vertices, unchanged subdivision:
author first3822.603ms/HIT78.553ms; parent first3919.085ms/HIT77.456ms (50.60x).
One immutable blueprint estimated44,995,412bytes (~42.91MiB). BOTH costs are
load/preparation only; HIT is not frame-safe. No fullfleet/loaded-scene FPS claim.

Root seam: this is a separate data provider, not automatic adapter adoption.
Adoption must preserve adapter current visibility selection and canonical frame
semantics; initialize its mutable row state once from this receipt during load.
Do not invoke acquire during contact/blast or replace per-car mutable meshes with
shared deformed geometry. Damage/HP/contact identity/life/event authority, RNG,
debris refresh and physical collision ownership remain with existing owners.
Strong deformation33.610–37.807ms and dirty hull refresh~22ms remain rejected;
this preparation cache does not solve those impact-frame bottlenecks.
