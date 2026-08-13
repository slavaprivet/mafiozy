"""Thirty virtual minutes of bounded mixed-city combat.

The browser owns the visible nineteen-family actor pool, while the server owns
street gangs and police.  This regression exercises the long-running server
simulation and pins the client contracts which join those two layers.
"""

import os
import itertools
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("BOT_TOKEN", "123456:mixed-city-stress-regression")

import mafiozi_bot as game
import npc_empire


ROOT = Path(__file__).resolve().parent


def rounded_los(sx, sy, tx, ty):
    """Packets round positions to 0.01; recover the server-space tolerance."""
    offsets = (-.006, 0.0, .006)
    return any(game._world_los(sx+dsx, sy+dsy, tx+dtx, ty+dty)
               for dsx, dsy, dtx, dty in itertools.product(offsets, repeat=4))


class Clock:
    now = 10_000.0


def spawn_gang(world, faction, x, y, weapons):
    gang = world._spawn_city_gang(faction)
    assert gang and len(gang["bots"]) == world.CITY_GANG_SIZE
    for index, bot in enumerate(gang["bots"]):
        bot.update(
            x=x + index * .18, y=y + index * .22,
            hp=1_000_000, max_hp=1_000_000, alive=True,
            weapon=weapons[index % len(weapons)], level=1,
            _shot_t=0.0, _act="walk", _act_until=Clock.now + 3600,
        )
    gang.update(
        _reinforcements=world.CITY_GANG_MAX_REINFORCEMENTS,
        _rival_replan_at=0.0, _cops_dispatched=True,
    )
    return gang


def assert_client_mixed_city_contracts():
    source = (ROOT / "world.html").read_text(encoding="utf-8")

    # All nineteen authored leaders participate, but visible actors, routes,
    # bullets and short-lived effects remain hard-capped.
    assert len(npc_empire.PROFILES) == 19
    assert len({p.leader_id for p in npc_empire.PROFILES}) == 19
    assert "EMPIRE_VISIBLE_CREW_CAP=36" in source
    assert "EMPIRE_VISIBLE_HOLDING_GUARD_CAP=18" in source
    assert "const _MAX_BULLETS = 50, _MAX_IMPACTS = 16, _MAX_BLOOD = 48" in source
    assert "if(!npc._empireRouteQueued){npc._empireRouteQueued=true;_empireRoutePlanQueue.push(npc);" in source

    # A family only targets its declared enemy, damage has a same-family
    # backstop, and both movement and the firing lane use the 3D footprint
    # passability predicate. The authored weapon id and speed feed the tracer.
    assert "if(candidateId!==enemyId||d>EMPIRE_FIELD_ENGAGE_R)continue;" in source
    assert "_empireLeaderIdOf(target)===_empireLeaderIdOf(source))return false;" in source
    assert "!_npcPathPassable(n.r,n.c,target.r,target.c,_empireBossPassable)" in source
    assert "spawnBullet(muz.r,muz.c,aimR,aimC,{hit,fromNpc:true,weapon,speed:visualSpeed" in source
    assert "targetActor:hit?target:null" in source

    # Every family keeps one stable, finite visible activity throughout all
    # sixty 30-second slots in the virtual run (19 simultaneously per slot).
    for now in range(10_000, 11_800, 30):
        activities = []
        for profile in npc_empire.PROFILES:
            row = {"hq_key": profile.hq_key, "members": 12,
                   "recruitment_started_at": 0}
            activity = npc_empire._visible_activity(profile, row, [], now)
            assert activity["target_id"]
            assert all(abs(float(activity[key])) < 1_000
                       for key in ("target_r", "target_c"))
            activities.append(activity)
        assert len(activities) == 19


def assert_blocked_and_surrendered_cannot_exchange_fire():
    game.random.seed(1801)
    world = game.WorldSim()
    world.city_gangs.clear()
    world.cops.clear()
    world._city_gang_next_spawn_at = Clock.now + 3600
    left = spawn_gang(world, "purple", 10, 10, ("rifle",))
    right = spawn_gang(world, "yellow", 14, 10, ("pistol",))
    for gang in (left, right):
        gang["_rival_replan_at"] = Clock.now + 3600
    pair = tuple(sorted((str(left["id"]), str(right["id"]))))
    world._city_gang_encounters[pair] = {
        "fight": True, "until": Clock.now + 60,
        "shot_at": 0.0, "police_called": True,
    }

    hp_before = [bot["hp"] for bot in right["bots"]]
    with patch.object(game, "_world_los", return_value=False):
        packets = world.tick_city_gangs(.25)
    assert not any(packet.get("npc_gang_fight") for packet in packets)
    assert [bot["hp"] for bot in right["bots"]] == hp_before

    allied = spawn_gang(world, "purple", 12, 10, ("pistol",))
    allied["bots"][0].update(x=12.0, y=10.0, _combat_state="surrender")
    allied["bots"][1]["alive"] = allied["bots"][2]["alive"] = False
    assert not world._city_gang_shot_safe(
        left, left["bots"][0], right["bots"][0]["x"], right["bots"][0]["y"])

    surrendered = left["bots"][0]
    surrendered["_combat_state"] = "surrender"
    surrendered["_surrendered_until"] = Clock.now + 60
    left["bots"][1]["alive"] = left["bots"][2]["alive"] = False
    world._city_gang_encounters[pair]["shot_at"] = 0.0
    hp_before = surrendered["hp"]
    packets = world.tick_city_gangs(.25)
    assert surrendered["hp"] == hp_before
    assert not any(packet.get("shooter_bot_id") == surrendered["id"]
                   or packet.get("bot_id") == surrendered["id"]
                   for packet in packets if packet.get("kind") != "city_gang_surrender")

    world.cops.append({"id": "surrender-cop", "x": 11.0, "y": 10.0,
                       "hp": 100, "alive": True, "target_uid": "",
                       "target_gang_id": left["id"], "kind": "combat",
                       "weapon": "pistol_heavy", "_shot_t": 0.0,
                       "_strafe_t": 0.0})
    assert world._city_gang_fire_on_cops(
        left, [surrendered], Clock.now) == []
    packets = world.tick_cops(.25)
    assert surrendered["hp"] == hp_before
    assert not any(packet.get("kind") == "cop_shot_bot"
                   and packet.get("bot_id") == surrendered["id"]
                   for packet in packets)


def run_thirty_virtual_minutes():
    game.random.seed(1800)
    world = game.WorldSim()
    world.city_gangs.clear()
    world.cops.clear()
    world.players.clear()
    world._city_gang_next_spawn_at = Clock.now + 3600
    weapons = ("pistol", "shotgun", "rifle")
    gangs = [
        spawn_gang(world, "purple", 30.0, 30.0, weapons),
        spawn_gang(world, "yellow", 34.0, 30.0, weapons),
        spawn_gang(world, "purple", 30.0, 34.0, weapons),
        spawn_gang(world, "yellow", 34.0, 34.0, weapons),
    ]
    for gang in gangs:
        gang["_rival_replan_at"] = Clock.now + 3600
    for left in gangs:
        for right in gangs:
            if left["id"] >= right["id"] or left["faction"] == right["faction"]:
                continue
            pair = tuple(sorted((str(left["id"]), str(right["id"]))))
            world._city_gang_encounters[pair] = {
                "fight": True, "until": Clock.now + 3600,
                "shot_at": 0.0, "police_called": False,
            }

    shots = police_calls = cop_shots = 0
    max_cops = max_routes = max_encounters = max_pending = 0
    previous = {bot["id"]: (bot["x"], bot["y"])
                for gang in gangs for bot in gang["bots"]}
    dt = .25
    for _ in range(int(30 * 60 / dt)):
        Clock.now += dt
        packets = world.tick_city_gangs(dt)
        packets.extend(world.tick_cops(dt))
        packets.extend(world.tick_pending_bot_shots())

        for packet in packets:
            if packet.get("npc_gang_fight"):
                shots += 1
                assert packet["attacker_faction"] != packet["victim_faction"]
                stats = world.AGGRO_WEAPON_STATS[packet["weapon"]]
                assert packet["bullet_speed"] == stats["speed"]
                assert rounded_los(packet["sx"], packet["sy"],
                                   packet["tx"], packet["ty"])
            elif packet.get("kind") == "city_gang_police_called":
                police_calls += 1
            elif packet.get("kind") == "gang_shot_cop":
                cop_shots += 1
                assert packet["bullet_speed"] == \
                    world.AGGRO_WEAPON_STATS[packet["weapon"]]["speed"]

        assert len(world.city_gangs) <= world.CITY_GANG_MAX
        assert sum(len(gang["bots"]) for gang in world.city_gangs) <= 12
        assert len(world._city_gang_encounters) <= 32
        assert len(world._pending_bot_shots) <= 64
        max_cops = max(max_cops, len(world.cops))
        max_encounters = max(max_encounters, len(world._city_gang_encounters))
        max_pending = max(max_pending, len(world._pending_bot_shots))
        route_nodes = sum(len(gang.get("_patrol_route") or [])
                          for gang in world.city_gangs)
        max_routes = max(max_routes, route_nodes)
        assert route_nodes <= game.WORLD_MAP_ROWS * game.WORLD_MAP_COLS

        current = {bot["id"]: (bot["x"], bot["y"])
                   for gang in world.city_gangs for bot in gang["bots"]
                   if bot.get("alive")}
        for bot_id, (x, y) in current.items():
            if bot_id in previous:
                old_x, old_y = previous[bot_id]
                assert ((x-old_x)**2 + (y-old_y)**2) ** .5 <= .8
        previous = current

    assert shots > 0
    assert police_calls > 0 and max_cops > 0, (shots, police_calls, max_cops,
                                               cop_shots)
    assert cop_shots > 0
    return {
        "virtual_seconds": 1800, "street_shots": shots,
        "police_calls": police_calls, "cop_return_shots": cop_shots,
        "max_cops": max_cops, "max_route_nodes": max_routes,
        "max_encounters": max_encounters, "max_pending_shots": max_pending,
    }


def run():
    with patch.object(game.time, "time", side_effect=lambda: Clock.now):
        assert_client_mixed_city_contracts()
        assert_blocked_and_surrendered_cannot_exchange_fire()
        metrics = run_thirty_virtual_minutes()
    print("OK: 30-minute mixed-city stress", metrics)


if __name__ == "__main__":
    run()
