# Local hit preflight — final frozen handoff

READY for Root21 player_impact_host integration. Current local_hit_reaction.gd SHA c5cb4afd51127a26b3a60d37b7e13ed8572c267bd207b8f9a20d307ee8ba9b36 supersedes b8b9 at the runtime file path; exact old code/test/results are archived and their receipts remain unchanged.

can_add_hit(event,actual_world_frames) returns the exact same public dictionary/error precedence as add_hit without any state/input mutation. Both call one full _prepare_hit: identity/typed epoch/replay, contact/impulse, all28 frames/lengths/scales, selected segment, current-local angular projection/inertia/ancestor tuning, angular_overflow and current velocity caps. Public preflight contains no velocity staging token, cache or reservation. add_hit alone commits staged velocities and the bounded FIFO after complete success.

Integration: invoke only during an actual admitted hit's synchronous preflight, then handle the real add_hit result. Revalidate actor/life/source authority/global dedup/contact/world frames at commit. Preflight=true is not a future success guarantee: a changed epoch, intervening commit or changed contact can invalidate it. No HP rollback, force application, new source actors or alternate host was introduced. All inherited source/rig/force/single-pose-writer limitations remain in LOCAL_HIT_REACTION_CONTRACT.md and LOCAL_HIT_PREFLIGHT_CONTRACT.md.

Actual author Godot4.7.2:16413 PASS, exit0/clean, test SHA cc52d7b6ce7e7ef5cb3050dcbe4d49406b24a58c07d2c8f85fbf7847eebc4b61; three genuine cached male/female/male rigs resident72/169/252 and manifest3c07 remain source-pinned. All prior15249 coverage remains, plus repeated active-state pure canaries, exact error/return parity, byte-identical inputs/snapshots/FIFO, commit-after-probes vs direct equivalence, replay and typed-epoch transitions. Explicit finite extreme synthetic angular-overflow fixture is separate from genuine models.

Independent actual Godot:691 new checks PASS plus original241 regression PASS, both exit0/clean. Active saturated fixture300 repeated preflights retains all motion/FIFO/epoch state; later commit/control/sample exact; eighteen malformed cases and independently authored late angular_overflow fixture reject identically; stale later contact/epoch is rechecked. Full review outputs/astra21_local_hit_preflight_review/REVIEW.md. Old test/result bytes a96e9e7c/3bbfea5b unchanged.

Author same actual frames/50warmup/2000calls per row CPU microseconds (p50/p95/max):
72: oldadd71/96/276, newadd74/127/329, can72/110/317, can+add146/231/400.
169: oldadd72/97/295, newadd75/131/327, can72/114/260, can+add147/244/467.
252: oldadd74/119/309, newadd74/128/1049, can72/94/272, can+add144/229/400.

Current direct-add median is0..3us above the old implementation; tails are larger under concurrent host load and the1049us spike is retained. No speedup or zero regression claim. Preflight intentionally incurs the entire validation/projection/staging-copy cost again, so can+add is about twice the direct path; no stale projection cache or weaker validator was introduced. Restrict it to event admission, not frame polling. Inherited sample CPU p50 remains67/68/66us; full-scene FPS/GPU/real combat load are not measured here.

Files and all exact hashes/bytes are in outputs/astra21_local_hit_preflight_delivery/DELIVERY_RECEIPT.json. Reproduce author with Godot console --headless --path C:/Users/Слава/Desktop/Мафиози/godot/mafiozi_walk --script res://scripts/tests/test_local_hit_reaction.gd. Independent scripts live in the own review directory. No main/player/driver/body/project/Git/GPU changes. Root owns actual host and sole-game validation; no playable-combat acceptance is implied.
