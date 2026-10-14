# Blast parts seam audit — 2026-09-20

Read-only CPU audit of actual male/female `NPC_ASSETS`, `createNpcActor`, and the generated `npc_blast_parts_prototype20.mjs` output. No production edits, GPU or LIVE acceptance.

World-position edge welding at 1e-5 metres found only newly exposed boundaries in `core_FABRIC`:

| Part | Male boundary edges | Female boundary edges |
|---|---:|---:|
| Torso | 146 | 111 |
| Left arm | 112 | 86 |
| Right arm | 82 | 81 |
| Head / each leg | 0 | 0 |

Edges are counted on both sides of a split: 170 unique male cross-part edges, 139 female. No original open boundaries at this tolerance. A 1e-6 tolerance falsely separates two float32-transformed male edges.

Largest shoulder loops deviate from their Newell mean plane by 8–9 cm; female torso reaches 17.2 cm. The male torso also has a branching 63-vertex boundary component. These are not planar circular neck/shoulder cuts. All are within the same fabric mesh, not a material-merging artefact.

The main connected fabric shell has 902 welded vertices and 1800 triangles. Male partition: torso508/left658/right634; female485/665/650. Assigning the whole closed component to one limb would move most of the jacket with that arm. Additional small closed cloth components are also split by dominant skin weights.

Bounded future approach: prepare oriented boundary half-edge cycles from original topology; split branches by the original surface fan; triangulate only validated cycles while preserving exact 3D boundary vertices. Reject non-manifold/self-intersecting projections. A generic centroid disc/fan is not an approved visual fix. Head and legs need no caps. Existing shoulder partition still requires visual acceptance.

Reproduction scripts used: `%TEMP%/npc_blast_seam_audit20.mjs`, `%TEMP%/npc_blast_meshseam_audit20.mjs`, `%TEMP%/npc_blast_components20.mjs`. Main prototype remains owned by Artist20's latency agent.
