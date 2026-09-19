# Specialist core actions — 19 September 2026

Scope: `mercenary_core.mjs`, `mercenary_targets.mjs`, `mercenary_safe_source.mjs` plus scoped tests. Shared workspace; no commit or broad cleanup.

## Implemented

- Demolitions: existing approach/work/attach phases remain. Live attached operator cannot detonate until physically outside the actual vehicle centre safety radius (minimum 8 m, or authored `blastRadius + 1`). Retreat endpoint adds 1 m so the movement stop radius cannot strand the operator just inside safety. Moving targets re-evaluate the centre. A blocked operator exposes `waitingForSafety` rather than exploding beside himself. Death/dismissal preserves the existing timed attached charge. Snapshot/restore preserve blocked safety and once-only receipts.
- Engineer: `disable_power`, five seconds, `power_panel` with `powered === true`, using cutting skill. Targets route only through `onDisablePower`, mutate power metadata only after explicit successful receipt, preserve pending dedup/conflict and rejected effects. Walk owner wires the authored `disablePower` callback.
- Targets accept authored `getApproachPosition()` and `getLootPosition()` callbacks. Approach avoids navigating into safe/cage/panel bodies; loot uses actual bag position.
- Safe binding opts into root-owned `dropLoot` source behavior. Unlock completion requires source-opened, no longer collected. Collect requires local effects plus root `canCollectSafeLoot(safe)`. Successful ledger updates/hydration invoke root `syncSafeLootBalance(balance)`. Standard safe/server behavior remains source-owned.
- Medic already automatically scans current squad/player at bounded frequency. New tests verify downed squad recovery, one application, restored active state, and hospital/healthy rejection. HP remains source-owned.

## Validation

65 selected tests passed: actions19, actions19_targets, core, lifecycle_restore, safe_source, targets, world. Eight new cases cover safety, moving blast radius, save/restore, engineer receipt handling, and medic rescue. Existing core/walk fixtures now physically move operator beyond safety before expecting explosion. Safe binding test verifies uncollected unlock, rejection out of pickup range, one 57-unit award and host synchronization.

Core-only five-member/5000-tick sample p50 0.0006 ms, p95 0.0020 ms; no claim of improvement or complete-game FPS. **Производительность общей сцены не проверена.** Browser acceptance is coordinator-owned.

Broad mercenary suite was also run while sibling files were changing: 120/125 passed at that snapshot; four failures were an extracted pick fixture missing `pickingProbe`, one was changed X control fixture. Controls owner notified and fixing; rerun complete suite after sibling changes stabilize.

## Limits

Retreat uses existing collision-aware physical movement, not a new global pathfinder. A trapped live operator waits; no teleport or unsafe forced explosion. Root roster must show the waiting-for-safe-retreat label, visual owner must keep charge visible during `waitingForSafety`. Root handles actual money-bag visuals, proximity and account delta. Full animated specialist scenarios and general scene performance still require live verification.
