# Home approach58 — isolated native PASS

Root subsequently integrated both payloads into stage58_07 (1212pins, manifest SHA256 `17f17cb0f4d9b577a68e02812c9272ec64e2cc7ec25eb0ade90e2b20a7eccaf9`). QA independent verification is preserved at `../qa58_routines/INDEPENDENT_HOME_APPROACH58.json`. The native receipts below remain the original exact06 overlay evidence; they have not been relabelled as stage07.

The distant guide selected a standing-clear point inside closed HOME58-002 before resident6 reached the exterior doorway staging. Exact stage06 native reconstruction reproduced checkpoint11 `[45.799491882,.243000016,187.286697388]`; the local physical planner then tried to reach inaccessible interior space. Two preserved stage05 full cycles failed this resident while the other nine physically completed home sleep and exit.

The two-file fix rejects intermediate guide checkpoints inside a current home when the requested endpoint lies outside that home. It uses the existing bounded radial repair and physical floor/standing checks. Exact final destinations, native movement, collision masks, door/bed ownership, population and work limits remain unchanged. Stale/destroyed home rows do not impose the restriction. Endpoints inside their own house remain allowed.

## Integration payload

`PATCH.json` is the flat root-integrator format; its SHA256 is `160954f2b26170669aa6dec7a8df1365d29af862b238d094a7ae40b98dd670d6`.

| Relative file | Base SHA256 | Candidate SHA256 |
| --- | --- | --- |
| scripts/homes/npc_home_registry58.gd | fbda1b59044f483ae4e04f69db1728aeb8aacc9c54896aa9e5341166158e5f5a | 60c44ebec1812571b47834b9270bd68a0af9e981aac6b2395bb7bc4601c10b79 |
| scripts/hospital/npc_long_route28.gd | 49681adf8f9108d53e559172fe8963ea9e20b278e69b7a03af3dae4015f78c54 | e49d12722b859e8885561172799fc756b689792dd277858cfa950f4fe0230cf2 |

Payloads are under `patch/` and the minimal diff is `PATCH.diff`. Independent scoped review by godot_addons31 found no concrete blocking defect; its limitation was the required native resident6 proof, now complete. Integration belongs to root. This agent did not change candidate, frozen releases, F5 or Git.

## Preserved native evidence

- `runs/native_guide01`: exact06 baseline diagnostic confirms the inaccessible interior checkpoint. Its diagnostic PASS means the defect was successfully reproduced.
- `runs/native_guide_candidate01`: exact06 plus the declared two-file overlay uses existing repair to select supported exterior `[46.914962769,.002999985,191.12802124]`. Final staging `[42.299999237,.003000015,193.650009155]` is byte-equivalent in recorded numeric data. One repair, 21 home rejections, 37 bounded probes; prepare max464us, guide work2154us. These are functional observations, not a performance comparison.
- `runs/native_cycle_candidate01`: actual ten resident bodies, original positions, native 60Hz physical callbacks, all10 home intents concurrently. **55/55 checks PASS**, ten actual sleep poses and ten physical exits, concurrent assigned occupancy3+3+2+2, no remaining claims. Native175.74878s / process wall209.62218s. Source1212 and controls unchanged, errors0, stderr0.
- Resident6: entered115.866578s, actual sleep121.399922s, physically outside174.666073s. Travel217.633792m; cumulative planning191373us with no decreases, unchanged500000us bound, exit retries0. The repaired checkpoint was followed with the exact original exterior target. Maximum native step across all10 was .03098315m.
- `audits/native_cycle_candidate01/AUDIT58.json`: unchanged motion10s, queue30s and spatial30s/1.5m gates PASS. Maximum required motion idle .992566s; resident6 recorded0s at1Hz. A sleep/rest sample is excluded only with current support, claim and current/prior pre-host pose commit.
- `ACCEPTANCE58.json`: CPU verification41/41, including exact source, manifest, complete declared control archive bytes, overlay bytes, endpoint identity, physical completion and cumulative work. Recompute with `python -B .../home_approach58/check_evidence58.py`; this launches no engine.

Raw old FAILs remain in `homes58/runs/native_cycle01` and `native_cycle02`. Baseline/candidate guide proof uses the same stage06 scene. The earlier whole-cycle baseline was stage05, so the whole-cycle results are regression evidence rather than a strict matched performance pair. V3 deep-copies mutable diagnostic dictionaries; old V2 service_watch/avoidance history has the documented alias limitation.

## Limits and remaining acceptance

This is physical component acceptance: the fixture explicitly owns home intents while real body, health, host, collisions and city continue. It does not accept new ordinary daily scheduling or FPS. Headless committed skeleton geometry passed for all10. The earlier actual resident3 image and C4 wake/physical-exit proof belong to unchanged stage05 home helpers; they are supplementary evidence, not new graphical acceptance of the full stage06 assembly. Reset of an occupied sleeping house remains a distinct lifecycle scenario unless covered by subsequent QA. Root controls merged-source acceptance and release.
