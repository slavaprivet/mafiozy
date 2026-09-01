import math
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def _number(name: str) -> float:
    match = re.search(rf"{re.escape(name)}=([0-9.]+)", WORLD)
    assert match, name
    return float(match.group(1))


def _simulate_dash(initial_distance: float | None, collision_step: int | None = None):
    step_size = _number("dashStepDistance")
    target_gap = _number("dashTargetGap")
    dash_max = _number("dashMaxDistance")
    air_max = _number("dashAirDistance")
    has_target = initial_distance is not None
    distance = float(initial_distance) if has_target else math.inf
    budget = (min(dash_max, max(0.0, distance - target_gap))
              if has_target else air_max)
    steps = max(1, math.ceil(budget / step_size))
    moved_total = 0.0
    stop = "budget"
    for index in range(steps):
        step = min(step_size, max(0.0, budget - moved_total))
        if has_target:
            step = min(step, max(0.0, distance - target_gap))
        if step < 0.005:
            stop = "target-gap"
            break
        moved = 0.0 if collision_step == index + 1 else step
        moved_total += moved
        if has_target:
            distance -= moved
        if moved < 0.005:
            stop = "collision-stop"
            break
        if moved_total >= budget - 0.005:
            break
    return {
        "budget": budget,
        "steps": steps,
        "moved": moved_total,
        "distance": distance,
        "stop": stop,
    }


def _simulate_throttled_dash(initial_distance: float | None, callback_times):
    step_size = _number("dashStepDistance")
    target_gap = _number("dashTargetGap")
    dash_max = _number("dashMaxDistance")
    air_max = _number("dashAirDistance")
    has_target = initial_distance is not None
    distance = float(initial_distance) if has_target else math.inf
    budget = (min(dash_max, max(0.0, distance - target_gap))
              if has_target else air_max)
    planned_steps = max(1, math.ceil(budget / step_size))
    duration = max(96, planned_steps * 16)
    moved_total = 0.0
    samples = 0
    for elapsed in callback_times:
        desired = budget * min(1.0, max(0.0, elapsed) / duration)
        catch_up = 0
        while desired - moved_total >= 0.005 and catch_up < 12 and samples < 24:
            step = min(step_size, desired - moved_total, budget - moved_total)
            if has_target:
                step = min(step, max(0.0, distance - target_gap))
            if step < 0.005:
                break
            moved_total += step
            if has_target:
                distance -= step
            samples += 1
            catch_up += 1
    return {"budget": budget, "moved": moved_total,
            "distance": distance, "samples": samples}


class MeleeInputAndHeavyDashTests(unittest.TestCase):
    def test_three_canvas_receives_physical_lmb_input(self):
        self.assertIn(
            "#threePreview { position:absolute; inset:0; width:100%; height:100%; "
            "pointer-events:auto; z-index:1; }",
            WORLD,
        )

    def test_pve_rejection_is_visible_but_policy_stays_non_combatant(self):
        punch = WORLD.split(
            "function punch(force, aimAngle = null, heavy = false) {", 1)[1]
        punch = punch.split("function _spawnPunchBlood", 1)[0]
        bridge = WORLD.split("  melee(angle,heavy=false) {", 1)[1]
        bridge = bridge.split("  selectBuilding(", 1)[0]

        self.assertIn("meleeInputDecision='rejected:pve-observer'", punch)
        self.assertIn("Нажми «PvE сменить» и выбери PvP", punch)
        self.assertLess(
            punch.index("if (myMode === 'pve')"),
            punch.index("lastPunchClientT = now"),
        )
        self.assertIn("if(myMode==='pve')return punch(true", bridge)
        self.assertLess(
            bridge.index("if(myMode==='pve')return punch(true"),
            bridge.index("if(_meleeBlockHeld)return false"),
        )

    def test_outer_acquire_band_reaches_contact_before_impact(self):
        acquire = float(re.search(
            r"acquireRange=heavy\?([0-9.]+)", WORLD).group(1))
        contact = float(re.search(
            r"contactRange=heavy\?([0-9.]+)", WORLD).group(1))
        trace = _simulate_dash(acquire)

        self.assertLessEqual(trace["distance"], contact)
        self.assertLessEqual(trace["moved"], _number("dashMaxDistance"))
        self.assertGreaterEqual(trace["distance"], _number("dashTargetGap"))
        self.assertLess(trace["steps"] * 16, 330)
        self.assertIn(
            "previewHeavyDistance=_UP.get('previewmeleeheavy')==='far'?2.35:1.15",
            WORLD,
        )
        self.assertIn(
            "const pinR=civilian.r,pinC=civilian.c,heavyTargetPin=setInterval",
            WORLD,
        )
        self.assertIn("document.documentElement.dataset.meleeImpact", WORLD)
        self.assertIn(
            "_UP.get('previewmeleeheavy')==='far'?5000:420",
            WORLD,
        )
        self.assertLess(math.hypot(2.35, 0.25), acquire)
        self.assertGreater(math.hypot(2.35, 0.25), contact)

    def test_near_target_stops_at_gap_and_never_overshoots(self):
        target_gap = _number("dashTargetGap")
        trace = _simulate_dash(target_gap + 0.22)

        self.assertAlmostEqual(trace["moved"], 0.22, places=6)
        self.assertAlmostEqual(trace["distance"], target_gap, places=6)
        self.assertLessEqual(trace["moved"], trace["budget"])

        already_close = _simulate_dash(target_gap - 0.01)
        self.assertEqual(already_close["moved"], 0)
        self.assertEqual(already_close["stop"], "target-gap")

    def test_air_dash_is_bounded_and_collision_stops_immediately(self):
        air = _simulate_dash(None)
        self.assertAlmostEqual(air["moved"], _number("dashAirDistance"), places=6)
        self.assertLessEqual(air["moved"], _number("dashMaxDistance"))

        blocked = _simulate_dash(2.42, collision_step=4)
        self.assertEqual(blocked["stop"], "collision-stop")
        self.assertAlmostEqual(blocked["moved"], 0.33, places=6)
        self.assertLess(blocked["moved"], blocked["budget"])

    def test_throttled_timer_catches_up_with_bounded_microsteps(self):
        target = _simulate_throttled_dash(2.42, [100, 200])
        air = _simulate_throttled_dash(None, [100, 200])
        self.assertAlmostEqual(target["moved"], target["budget"], places=6)
        self.assertLessEqual(target["distance"], 1.75)
        self.assertAlmostEqual(air["moved"], air["budget"], places=6)
        self.assertLessEqual(target["samples"], 24)
        self.assertLessEqual(air["samples"], 24)

    def test_production_loop_resamples_target_and_uses_try_move(self):
        self.assertIn("const liveTarget=tgt?.getPos?.()", WORLD)
        self.assertIn(
            "liveTargetValid=!!liveTarget&&Number.isFinite(+liveTarget.r)"
            "&&Number.isFinite(+liveTarget.c)", WORLD)
        self.assertIn("Math.max(0,liveDistance-dashTargetGap)", WORLD)
        self.assertIn("desiredMoved=dashBudget*dashProgress", WORLD)
        self.assertIn(
            "catchUpSteps<12&&step<dashSampleCap", WORLD)
        self.assertIn(
            "tryMove(player,Math.sin(ang)*stepDistance,"
            "Math.cos(ang)*stepDistance)", WORLD)
        self.assertIn("totalMoved>=dashBudget-.005", WORLD)
        self.assertIn("if(moved<.005){stopReason='collision-stop';break;}", WORLD)
        self.assertIn("stopReason||'target-aware-run'", WORLD)

    def test_non_finite_initial_target_fails_before_movement(self):
        punch = WORLD.split(
            "function punch(force, aimAngle = null, heavy = false) {", 1)[1]
        punch = punch.split("document.documentElement.dataset.meleeAttack", 1)[0]
        guard = "if(!pos||!Number.isFinite(+pos.r)||!Number.isFinite(+pos.c))return false;"
        self.assertIn(guard, punch)
        self.assertLess(punch.index(guard), punch.index("lastPunchClientT = now"))

    def test_firearm_and_server_authority_are_out_of_scope(self):
        firearm = WORLD.split("function fire(angle = null) {", 1)[1]
        firearm = firearm.split("function _meleeTargetIsProne", 1)[0]
        for token in ("dashTargetGap", "meleeInputDecision", "target-aware-run"):
            self.assertNotIn(token, firearm)
        self.assertEqual(
            WORLD.count(
                '<meta name="mafiozy-melee-input-dash-contract" '
                'content="pve-reason-target-aware-v1">'),
            1,
        )


if __name__ == "__main__":
    unittest.main()
