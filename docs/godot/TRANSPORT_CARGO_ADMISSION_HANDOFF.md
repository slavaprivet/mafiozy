# Transport cargo placement geometry

`transport_cargo_admission.gd` ports the source `vehicle_trunk.mjs`
`acceptsItem` / `localItemBounds` geometry. It is a pure query and creates no
item, inventory record, damage event, or ownership transfer.

API:

- `accepts(native_cargo_AABB, local_item_center, local_item_half, amount,
  detached, has_actual_floor, mode, lid_visible, current_native_lid_AABB,
  available=true)`
- `world_item_local_bounds(bound_vehicle_transform, world_AABB_center,
  world_AABB_half) -> {center, half}` (empty on invalid input)

Containment uses all source tolerances: 1e-7 at cargo bounds, lid amount at
least .85 unless detached, and opening span plus .001m. The trunk Z equation
is converted for the native -Z basis; hatch checks vertical clearance below
the raised lid, tailgate above the lowered lid. World AABBs use all eight
inverse-transformed corners, including pitched/rolled vehicles.

Root supplies the exact compartment cargo bounds, actual floor collider
presence, current posed lid bounds, amount/detached/visibility and mode.
The companion currently supplies cargo bounds but does not prove floor
presence or current lid AABB. Missing evidence must not become `has_floor=true`.
This query adds no route sweep or new cargo placement policy beyond source.

The caller separately binds the vehicle/item lifetime, source revision,
inventory authority and placement transform. A successful query is not a
load receipt. Imported bank bags and quest boxes keep their source reply
gates. Visual cargo must appear only after an actual storage receipt.

Actual Godot4.7.2: 319 checks across13 exact companion profiles, opening and
containment positives/negatives, world/local transform and singular rejection.
Nonzero asymmetric AABB yaw+roll conversion matches an analytic oracle;
disposed providers, unknown modes and containment tolerance boundaries reject.
10000 pure queries: about11-15.3ms isolated CPU. Full scene performance unmeasured.
No main/player/visual/physics/Git/GPU changes; native transport rev6 unchanged.
