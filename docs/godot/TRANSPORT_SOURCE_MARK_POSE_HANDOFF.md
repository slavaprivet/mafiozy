# Raw source mark pose — additive conversion seam

Frozen transport_source_mark_pose.gd SHA
6e8032efe2612e4d70bdad1208a15d633d3b292b903e6705648e935e8d03e5b2.
Exact files/SHA in TRANSPORT_SOURCE_MARK_POSE_MANIFEST.json.52author+52parent+
52independent actualGodot checks PASS, independent34+parent34 adversarial PASS.
Three180 Matrix4.compose executed on12rows including frozen actual mark oracle
85762dbd… nonunit scratch quaternion; fixture98b31923… byte-identical exports.

Inputs and expected matrices stored as authoritative Float64 LE bytes. This
avoids Godot JSON decimal parsing losing one ULP; final exact matrix comparisons
use decoded binary inputs and output bytes. Initial decimal-only test failed7
rows and was fixed without loosening the Float64 comparison.

API static compose(PackedFloat64Array position3,raw_quaternion4,positive_scale3)
returns matrix_f64 column-major16, three f64 basis columns, native_transform.
Raw quaternion is never normalized or converted via Quaternion(Basis). Native
Transform3D uses explicit columns; source-local geometry/axes remain unchanged.
Host sets mark.local_transform to native_transform under the actual panel, so
parent*local is applied once. No extra native X/Z flip: imported parent already
contains its source/native conversion. Canonical mark geometry is XY/+Z.

Finite/type/positive scale guards reject invalid inputs; native Float32 overflow
of scale, matrix columns or origin and positive-scale underflow reject. Valid
raw nonunit source scratch basis remains nonorthogonal. Returned native values
round to engine precision; native point tests use that explicit tolerance while
raw source matrix remains exact. Source marker generation, hit/ray/reprojection,
cursor, Nodes/render/materials/authority are separate host dependencies.

Parent100k655.775ms=6.558us/compose; author6.143us. Pure CPU query, no nodes/GPU,
main/LIVE integration or fullsceneFPS. Frozen mark planner bac706d5 unchanged.
