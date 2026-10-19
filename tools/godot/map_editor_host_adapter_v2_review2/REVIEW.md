# Independent host V2 review 2

Current runtime SHA256 `67a7c60a32b7e692d15b6119af6851107cac94f1d74ec5c4dde20dbc2098e700`; frozen base SHA256 `1147d035070488da5b01e558faeee41fde40fc18b0ef86ab1d4a3f5385a3f360`. Review script SHA256 `a6330557cf6c59771edb825d952f64be4360d358a0f06772aa368773ec825259`. No production, main, GPU, or real scene owner changed.

Fresh isolated stage: `outputs/editor-host-v2-juMzFb`, source receipt pins all staged bytes. Official Godot 4.7.2 headless: V2 fixture **47/47 PASS** and original contract **13/13 PASS**, both exit 0. Independent negative script `test_negative.gd`, staged as `test_independent_review2_negative.gd`, exit 0 with `old_reproduced:false` on exact old conditions:

- Workspace queued during verification: `queued:true`, `forwarded:0`, `consumed:true`, `leased:true`, `blocked:true`.
- Owner queued in `ground_patch`: `refused:true`, `owner_queued:true`, `resumes:0`, `leased:true`, `fault:true`.

New input callback lifetime gap: `Workspace.handle_input` can call `queue_free()` on itself and return false. V2 delegates to inherited `handle_input`, which forwards that false without a post-callback lifetime/lease check. Observed `queued:true`, `forwarded:1`, `consumed:false`, `leased:true`, `blocked:true`, `new_hole_reproduced:true`. A caller using the returned bool to decide propagation can pass the same input to stopped gameplay. The workspace callback is an ordinary fixture; no private host fields were changed. Before accepting the host input boundary, recheck workspace identity/tree/queued state and original owner/request/receipt/lease after the workspace callback; consume if any changed. Stable callback false can keep its existing meaning.

This is a component fixture only. Actual owner pause, clocks, navigation, terrain, authority, editor LIVE, and full migration remain unverified.
