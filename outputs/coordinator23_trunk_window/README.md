# Large trunk contents window — narrow candidate09 overlay

**Native143 PASS,3.59s; outputs-only.** Exact seven-file guard map in RECEIPT.json; merge.patch is reviewable. No shared/candidate/Git/GPU mutation. Rendered UI and loaded-scene performance remain pending.

User behavior:
- First E at a closed rear hatch retains normal transport opening. Once physically open, E opens contents even with camera facing away from miniature models.
- Large existing Walk thumbnails, weapon names, exact magazine/reserve, «Взять»40px buttons, used/free100 capacity. Responsive four/three/two-column scrollable window; empty state; held-weapon details and «G Положить оружие» button.
- «Взять» takes the exact selected UID with its finite ammo and equips it. Window stays open for additional items. G/button stores held item. «Закрыть крышку» closes the physical hatch.
- E/Q close contents only; Q does not simultaneously open the arsenal. Esc closes and frees cursor. Arsenal launcher closes trunk before opening arsenal. Blur/lid/access invalidation closes contents. Window suppresses movement, mouse-look, firearm/posture input and jump.

Ownership remains the existing concrete Inventory + Cargo store/prepare/validate/paired commit + prepared model placement. No inventory/transport store implementation or miniature geometry is changed. Bridge gets explicit selection_mode=trunk_window plus modal epoch and selected UID; it does not forge tiny-model hover. Near-open store uses its own explicit selection mode. Original lid geometry, physical amount>=.85, rear proximity, upright/speed, current lifetime, world obstruction and before/after evidence equality still apply. A stale missing UID cannot duplicate an item. Selected state exists only during synchronous transfer and clears afterwards.

Performance structure: UI starts hidden; thumbnails reuse existing cached arsenal textures; fourteen cards rebuild on cargo revision, not every frame. Scalar capacity/access refresh is150ms. Full snapshots occur at revision/transfer boundaries. Native143 is behavior proof, not loaded FPS proof.

Files under files/:
- New scripts/weapons/walk_trunk_window.gd.
- preview_weapon_cargo controller/modal/access, weapon_cargo_bridge explicit evidence, preview_weapons input owner, walk_weapon_ui reticle and weapon_aim_camera blocking.
- scripts/preview_player.gd is exact09 plus ONE controls_blocked check on the physics jump shortcut; fixes Space bypass for both arsenal and cargo.

Root integration seams:
1. Verify every existing BEFORE SHA in RECEIPT; new window must be absent. Apply seven overlays only.
2. Explicitly add res://scripts/weapons/walk_trunk_window.gd to export_files. Existing thumbnails and other dependencies already exported.
3. Update trunk note: «У открытого багажника E — содержимое. Кнопка „Взять“ — оружие в руки; G — положить. Патроны сохраняются.» Keep note/runtime revision paired.
4. Actual exported UI/input/render/performance acceptance before replacing user's game.

Test evidence: actual main/hatchback and concrete inventory/cargo owners; camera pointed away; actual Input.parse_input_event E confirms no seat/hatch fallthrough. Fourteen UID+magazine/reserve button-take/store roundtrips at full100; stale UID, closed lid, real blocker, speed, out-of-range, blur, Q/Esc, no fire/ammo spending and Space tested. test_native.gd, RUN01, RESULT01, native01.log and all stage inputs are hashed. NPCs disabled only in this isolated behavioral fixture. No new behavioral package was sent to owner threads.

Reproduce: create a fresh isolated copy of candidate09, apply the seven guarded files, then run locked Godot headless with --fixed-fps60 --path ABS/COPY --script ABS/test_native.gd. run_once.py is one-use and refuses an existing stage. Current stage is disposable and should not be committed; preserve files, patch, test and receipt/log.
