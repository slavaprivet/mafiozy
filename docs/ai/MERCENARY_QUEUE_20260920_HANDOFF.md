# Specialist command queue — 20 September 2026

Owner `/root/crew_follow_routes18`; source/core READY. Production edits: `mercenary_core.mjs`, `mercenary_world.js`. New tests: `test_mercenary_queue18.mjs`. UI owner `/root/safe_operator_clearance18` received the API contract; renderer/browser not touched here.

## Behavior

An eligible X action issued to a busy specialist is appended to that member's FIFO queue, capped at **8 waiting tasks plus 1 active task**. The current approach, progress and timer remain unchanged. Work starts sequentially after the current acknowledged completion, its ordinary cooldown and any physical post-safe exit. A free specialist is preferred when several members have the matching profession.

- Target/action duplicates and already reserved conflicting door operations are rejected. Queued reservations are included, so two specialists cannot simultaneously reserve the same destructive door work.
- Completed, removed or otherwise invalid queued targets are skipped. Failed effect receipts or timed-out targets release the member for the next valid task; no callback is repeated.
- V, an accepted X-ground rally, explicit cancel/dismiss and focused attack clear affected future work. HP loss/death removes queued work. An already attached bomb or committed pending receipt retains its prior independent semantics; clearing a queue does not defuse the bomb or replay a receipt.
- Explicit work takes priority over automatic medic scans. Auto-medic scans never create queues during cooldown.
- Queue snapshots are read-only projections. Save/restore keeps queued order. Unfinished current approach/work is saved as `resumeWork` and restarted ahead of the queue after reload, with zero partial timer credit. Armed charges and pending receipts remain in their existing snapshot contracts and are never resubmitted.
- While waiting for cooldown the operator holds position instead of pointlessly returning to the leader between consecutive jobs. The safe's short physical clearance still takes precedence over the next task.

## Public API

- `host.getQueue(memberId)` and `host.getMember(memberId).queued`, `host.getRoster().members[].queued`: `[{kind,targetId,queuedAt}]`. No extra queue ID: kind+targetId is unique among reserved work. Current stable action ID remains `host.getAction(id).id`.
- `getActions(target)` adds `willQueue:boolean`, `queuedCount:number`; matching busy professionals remain `enabled:true` if the target is valid, unreserved and the queue has space.
- `host.command(action,target)` preserves `{ok,message}` and additionally returns `queued:true`, `reason:'queued'`, `queuePosition` (1-based **among waiting tasks**) and `memberId` for accepted queued work. Message is “Задача добавлена в очередь”. Current job is normally numbered 1; UI waiting marker uses queuePosition+1 when a current job exists.
- Core exposes `clearQueue(id) -> removedCount`, `getQueue(id)`. `cancel(id)` also clears queued work even when the committed current action cannot be cancelled. `queuedCleared` is returned for that case.
- `canStartQueued(id)` adapter hook prevents the next action starting while the real safe-exit movement/door-opening hold is still active.

Also completed the requested micro-fix: `unlock_door` now respects explicit `lockpickable:false` for **door** as well as vehicle. QA breach-only doors cannot advertise an unimplemented lockpick operation; legacy doors without the flag retain their behavior.

## Verification / limits

New queue suite **14/14 PASS**: shield then gate FIFO and separate timers, same-action cooldown, cap8/dedupe/projection isolation, invalid target skipping, HP/death clearing, autonomous armed charge, committed async receipt, reload first-before-queue, safe clearance gating, lockpickable guard, source V/X-ground clearing, and actual source approach+two effects in order at **5/10/30 FPS**.

Queue/world/rally/lifecycle/elapsed/safe-exit/door regression run: **126/126 PASS**. Existing standalone core suite also PASS. Final small empty-queue short circuit was retested with queue+core suites. Core fixture 5 members/5000 updates p50/p95 about .0011/.0028 ms; source/GPU excluded, not a matched whole-scene benchmark. Empty queues do no target resolution/drain work; maximum queued validation is bounded by five members times eight waiting tasks. No additional scene geometry/draw calls from this scope.

**LIVE and performance of the shared game scene are not checked.** Root must load UI+source together, issue X on panel then X on fence while the first job is running, observe queued marker/current timer and FIFO completion, and verify V cancels future work while a planted bomb still has its fuse.
