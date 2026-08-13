"""Accelerated 15-minute regression for concurrent autonomous street gangs."""

import json
import os
from collections import Counter
from unittest.mock import patch

os.environ.setdefault("BOT_TOKEN", "123456:gang-multi-stress")

import mafiozi_bot as game


def spawn_group(world, faction, x, y, now):
    gang = world._spawn_city_gang(faction)
    assert gang
    for index, bot in enumerate(gang["bots"]):
        bot.update(
            x=x + index * .30,
            y=y + index * .55,
            hp=90,
            max_hp=90,
            weapon=("pistol", "shotgun", "rifle")[index],
            level=1,
            alive=True,
            _shot_t=0.0,
            _act="idle",
            _act_until=float("inf"),
        )
    gang.update(
        _reinforcements=world.CITY_GANG_MAX_REINFORCEMENTS,
        _rival_replan_at=0.0,
        _business_replan_at=float("inf"),
        _motion_check_at=float("inf"),
        _patrol_wp_until=float("inf"),
    )
    return gang


def run():
    game.random.seed(20260813)
    clock = [1_800_000_000.0]
    world = game.WorldSim()
    world.city_gangs.clear()
    world.cops.clear()
    world._city_gang_next_spawn_at = float("inf")

    with patch.object(game.time, "time", side_effect=lambda: clock[0]):
        purple_west = spawn_group(world, "purple", 10.0, 10.0, clock[0])
        yellow_west = spawn_group(world, "yellow", 14.0, 11.0, clock[0])
        purple_east = spawn_group(world, "purple", 50.0, 50.0, clock[0])
        yellow_east = spawn_group(world, "yellow", 54.0, 51.0, clock[0])

        with patch.object(game.random, "random", return_value=0.0):
            first = world.tick_city_gangs(.1)

        assert purple_west["_rival_target_gid"] == yellow_west["id"]
        assert yellow_west["_rival_target_gid"] == purple_west["id"]
        assert purple_east["_rival_target_gid"] == yellow_east["id"]
        assert yellow_east["_rival_target_gid"] == purple_east["id"]

        packets = list(first)
        max_gangs = len(world.city_gangs)
        max_bots = sum(len(g["bots"]) for g in world.city_gangs)
        max_cops = len(world.cops)
        max_encounters = len(world._city_gang_encounters)
        # 900 seconds at just over one simulated second per tick.
        for _ in range(856):
            clock[0] += 1.052
            with patch.object(game.random, "random", return_value=0.0):
                tick_packets = world.tick_city_gangs(.1)
            packets.extend(tick_packets)
            max_gangs = max(max_gangs, len(world.city_gangs))
            max_bots = max(max_bots, sum(len(g["bots"]) for g in world.city_gangs))
            max_cops = max(max_cops, len(world.cops))
            max_encounters = max(max_encounters,
                                 len(world._city_gang_encounters))

        shots = [p for p in packets if p.get("npc_gang_fight")]
        assert shots
        assert all(p["attacker_faction"] != p["victim_faction"] for p in shots)
        assert all(p["bullet_speed"] ==
                   world.AGGRO_WEAPON_STATS[p["weapon"]]["speed"] for p in shots)
        assert all(p["attacker_gid"] != p["tid"] for p in shots)
        assert any(p["kind"] == "city_gang_police_called" for p in packets)
        assert any(p["kind"] == "city_gang_civilians_flee" for p in packets)
        assert max_gangs <= world.CITY_GANG_MAX
        assert max_bots <= world.CITY_GANG_MAX * world.CITY_GANG_SIZE
        assert max_cops <= world.CITY_GANG_MAX * 2
        assert max_encounters <= 6  # C(4, 2), with no per-tick state growth.
        # Combat must converge: no opposing live pair remains in firing range.
        live = [(g, [b for b in g["bots"] if b.get("alive")])
                for g in world.city_gangs]
        for index, (gang, bots) in enumerate(live):
            if not bots:
                continue
            cx = sum(b["x"] for b in bots) / len(bots)
            cy = sum(b["y"] for b in bots) / len(bots)
            for rival, rivals in live[index + 1:]:
                if not rivals or gang["faction"] == rival["faction"]:
                    continue
                rx = sum(b["x"] for b in rivals) / len(rivals)
                ry = sum(b["y"] for b in rivals) / len(rivals)
                assert (cx-rx) ** 2 + (cy-ry) ** 2 > 7.0 ** 2

        # A wall blocks the exchange completely and does not consume HP.
        blocked = game.WorldSim()
        blocked.city_gangs.clear()
        blocked._city_gang_next_spawn_at = float("inf")
        left = spawn_group(blocked, "purple", 20.0, 20.0, clock[0])
        right = spawn_group(blocked, "yellow", 24.0, 20.5, clock[0])
        before = [b["hp"] for b in left["bots"] + right["bots"]]
        with patch.object(game, "_world_los", return_value=False), \
                patch.object(game.random, "random", return_value=0.0):
            blocked_packets = blocked.tick_city_gangs(.1)
        assert not any(p.get("npc_gang_fight") for p in blocked_packets)
        assert before == [b["hp"] for b in left["bots"] + right["bots"]]

        # Hands-up is terminal combat state: neither the survivor nor its
        # opponent may add another gang-fire packet during the grace period.
        surrender_world = game.WorldSim()
        surrender_world.city_gangs.clear()
        surrender_world._city_gang_next_spawn_at = float("inf")
        yielding = spawn_group(surrender_world, "purple", 70.0, 70.0, clock[0])
        opponent = spawn_group(surrender_world, "yellow", 74.0, 70.5, clock[0])
        yielding["bots"][1]["alive"] = yielding["bots"][2]["alive"] = False
        yielding["bots"][0]["hp"] = 1
        with patch.object(game.random, "random", return_value=0.0):
            surrender_packets = surrender_world.tick_city_gangs(.1)
        assert any(p.get("kind") == "city_gang_surrender"
                   for p in surrender_packets)
        assert not any(p.get("npc_gang_fight") and (
            p.get("attacker_gid") == yielding["id"] or p.get("tid") == yielding["id"])
            for p in surrender_packets)

        # A denied reinforcement observes its retry deadline instead of
        # producing one request/denial FX pair on every server tick.
        broke = game.WorldSim()
        broke.city_gangs.clear()
        broke._city_gang_next_spawn_at = float("inf")
        broke_group = spawn_group(broke, "purple", 30.0, 30.0, clock[0])
        broke_group["_reinforcements"] = 0
        broke_group["bots"][-1]["alive"] = False
        broke_group["_reinforce_at"] = clock[0] - 1.0
        broke._npc_gang_economy["purple"]["treasury"] = 0
        denied = broke.tick_city_gangs(.1)
        assert sum(p.get("kind") == "city_gang_backup_denied" for p in denied) == 1
        retry_noise = []
        for _ in range(10):
            clock[0] += 1.0
            retry_noise.extend(broke.tick_city_gangs(.1))
        assert not any(p.get("kind") in {
            "city_gang_backup_called", "city_gang_backup_denied"
        } for p in retry_noise)

        # Projectile storage is bounded and all due shots/FX are drained.
        projectile_world = game.WorldSim()
        projectile_world.add_or_update("target", "Target", {})
        target = projectile_world.players["target"]
        target.update(x=2.0, y=2.0, hp=100, max_hp=100, dead=False)
        for index in range(600):
            projectile_world._enqueue_bot_shot(
                target=target, sx=0.0, sy=0.0, tx=2.0, ty=2.0,
                weapon="pistol", bot_id=f"stress-{index}", tid="stress")
        assert len(projectile_world._pending_bot_shots) == \
            projectile_world.CITY_GANG_PENDING_SHOT_CAP
        clock[0] += 10.0
        projectile_world.tick_pending_bot_shots()
        assert not projectile_world._pending_bot_shots

    kinds = Counter(p.get("kind") for p in packets)
    metrics = {
        "virtual_seconds": round(856 * 1.052, 1),
        "gang_shots": len(shots),
        "police_calls": kinds["city_gang_police_called"],
        "civilian_flee_events": kinds["city_gang_civilians_flee"],
        "max_gangs": max_gangs,
        "max_bots": max_bots,
        "max_cops": max_cops,
        "max_encounters": max_encounters,
        "pending_shot_cap": world.CITY_GANG_PENDING_SHOT_CAP,
        "pending_shots_after_drain": len(projectile_world._pending_bot_shots),
        "friendly_fire_packets": sum(
            p["attacker_faction"] == p["victim_faction"] for p in shots),
        "blocked_wall_shots": sum(
            bool(p.get("npc_gang_fight")) for p in blocked_packets),
        "reinforcement_retry_noise": sum(
            p.get("kind") in {"city_gang_backup_called", "city_gang_backup_denied"}
            for p in retry_noise),
    }
    print("GANG_MULTI_STRESS_OK " + json.dumps(metrics, sort_keys=True))


if __name__ == "__main__":
    run()
