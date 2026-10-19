# Source paint mark plan — additive pure component

Frozen transport_damage_mark_plan.gd SHA
bac706d5449155814667bf7677c7ae5364b8b95d10cf364d3104799c25d6b42c.
Exact files: TRANSPORT_DAMAGE_MARK_PLAN_MANIFEST.json. Actual private mark and
public contactImpact executed through in-memory source instrumentation, not copied
oracle equations. damage e029cb4a…/Three180 pinned. Fixture85762dbd…9rows, two
byte-identical exports.85author+85parent+85independent actual Godot PASS.

API static plan_bullet(cursor,local_point_f64,unit_local_normal_f64,damage=24),
plan_collision_round(cursor,point,normal), plan_collision_scratch(cursor,point,
normal,unit_local_tangent_f64,impact_speed,slide_speed>=1.5). Returns slot,
slot_kind,next_cursor,position,raw Float64 quaternion[x,y,z,w],scale,angle.
Pure query; caller persists cursor only after actual host success. Finite/type/
unit vector gates and operation-specific Number.MAX_SAFE_INTEGER next-cursor
overflow reject. No RNG, HP, ownership, event reservation, Nodes or Resources.

Retains32physical slots, scratch slots divisible by3, bullet skip, collision round
possibly landing on an existing scratch slot, source two-stage scratch cursor
selection at wrap, .007surface offset, 2.399angle AFTER increment, defaultdamage24,
bullet3.2scale cap, collision2.2scale, scratch dimensions and antiparallel normal.
Total cursor is never reduced modulo32: angle depends on accumulated cursor.

Critical Root seam: inputs/outputs use the SAME actual hit mesh-local frame.
No automatic native X/Z conversion; imported GLB root already contains RY(pi).
Host owns actual contact ray and re-projection onto current deformed surface,
source world tangent projection/fallback, inverse-frame normalized local vectors,
actual private32pool meshes/materials, cursor persistence and authority/lifetime.
Canonical mark geometry is XY plane/+Z, not a default horizontal plane.

Under nonuniform scale scratch axes are intentionally nonorthogonal: actual
source fixture x dot z=.212544 and quaternion length=.980638. Raw source
Quaternion.setFromRotationMatrix result MUST NOT be normalized/orthogonalized
using a Godot Quaternion(Basis) convenience conversion. Host must preserve the
raw source quaternion composition when constructing the final visual basis.
Pose comparison is numerical binary64 tolerance, not exact resource render proof.

Parent100kqueries778.141ms=7.781us/query; author7.874us. This excludes contactray,
reprojection, resource/node upload and loaded-scene cost. Not main/LIVE adoption,
complete visual crash implementation or full-sceneFPS proof. Frozen dent883 and
deformation74e5 retain their separate performance rejection. No foreign/Git/GPU.
