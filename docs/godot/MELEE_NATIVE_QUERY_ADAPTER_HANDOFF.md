# Native skin → query adapter — 29 September 2026

**77,281 checks PASS**, official Godot 4.7.2 headless, exit 0, no script errors in
`outputs/coordinator22_native_query/run.log`. Isolated project only. Main/player,
existing skin provider/selector, native C, production extension registration,
NPC placement/HP and the sole visible game were not changed.

## Implemented boundary

`scripts/combat/melee_native_query_adapter.gd` owns one private
`MeleeNativeGeometry` Object for one already-configured actual skin provider:

- `configure(provider)` binds that provider; it does not load the extension.
- `update(pose_revision)` captures current full skin, configures immutable native
  topology once, then sends subsequent `PackedVector3Array` vertices directly to
  native refit. Same-revision reuse still checks actual current frames/visibility.
- `actor()` publishes a caller-owned view for the existing selector, retaining
  actual source actor ID, receipt, root position and original mesh/face order.
- `current(actor_row)` and `query(actor_row, request)` are the selector ports.
  Query consumes every native page, checks revision/query ID/total/offset/count,
  and retains native score/triangle/limb order. It echoes the original key/receipt.
- `dispose()` retires the native Object. Main-thread final-reference destruction
  also frees it. Calls, explicit disposal and final ownership belong to the engine
  main thread; this is not a worker-owned service.

Provider identity is stronger than actor ID strings: this adapter retains the
object identity of the provider's `_actor` WeakRef created at configure. The
existing `melee_skin_provider.gd` creates a fresh WeakRef on every configure and
clears it on disposal. Thus reconfiguring even the same provider with identical
source ID/life cannot reuse the old adapter. This is an explicit dependency on
that inspected provider implementation, not an anonymous generic callback port.
Actual mesh/Skin/skeleton/pose validation still belongs to that provider.

A failed capture, failed native configure/refit/query, mismatched receipt or
retired owner frees the entire native context and clears the cached pose. No
previous triangles escape as a successful result or miss. A new valid capture of
the same bound life may build a new context. Another actor/life/provider binding
requires a new adapter. Reentry interrupts the outer operation; retirement during
the final owner check discards all already-collected query pages.

The initial topology configure repacks once into native float64 input. Each later
refit passes the existing packed float32 skin array directly. Query pages use
bulk packed-array slice/append, avoiding per-coordinate GDScript loops. Actor
views are duplicated at publication, not once per result page.

## Actual checks

The isolated project imports the unchanged real hero GLB and instantiates three
hash-verified prepared resident rigs. These are actual model geometry, with
**TEST_ONLY** displayed-pose receipts and no admitted gameplay targets. The hero
is the imported model fixture, not a running player scene. Each query result is
compared against a complete scalar scan of every triangle using the independently
accepted kernel: all candidate counts, global order, double score/distance and
native point/line/normal/barycentric vectors match. The actual selector accepts
the adapter ports and resolves a current skin contact on every fixture.

| Fixture | Vertices | Triangles | Last query rows / pages |
|---|---:|---:|---:|
| Hero | 8,338 | 13,034 | 302 / 2 |
| npc_resident_72 | 6,692 | 9,944 | 1,218 / 5 |
| npc_resident_169 | 6,713 | 9,936 | 1,359 / 6 |
| npc_resident_252 | 6,692 | 9,944 | 1,317 / 6 |

Adversarial cases include 1,200 tied candidates across five pages/two limbs,
caller mutation isolation, actual out-of-bounds native refit failure, failed
capture, new life, mismatched receipt, capture reentry/disposal, owner retirement
at query completion, provider reconfiguration with repeated IDs, freed provider,
wrong-thread rejection without invalidating main-thread data, malformed native
query failure, native Object destruction, real unpublished root motion, real
mesh replacement, and queued actual skeletons before deletion.

An earlier run had passing assertions but Godot reported an invalid self method
call during RefCounted PREDELETE. That run is **not accepted**; its receipt is
retained as `report_before_cleanup_fix.json`. Cleanup now performs the native
free directly within the notification; explicit and automatic cleanup tests pass
with a clean log. The final report is `report.json`.

Independent read-only review found a second callback gap: same-revision cached
validation could dispose the adapter, then the failed cache branch dereferenced
the retired provider before capture. A new live-binding guard now precedes that
dereference. Regressions cover cached-current disposal, reentry and rebinding;
all return failure and assert that no subsequent capture was invoked.

## Component CPU, microseconds

Per fixture: 16 warmups, 48 measured changing head poses, radius .14 m, full pages.
Numbers include real provider lifetime/frame checks, engine boundaries and output
copying for the named operation. Other project CPU/GPU activity was not stopped.

| Fixture | capture + refit p50 / p95 | complete query p50 / p95 | cached pose check p50 / p95 |
|---|---:|---:|---:|
| Hero | 1166 / 1490 | 418 / 614 | 133 / 180 |
| Resident 72 | 1123 / 1391 | 888 / 1112 | 164 / 278 |
| Resident 169 | 1063 / 1317 | 904 / 1121 | 164 / 252 |
| Resident 252 | 1072 / 1331 | 913 / 1116 | 166 / 248 |

Initial capture/topology build costs 10.7–14.9 ms in this run; perform setup at
controlled admission, not unexpectedly inside a hot combat sample. These are
component measurements, not before/after gameplay FPS. They exclude attack-pose
production, publication via `actor()`, the selector's repeated current-owner and
occlusion callbacks, source consequences, physical response and rendering.
The selector can call current-owner validation many times; its composed cost
must be measured before live adoption. No loaded-scene performance acceptance.

The native query remains synchronous. Paging bounds copy chunks, not compute
time. Its maximum allowed topology × four sweeps can allocate roughly 64 MiB
native candidate storage plus another 64 MiB packed result. This adapter does not
invent a timed-out miss, sampled proxy or stale-pose fallback; host scheduling
and target-count/time admission remain required.

## Remaining gameplay work

This package supplies geometry evidence only. The caller still needs admitted
source actor/session/life ownership, published real NPC poses, sweep windows,
current blocker snapshots, source damage/medical/death transactions, durable
triangle anchor identity, physical input and force calibration. No HP, attack
permission or native impulse follows from a nonempty result. Source IDs and life
are copied, never generated. Session authority is deliberately absent here.

## Frozen bytes and reproduction

- New adapter: `f7c663fe65f03a21c41c3b73ee7df4aea3d989757b635680671205460ad614d4`
- New test `scripts/tests/test_melee_native_query_adapter.gd`:
  `86c5ca6d781e945497fa41de28f96fb7614ec04399a696815681f9e7adf755e5`
- Unchanged provider: `db54fbb69ebd100ea283e1118b91acd3381a3aaa82857b94cc0f24ebc38b2081`
- Unchanged selector: `58b43da1d21badd08003ae8b0aad59db631c6946467cdff8892f259f528039e8`
- Combined DLL: `a5695c0b117e42a4847d10cdef0f7b71485f6243a7f412b6d6cb0eb5924c2add`
- Hero GLB: `8130dfb1f7eb91bff31e932feef1717672070a6767ccc726d7cb1ee23133fd00`
- Prepared NPC manifest: `3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0`

`outputs/coordinator22_native_query/run.ps1` copies only the needed existing
sources/assets/DLL into its isolated `project`, imports headlessly, then runs the
test with a bounded frame timeout. It rejects nonzero exits and any engine/script
error log. The full wrapper, including isolated import and all checks, passed
after Root released the CPU measurement hold.
It never copies/renames the inactive descriptor in the production project.

No commit/push or other owner's files were changed.
