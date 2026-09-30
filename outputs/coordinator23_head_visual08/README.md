# Root-only close views of final compiled combat pack

Prepared only: **not launched, GDScript syntax/render acceptance pending**. Python runner syntax checked. Accepts exact future23f pack (candidate08/09) via explicit --pack and --sha256; verifies sibling export receipt. It does not assume old08 implementation bytes.

```powershell
python outputs/coordinator23_head_visual08/run_capture.py --pack "ABS/MafioziPreview.pck" --sha256 "EXACT_SHA256" --out "ABS/FRESH_VISUAL_RESULT_DIRECTORY"
```

Root must stop/restore the user game with its usual finally wrapper. This runner does not manage other processes. Uses GUIexe directly, NO_FOCUS and offscreen position-32000,-32000,1280x720;25second subprocess timeout and23second harness guard. No headless/GPU launch has occurred here.

Four intended PNGs with adjacent JSON:
1. Clothing wound after one real TT input shot.
2. Skin wound after real anatomical head input shot.
3. Final head/closed eyes from first local head axis side.
4. Opposite side, so both face/back are visible without assuming authored face direction.

Normal main, three moving NPCs, buildings, car, colliders, materials and physics stay enabled and unmodified. Inherits proven actual-input helpers from a locally frozen test: equip inventory TT, send normal player fire events, check fresh actual muzzle sight, one shot/one spent round and native impact. Only first-shot source RNG chooses noncritical damage. The second aim must pass native muzzle/head-skin proof before firing; if unavailable, harness fails instead of fabricating damage. No fake wound generation, HP/physics writes or corpse freezing.

QA aim camera is detached and tracks torso/head; small bounded vertical aim offsets compensate coarse proxy/parallax. These are test camera fixtures, not player-camera parity. A separate42degree observer follows the actual mark's current original triangle/barycentric skin attachment for close views. No shader/material changes. Normal UI stays present. Root should visually inspect both eye-side PNGs; file existence alone is not closed-eye visual proof.

VISUAL_RESULT records current bound mark event, clothing/skin flag, source surface, live anchor position/normal, head/contact receipt, ammo/shots and raw native impacts. RESULT retains inherited assertions; RUN records exact pack/receipt and runtime bound. Four key implementation resources must load as compiled scripts without source. Both success/error evidence is retained; unavailable cloth/skin mark yields explicit FAIL.

This is appearance/behavior capture, not full-scene performance. First-use shader timing is owned by root's separate cold/warm benchmark. Use fresh --out each attempt; no existing results overwritten.
