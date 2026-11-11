NON-BLOCKER

Concrete residual risks, all non-blocking:
- `Basis.scaled_local` is the correct local-axis scaling path for rotated boxes; only remaining engine risk is if non-uniform scale is applied directly to a `CollisionShape3D` rather than baked into the shape/mesh. Local-axis, support-cascade, single-brick, and breach checks passed.
- 2.5–3% tangential overlap and 2 cm crown-ring overlap may produce minor z-fighting, shadow acne, or hidden internal faces. Screenshots passed.
- Unchanged merlon support bottoms could leave small gaps/overhangs if tangential widths shifted, but support cascade passed.
- No instances added means no new draw-call/instance/FPS blocker; three FPS runs passed.

No blocker identified.