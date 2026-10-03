# Release48: native C4 and matched loaded-scene measurements

Ready for root decision; engines RELEASED. No production, accepted45, current-version pointer or user process was changed by this QA work.

Immediate Q → LMB without camera settle: `c4_release48_fast8_03` PASS2093, all eight real native holds and one remote batch, exit0/stderr0. This proves the camera-v2 and shared-shape lifecycle fixes together on exact production48 closure.

Final matched pairs pass original NPC/camera/settings/input/window/source gates. Only the declared foundation geometry domain differs; `COMPARISON_FIXED18_1_RESOLVED.json` and `_8_RESOLVED.json` have no residual failures. All raw reports/comparisons remain unchanged.

| Charges | Phase | Accepted45 p50/p95/max ms | Release48 p50/p95/max ms |
|---|---|---:|---:|
| 1 | idle | 7.007/9.669/10.561 | 7.051/9.704/10.455 |
| 1 | actual_blast_and_physics | 7.026/10.274/18.201 | 6.960/10.753/22.870 |
| 1 | recovery | 7.056/9.701/11.929 | 6.963/9.692/13.059 |
| 8 | idle | 6.925/9.855/12.564 | 6.969/9.839/12.564 |
| 8 | actual_blast_and_physics | 6.750/11.387/18.672 | 6.796/11.995/21.864 |
| 8 | recovery | 6.856/9.478/11.128 | 7.022/10.886/12.128 |

Peak RSS: 1 charge 1532.070 → 1560.078 MiB (+28.008); 8 charges 1543.980 → 1581.586 MiB (+37.605). Private-memory peaks: +36.703/+31.094 MiB respectively.

The eight-charge candidate blast had 4/748 intervals above16.667ms, none above33.333ms; max21.864ms. Recovery p95 increased9.478→10.886ms (+1.408ms). The earlier unmatched candidate8 peak32.814ms is preserved. These observations are not proof of optimization or a guaranteed upper bound; release acceptance belongs to root.

Native receipts: final1 PASS58/1979 (29.412/29.553s), final8 PASS198/2105 (55.577/55.521s). Both variants used an equal18 physics ticks after real Q, with last-three-frame stability checked. Scene/NPC-ready is observed read-only from main's immediately subsequent PreviewPerf insertion; first hold is ready+110 for pair1 and ready+130 for pair8. Actual anchors/holds are10/120 and10/140, respectively. All eight repeated waits are exactly18 ticks. Native windows are focusable, render normally, and use real Input.parse_input_event / Viewport.push_input; no NPC freezing, input callback substitution or runtime timer changes. Soft56s/hard60s remain unchanged.

Initial unequal early-settle results are preserved: baseline needed18ticks and camera-v2 only3, causing up to120ticks of NPC age mismatch. A fixed110 boundary eight-charge attempt failed before holds because aim completed at111; that evidence is preserved. Root-selected130 provides margin without changing any measured window. No further runs are scheduled by this package.

Foundation exception is narrow: all657 original owned authored rows and remaining statics are exact; posthost statics are exact after removing only the verified OriginalFoundation. Replacement12cells match4×3 positions, identity bases, dimensions and enabledBoxShapes. The owner's frozen native r3 proof confirms689 unchanged physical/visual records and explicit1static→12rigid/44→144 authored triangles. Both perf variants preserve their own known frozen-body hashes from prehold through preblast, with the same released LobbyTable index96/dynamic1/awake0. Raw frozen-row arrays were not recorded; this is a source-linked scoped exception approved by root, not a fabricated normalized phase hash or direct r3 predicate on a warmed scene.

Idle render-primitives deltas are+8102/+40890 for1/8; blast deltas+4640/+840. The baseline charge is fourBoxMeshes; candidate uses detailed c4_visuals ArrayMesh/TextMesh/wires/screen. Idle includes planted charges; consumption sharply reduces this model delta. Geometry positions/camera/NPC gates pass. Exact attribution by draw pass was not captured. Godot's [primitive monitor](https://docs.godotengine.org/en/stable/classes/class_performance.html#class-performance-constant-render-total-primitives-in-frame) counts rendered vertices/indices including depth/shadow passes, so it must not be relabeled authored triangles.

Detailed diagnostic snapshot/event work is confined to placement holds. Measured idle/blast/recovery carry the same per-process focus check and empty active-hold branch. Authored rows are captured before the measured phases. Wall intervals are authoritative; periodic engine process/physics maxima are retained separately, never subtracted to invent GPU time.

Current source closure: accepted45 production473 +metadata1 +QA9 =483; release48 production486 +QA9 =495. Pair1 retains its earlier482/494 manifest identity. Production48 ASSEMBLY SHA513c9165b7f00be7e6cb8967470a5513e4d37e8fd8642f528d29ec36c08dd83c. Full manifest bindings, raw intervals, checks, source hashes and phase peaks are in FINAL_REVIEW.json and the linked run directories.

The separate registration adapter preserves original engine deadlines, exact editor identity, registered-child identity and all unknown user processes. Required parallel headless imports exercised the real publication race: WAITING→REGISTERED in1.3347745s with exact parent+child creation identities and full command. Functional remains graphical/read or headless/write; measured pairs use perf/read. No fallback to exclusive-perf is required for future functional tests.

Revalidation only (no engine): `check_fixed18_pair.py --charges1` and `check_fixed130_pair.py --charges8` recompute comparisons, but intentionally refuse to overwrite existing output files. `prepare_fixed130.py` defaults read-only. `resolve_foundation_pair.py` verifies the four scoped exceptions against pinned native evidence and preserves all other failures. All old packages, stages, source freezes and receipts are retained.
