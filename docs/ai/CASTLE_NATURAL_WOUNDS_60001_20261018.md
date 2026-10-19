# Natural sword wounds and actual helmet arrow flight — 2026-10-18

Exact source60001a6dedf1880eb0bbd2e2237d24362dd4ac8e, D:/MafioziCastle31/main60001_candidate31. Source manifest B821B1F3F48A9C6ACB3BDDF33C9CB829F2BB3716666100C061982B56D2DF5710 verifies778/778 scripts/scenes and project against Git; import PASS40.67s/exit0/stderr0.

## Natural melee wound now demonstrated

D:/MafioziCastle31/qa/natural_sword60001_rear/run01: graphical scheduler PASS/empty stderr. Ordinary Q1, LMB and mouse stroke; live NPC AI and sword enabled. Fixture only sets initial player placement1.05m behind the actual NPC model rear and aligns camera/player. No direct damage, sweep invocation or weapon transform.24 frames with11px horizontal/5px vertical per frame. Tagged ray peak speed21.19m/s; forearm health30 to3.5199, head50 to44.4744, blood true, NPC alive/no sever. A later steel clash produced16sparks but did not cancel earlier wounds. Root inspected strike_20.png. This closes the previous natural-unblocked-wound gap for this one rear attack, not all angles or animation quality.

D:/MafioziCastle31/qa/natural_sword60001_rear_light: fresh scene/target, same setup and total mouse displacement spread over72frames. Graphical scheduler PASS/empty stderr. Tagged peak speed5.21m/s; forearm30 to17.5916, upperarm34 to30.0907; blood true/no sever/death, no steel clash. This is a slower cut, NOT a gentle brush. Dynamic target contacts differ, so the outcomes demonstrate natural wounds at different speeds, not an isolated one-variable damage calibration. Snapshot last_hit_kind is assigned slice unconditionally in the NPC path and is not independent proof of edge classification. No production tuning was done for these results.

## Actual flight into moving helmet

D:/MafioziCastle31/qa/armor23_arrow_flight60001_02: scheduler headless PASS10.89s/exit0/stderr0. External fixture SHA5186B940FFF6CE5E27694571CAF5A3C87603C376448736CC161489C3C550E23A. Two fresh real NPC scenes wearing heavy_head, actual eye aperture from visual mesh versus visible nose metal. Actual PrototypeArrow model/flight entry launched at prescribed36m/s; production physics advances three ticks, moving head travels about0.040m. Natural collision/stick/damage path, no direct hit handler or NPC damage helper.

Eye joint: initial90HP to69.202, blood true, stuck. Nose plate:90 to83.590, blood false, stuck. No sever. These are controlled launch positions/speeds, not player aiming acceptance. Earlier01 output used wrong initial100HP in reporting; final02 fixes reporting and asserts actual region. Source pins rechecked unchanged.

## Pending

True gentle-touch gate and long mixed armored combat are not accepted here.120-180s same-world harness is being prepared; must prove actual bow/spear/NPC activity and account for per-part wounds. Long clean combat FPS remains unmeasured. Functional screenshots and concurrent diagnostics are not FPS acceptance.
