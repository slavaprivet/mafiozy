"""Deterministic regressions for foot police custody of NPC gang offenders."""

import os
import random
import time
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("BOT_TOKEN", "123456:npc-custody-regression")

import mafiozi_bot as game


def _lethal_police_shot(world, gang, bot, roll):
    gang["state"] = "hostile"
    cop = world.spawn_cop(bot["x"] + .7, bot["y"], "", kind="combat")
    cop["target_gang_id"] = gang["id"]
    cop["_shot_t"] = 0
    bot["hp"] = 1
    with patch.object(game.WorldSim, "COP_MISS_CHANCE", 0.0), \
            patch("mafiozi_bot.random.random", return_value=roll):
        packets = world._tick_cop_vs_gang(cop, .12)
    return cop, packets


def run():
    # 30% branch: a lethal police hit leaves the NPC wounded, reserves exactly
    # one custody slot and the officer closes in before applying handcuffs.
    world = game.WorldSim()
    world.city_gangs.clear(); world.cops.clear()
    gang = world._spawn_city_gang("purple")
    offender = gang["bots"][0]
    offender.update(x=24.0, y=28.0, alive=True)
    cop, packets = _lethal_police_shot(world, gang, offender, .10)
    custody = world._npc_custodies[offender["_custody_id"]]
    assert custody["mode"] == "foot" and custody["phase"] == "wounded"
    assert any(p["kind"] == "npc_custody_started" and p["mode"] == "foot"
               for p in packets)
    assert offender["alive"] and offender["hp"] == 1
    assert offender not in [b for b in gang["bots"]
                            if b.get("alive") and not b.get("_custody_id")]

    for _ in range(200):
        world._tick_cop_vs_gang(cop, .12)
        if custody["phase"] == "cuffing":
            break
    assert custody["phase"] == "cuffing"
    custody["phase_at"] = time.time() - world.NPC_CUSTODY_CUFF_S - .1
    world._tick_npc_custodies(.12, time.time())
    assert custody["phase"] == "foot_escort"
    world._tick_cop_vs_gang(cop, .12)
    assert .55 <= ((cop["x"]-custody["x"])**2 +
                    (cop["y"]-custody["y"])**2) ** .5 <= .9

    # Walk the actual A* city route, then the authored gate/intake route.
    for _ in range(2600):
        world._tick_npc_custodies(.12, time.time())
        if cop.get("alive"):
            world._tick_cop_vs_gang(cop, .12)
        if custody["phase"] == "jailed":
            break
    assert custody["phase"] == "jailed", custody
    assert 59 <= custody["jail_until"] - time.time() <= 61

    world.add_or_update("observer", "Observer", {})
    snap = world.snapshot_for("observer")["d"]
    prisoner = next(q for q in snap["npc_custodies"] if q["bot_id"] == offender["id"])
    assert prisoner["mode"] == "foot" and prisoner["prisoner"]

    custody["jail_until"] = time.time() - .1
    world._tick_npc_custodies(.12, time.time())
    assert custody["phase"] == "released"
    custody["phase_at"] = time.time() - 1.3
    world._tick_npc_custodies(.12, time.time())
    assert not offender.get("_custody_id")
    assert (offender["x"], offender["y"]) == (
        world.NPC_CUSTODY_RELEASE_X, world.NPC_CUSTODY_RELEASE_Y)

    # 70% branch: the same lethal police hit is an ordinary death.
    death_world = game.WorldSim()
    death_world.city_gangs.clear(); death_world.cops.clear()
    death_gang = death_world._spawn_city_gang("yellow")
    doomed = death_gang["bots"][0]
    doomed.update(x=31.0, y=31.0, alive=True)
    _cop, death_packets = _lethal_police_shot(death_world, death_gang, doomed, .80)
    assert not doomed["alive"] and doomed["hp"] == 0
    assert not doomed.get("_custody_id") and not death_world._npc_custodies
    assert any(p["kind"] == "cop_shot_bot" and p["killed"]
               for p in death_packets)

    # Repeated calls for the same fight fill only the requested quota.
    cap_world = game.WorldSim()
    cap_world.city_gangs.clear(); cap_world.cops.clear()
    cap_gang = cap_world._spawn_city_gang("purple")
    for _ in range(12):
        cap_world._dispatch_cops_on_gang(cap_gang, 30, 30, count=2)
    assigned = [c for c in cap_world.cops if c.get("target_gang_id") == cap_gang["id"]]
    assert len(assigned) == 2

    # A captured-business garrison is part of the same visible actor budget;
    # it must not trigger a fifth replacement group on the next spawn tick.
    density_world = game.WorldSim()
    density_world.city_gangs.clear(); density_world.cops.clear()
    for index in range(density_world.CITY_GANG_MAX):
        group = density_world._spawn_city_gang("purple" if index % 2 else "yellow")
        if index == 0:
            group["_business_mode"] = "guard"
            group["_business_target_id"] = "bar"
    density_world.add_or_update("observer", "Observer", {})
    density_world._city_gang_next_spawn_at = 0
    density_world.tick_city_gangs(.12)
    assert len([g for g in density_world.city_gangs
                if not g.get("district_did")]) == density_world.CITY_GANG_MAX

    # Fixed-map sample: cuffed NPCs can walk from varied streets to the gate
    # without route churn or teleporting.
    passable = [(x+.2, y+.2)
                for y in range(8, game.WORLD_MAP_ROWS-12, 18)
                for x in range(8, game.WORLD_MAP_COLS-12, 18)
                if game._world_bot_passable(x, y)]
    for seed, (x, y) in enumerate(passable[:24]):
        random.seed(seed)
        sweep = game.WorldSim()
        sweep.city_gangs.clear(); sweep.cops.clear()
        group = sweep._spawn_city_gang("purple")
        target = group["bots"][0]
        target.update(x=x, y=y, alive=True, hp=1)
        officer = sweep.spawn_cop(x+.7, y, "", kind="combat")
        officer["target_gang_id"] = group["id"]
        q = sweep._begin_npc_custody(group, target, officer, time.time())
        q["phase_at"] -= sweep.NPC_CUSTODY_CUFF_S + .1
        sweep._tick_npc_custodies(.12, time.time())
        for _ in range(3000):
            sweep._tick_npc_custodies(.12, time.time())
            if q["phase"] == "jailed":
                break
        assert q["phase"] == "jailed", (seed, x, y, q["phase"])
        assert int(q.get("foot_route_replans") or 0) <= 1

    html = Path("world.html").read_text(encoding="utf-8")
    assert "if(!source)return false" in html
    assert "q.mode==='foot'" in html
    assert "suit:'#f07818'" in html
    print("NPC_POLICE_CUSTODY_OK: 70/30, 24 foot routes, release, bounded dispatch")


if __name__ == "__main__":
    run()
