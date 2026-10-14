# Independent V2 boundary review

27 September2026. Frozen candidate `host_adapter_v2.gd` SHA f9373f2c26962f05ed5325e2556d7f49739406d3fbd5d0152dafcb3444ef2947 unchanged. Original base SHA1147d035070488da5b01e558faeee41fde40fc18b0ef86ab1d4a3f5385a3f360 unchanged. Source review + one bounded Godot4.7.2 headless negative run; no production/main/GPU or real gameplay admission. All callbacks in this test are diagnostic fixtures.

## Two reproduced holes

1. **Workspace may die during verification, then receive input.** V2 `handle_input` checks queued workspace before invoking inherited implementation. Inherited implementation calls `_lease_valid`; actual verify callback can queue the workspace while keeping the scene/lease valid. V2 postflight checks only main/receipt/request. Base then forwards to the already queued workspace. Observed `queued:true`, `forwarded:1`, `consumed:false`, `gameplay_blocked:true`. No private adapter state mutation required. Blocking separately via `gameplay_blocked` protects a correctly written caller, but does not make the stated handle-input lifecycle barrier reliable.

2. **Owner may die in ground_patch, then receive resume.** Base leave obtains readiness before calling `ground_patch`; a valid callback can queue the main during that call. It immediately dispatches `resume_gameplay` without a post-ground current owner/lease check. V2 leave only guards before invoking base. Observed `resume_calls:1`, `resume_received_queued_owner:true`; return eventually fails and retains lease. Retention is correct, but the stale owner has already received potentially irreversible resume effects. Failure after dispatch is not a safe pre-dispatch boundary.

Suggested bounded correction in NEW reviewed candidate, not edited here: capture workspace weak identity/ancestor/current lease before verification, recheck immediately before forwarding; consume input on any loss while lease/request/fault is held. For leave, revalidate original main identity/not queued/in-tree and lease/request after ground callback, before resume. Treat callback reentry and lifecycle failure as retained unknown partial state, not cancellation of owner work. Public genuine owner callbacks must themselves maintain their checkpoint/lifetime guarantees; adapter cannot make arbitrary unsafe owner implementation atomic.

## Guards reviewed positively, within declared trust boundary

`_verifying` and `_querying` correctly reject nested enter/leave/readiness and forwarding during verify/readiness callbacks. Readiness checks captured main/request/receipt after callback. `_main` rejects queued scene owners, enter rejects missing/queued owners before pause callback, and orphan/queued retained lease consumes events. Existing `_busy` prevents transition reentry in pause/resume/ground callbacks; it does not stop callbacks from changing Node lifecycle. Dictionaries/private fields remain trusted, not a GDScript security sandbox. Callback validity at mount alone is not proof of callback compiled source lifecycle; owner-managed Script reload/generation remains separate admission requirement.

## Reproduction

Independent test `test_negative.gd` (new package only). Existing isolated `outputs/editor-host-v2-lzJ9Cg/test_independent_negative.gd` is a new entry referencing this test; no staged candidate/base mutation. Command: Godot console `--headless --path outputs/editor-host-v2-lzJ9Cg --script res://test_independent_negative.gd --quit-after300`.

Native output `reproduced:true`, both negatives above, exit0 means the flaws reproduced, NOT that candidate passes safety acceptance. No real main owner was replaced with fixture success; no synthetic pause/nav/terrain readiness is advertised. Root17+13 previous fixture PASS cannot cover callback-induced workspace/ground lifetime transitions until corresponding negative assertions are added.
