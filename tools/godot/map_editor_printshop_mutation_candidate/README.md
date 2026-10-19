# Printshop monotonic owner-API revision proposal — tools only, HOLD

This is an exact-byte source derivation of the immutable Coordinator22
`preview_printshop_interior.gd` (SHA-256 `f6f08258…`). It does not write to
`godot/mafiozi_walk`, stage a project, import assets, or launch Godot.

`node tools/godot/map_editor_printshop_mutation_candidate/test_patch.mjs`
currently passes source checks. The derived script SHA-256 is
`76fc236779b8174c3487d43d924946177941a1d9d1388e5a67cdb038a1008cab`.
The source check confirms the building attach attempt, accepted door command
(including same-target commands), each door-motion step, and restore path
advance a monotonic owner-API counter before their state changes. Revision
exhaustion marks the diagnostic counter invalid but does not interrupt the
original door, attach or restoration behavior. Existing geometry/material generation, swept
door collision, 111-collider construction path and ordinary gameplay methods
are left byte-identical outside those insertion points.

This is **not** an editor lease and grants **zero** Printshop roots.
`begin_editor_mutation_lease` deliberately returns `ok:false` /
`printshop-external-writers-unsealed`. The actual main/Printshop adapter
still exposes its root, descendants, two mutable door dictionaries, generated
meshes/materials, collision shapes and restore inventory. Another writer can
change and restore those directly without calling a revised method; a current
snapshot plus the API counter cannot prove that no mutation happened. Direct
scene deletion can also bypass the owner. The existing read-only
`map_editor_printshop_interior_receipt_candidate` therefore stays HOLD.
No positive admission, move/rotate/delete/undo, save/reload, native
parse/runtime, collision or FPS result is claimed.

Next integration requires a production-owner change with one main-thread
pause-safe capability that owns *all* Printshop writers and the parent/root
lifetime, prevents direct external writes (or observes every such mutation
with a monotonic generation), and composes interior/door/111-collider
revisions with player/NPC/nav/physics leases. It must atomically reject or
hold on callback reentry, direct resource edits, move/undo A→B→A,
deletion/reparenting, and revision exhaustion. Only then can the diagnostic
receipt be converted into a positive root admission and tested in an isolated
Godot fixture followed by one coordinator-owned LIVE run.
