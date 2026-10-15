# Exterior admission guard — services31 resume

Ready for root integration into the merged six-file candidate. The common game and previous evidence are unchanged.

## Defect and exact change

`npc_restaurant_visit28.step()` updated `_entered` whenever the actor was more than0.55m behind the entrance plane. That plane spans the city. An exterior actor approaching from behind the building could therefore become entered while outside the venue bounds. On a genuine route failure, `needs_exit()` remained true, the capacity claim stayed owned, and `begin_exit()` created an OUTBOUND path to an internal door staging point. This matches the newly observed resident8 failure signature; the city trace does not itself contain the bounds/door to prove the exact geometry.

Change exactly one line:

```gdscript
if not _entered and _initially_inside30(): _entered = true
```

The existing helper requires the measured venue envelope, matching interior floor height and native capsule/floor support as well as depth. Existing genuine entered ownership is preserved; the helper is skipped once entered. World/door collision and route budgets do not change.

## Native evidence

- `runs/baseline02`: clean expected FAIL, native real shop and four exterior walls. Actor begins15.5m behind the door plane, outside venue envelope. First step wrongly sets entered. Actual native planning reaches `service_planning_work_limit30` after672 physics frames; the claim remains owned and false OUTBOUND starts.
- `runs/candidate02`: PASS10/10. Same SOURCE and HARNESS hashes. Actual planning reaches the same failure reason after667 frames. Entered stays false, claim releases, false OUTBOUND is refused.
- `runs/entry_exit_candidate01`: PASS30/30 using the inherited actual compact-shop regression. Genuine entry and physical exit, exit under8s, two-way native overlap, collision exception cleanup, player/wall/closeddoor and hit rays remain correct.
- All runs exit0, stderr empty, source/harness drift empty; actual engine/controller60Hz and physics context checked. Fixture has no actor position writes after initial setup.
- `baseline01` is retained as preliminary evidence: its600-frame ceiling ended before the real route-work limit, so it is superseded by baseline02 for the failure/release branch.

## Integration

1. Under a write lease for the shared candidate, assert current `scripts/hospital/npc_restaurant_visit28.gd` SHA256 equals `63a7e4c03a11b0774f806c5f3565ca4d3c2d1c611cd2b90c5f935cd2cd90fc4f`.
2. Copy only `patch/scripts/hospital/npc_restaurant_visit28.gd` to the same shared-game relative path.
3. Assert SHA256 equals `bc162fb155708a7172484b24f77ddc994a8d84bf30342182860f5ac1b1345498`; record the seventh-file integration delta.
4. Re-run the long merged behavior soak and services acceptance. This scoped native PASS does not replace the failed600s city gate. The separate resident1 10.3s SERVICE_APPROACH route-planning latency remains open.

`PATCH.json`, `EXIT_ENVELOPE31.patch`, `EXIT_ENVELOPE31_SOURCE.zip` and `ACCEPTANCE.json` pin the proposal and evidence. Existing release56, user window, F5 and Git are untouched.

The wrapper defaults to the current shared merged project and overlays only the proposed script in memory for `--candidate`. New runs after integration need a separately pinned baseline/adapted wrapper: the current runner intentionally rejects a changed baseline.
