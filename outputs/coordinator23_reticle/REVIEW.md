# Original Walk reticle proposal — outputs only

The actual source is `assets/maps/city_rebuild_v1/weapon_crosshair.mjs`, not the arsenal HUD. It draws a white2×2px center square and four cream #f7f4e8 bars,6×2 horizontal /2×6 vertical,1px corner radius. The source gap is `round(clamp(3+tan(sampleWeaponAccuracy(...).spread)*viewportHeight/(2*tan(FOV*pi/360)),3,64))`. The cone includes live fire heat, movement/run, stance, RMB accuracy and shotgun pellet spread. Native currently uses a34px text middot and never displays this physical cone.

Source `walk_preview.mjs:792` shows ordinary reticle only when combatAllowed&&(aiming||triggerHeld), excluding sniper RMB scope. Proposal restores that rule and original geometry/colors. Scope SVG remains unchanged. Existing native cargo targeting keeps only the small central dot, including unarmed pickup; this is explicitly a retained native interaction aid.

## Integration

- Copy `walk_weapon_crosshair.gd` to `scripts/weapons/walk_weapon_crosshair.gd` and add that resource to selected export inputs.
- Apply **minimal `reticle_integration.patch`** only: UI preload/control type/construction/center/refresh, plus host `_crosshair` type fromLabel→Control. It is rebased on current production palette edits; no palette or unrelated UI changes. Do not replace production with generated whole candidate files.
- Module is mouse-ignore and nonfocusable. It never owns input or changes ammo/state. Menu/blur/text/seat/death/source host gates hide it. Ordinary held-scope reload remains governed by original source; no invented reload suppression.

## Verification

**1784 checks PASS** in `RESULT.json`.

`build_oracle.mjs` executes original source crosshair and weapon-fire functions, capturing actual DOM arm style geometry:252 combinations across14weapons,3stances,3movement/aim modes and42°/38° at720/1080height. Native floating gap/cone, rounded gap and every arm rectangle match.

The actual-main test uses real AK equip and RMB/LMB, movement and real ammo consumption. It proves rest gap3, movement widening, real spray bloom, no repeated redraw at settled integer gap, exact screen center, held hipfire visibility, source inactive hide, sniper replacement, menu/blur hide and retained unarmed cargo dot. Main/controller/host continue running; no manual bone or fire-state substitution.

Cost is bounded: one Control, two reused styles, maximum five stylebox draws; no per-frame nodes/textures and redraw only when the rounded gap or arm mode changes. The tiny cone sample still runs when visible so telemetry remains current. This is not a loaded GPU performance claim.

Geometry and colors are source-exact. CSS `box-shadow:0 0 2px 1px #111` is represented by native StyleBoxFlat soft shadow size3; Gaussian blur pixels are not proven identical. GPU appearance and loaded-scene performance remain root acceptance. No GPU or production edits by this agent.
