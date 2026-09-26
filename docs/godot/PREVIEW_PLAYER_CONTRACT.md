# Godot migration preview player

Owned implementation: `godot/mafiozi_walk/scripts/preview_player.gd`.
This is a bounded local migration preview, not a replacement for Walk gameplay.
No inventory, combat, authority, health, NPC, vehicle or persistence code is added.

## Root integration

```gdscript
const PreviewPlayer = preload("res://scripts/preview_player.gd")
var player: PreviewPlayer = PreviewPlayer.new()
player.position = spawn_position # Feet, not capsule centre; choose free ground.
add_child(player)
```

The script creates its own capsule, imported hero, camera rig and input actions
when entering the tree. The camera becomes current automatically. The root must
provide physical ground/buildings on collision layer 1. The player is on layer 2,
with collision mask 1, a 0.30 m radius capsule and 1.90 m total height. Root owns
scene, spawn selection, lighting, status UI and world colliders. Do not scale the
CharacterBody3D; asset normalization is exclusively inside the visual subtree.

Public methods:

- `get_preview_camera() -> Camera3D`: the current third-person camera.
- `get_preview_status() -> Dictionary`: actual import, pose and movement status.
- `set_mouse_captured(captured: bool)`: capture/release; also resets held RMB.

Exported parameters include `hero_scene_path` (default `res://assets/hero.glb`),
`model_target_height` (1.9), `visual_yaw_degrees` (180), walk/run speeds (3.2/5.8
m/s), jump speed (5.2 m/s), acceleration (18 m/s²), mouse sensitivity and camera
distance (4.8 m). Visual heading uses Godot -Z with a +Z glTF correction; adjust
only `visual_yaw_degrees` if an actual imported model has a different front.

## Input

WASD or arrows move relative to horizontal camera yaw. Shift runs. Space jumps
only from physical ground. RMB drag or Tab capture rotates the camera. Esc and
application focus loss release the cursor. Text editing suppresses movement and
jump. No controls are automatically captured at startup.

Actions are `preview_move_left/right/forward/back`, `preview_run`, `preview_jump`
and `preview_capture_mouse`. Missing actions are registered on startup with
physical key codes, preserving existing project bindings.

## Geometry, collision and current limitations

The real hero GLB is loaded through Godot's imported PackedScene. The union of
actual MeshInstance3D bounds, transformed into one model coordinate space, gives
the source height and foot plane. One uniform scale maps it to 1.9 m; X/Z are
centred and the lowest visible mesh point is placed at the capsule's feet.
Original mesh proportions and materials remain intact. A missing/broken GLB
produces an explicit magenta marker and `model_loaded: false`, not a successful
hero import. SpringArm3D uses a sphere, layer-1 collisions, a margin and explicit
player RID exclusion; it shortens the camera arm at walls.

### Authored colour fix after the first LIVE image

The first native Godot screenshot showed a white hero. Actual imported-resource
inspection proved that all seven surfaces retained their authored `COLOR_0`, but
all four imported materials had `vertex_color_use_as_albedo=false` and white
material albedo. The controller now assigns four owned copies of those materials
to the seven mesh instances, enabling vertex albedo. `vertex_color_is_srgb=false`
preserves glTF's **linear** vertex colours; there is no second gamma conversion,
new flat palette or geometry rewrite. Albedo, roughness, metallic, textures,
alpha/culling and original material names are preserved. Shared imported
materials are untouched. This work runs once when the hero loads.

The exact canonical male mapping is:

| Mesh suffix after `player_male_DEMO_` | Material | Colour vertices | Roughness | Metallic |
| --- | --- | ---: | ---: | ---: |
| `core_FABRIC` | `FABRIC` | 2229 | 0.76 | 0 |
| `core_HAIR` | `HAIR` | 1162 | 0.61 | 0 |
| `core_SKIN` | `SKIN` | 3055 | 0.68 | 0 |
| `core_TRIM` | `TRIM` | 294 | 0.35 | 0.55 |
| `hair_HAIR` | `HAIR` | 1195 | 0.61 | 0 |
| `headwear_FABRIC` | `FABRIC` | 48 | 0.76 | 0 |
| `headwear_HAIR` | `HAIR` | 355 | 0.61 | 0 |

These are the original male asset colours, including its existing hair/hat.
Walk's separate `walk_hero_appearance.mjs` and `npc_appearance.mjs` modify vertex
palettes and cosmetics according to saved appearance. For an empty male look,
their defaults include suit/trousers `#1a2e1a`, skin `#FDDBB4`, shirt `#dddddd` and
hair `#1a0e00`; that appearance/persistence path is **not** implemented in this
static asset preview. It must not be substituted by a guessed material-wide
recolour because eyes, skin shading, shirt and other details share surfaces.

The original GLB declares Y-up/+Z-forward. Its imported bright eye vertices have
centroid Z=+0.552 (122 vertices); current 180° visual correction turns that front
toward Godot's movement -Z, away from the initial camera at +Z. The first white
screenshot alone does not justify reversing this. The coordinator subsequently
viewed `outputs/godot_preview_materials_20260926.png` and confirmed authored
colours and correct rear orientation. No yaw change was needed.

The source `player_male.8130dfb1f7eb.glb` has **zero embedded animation clips**.
The first visible checkpoint used its static pose. The next bounded step adds
canonical procedural unarmed idle/walk/run through `preview_locomotion.gd`; see
[the locomotion contract](PREVIEW_LOCOMOTION_CONTRACT.md) for source coefficients,
actual skin contact checks and limits. The status still reports jump/combat
animation as unfinished. This is not complete animation migration; locomotion
needs independent review and native LIVE acceptance.

This stage has no stair-step resolver, vaulting, swimming, water authority,
vehicle entry, aiming, weapon animation, automatic unstuck teleport or savegame
integration. Headless physics tests are not visual LIVE acceptance or FPS proof.

## Validation

Verified 26 September 2026 with Godot
`4.7.2.stable.official.ed1daf0bf`, after the root's real GLB editor import:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path godot/mafiozi_walk \
  --fixed-fps 60 --script res://scripts/test_preview_player.gd
```

Exit 0, no script parse/runtime errors, 16 focused assertions PASS: actual hero
PackedScene and all seven meshes, real bounds, uniform 1.9 m height, floor
settling/foot height, current camera, unfinished animation disclosure, walking,
normalized diagonal movement, running, release stop, grounded jump with rejected
midair second jump, landing, physical wall block and SpringArm wall retraction.
The test uses Godot physics and the actual imported GLB, not a mocked controller.

After the material correction, the same physics test again passes. Additional
`--headless --script res://scripts/test_preview_player_materials.gd` exits 0 on
the actual imported scene: seven surfaces/8338 colour vertices, four shared
owned material copies, linear vertex-albedo flags, retained semantic material
names, original PBR/alpha/culling, unchanged mesh/skin resources and unchanged
shared imported materials. This catches the actual white-material regression;
it does not claim a completed renderer comparison.

Headless testing does not establish that the static pose, orientation, visual
materials or camera feel are accepted. Root performs the single visible Godot
session and visual acceptance. No extra GPU window is opened by this subtask.

Implementation references: Godot's [CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)
and [SpringArm3D](https://docs.godotengine.org/en/stable/classes/class_springarm3d.html)
contracts.
