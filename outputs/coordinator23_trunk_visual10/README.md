# Trunk GUI acceptance — root launch only

Prepared, not executed. Root must serialize this with other GPU work and manage the user's game restoration. The launcher invokes the GUI engine directly, offscreen with NO_FOCUS, deadline 40 seconds. It verifies the exact PCK and sibling export receipt before launch. No production files change.

`python outputs/coordinator23_trunk_visual10/run_capture.py --pack ABS_PCK --sha256 EXACT_SHA --revision s01-20260930-quality23g --out ABS_FRESH_OUTPUT`

Compiled main and all three original NPCs remain active. No population, collisions, materials, physics, item data or ammunition are fabricated. All 14 weapons are equipped and stored through the real owners, retaining their exact UID and finite ammunition. The fixture places only the player near the physical rear hatch and sets a regular attached camera orbit. Setup uses owner APIs; actual acceptance take/store/close clicks are InputEventMouseButton press/release events at the visible button rectangle, never direct pressed signal emission. E/Q use the real input dispatcher.

Images: 14-card window at 1280×720 and 800×600; scrolled final row at800; Q arsenal at800. Small viewport explicitly uses 1:1 content_scale_size so the responsive layout is exercised rather than merely shrinking a1280 canvas. Card clipping, last-row reachability, store and close button bounds are asserted. Two first-row take/store round trips and one last-row round trip check real GUI behavior; stale UID and same-frame closed-lid callbacks must fail. Q closes trunk without opening arsenal; subsequent Q opens arsenal alone.

The offscreen harness never intentionally captures the OS mouse. For modal-close actions it momentarily clears only the logical free-look flag during synchronous event dispatch, then restores it; this avoids the existing production close handler's CAPTURED branch. GUI take/store uses normal logical input throughout. This is explicitly a safety fixture, not focus behavior acceptance.

Short 60-frame wall/GPU/draw/memory samples before/after opening a fully loaded window retain3NPC,8buildings,377collision objects/shapes and the same player/camera. They establish that actual rendering happened and provide diagnostics, not a statistically comparable performance verdict. Do not interpret an offscreen screenshot test as native camera validation or first-use stutter closure.
