# Host adapter V2 — source-only lifecycle hardening

Not production, not an actual pause/terrain/navigation owner. Extends the frozen
original editor_host_adapter SHA256
`1147d035070488da5b01e558faeee41fde40fc18b0ef86ab1d4a3f5385a3f360`.
No frozen/production script was changed. Independent review is pending.

Root reproduced original defects in
`../map_editor_host_adapter_review/test_lifetime_reentry.gd`: seven diagnostic
fixture checks establish queued-for-deletion owner admission, verify callback
reentry into leave, and readiness returned after the lease was released. The
independent review of an earlier V2 revision also reproduced two new gaps:
verify could queue workspace then still forward input; ground_patch could queue
main then resume was still invoked. That negative evidence is preserved at
`../map_editor_host_adapter_v2_independent_review/`. The current candidate
rechecks workspace/lifetime across callbacks and refuses resume after ground
invalidates the lease. A further independent counterexample exposed false
`handle_input` after the workspace queues itself during its own handler;
the current revision performs post-handler checks and consumes that event.

Candidate changes:

- Refuse queued scene/workspace owners before mount/bind/entry.
- Guard verification and readiness callbacks against nested enter/leave/readiness
  or workspace forwarding; retain normal pause/resume callback busy guards.
- Revalidate exact owner, request and receipt after callbacks before readiness.
- Revalidate workspace parent/lifetime after verify and readiness callbacks;
  revalidate the owner/lease again after ground_patch before resume.
- Revalidate owner, workspace and lease after workspace.handle_input itself;
  never forward its `false` across a callback-driven lifetime transition.
- Consume even a stable callback's `false` while editor/gameplay lease is active;
  preserve `false` forwarding only after the editor is genuinely inactive.
- Retain orphan/queued leases as blocked input barriers rather than forwarding
  input to a dying workspace or another game session.

Reproduce only via unique isolated stage:

```
node tools/godot/map_editor_host_adapter_v2/stage.mjs
Godot --headless --path <returned-stage> --script res://test_host_v2.gd --quit-after 1200
Godot --headless --path <returned-stage> --script res://test_original_contract_v2.gd --quit-after 1200
Godot --headless --path <returned-stage> --script res://test_independent_fixed_v2.gd --quit-after 1200
```

Root stage `outputs/editor-host-v2-d5HZUl`, official Godot 4.7.2: 57 boundary
fixture checks and all 13 original adapter contract checks PASS, no ScriptError.
The independently authored negative fixture has old_reproduced:false and
new_hole_reproduced:false, with exact `queued:true/forwarded:1/consumed:true`
for the post-handler case, and now exits0 under the opposite strict assertion.
The stager pins the original adapter, copies data-only document dependency,
preserves original test assertions (only preload switched to V2), and writes
exclusive new outputs. Source receipt contains copied file SHA/bytes.

Runtime SHA256:
`ff81ab148b1e2039a5d1b8d3a5d1dfca94ec57a2f4c161e0e9c0cc4fd1302efb`.
Test SHA256:
`cf3892d9554e9a54d49933dbcb50b2f6fcd0c8add831995e5fc7e8984aa656ee`.

All owner callbacks here remain TEST FIXTURES. Actual scene physics/input/clock/
navigation/water/authority contracts must be implemented and verified by their
real owners. This module cannot stop all clocks or grant valid terrain adoption.
Trusted compiled callback/workspace scripts and no arbitrary mutation of private
adapter fields are required; this is not a hostile GDScript sandbox. Full editor
LIVE, source generation reload, transactional ground/nav/water adoption and
fresh save/load acceptance remain open.
