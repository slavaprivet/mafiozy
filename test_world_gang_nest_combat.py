"""Production fire-flee and business nest combat/cleanup regression."""

import os
from unittest.mock import patch

os.environ.setdefault("BOT_TOKEN", "123456:world-gang-nest-combat")

import mafiozi_bot as game


def run() -> None:
    clock = [1000.0]
    world = game.WorldSim()
    world.players.clear()
    world.gang_nests.clear()
    world._gang_nest_next_spawn_at = float("inf")

    burning = {
        "id": "burn-test", "x": 10.0, "y": 10.0,
        "hp": 20, "alive": True, "threat": "",
    }
    with patch.object(game.time, "time", side_effect=lambda: clock[0]):
        world._ignite_bandit(burning, 9.0, 10.0)
        flee_target = (burning["_fire_flee_x"], burning["_fire_flee_y"])
        world._ignite_bandit(burning, 9.0, 10.0)
        assert (burning["_fire_flee_x"], burning["_fire_flee_y"]) == flee_target
        clock[0] = 1001.1
        assert world._tick_bandit_fire_flee(burning, .1, lambda _x, _y: True)
        assert burning["hp"] == 14 and burning["alive"]
        clock[0] = 1005.0
        assert not world._tick_bandit_fire_flee(burning, .1, lambda _x, _y: True)
        assert burning["threat"] == ""

    bot = {
        "id": "raider", "x": 30.0, "y": 30.0, "ang": 0.0,
        "hp": 100, "max_hp": 100, "alive": True,
        "weapon": "pistol_heavy", "_guard_shot_t": 0.0,
        "_moving": False, "look": {},
    }
    guard = {
        "id": "guard", "x": 34.0, "y": 30.0, "ang": 0.0,
        "hp": 100, "max_hp": 100, "alive": True,
        "weapon": "pistol", "_shot_t": 0.0, "_moving": False,
    }
    nest = {
        "id": "business-nest", "bots": [bot], "defenders": [guard],
        "state": "guard", "_spawned_at": 900.0, "_expires_at": 5000.0,
        "_hostile_until": 0.0, "_target_uid": None,
        "anchor_r": 30.0, "anchor_c": 32.0, "_threat_t": {},
        "_cops_dispatched": False, "_cleared": False,
        "faction": "yellow", "mafia_family": "moretti",
        "business_id": "coffee", "guard_owner_uid": "owner",
        "_guard_shot_t": 0.0, "_gang_shot_t": 0.0,
        "_combat_uids": set(),
    }
    world.gang_nests = [nest]
    world._business_npc_occupations["coffee"] = nest["id"]
    clock[0] = 1100.0
    with patch.object(game.time, "time", side_effect=lambda: clock[0]), \
            patch.object(game, "_world_is_wall", return_value=False), \
            patch.object(game.random, "uniform", side_effect=lambda a, b: a), \
            patch.object(game.random, "randint", side_effect=lambda a, b: a):
        packets = world.tick_gang_nests(.1)
    shots = [packet for packet in packets
             if packet.get("kind") == "business_defense_shot"]
    assert {packet["side"] for packet in shots} == {"guard", "raider"}
    assert bot["_moving"] or guard["_moving"]
    assert bot["hp"] < 100 and guard["hp"] < 100

    bot["hp"] = 0
    bot["alive"] = False
    clock[0] = 1101.0
    with patch.object(game.time, "time", side_effect=lambda: clock[0]):
        cleared = world.tick_gang_nests(.1)
    clear_packets = [packet for packet in cleared
                     if packet.get("kind") == "gang_nest_cleared"]
    assert len(clear_packets) == 1
    assert clear_packets[0]["business_id"] == "coffee"
    assert not world.gang_nests
    assert "coffee" not in world._business_npc_occupations
    assert world._business_npc_capture_cooldown["coffee"] > clock[0]
    print("world gang nest combat: fire flee, defense exchange and clear OK")


if __name__ == "__main__":
    run()
