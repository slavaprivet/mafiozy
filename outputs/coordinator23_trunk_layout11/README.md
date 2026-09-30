# Responsive trunk proposal11

Two-file narrow overlay against candidate10 exact SHA guards in RECEIPT.json. Production/candidate10 untouched.

Cause: unwrapped long weapon labels constrained all grid columns; panel size was requested before child minimum widths changed, then the viewport-size cache prevented a retry after deferred container sorting. Long hint/empty/error labels and horizontal held/actions footer also imposed avoidable minimum widths.

Fix: wrap informational text and item names; give held-item information its own line above two equally sized action buttons; update child widths first and retry the requested panel size only while deferred minima leave it unequal. Existing thumbnails, names, item UID/ammo ownership and cargo limits unchanged.

Keyboard fix: modal early input yields only fixed GUI navigation/activation keycodes to GUI. Unhandled modal input still consumes unused keys; gameplay movement/fire/jump remain blocked. Native tests dispatch Tab and Enter to real focused buttons, verifying transfer and store with preserved UID/ammunition and Space not jumping.

233 headless checks PASS: original143 behavior checks plus90 responsive/keyboard assertions. Resize sequence800x600 ->1280x720 ->800x600 ->640x480 ->1280x720. At800, panel exactly752x552 at24,24 (minimum722x245), all14 buttons reachable through scroll, close/store inside viewport. At640, panel592x432 at24,24. This is component CPU/layout verification with NPC disabled; no GPU/performance/visual PASS claimed. Root should rerun frozen actualGUI harness10 against exported next pack, full3NPC and unchanged collision workload.

Files are frozen. Private stage is reproduction support only, not a publishable source artifact.
