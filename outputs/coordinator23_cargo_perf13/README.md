# Prepared loaded cargo rendering pair — ROOT ONLY, NOT RUN

Use accepted candidate11 PCK ae82e44c... as baseline and root's final candidate PCK as after (currently15:133fe8dc...). This package has NOT launched any engine or GPU. Python helpers were AST-parsed only; GDScript runtime remains unvalidated until root runs. No fabricated result files are supplied.

## Scenario

One offscreen1280×720 NO_FOCUS window per process at(-32000,-32000), identically on both sides, uncapped, vsync disabled, Vulkan Forward+, TAA+MSAA4×, medium shadow filter. Input.mouse_mode remains VISIBLE; no capture setter, native key dispatch, mouse warping, fake GUI hover or overlay camera. Driver explicitly renews logical QA admission on scheduled physics only if external focus revoked it. Thus this is rendering/public-API performance, not OS input/focus acceptance. Offscreen position and NO_FOCUS may affect absolute desktop pacing: same position/flags and comparable desktop conditions are mandatory on both sides; no overallFPS claim.

Loads compiled actual main with all3original NPCs,8buildings and377original collision bodies/shapes; fails if counts differ. Player placed at real supported hatch access once, attached spring camera kept at yaw−PI/2,pitch−.32. No collision flags, meshes, physics steps, actor updates or camera ownership are disabled. All14 real inventory items are equipped/stored through existing admitted public API, preserving UID and finite ammo. Modal stays open during setup/warmup so candidate world model highlight is not prewarmed. No camera target search or geometry edits.

Three phases, each240 actual frame_post_draw events: close contents(false) → first world hint/possible model highlight; open contents(); close contents(false) again. These public transitions avoid11vs13 native E/F semantics and never request mouse capture. Snapshot/collision traversal/PNG readbacks occur outside measured spans. Before/after assert unchanged14UID/ammo,3NPC/8buildings/377collisions, camera angles/top-levelfalse and modal state. NPC autonomous activity remains running.

Raw frame wall intervals, GPU and renderCPU timestamps, static/VRAM memory, drawcalls/primitives all saved per frame. First transition interval begins immediately before public action, intentionally not a whole preceding frame. First1second comparison includes every overlapping frame interval, including stalls that end outside the nominal window. No p95-only acceptance. Actual first model hover is observed from native renderer, never forced; fixed ray missing means explicitSKIP, not a first-hover performance PASS. The unchanged attached camera and exact actual aim receipt are saved. Scene PNGs show the real viewport; hardware cursor is not composited.

55s internal failquit,60s external bound per process. Root owns other GPU processes: run sequentially only after its inventory/quiet check. The launcher never closes any other app. Do not run baseline and candidate concurrently. Do not change/delete shader caches here; supply truthful identical --cache-note policies and retain root cache receipts. Normalwarm/cold cannot be inferred solely from first use in this harness.

## Root commands

Run `python outputs/coordinator23_cargo_perf13/run_pair_side.py --side baseline --pack <absolute candidate11PCK> --sha256 ae82e44c46cf3d5f420897c7e91d8a631691dbf4180d27c45342ff428916209e --out <fresh absolute before directory> --cache-note <same truthful policy>`.

Then use the same launcher with `--side candidate`, final candidate's exact PCK/hash and a fresh after directory. Candidate15 hash, only if still final:133fe8dc70af97eee15fc4a069f11d1b87fb57ad0699d08e6e4bb07d520c329b.

Compare: `python outputs/coordinator23_cargo_perf13/compare.py --before <before directory> --after <after directory> --candidate-sha <exact after hash> --out <comparison.json>`.

Comparator rejects incorrect hash/settings/harness, missing720frames, content/ammo/actor changes, focusflag mismatch and camera/player drift exceeding.01 native units/basis components. UID values are checked within each process, not compared across generated sessions. It emits metrics and comparability, never invents an acceptance threshold. Root must inspect maxima, raw first-use intervals and photos before adoption. A short240-frame pair does not establish long-duration leak behavior or all-camera worst-case performance.

Root steering before launch: both launcher and SceneTree initialization explicitly position(-32000,-32000), so no unfinished demo appears on the desktop. Raw snapshots record actual window position, settings record nominal position, comparator rejects side-to-side position differences. These are actual viewport GPU timings under offscreen/NO_FOCUS conditions, not visible-window/native focus acceptance. Metadata corrected before any pair run; retain one identical harness SHA on both sides.
