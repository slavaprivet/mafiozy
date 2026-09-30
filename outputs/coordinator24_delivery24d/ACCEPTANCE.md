# 24d: bullet marks stay on the contacted surface

The renderer correctly found the incoming bullet's triangle, then discarded that anchor and projected again along its normal. A nearby folded limb could steal the mark. The fix retains the incoming-ray triangle and barycentric center; edge decoration chooses the closest surface to that impact plane. Weapon spread, native contact admission, HP and ragdoll physics are unchanged.

The actual old renderer reproduces a 120 mm displacement onto another bone in the bent/skinned fixture. The corrected renderer has zero center displacement there, including a rotated lying pose and subsequent bone movement. All 41 geometry checks pass; duplicate and mesh-grazing rejection remain intact.

The exact compiled 24d game passes 75 checks with real Uzi inventory/input/projectiles and reload: one natural lethal hit and three additional hits to the dead actor. All three postmortem marks render; their center is within 0.001 mm laterally of the actual incoming ray. Their forward offset follows the visible skin behind its physical proxy. Original three residents and eight buildings remain; no actor, HP, ammunition or ragdoll override is used. The test uses injected Godot input and an explicit one-time clear-floor player placement, not physical Windows input. Two rendered images were inspected. This is not whole-city FPS acceptance.

Exactly three source files were promoted, with 1739 unrelated files preserved. PCK SHA256: `21c0c2799589fe19b3c506fe8b3d0fc304f4a3f1701ec43013e8c9a3c506e63f`. The ordinary release was opened as PID16508 and verified responsive with all scene readiness markers and no errors.

Full building collapse and physical player/corpse blocking are separate unfinished work. This release does not claim either.
