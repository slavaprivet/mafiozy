# Narrow root-owned invalidation fix

`proposal.patch` only expands the `preview_weapons.advance` interaction-denial cargo closure with `player.set_mouse_captured(false)`. It does not touch the arsenal/Q handoff or player implementation. The modal is already closed before releasing controls, so recursive weapon release sees no active cargo menu.

Actual scheduled native regression: `before/RESULT.json` reproduces the one failure (modal closed after public pose-authority handoff, logical controls remained active). `after/RESULT.json`: **18 checks PASS**, with all original residents enabled. Tests use the production public `set_preview_pose_authority` API before scheduled physics; no direct `advance`, no manual player physics. Inventory and shots are preserved; Q closes cargo, next Q opens arsenal, Q closes arsenal; direct public arsenal handoff and selecting/equipping a weapon still work.

`cargo_focus.patch` is separate and proposed atop frozen cargo13. It adds explicit `player.set_mouse_captured(false)` when the actual rendered window lacks focus. This closes the remaining focus-loss race. The existing headless or truly focused path is unchanged. Rendered NO_FOCUS tests must expect suspended controls, not silently pretend capture happened. The actual no-focus branch has not been rendered by this agent.

`../probe_rendered_backend.gd` is PREPARED ONLY and refuses headless use. Root-controlled NO_FOCUS window loads actual main; it calls the real player setter CAPTURED → reads mode/flag → VISIBLE synchronously, without any await while captured or any force-focus. It proves backend capture support only, not cargo's real focused Take branch. A fleeting native capture may move the OS cursor; before/after positions are recorded. Temporarily clearing NO_FOCUS does not prove focus, and force-focusing the desktop would interfere with the user. No focus override or logical flag substitution is used.

No shared production, source NPC files, Git, or GPU were changed. Isolated `stage` copies all scripts/metadata and hardlinks only immutable large binary assets.
