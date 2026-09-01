"""Focused terminal replacement cooldown contract for ordinary city gangs."""

import os
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("BOT_TOKEN", "123456:city-gang-cooldown-regression")

import mafiozi_bot as game


ROOT = Path(__file__).resolve().parent
T0 = 1_900_000_000.0
REAL_SPAWN_CITY_GANG = game.WorldSim._spawn_city_gang


def terminal_gang(gid: str, *, district: str = "", business_mode: str = "") -> dict:
    gang = {
        "id": gid,
        "bots": [{
            "id": f"{gid}-dead", "alive": False, "hp": 0,
            "x": 10.0, "y": 12.0, "weapon": "pistol",
        }],
        "faction": "purple",
    }
    if district:
        gang["district_did"] = district
    if business_mode:
        gang["_business_mode"] = business_mode
    return gang


def fresh_world() -> game.WorldSim:
    world = game.WorldSim()
    world.city_gangs.clear()
    world.cops.clear()
    world.players = {"observer": {
        "dead": False, "x": 0.0, "y": 0.0,
        "_mode": "pve", "_jail_until": 0.0,
    }}
    return world


def tick_at(world: game.WorldSim, now: float, spawn):
    with patch.object(game.time, "time", return_value=now), \
            patch.object(game, "_world_bot_passable", return_value=True), \
            patch.object(game.WorldSim, "_spawn_city_gang", side_effect=spawn):
        return world.tick_city_gangs(0.0)


def test_exact_terminal_boundary() -> None:
    world = fresh_world()
    dead = terminal_gang("cg-old")
    world.city_gangs = [dead]
    world._city_gang_next_spawn_at = T0 - 1.0
    next_gang_id = world._city_gang_next_id
    next_bot_id = world._next_bot_id
    loot = dict(world.district_loot)
    calls = []

    def spawn(_faction=None):
        calls.append(_faction)
        return REAL_SPAWN_CITY_GANG(world, _faction)

    packets = tick_at(world, T0, spawn)
    assert not calls and not any(p.get("kind") == "city_gang_spawned"
                                 for p in packets)
    assert world._city_gang_next_spawn_at == T0 + 120.0
    assert dead not in world.city_gangs
    assert world._city_gang_next_id == next_gang_id
    assert world._next_bot_id == next_bot_id
    assert world.district_loot == loot
    assert dead["bots"][0]["alive"] is False

    tick_at(world, T0 + 119.999, spawn)
    assert not calls
    packets = tick_at(world, T0 + 120.0, spawn)
    assert len(calls) == 1
    assert any(p.get("kind") == "city_gang_spawned" for p in packets)
    assert world._city_gang_next_spawn_at == T0 + 128.0


def test_future_deadline_and_simultaneous_losses() -> None:
    future = fresh_world()
    future.city_gangs = [terminal_gang("cg-future")]
    future._city_gang_next_spawn_at = T0 + 300.0
    tick_at(future, T0,
            lambda faction=None: REAL_SPAWN_CITY_GANG(future, faction))
    assert future._city_gang_next_spawn_at == T0 + 300.0

    simultaneous = fresh_world()
    simultaneous.city_gangs = [terminal_gang("cg-a"), terminal_gang("cg-b")]
    simultaneous._city_gang_next_spawn_at = T0 - 1.0
    calls = []

    def spawn(_faction=None):
        calls.append(_faction)
        return REAL_SPAWN_CITY_GANG(simultaneous, _faction)

    tick_at(simultaneous, T0, spawn)
    assert not calls
    assert simultaneous._city_gang_next_spawn_at == T0 + 120.0
    tick_at(simultaneous, T0 + 120.0, spawn)
    assert len(calls) == 1
    assert simultaneous._city_gang_next_spawn_at == T0 + 128.0


def test_exclusions_and_unchanged_spawn_cadence() -> None:
    district = fresh_world()
    district.city_gangs = [terminal_gang("district-old", district="old_town")]
    district._city_gang_next_spawn_at = T0 + 10.0
    tick_at(district, T0,
            lambda faction=None: REAL_SPAWN_CITY_GANG(district, faction))
    assert district._city_gang_next_spawn_at == T0 + 10.0

    guard = fresh_world()
    guard.city_gangs = [terminal_gang("guard-old", business_mode="guard")]
    guard._city_gang_next_spawn_at = T0 + 11.0
    tick_at(guard, T0,
            lambda faction=None: REAL_SPAWN_CITY_GANG(guard, faction))
    assert guard._city_gang_next_spawn_at == T0 + 11.0

    failed = fresh_world()
    failed._city_gang_next_spawn_at = T0
    attempts = []

    def reject(_faction=None):
        attempts.append(_faction)
        return None

    tick_at(failed, T0, reject)
    assert len(attempts) == 1
    assert failed._city_gang_next_spawn_at == T0 + 15.0
    tick_at(failed, T0 + 14.999, reject)
    assert len(attempts) == 1
    tick_at(failed, T0 + 15.0, reject)
    assert len(attempts) == 2

    initial = fresh_world()
    initial._city_gang_next_spawn_at = T0
    tick_at(initial, T0,
            lambda faction=None: REAL_SPAWN_CITY_GANG(initial, faction))
    assert initial._city_gang_next_spawn_at == T0 + 8.0


def test_world_marker_is_inert_and_exact() -> None:
    world_source = (ROOT / "world.html").read_text(encoding="utf-8")
    marker = (
        '<meta name="mafiozy-city-gang-replacement-cooldown-contract" '
        'content="terminal-ordinary-120s-v1">'
    )
    assert world_source.count(marker) == 1


def run() -> None:
    test_exact_terminal_boundary()
    test_future_deadline_and_simultaneous_losses()
    test_exclusions_and_unchanged_spawn_cadence()
    test_world_marker_is_inert_and_exact()
    print("city gang terminal replacement cooldown: 4/4 OK")


if __name__ == "__main__":
    run()
