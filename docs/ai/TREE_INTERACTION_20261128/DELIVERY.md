# Tree interaction delivery — 28 November 2026

Base: `0fa35b23` (`origin/main`).

Implemented:

- no stump/pile remains after a felled tree;
- exact hit-position chop marks use one 48-slot MultiMesh bank, at most four per tree;
- shared tree label shows current/max HP, last damage, estimated hits remaining and `СРУБЛЕНО`;
- pickup toast reports gained wood;
- logs use a damped BoxShape physics body and do not collide with the player capsule;
- a bounded horizontal foot nudge moves nearby logs in the walking direction without changing Y;
- logs below the world are cleaned and the physical-body cap remains 32;
- dragging the resource card outside the inventory drops one log for one unit or one visual stack for N units;
- inventory count changes only after an exact successful world-spawn acknowledgement.

Verification:

- `test_tree_resource_system57.gd`: 50/50 checks passed;
- `test_resource_inventory_modal58.gd`: 14/14 checks passed;
- graphical capture: intact tree, hit/HP, falling tree, logs and B inventory all saved successfully;
- Godot editor scan: exit 0, no script/parse errors;
- DeepSeek final review saved in `DEEPSEEK_RESPONSE_FINAL.md`; its airborne-sleep and below-world cleanup findings were applied.

Limits: this iteration does not claim full 50v50 performance acceptance. Existing unrelated worktree changes were not staged.
