# Independent Escape review — candidate22 / 24b

No release blocker found for the narrow F → Esc behavior. Read-only review; no engine/GPU/production changes by reviewer.

Independently verified all209 receipt source hashes and exact PCK `becb595b967ca70fe31660e137a9e591a17abb2418259733fa707342ddc7a749`. Against candidate20, authored content differs only in cargo, main revision and notes. Cargo's sole change at line662 is `close_window(false); weapons.player.set_mouse_captured(false)` → `close_window()`. Main/notes agree on24b. Receipt SHA `7864b23dcb9218b77864489d8505c1eeed9ecdd4652368e36bb117d971c814cb`.

**Propagation is correct.** While the modal is active, `preview_weapons._input` sends Escape through `input_event` to `window_input`. The latter returns true even after closing the window, so the weapon host marks this same event handled before the player's ordinary `_unhandled_input` Escape branch. Existing `close_window()` resumes only allowed, focused gameplay and restores physically held movement. No new per-frame work is added.

Held Escape echo and its key-up cannot toggle capture: the subsequent key path requires pressed && !echo. A distinct second Escape reaches the unchanged player release branch. Real focus-out still invokes `set_mouse_captured(false)` → release_controls → close_window(false), releasing actions; focus-in alone does not recapture. The existing focus check also prevents an unfocused modal close from capturing the cursor.

**Saved evidence is consistent:** baseline01 reproduces the extra-click behavior (27 PASS); candidate01 restores held-W movement without a click (26 PASS); focused01 has30 PASS, actual focus=true/capture2,0.034236m motion, later Escape restores visible cursor. All exit0, unchanged pinned pack, no native errors. All use the independently matching harness SHA `8cdc92e8ec88d0c60c52d6e07adf109f8be79d0a5a2b0cdaae6955f5847f67aa`.

Test honesty/limits:

- F/G/Q/Escape use real Godot event dispatch; no game script override or manual gameplay tick. Original3NPC/8buildings/377collision and attached camera stay active. Player relocation, direct initial weapon equip and opening the real hatch are declared setup fixtures.
- UID/ammo/equipped/cargo equality, no shot, unchanged lid/seat, echo/key-up and second Escape are asserted. W key-up checks action release; this harness does not repeat candidate20's detailed physical deceleration proof.
- New harness does not perform Alt-Tab/OS focus-loss tests. Blur preservation above is source review plus unchanged inherited code. Injected Godot keys and real native capture are not manual OS-keyboard proof, camera-rotation proof or a blanket freeze fix.
- Runner verifies209 sources before launch, fixed PCK before/after and45s own-child timeout. It relies on Root to keep GPU execution exclusive; it has no process-inventory guard. Harness hash is recorded after execution, so keep its bytes frozen during runs. No evidence of a mismatch exists in these three results.
- No GPU/performance regression claim is made from this functional run. Existing behavior/performance for the unchanged paths remains inherited.

Runner reviewed SHA `ad2a22c793c96f84fffcda3b2a85eadd70844125228d5b639fea19442382cc0d`. No further runtime change is recommended for this delivery.
