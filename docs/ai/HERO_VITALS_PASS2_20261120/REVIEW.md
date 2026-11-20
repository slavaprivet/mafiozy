# Hero vitals pass 2 — 20 November 2026

All accepted skin wounds now contribute to blood loss; the visual BloodFlow32 limit of four particles is independent. A fixed 121-tick expiry ring covers 15 body segments and the longest 12-second stump wound. Per-tick work is constant, with a smooth rate bounded below 6 HP/s. The skin wound from a severing blow is replaced by one stump source. Existing mirrored bone-to-visible-side mapping is preserved.

The left HUD now shows the current held weapon, numeric health, and short active statuses. It omits zero bleeding, HP/s and the redundant "no wounds" line. Weapon changes through the arsenal update immediately; a cheap 0.2-second check covers physical drops outside the arsenal. Burning and bleeding each have their own status line, while exact lost parts remain visible in the body diagram and label.

A real sever regression exposed a null skeleton in debris skin transforms. The cut now resolves the skeleton from the source mesh before falling back to the NPC rig. On Godot 4.7.2, `test_hero_vitals_integration.gd` passed with no script errors, including 5th and 41st wounds, staggered expiry, actual hand/head sever through `_apply_player_damage`, true non-split chest death, fire occlusion, reset and weapon label. `dsh_sever_hands.gd` passed. DeepSeek was consulted through the protected client; its review is saved alongside this note. No credentials are stored here.

The hero still has no physical torso bisection. The HUD intentionally does not claim it after a chest kill.
