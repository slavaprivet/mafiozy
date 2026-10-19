# Population atomic-resume candidate — tools only, HOLD for K

This derives the SHA-pinned Coordinator22 three-resident pause candidate. It
does not edit the production Godot project, its default-resident population,
or the navigation candidate. It exposes the requested population API:

- `prepare_editor_resume_atomic(receipt) -> Dictionary`
- `commit_editor_resume_atomic(ticket) -> Dictionary`
- `abort_editor_resume_atomic(ticket) -> bool`
- `finalize_editor_resume_atomic(ticket) -> bool` (tree still paused)
- `flush_editor_resume_atomic(ticket) -> bool` (after root unpauses)
- `cancel_editor_pause(receipt) -> bool` (only before root pauses)

Preparation and commit do not release resident/policy/navigation gates or
replay callbacks. Failed preparation/commit aborts acquired tickets in reverse
order. Finalization releases local residents/policy before the navigation host
while the scene tree is paused; the navigation host must retain completions.
Only `flush` after root unpauses may replay those callbacks. The legacy
population `end_editor_pause` is disabled in this variant. Cancel requires the
separate nav `cancel_editor_pause` contract, which must refuse held callbacks.

This is a **source-only candidate**, not proof of an atomic gameplay handoff.
The nav atomic variant's exact implementation, native import/negative tests,
default-population admission, and one-game LIVE/performance evidence are all
missing. An unexpected late refusal enters terminal HOLD. Do not wire K or
advertise all-resident readiness from these static checks.

Run `node tools/godot/map_editor_resident_atomic_candidate/test_source_patch.mjs`
for static structure checks. Do not stage/import/run Godot without the current
coordinator's separate CPU window; never create a second GPU game.
