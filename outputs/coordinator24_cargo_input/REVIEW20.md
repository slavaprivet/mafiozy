# Read-only review of composed candidate20

Reviewed candidate20 manifest and four changed files against candidate16. No candidate mutation or native run during this review.

- Cargo movement helper is identical to this proposal and called only by existing focused modal resume. _allowed repeats current player/transport authority admission. Jump/E/fire stay excluded; focus guard is unchanged.
- The composed second fix only uses cancel_inputs(false) during take_item preflight; cancel_inputs defaults to prior camera-reset behavior for all other callers. Successful _apply_transfer still performs normal reset after paired ownership commit. UID/ammunition paths unchanged.
- main runtime revision24a and preview_updates runtime_revision agree. UI describes the two concrete cargo behavior changes and explicitly leaves RPG blast damage unfinished; it does not claim the whole intermittent freeze report fixed.

Remaining meaningful acceptance gap: tests press/release mappings in a loop, but opening the next modal clears actions again and could mask a sticky synthetic action_press. Add the following assertion immediately after each physical mapping key-up, before any subsequent open_window:

    check(not Input.is_physical_key_pressed(pair[0]) and not Input.is_action_pressed(pair[1]), "resumed mapping releases on physical key-up " + str(pair[0]))

A physical movement follow-up after released W can also verify that no continuing motion remains after the controller's normal stopping interval. The action-state assertion is the essential immediate regression check.

Compiled acceptance must not use --patch, which intentionally overlays the standalone W-only proposal. Use a test-only --compiled-candidate mode to enable mapping/negative assertions without ResourceLoader takeover, or root's equivalent harness. No defect is claimed until the proposed key-up assertion is executed.
