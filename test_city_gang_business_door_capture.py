"""Focused contract for physical exterior city-gang business captures."""

import os
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("BOT_TOKEN", "123456:city-gang-door-contract")

import mafiozi_bot as game


ROOT = Path(__file__).resolve().parent


def _gang(world, faction="purple"):
    gang = world._spawn_city_gang(faction)
    assert gang and not gang.get("district_did")
    gang["_business_replan_at"] = 10_000.0
    return gang


def _place_at(gang, r, c):
    for index, bot in enumerate(gang["bots"]):
        bot.update(x=c + index * .03, y=r + index * .03, alive=True)


def _tick_strategy(world, gang, now):
    alive = [bot for bot in gang["bots"] if bot.get("alive")]
    cx = sum(float(bot["x"]) for bot in alive) / len(alive)
    cy = sum(float(bot["y"]) for bot in alive) / len(alive)
    return world._tick_city_gang_business_strategy(gang, alive, cx, cy, now)


def run():
    expected = {
        "coffee": (34.9073, 13.5), "carwash": (24.5293, 26.0),
        "barbershop": (54.9073, 23.5), "pizza": (55.0293, 53.5),
        "garage": (15.1512, 63.5), "bar": (45.0293, 33.5),
        "club": (65.1512, 53.5), "warehouse": (75.3951, 23.5),
        "casino": (14.5232, 46.25), "port": (183.3951, 31.5),
    }
    assert game.BUSINESS_ENTRANCES_RC == expected
    assert all(game._world_bot_passable(c, r) for r, c in expected.values())

    world = game.WorldSim()
    world.city_gangs.clear()
    gang = _gang(world)
    route_args = []

    def route_probe(sx, sy, tx, ty):
        route_args.append((sx, sy, tx, ty))
        return [(tx, ty)]

    with patch.object(game, "_world_bot_path", side_effect=route_probe):
        assert world._city_gang_set_business_target(gang, "coffee", 1000.0)
    entry_r, entry_c = expected["coffee"]
    assert route_args[-1][2:] == (entry_c, entry_r)
    assert gang["_patrol_route"][-1] == (entry_c, entry_r)
    assert world._city_gang_business_operation(gang, 1000.0)["phase"] == "APPROACH"

    _place_at(gang, entry_r, entry_c)
    first = _tick_strategy(world, gang, 1000.0)
    assert [p["kind"] for p in first] == ["npc_business_breach_started"]
    assert first[0]["phase"] == "BREACH" and first[0]["required_s"] == 1.5
    assert first[0]["entrance_r"] == entry_r and first[0]["entrance_c"] == entry_c
    assert not _tick_strategy(world, gang, 1001.499)
    breach = world._city_gang_business_operation(gang, 1001.499)
    assert breach["phase"] == "BREACH" and breach["progress"] > .99

    capture_start = _tick_strategy(world, gang, 1001.5)
    assert [p["kind"] for p in capture_start] == ["npc_business_capture_started"]
    assert capture_start[0]["phase"] == "CAPTURE"
    assert capture_start[0]["required_s"] == world.CITY_GANG_BUSINESS_CAPTURE_S
    assert not _tick_strategy(world, gang, 1001.501)
    mid = world._city_gang_business_operation(gang, 1005.0)
    replay = world._city_gang_business_operation(gang, 1005.0)
    assert mid == replay and mid["phase"] == "CAPTURE"
    assert 0 < mid["progress"] < 1 and mid["remaining_s"] > 0
    assert not _tick_strategy(world, gang, 1008.499)

    with patch.object(game.WorldSim, "_faction_war_add", return_value=None):
        captured = _tick_strategy(world, gang, 1008.5)
    assert [p["kind"] for p in captured] == ["npc_business_captured"]
    assert captured[0]["phase"] == "GUARD" and captured[0]["progress"] == 1.0
    assert world._npc_business_controls["coffee"]["guard_gid"] == gang["id"]
    assert world._city_gang_business_operation(gang, 1009.0)["phase"] == "GUARD"
    assert not _tick_strategy(world, gang, 1009.0)

    # A reconnect only reads the same operation; it cannot advance or repeat it.
    before = dict(world._npc_business_controls["coffee"])
    reconnect_a = world._city_gang_business_operation(gang, 1010.0)
    reconnect_b = world._city_gang_business_operation(gang, 1010.0)
    assert reconnect_a == reconnect_b and world._npc_business_controls["coffee"] == before
    assert reconnect_a["started_at"] == 1008.5
    assert reconnect_a["operation_id"] and reconnect_a["phase_seq"] == 3

    # Leaving the tight entrance corridor resets the physical hold. Wall time
    # spent elsewhere can never turn into an instant capture on return.
    continuity = game.WorldSim()
    continuity.city_gangs.clear()
    walkers = _gang(continuity)
    assert continuity._city_gang_set_business_target(walkers, "coffee", 3000.0)
    _place_at(walkers, entry_r, entry_c)
    assert _tick_strategy(continuity, walkers, 3000.0)[0]["phase"] == "BREACH"
    _place_at(walkers, entry_r, entry_c + continuity.CITY_GANG_BUSINESS_ENTRY_RADIUS + .1)
    lost = _tick_strategy(continuity, walkers, 3001.0)
    assert len(lost) == 1 and lost[0]["kind"] == "npc_business_march"
    assert lost[0]["phase"] == "APPROACH" and lost[0]["reason"] == "left_entrance"
    assert walkers["_business_breach_started"] == 0
    _place_at(walkers, entry_r, entry_c)
    assert _tick_strategy(continuity, walkers, 3010.0)[0]["phase"] == "BREACH"
    assert not _tick_strategy(continuity, walkers, 3011.499)
    assert _tick_strategy(continuity, walkers, 3011.5)[0]["phase"] == "CAPTURE"

    # Hostility also invalidates the uninterrupted door hold.
    walkers["state"] = "hostile"
    assert not _tick_strategy(continuity, walkers, 3012.0)
    assert walkers["_business_capture_started"] == 0
    assert walkers["_business_mode"] == "travel"
    walkers["state"] = "patrol"
    assert _tick_strategy(continuity, walkers, 3100.0)[0]["phase"] == "BREACH"

    # The generic patrol planner must not replace a door hold with a random
    # city route after the authored entrance route has been exhausted.
    hold_world = game.WorldSim()
    hold_world.city_gangs.clear()
    hold_world.cops.clear()
    hold_world._city_gang_next_spawn_at = 99_999_999_999.0
    holders = _gang(hold_world)
    assert hold_world._city_gang_set_business_target(holders, "coffee", 5000.0)
    _place_at(holders, entry_r, entry_c)
    holders["_business_mode"] = "breach"
    holders["_business_breach_started"] = 5000.0
    holders["_patrol_route"] = []
    holders["_patrol_route_i"] = 0
    holders["_patrol_wp"] = (entry_c, entry_r)
    with patch.object(game, "_world_bot_path", side_effect=AssertionError("random route during door hold")):
        hold_world.tick_city_gangs(.05)
    assert holders["_patrol_wp"] == (entry_c, entry_r)

    # A live rival guard cannot suppress the first authoritative breach cue.
    contested = game.WorldSim()
    contested.city_gangs.clear()
    defenders = _gang(contested, "purple")
    defenders.update(_business_mode="guard", _business_guard_id="coffee",
                     _business_target_id="")
    _place_at(defenders, entry_r, entry_c)
    contested._npc_business_controls["coffee"] = {
        "biz_id": "coffee", "faction": "purple",
        "guard_gid": defenders["id"], "defense_level": 1,
    }
    raiders = _gang(contested, "yellow")
    assert contested._city_gang_set_business_target(raiders, "coffee", 6000.0)
    _place_at(raiders, entry_r, entry_c)
    fight = _tick_strategy(contested, raiders, 6000.0)
    assert [p["kind"] for p in fight] == ["npc_business_breach_started"]
    assert not _tick_strategy(contested, raiders, 6000.1)

    # Blocking ownership work cancels a pending operation exactly once.
    cancel = _gang(world, "yellow")
    assert world._city_gang_set_business_target(cancel, "bar", 2000.0)
    world._business_closed_until["bar"] = 3000.0
    cancelled = _tick_strategy(world, cancel, 2001.0)
    assert len(cancelled) == 1
    assert cancelled[0]["kind"] == "npc_business_operation_cancelled"
    assert cancelled[0]["phase"] == "CANCELLED"
    assert cancelled[0]["operation_id"] and cancelled[0]["phase_seq"] == 1
    assert not _tick_strategy(world, cancel, 2001.1)

    district = _gang(world)
    district["district_did"] = "0:0"
    district["_business_target_id"] = "coffee"
    assert not _tick_strategy(world, district, 4000.0)
    world.add_or_update("door-observer", "Observer", {})
    assert all(op["gid"] != district["id"] for op in
               world.snapshot_for("door-observer")["d"]["npc_business_operations"])

    client = (ROOT / "world.html").read_text(encoding="utf-8")
    assert "function _normalizeNpcBusinessOperation(raw)" in client
    assert "if(_consumeNpcBusinessOperationEvent(d))return;" in client
    assert "function _drawNpcBusinessOperation(b,r,c,t)" in client
    assert "_drawNpcBusinessOperation(b,r,c,t);" in client
    assert "_openResidentDoorVisual(door" in client
    assert "dataset.npcBusinessOperations=" in client
    assert "APPROACH','BREACH','CAPTURE','GUARD" in client
    assert "operation_id:String(raw.operation_id||'')" in client
    assert "op.phase_seq<prior.phase_seq" in client
    assert "npcBusinessOperationHud" in client

    print("city gang business door capture: 10 entrances + 4 phases + reconnect OK")


if __name__ == "__main__":
    run()
