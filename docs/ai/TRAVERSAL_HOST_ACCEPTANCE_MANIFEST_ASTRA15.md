# Frozen traversal host acceptance manifest — 23 September 2026

The manifest freezes the actual traversal, surface, ladder, pose, authored hero
models and existing test sources before the `/walk` integration slot. It also
freezes the current production source hashes and checks semantic host and
transport anchors. It does not duplicate physics or pose assertions: the
runner executes the existing focused suites.

The current endpoint addendum freezes the verified passability
`B2A5…AD10C`, integration contract `61F4…505` and NPC edge probe
`08EA…5523`. Reused focused suites explicitly cover endpoint certification,
storey-safe cache separation and blocked/clear zero-distance queries for both
the player surface route and NPC consumers.

The current production host baseline is `walk_preview.mjs`
`6B242067…11479`. Its preservation gate also pins the local vehicle explosion
owner, hero and crew occupant receipts, explosion reset re-arming, the
diagnostic receipt, and the existing fleet QA selector. These checks protect
the verified transport additions while traversal remains on HOLD.

Current production HOLD check:

```powershell
node assets/maps/city_rebuild_v1/test_traversal_host_acceptance_manifest.mjs
```

Expected final receipt: `status: "HOLD-PASS"`. This means the frozen package,
the current source baseline and all tests agree; it does not mean traversal is
integrated.

Candidate check without editing production:

```powershell
$env:WALK_PREVIEW_CANDIDATE='C:\path\to\candidate\walk_preview.mjs'
$env:BUILDING_VERTICAL_NAVIGATION_CANDIDATE='C:\path\to\candidate\building_vertical_navigation.mjs'
node assets/maps/city_rebuild_v1/test_traversal_host_acceptance_manifest.mjs
Remove-Item Env:WALK_PREVIEW_CANDIDATE
Remove-Item Env:BUILDING_VERTICAL_NAVIGATION_CANDIDATE
```

Expected receipt is `status: "integrated-candidate-PASS"`. Candidate mode
forces the full pose semantic gate, including separate disabling of legacy
ladder bones and weapon ownership, one orchestrated apply, preserved
root/yaw/camera, hero lifecycle binding, and all current transport anchors.
A partial candidate fails; it cannot fall back to HOLD.

The runner always verifies the unchanged actual production baseline before it
checks candidate copies. If another owner intentionally changes a frozen
dependency or either production baseline first, stop and review/regenerate the
manifest rather than updating a hash blindly.
