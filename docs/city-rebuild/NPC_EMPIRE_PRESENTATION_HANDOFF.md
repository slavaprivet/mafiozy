# Empire dashboard and dossier presentation — Artist14, 2026-09-09

Presentation changes live in `assets/maps/city_rebuild_v1/npc_empire_ui.css`, loaded once by `npcEmpireArtist14Theme` after the existing readable theme installer in `world.html`. Existing modal IDs, event handlers, ownership, server state, war admission and disabled controls are untouched. The repeated root selector deliberately takes priority over the accumulated older theme selectors, without global CSS leakage or deleting legacy code shared elsewhere.

Dashboard: charcoal cards, brass dividers, restrained burgundy header, two/three desktop columns, complete wrapping names and gang names, relationship badge beneath the name, separate activity and metrics, dossier action in normal flow. Portrait containers remain `.ns-rank-portrait canvas`: 112 × 190 desktop, 90 × 190 narrow. Existing hospital styling remains grayscale.

Dossier: existing source sections kept in order. A large `.ne-dossier-photo canvas` is 260 × 340 desktop, 150 × 230 below 740 px, and 190 × 260 centered below 440 px. Statistics, diplomacy controls, war explanation, plans and properties have readable text and spacing. Narrow layouts keep every command statistic visible; biography remains visible. Existing real-pose portrait painter is owned by weapon_art_upgrade and keeps the same canvas selectors.

No backdrop blur, decorative gradient stack, animations, extra WebGL scene or new assets are required by this stylesheet. Modal scrolling is bounded by dynamic viewport height, focus-visible borders are retained, and disabled controls stay visibly disabled.

Validation so far: `python -B test_npc_empire_ui_layout.py` passes. The older broad `test_npc_empire_ui.py` fails its unrelated exact-string assertion `walking:!death.dead&&declaredMoving` at line 71 because the existing actor snapshot now also guards stun. This presentation patch does not modify that snapshot or test. Live screenshots are pending parent permission to use the active tab; no browser was operated for this patch yet.
