# Hero motion pose semantic host gate — 23 September 2026

`test_hero_motion_pose_host_gate.mjs` is HOLD-safe. It does not require a fixed
whole-file hash and does not edit `walk_preview.mjs` or
`building_vertical_navigation.mjs`.

Current unintegrated host:

```powershell
node assets/maps/city_rebuild_v1/test_hero_motion_pose_host_gate.mjs
```

Expected result is `HOLD-ready`. Once any orchestrator import/constructor is
present, the same command automatically changes to the full integrated gate.
The owner can force that gate before commit:

```powershell
$env:WALK_POSE_REQUIRE_INTEGRATED='1'
node assets/maps/city_rebuild_v1/test_hero_motion_pose_host_gate.mjs
Remove-Item Env:WALK_POSE_REQUIRE_INTEGRATED
```

Candidate copies can be supplied through `WALK_PREVIEW_CANDIDATE` and
`BUILDING_VERTICAL_NAVIGATION_CANDIDATE`.

The required navigation contract is two independent, backwards-compatible
options on `createBuildingVerticalNavigation`:

```js
applyLegacyPose=true,
manageLegacyWeapon=true,
```

Production `/walk` must pass both as `false`. `update(dt)` must still own and
apply root position, root yaw, camera shift and controls-target shift. Only the
legacy bone call and the legacy weapon capture/hide/restore/reset path are
disabled. Other callers keep both defaults and therefore preserve their old
behavior.

The integrated host must never call `verticalNavigation.pose()`. It adapts the
authoritative navigation state and runs exactly one
`motionPoseApplicator.apply(...)` after the ordinary hero base pose. Artist
surface/reaction, an allowed follow gesture, source-vehicle presentation and
custody pose must also run before that final apply. Health/action and the
active follow gesture arbitrate as `interaction`; water retains ownership
while either swimming is active or its residual blend exceeds `.1`. This
prevents the current internal legacy pose plus explicit host legacy pose plus
new orchestrated pose from stacking in one frame.

The integrated gate also rejects the old per-frame generic assignment
`weaponModel.visible=!occupiedSeat...`. Vehicle/window fire, transition,
custody, death and water keep their explicit external policies; traversal,
ladder and motion layers use the orchestrator's holster/restore policy. Cover,
follow gesture and an explicit jump preserve their external presentation.
`applyMotionPoseWeapon(...)` runs after the final bone applicator.

Inside that function, `externalHide` is evaluated before an `external` policy
can return. It contains transition, blast, custody, active or fading water and
death. An occupied or source vehicle is deliberately excluded from
`externalHide`, because the vehicle/window-fire presentation remains its only
visibility writer.

The two switches are intentionally separate. Disabling bones while leaving the
old weapon path active makes the orchestrator see an already-hidden weapon and
remember `false`, so it may remain invisible after exit. Disabling weapon
management without disabling the bone call still double-applies ladder joints.
