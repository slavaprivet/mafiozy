# Cargo controls13 — latest Take returns to gameplay

Frozen three-file proposal against accepted23g; exact guards in RECEIPT.json. Supersedes controls12 (whose244-test evidence stays intact). No shared writes/GPU/Git.

World controls: E on an actually picked weapon takes that UID; E with no item remains available to existing transport to open/close the hatch. F opens contents beside an accessible open hatch, G stores. The compact world hint shows E/F and optional G without a large inventory/capacity panel. Existing world geometry placement protections remain.

Modal controls: mouse-hover card is highlighted; E takes only that currently hovered UID. No hovered item means no take/close/seat action. Take button and E immediately return to gameplay on successful ownership transfer, cancel trigger state and claim the GUI activation before hiding. Any still-held E/Enter/Space/LMB activation is quarantined until its release. Failure stays in the modal with feedback. Q/X return to captured gameplay; Esc frees controls. Close-lid button remains.

Focused normal game restores player.set_mouse_captured(true) synchronously, so a second capture click is unnecessary. NO_FOCUS synthetic offscreen QA does not steal the desktop pointer. Invalid range/lid/owner/snapshot closes via a dedicated helper and explicitly releases both logical control and OS mouse. Generic close_window(false) retains its existing meaning for the arsenal transition; clearing logical control there would prevent Q-menu equip.

All Take/Store/Close/shut buttons request the pointing-hand cursor, ready for root's custom cursor assets. Renderer hover seams are called only if available: normal .15second context refresh uses set_hover(context), all clear/modal/control/lid paths use clear_hover(). The independent root/equip renderer and picker proposal supplies the world model outline. Modal hover is independent of keyboard focus; native Tab/Enter still activates focused buttons.

269 native headless checks PASS: real mouse motion/card highlight/E exact UID+ammo, real LMB press/release Take, automatic logical gameplay return, movement without another click, no activation shot/ammunition loss, held E release suppression, F reopen per transfer,14roundtrips/cap100, stale/access/closed-lid, repeated1280/800/640 layout and Tab/Enter. The fixture uses the actual main/player/inventory/cargo/transport, NPC disabled for component verification.

OS mouse capture is explicitly SKIP in headless: direct Godot4.7.2 Dummy setter probe returns VISIBLE even after assigning CAPTURED. Logical control/unblocked state and real movement are verified; focused GPU capture and actual rendered visual acceptance remain root's checks. Results: RESULT04.json/native04.log. Earlier native01/02 capture assertions failed for that Dummy limitation; a test-only mojibake close-label was repaired in04, restoring all269 assertions. Runtime files were unchanged across those runs.

Root/equip owns actual world picker/outline proof. Root should merge all five exact files, custom cursor and updated notes into one isolated candidate, then run full3NPC GUI+world acceptance. Previous GUI harness10 assumes E opens and Take keeps the modal open, so it must be adapted before use.
