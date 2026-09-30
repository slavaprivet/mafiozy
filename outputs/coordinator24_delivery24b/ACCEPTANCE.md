# cargo24b — delivered modal Escape fix

User reproduced F (cargo contents) → Esc → extra left click required to move.
Exact previous24a reproduces this:27checks, one neutral click,0m held-W motion.
Candidate22 changes one runtime line: modal Esc calls the existing close_window()
path, restoring capture and physically held movement keys. Its input event is
consumed; echo/key-up cannot reach normal player Escape handling. A later distinct
Escape outside the modal still releases the cursor.

Exact compiled candidate: headless26checks and focused native GPU30checks PASS.
The focused run reports capture2, windowfocus=true, movement0.0342359m without any
click, preserved cargo/UID/ammo/transport and no unintended shot. Root inspected
after_modal_escape.png; overlay identifies24b and the contents modal is closed.
Independent REVIEW.md found no release blocker and verified all209 frozen inputs.

PCK: becb595b967ca70fe31660e137a9e591a17abb2418259733fa707342ddc7a749.
Receipt:7864b23dcb9218b77864489d8505c1eeed9ecdd4652368e36bb117d971c814cb.
Three guarded production files promoted,1725other source files byte-preserved.
Immutable export copied to quality24b-play; user game PID34044 responding at17:45,
project shortcut updated. Fresh inventory had no old user game; Manager45268 retained.

Limits: keys are injected through Godot, not manual Windows keyboard proof. Actual
window focus and mouse capture were observed. This new regression does not exercise
real Alt-Tab; existing focus-loss guards remain unchanged. No added per-frame work,
only routing Esc through the already-tested close path. Prior24a timing remains
limited to the three-resident preview; no new whole-city FPS claim. NPC visits,
postmortem marks and blocking/nudging improvements are not included in this release.
