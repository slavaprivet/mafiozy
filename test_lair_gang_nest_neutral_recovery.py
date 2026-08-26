"""Focused contract for collision-safe neutral Lair/Nest patrol recovery."""

import math
import os
import random
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("BOT_TOKEN", "123456:bandit-neutral-recovery")

import mafiozi_bot as game


def _case(name, fn, passed):
    fn()
    passed.append(name)


def run():
    passed = []

    def point_contract():
        assert game._world_bandit_point_ok(40.001, 40.001)
        assert not game._world_bandit_point_ok(float("nan"), 40)
        assert not game._world_bandit_point_ok(40, 40, lambda _x, _y: False)
        assert not game._world_bandit_point_ok(40, 40, reserved=((40.69, 40),))
        assert game._world_bandit_point_ok(40, 40, reserved=((40.70, 40),))

    _case("rounded full-body/reservation admission", point_contract, passed)

    def nearest_bound():
        point = game._world_bandit_nearest_point(
            40, 40, lambda x, y: math.hypot(x - 40, y - 40) <= 1.5,
            reserved=(), include_origin=False,
            corridor_from=(40, 40))
        assert point is not None
        assert 0 < math.hypot(point[0] - 40, point[1] - 40) <= 1.5
        assert game._world_bot_passable(*point)
        # A passable endpoint beyond a solid column must not permit a visible
        # recovery teleport through that wall.
        with patch.object(
                game, "_world_bot_passable",
                side_effect=lambda x, _y: not (11.0 <= x < 12.0)):
            corridor_point = game._world_bandit_nearest_point(
                10.99, 10.5, lambda x, y: 9 <= x <= 13 and 9 <= y <= 12,
                max_distance=1.5, include_origin=False,
                corridor_from=(10.99, 10.5))
        assert corridor_point is not None and corridor_point[0] < 11.0
        with patch.object(game, "_world_bandit_point_ok", return_value=True) as probe:
            assert game._world_bandit_corridor_ok(0, 0, 1.5, 0)
        assert probe.call_count == 8

    _case("same-zone <=1.5 nearest fallback", nearest_bound, passed)

    def authored_step():
        bot = {"x": 40.0, "y": 40.0, "ang": 0.0}
        assert game._world_bandit_safe_step(bot, 41, 40, .18)
        assert (bot["x"], bot["y"]) == (40.18, 40.0)

    _case("authored heading advances safely", authored_step, passed)

    def fan_is_o8():
        bot = {"x": 40.0, "y": 40.0, "ang": 0.0}
        calls = []

        def allow_last(x, y, *_args, **_kwargs):
            calls.append((x, y))
            return len(calls) == 8

        with patch.object(game, "_world_bandit_point_ok", side_effect=allow_last):
            assert game._world_bandit_safe_step(bot, 41, 40, .18)
        assert len(calls) == 8

    _case("collision fan is bounded O(8)", fan_is_o8, passed)

    def boxed_stays_put():
        bot = {"x": 40.0, "y": 40.0, "ang": 1.25}
        with patch.object(game, "_world_bandit_point_ok", return_value=False) as probe:
            assert not game._world_bandit_safe_step(bot, 41, 40, .18)
        assert probe.call_count == 8
        assert (bot["x"], bot["y"], bot["ang"]) == (40.0, 40.0, 1.25)

    _case("boxed actor never crosses wall", boxed_stays_put, passed)

    def exact_stall_boundary():
        bot = {"id": "gbot-boundary", "x": 10.0, "y": 10.0}
        assert not game._world_bandit_recovery_due(bot, 0.0, True)
        assert not game._world_bandit_recovery_due(bot, 3.999, True)
        assert game._world_bandit_recovery_due(bot, 4.0, True)

    _case("recovery begins at exact four seconds", exact_stall_boundary, passed)

    def progress_resets_timer():
        bot = {"id": "gbot-progress", "x": 10.0, "y": 10.0}
        assert not game._world_bandit_recovery_due(bot, 0.0, True)
        bot["x"] = 10.12
        assert not game._world_bandit_recovery_due(bot, 3.9, True)
        assert not game._world_bandit_recovery_due(bot, 7.89, True)
        assert game._world_bandit_recovery_due(bot, 7.9, True)

    _case("real progress resets watchdog", progress_resets_timer, passed)

    def idle_is_not_stall():
        bot = {"id": "gbot-idle", "x": 10.0, "y": 10.0}
        assert not game._world_bandit_recovery_due(bot, 0.0, True)
        assert not game._world_bandit_recovery_due(bot, 10.0, False)
        assert not game._world_bandit_recovery_due(bot, 13.999, True)
        assert game._world_bandit_recovery_due(bot, 14.0, True)

    _case("ordinary idle pause is excluded", idle_is_not_stall, passed)

    def reseed_window_cap():
        bot = {"id": "gbot-cap", "x": 10.0, "y": 10.0}
        assert not game._world_bandit_recovery_due(bot, 0.0, True)
        assert game._world_bandit_recovery_due(bot, 4.0, True)
        assert game._world_bandit_recovery_due(bot, 8.0, True)
        assert game._world_bandit_recovery_due(bot, 12.0, True)
        assert not game._world_bandit_recovery_due(bot, 16.0, True)
        assert game._world_bandit_recovery_due(bot, 19.0, True)

    _case("three reseeds per half-open 15s window", reseed_window_cap, passed)

    def deterministic_phase():
        one = game._world_bandit_recovery_phase({"id": "nest42"})
        two = game._world_bandit_recovery_phase({"id": "nest42"})
        other = game._world_bandit_recovery_phase({"id": "nest43"})
        assert one == two and one != other and 0 <= one < math.tau

    _case("stable per-actor recovery phase", deterministic_phase, passed)

    def lair_spawn_atomic_and_safe():
        world = game.WorldSim()
        random.seed(130013)
        before_id = world._next_bot_id
        assert world._aggro_spawn("lair", world.TERRITORIES_DEF["lair"])
        bots = world.aggro["lair"]["bots"]
        assert len(bots) == world.AGGRO_BOTS_COUNT + 1
        assert world._next_bot_id == before_id + len(bots)
        assert all(game._world_bot_passable(bot["x"], bot["y"]) for bot in bots)
        distances = [
            math.hypot(left["x"] - right["x"], left["y"] - right["y"])
            for index, left in enumerate(bots) for right in bots[index + 1:]
        ]
        assert min(distances) >= game._WORLD_BANDIT_SEPARATION
        failed = game.WorldSim()
        failed_id = failed._next_bot_id
        with patch.object(game, "_world_bandit_nearest_point", return_value=None):
            assert not failed._aggro_spawn("lair", failed.TERRITORIES_DEF["lair"])
        assert "lair" not in failed.aggro and failed._next_bot_id == failed_id

    _case("Lair spawn is complete, safe and atomic", lair_spawn_atomic_and_safe, passed)

    def nest_and_client_witness():
        world = game.WorldSim()
        random.seed(130014)
        world._spawn_gang_nest()
        assert len(world.gang_nests) == 1
        bots = world.gang_nests[0]["bots"]
        assert len(bots) == world.NEST_BOTS
        assert all(game._world_bot_passable(bot["x"], bot["y"]) for bot in bots)
        distances = [
            math.hypot(left["x"] - right["x"], left["y"] - right["y"])
            for index, left in enumerate(bots) for right in bots[index + 1:]
        ]
        assert min(distances) >= game._WORLD_BANDIT_SEPARATION
        failed = game.WorldSim()
        failed_nest_id = failed._gang_nest_next_id
        failed_bot_id = failed._next_bot_id
        with patch.object(game, "_world_bandit_nearest_point", return_value=None):
            random.seed(130014)
            failed._spawn_gang_nest()
        assert failed.gang_nests == []
        assert failed._gang_nest_next_id == failed_nest_id
        assert failed._next_bot_id == failed_bot_id
        assert failed._business_npc_occupations == {}
        world_source = Path(__file__).with_name("world.html").read_text(encoding="utf-8")
        assert "_observeGangMobilitySnapshot" in world_source
        assert "gangMobilityWitness" in world_source
        assert "bot.x=" not in world_source[world_source.index("function _observeGangMobilitySnapshot"):world_source.index("function applyAggroTargets")]

    _case("Nest spawn safe; client witness observational", nest_and_client_witness, passed)

    assert len(passed) == 12
    print(f"PASS: {len(passed)}/12 neutral patrol recovery cases")
    for name in passed:
        print(f"  OK {name}")


if __name__ == "__main__":
    run()
