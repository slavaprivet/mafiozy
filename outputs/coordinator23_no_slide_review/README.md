# Standing-hit slide: exact isolated candidate

The NPC-owned shared change removes the source path callback's instantaneous
0.09-cell (0.369 m) CharacterBody translation. It retains the requested path for
inspection and returns false; it does not invent a new knockdown, flinch, damage
event or impulse. Candidate SHA is in RESULT.json. The copy here is preserved
for the next controlled build, not enabled by this Git checkpoint. Artist23
owns the shared NPC file; accepted23e PCK remains unchanged.

Independent test measures the **standing CharacterBody** before and immediately
after real native TT collision callbacks on all three original residents.
Accepted23e before:45 checks, 0.368999481 m displacement on each. Shared candidate
after:48 checks, 0 m each, HP30/IDLE retained and all original path requests
recorded. Both exit0 with no engine errors. The older91-check physical-body test
also passes, but its peak-distance counter runs only while ragdoll is ACTIVE;
its zero for a standing TT survivor alone was not proof of this correction.

The fixture deliberately fixes source shot/RNG and uses an isolated native ray
corridor, with the car collider disabled in the test. It is not ordinary mouse
input, GPU appearance, medical getup or whole-scene performance acceptance.
The test parent is pinned from the owner's native_base.gd; the sole adaptation
is to load HitOwner from the tested project's res:// path instead of the
owner's experimental sibling. BASE_PROVENANCE.json records the source hash.

To reproduce, first import a scratch copy of the Godot4.7.2 project. Run the
external test_standing_capsule.gd headlessly with --main-pack accepted23e.pck
and user argument --expect-old-slide. Then put this candidate owner at the same
res://scripts/npc_visual path in the scratch project and run the same script
with --path scratch, without --expect-old-slide. Preserve original source
assets, bindings and collisions; do not overwrite the shared NPC owner's work.

Separate shared-project startup repair: scope_optic.svg had no imported texture
in the working project's cache. One headless editor import restored it. The
ordinary main (without fixture flags) then loaded14 weapons,3 hit owners and
the car; optic width800, startup test PASS. Import itself also reported a stale
editor-tab script outside the project defining NativeVehicleBody twice; that
foreign file/layout was not edited. Actual game startup and native tests were
clean. Import cache is local/generated and is not a source dependency to commit.

Remaining: compiled/LIVE acceptance of this candidate; proper point impulse,
always-lethal anatomical headshots, persistent wounds and physical corpse-foot
interaction. Do not substitute these isolated results for those features.
