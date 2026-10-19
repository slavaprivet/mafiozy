# Staff30 integration and native cycle acceptance

This adapter takes the frozen `venues29_staff` package onto
`outputs/coordinator29_release53a/game`. It preserves the release53a attention,
UI, ambient and medical/economic authority code. It never writes release53a,
coordinator29 production, F5, Git or the accepted48 pointer.

`apply_staff30.py` validates every file pinned by `MANIFEST_STAFF29.json`, computes
all five exact-context patches before writing, then adds the three staff scripts
and staff asset descriptor. Unrelated changes in those five files survive.
The destination must be under `outputs/coordinator30_npc54`. Reapplying the same
hunks is safe. Do not copy a full old restaurant/economy/main file over navigation
or attention work.

Standalone application obtains a scheduler write lease:

```powershell
python -B outputs/coordinator30_npc54/proposals/staff30/apply_staff30.py outputs/coordinator30_npc54/game --report outputs/coordinator30_npc54/STAFF_INTEGRATION30.json
```

Root can import and call `apply(game, report)` while already holding the target's
write lease. Enable `--city-venue-sites29=1 --city-venue-staff29=1` for the twelve
physical service venues. The prepared resident manifest and ordinary population
selection are unchanged. Staff are stationary, have no roaming planner, and do
not share a resident skeleton writer.

The standalone runner stages a private source snapshot under read/write leases,
pins the scheduler and engine, imports with a write lease, then runs a bounded
headless fixture with a read lease. It preserves failed runs. Source differences
other than generated import metadata fail acceptance. A source override permits
root to validate the final merged game54 using the same observer:

```powershell
python -B outputs/coordinator30_npc54/proposals/staff30/run_staff30.py merged_cycle --source outputs/coordinator30_npc54/game --duration 240
python -B outputs/coordinator30_npc54/proposals/staff30/run_staff30.py merged_fixture --source outputs/coordinator30_npc54/game --case fixture
```

`qa/staff_cycle30.gd` observes the ordinary one-resident simulation at every
physics step. Initial flags request HP49, energy19, wallet0 and the existing seed53.
It does not set transforms, manufacture route arrival, heal, pay or force tasks.
It saves the actual service point, full route gate, staff identity/gesture and
customer identity for hospital, bank and food. It checks that increases in HP or
receipt count occur only at a verified service position. Completion requires
the hospital's successful physical exit, a real bank grant, a real food purchase,
subsequent physical exit, released capacity/service claims and resumed roaming.

`--case fixture` reuses the pinned native637 invariant suite against the new
release53a + staff snapshot. It checks FIFO, physical service approach, exit
ownership, waiting exclusion, stale-body cleanup, reset generation and native
counter destruction. It does not certify a real resident's wallet or HP.

Native results live in `runs/<name>/RESULT.json` and `NATIVE.json`, with full
scheduler receipts and source pins. Whole-game performance and rendered visual
acceptance remain root responsibilities; native headless functional success is
not an FPS or animation appearance acceptance. Staff death/respawn is not part
of the package: only the existing resident lifecycle is implemented.
