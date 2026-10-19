# Sword and shield G ownership fix

Component source is exact published `60001a6dedf1880eb0bbd2e2237d24362dd4ac8e`; frozen baseline `D:/MafioziCastle31/main60001_candidate31`. All native tests used `tools/godot/test_scheduler.py`; no shared or frozen source was edited. Current shared sword blob still equals base `d5ccb932652822074e0f9d5525634e9a5f56abf5` and `git apply --check` passes for `SWORD_STORAGE_G31.patch`. Candidate blob is `0ae09a4a966ce088e4918ab673d950ad639510bb`.

Baseline ordinary graphical Q card and key probe, external fixture `sword_storage_g_probe31.gd`:

- Sword G: `D:/MafioziCastle31/sword_storage_g_baseline31/SWORD_STORAGE_G31.json`, scheduler exit 1 as expected. Prototype sword grounded, but storage revision remains 1, `carried={sword}`, `fallen={}`, no physical storage item.
- Sword + shield, hold RMB then G: `D:/MafioziCastle31/shield_storage_g_baseline31/SWORD_STORAGE_G31.json`, scheduler exit 1 as expected. Right hand input was held, prototype shield dropped, but storage revision remains 2, `carried={sword,shield}`, `fallen={}`.

The scoped patch changes only `sword_prototype.gd::_input` KEY_G. For an item recorded as carried by castle storage, it calls the existing `drop_held()` transaction and consumes the event. Shield intent is `_shield_worn and _hold_right`; all other held weapons use the stored hand weapon ID. Legacy prototype G remains for an item outside castle storage. No damage/animation/physics method was changed.

Isolated stage `D:/MafioziCastle31/sword_storage_routing31` import PASS (`..._import/SCHEDULER_RUN.json`). Same ordinary graphical fixture passed on:

- `D:/MafioziCastle31/sword_storage_g_candidate31b/SWORD_STORAGE_G31.json`: sword removed from carried, physical `RigidBody3D` with collision, fallen sword listed.
- `D:/MafioziCastle31/shield_storage_g_candidate31/SWORD_STORAGE_G31.json`: shield removed, sword remains carried, physical shield listed with collision.
- `D:/MafioziCastle31/spear_storage_g_candidate31/SWORD_STORAGE_G31.json`: two handed spear removed, physical spear listed with collision.

Sword and spear storage revisions advance by two because `selected_none()` advances one revision when unequipping and `drop_held()` advances another after creating the floor item. The first sword candidate receipt asserted exactly one revision and therefore exited 1 despite the correct physical result; the assertion was corrected to require an increase, then rerun passed as candidate31b. Shield revision advances by one. These are component input proofs, not a long combat/performance acceptance.