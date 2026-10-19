# Original weapon models — native package

The package contains the original 14 `hero_arsenal.mjs` firearms, plus the empty
`none` state, in the original catalogue order. No invented model, rescaling,
reorientation, simplified silhouette, or gameplay authority is introduced.

`tools/godot/export_weapon_models.mjs` invokes the real source factory with the
existing Three r180 vendor. Two independent captures must agree. Original part
names/matrices, all vertex/normal/UV/index data, materials, authored details,
muzzle/ejection/support/mount metadata and reload slots are captured. Source text
hashes use CRLF-to-LF normalization only. Offline native preparation combines
static geometry only by identical material; magazine/drum and slide nodes remain
independent. Every source triangle survives, with winding reversed for Godot.
Transparent parts cannot be merged with another independently sorted part.

The original **563 mesh surfaces become 127** native surfaces across all weapons;
a selected firearm uses **8–10 surfaces**. Native assets including manifest total
1,661,403 bytes. No geometry is created by the runtime loader. Meshes and materials
are shared immutable resources; transforms/animation nodes belong to each instance.
Use a common catalogue for held, dropped and cargo models to reuse the same cache.

## Runtime API and root attachment

```gdscript
const Catalog = preload("res://scripts/weapon_visual/weapon_visual_catalog.gd")
var catalogue = Catalog.new()
var opened = catalogue.open() # optional second parameter: trusted manifest SHA256
var result = catalogue.instantiate_weapon("ak74")
if result.ok:
    var weapon = result.visual
    source_weapon_socket.add_child(weapon)
    # Original socket is Skeleton3D bone "socket_weapon", inherited rig scale.
    # The source weapon pose sampler must supply the final aiming/IK frame.
    # Rest attachment alone is NOT the original held/aiming pose.
    weapon.apply_reload(reload_progress, prone_amount)
    var shot = weapon.shot_transform() # origin, ejection_origin, direction
```

Root/player owns the sole bone writer, world weapon frame, right/left palm IK,
event admission, fire/ammo/HP, and equipment identity. Original source forward is
**+Z**, dimensions are **unscaled original hero-rig units**. The existing hero
normalization scales by 1.9 / 5.15999984741211 = 0.368217065152222; its visual
pivot already turns source +Z into Godot movement -Z. Do not add a second scale
or yaw when inheriting the normalized socket. If assigning a world weapon frame,
it must include the one intended prop scale. No fake hand position is supplied.

`weapon.profile()` returns a private copy with source metadata, source ID,
two-handed/family fields, primary hand grip `[0,-.13,-.02]`, reload hand target,
and bounds. `GripOrigin` stays `[0,0,0]`; it is not the palm grip. The support grip
uses the actual model metadata, including M16 `[0,.1,.57]` and RPG `[0,.09,.46]`.
`anchor_world(name)` resolves GripOrigin, PrimaryHandGrip, Muzzle, EjectionPort,
SupportGrip. A missing ejection port falls back to muzzle in `shot_transform`;
`none` and detached models produce no usable shot transform.

`apply_reload` ports the exact `sampleReloadPresentation` envelope and the source
part translations: magazine Y -pull*.62*(1-prone), X -pull*.25*prone; slide Z
-bolt*.12. Each call restores rest, avoiding drift. The returned envelope exposes
lower/grab for the separate body/hand pose sampler. Body IK is not implemented in
this asset module. There is no autonomous processing, timer, light, collision,
damage logic, ammo mutation or effect pool attached to a weapon.

## Cargo layout and picking

`catalogue.get_entry(id).profile.bounds_native` is the **exact native rest vertex
AABB**, in source local units, available without loading any mesh. It provides
`min` and `max` arrays. `bounds_source` separately preserves the factory's original
conservative transformed-mesh AABB. `weapon.local_bounds()` returns the native
rest AABB as a Godot AABB; a cargo host can transform it by its chosen orientation
and scale to lay out nonoverlapping models. Do not use the rest bound to represent
an extracted magazine during reload.

`weapon.geometry_nodes()` returns borrowed MeshInstance3D nodes for host picking.
Their source geometry is already cached; do not mutate shared Mesh/Material.
Cargo/ground/hand instances can each have a different root transform without
copying those resources. Capacity, stack units, transfers, ground-drop lifetime,
selection ray and physical collision remain host-owned. Free instance roots on
retirement; `catalogue.close()` releases retained PackedScenes. Live instance
resources survive cache closure through their own references.

## Verification and costs

`outputs/coordinator22_weapon_visual/report.json`: **224,951 PASS** checks against
independent original source arrays. All vertices, triangle corners, material
values, source/rest/world anchors, exact native bounds, animation samples,
instance isolation and shared resources are checked. Maximum position difference
1.238e-7 source units; normal-vector difference 1.166e-4 from native normal packing.
Normals are not claimed bit-identical. No warning/error in final logs.

`export_report.json`: **79 PASS**, actual exported Windows release PCK with
compiled scripts, all hashed `.scn` resources, imported actual hero and actual
socket_weapon attachment. Model scale is inherited exactly once. Firearm cold
hash/load/instantiate cost 1.694–2.662 ms; all 14 total 29.427 ms when deliberately
loaded consecutively. Cache is lazy: do not synchronously preload all guns during
an interactive frame. Warm instance/free p50 is approximately 0.05–0.08 ms in
the headless component test. Reload presentation p50 is 2.82–3.98 microseconds.
Full all-ID cache retains 262 resources (15 scenes, 127 meshes, 119 materials,
one behavior script). Release static allocation counter is unavailable and is
reported as **null**, not zero memory. Root must measure actual loaded-game
frame time/memory and visual lighting; headless costs do not establish city FPS.

## Build and export

1. Run `node tools/godot/export_weapon_models.mjs`; it writes source captures and
   independent oracles only under `outputs/coordinator22_weapon_visual/source`.
2. In an isolated Godot project containing these scripts, run
   `prepare_weapon_models.gd -- --source=<capture-dir> --output=<asset-dir>`.
   It builds the 15 native scenes and manifest. Preserve the `.gd.uid` files.
3. Run `test_weapon_models.gd -- --source=<capture-dir> --assets=<asset-dir>
   --report=<report-path>`. Test and prepare scripts are offline tools only.

Root's resource export list needs all `assets/weapon_visual/*.scn` plus runtime
`weapon_visual.gd` and `weapon_visual_catalog.gd` (script dependencies also follow
from the scenes). Nonresource include_filter needs
`assets/weapon_visual/manifest.json`. Keep prepare/test scripts out of release.
No native DLL, addon, source factory, original JSON oracle or raw `.bytes` capture
is required by the game. Compiled script export mode 2 works and was tested.
SCN geometry/material resources are embedded; behavior script remains a normal
external dependency. Bundling GDScript into binary SCN was rejected during testing.

Exact hashes of all shipped files and test receipts are in
`outputs/coordinator22_weapon_visual/freeze.json`. No main/player/export preset,
weapon fire authority, NPC or GPU integration was modified by this package.
