"""Deterministic regression for gang/Lair NPC police custody."""

import os
import time
from pathlib import Path

os.environ.setdefault("BOT_TOKEN", "123456:npc-custody-regression")

import mafiozi_bot as game


def _advance(world, custody, phase, age):
    custody["phase"] = phase
    custody["phase_at"] = time.time() - age
    return world._tick_npc_custodies(.12, time.time())


def run():
    world = game.WorldSim()
    world.city_gangs.clear()
    world.cops.clear()
    gang = world._spawn_city_gang("purple")
    offender = gang["bots"][0]
    offender.update(x=24.0, y=28.0, alive=True, hp=100)

    assert world._flag_npc_murderer_by_ids(gang["id"], offender["id"], "gang_npc")
    assert offender["_npc_murder_wanted"]
    cop = next(c for c in world.cops if c.get("target_gang_id") == gang["id"])
    cop.update(x=offender["x"] + .7, y=offender["y"], alive=True)
    packets = world._tick_cop_vs_gang(cop, .12)
    assert any(p["kind"] == "npc_custody_started" for p in packets)
    custody = world._npc_custodies[offender["_custody_id"]]
    assert custody["bot_id"] == offender["id"]
    assert offender not in [x for x in gang["bots"]
                            if x.get("alive") and not x.get("_custody_id")]

    _advance(world, custody, "cuffing", world.NPC_CUSTODY_CUFF_S + .1)
    assert custody["phase"] == "escort"
    _advance(world, custody, "escort", world.NPC_CUSTODY_ESCORT_S + .1)
    assert custody["phase"] == "loading"
    _advance(world, custody, "loading", world.NPC_CUSTODY_LOAD_S + .1)
    assert custody["phase"] == "transport"
    custody["route"] = [(world.NPC_CUSTODY_GATE_X, world.NPC_CUSTODY_GATE_Y)]
    custody["vehicle_x"] = world.NPC_CUSTODY_GATE_X
    custody["vehicle_y"] = world.NPC_CUSTODY_GATE_Y
    world._tick_npc_custodies(.12, time.time())
    assert custody["phase"] == "unloading"
    _advance(world, custody, "unloading", world.NPC_CUSTODY_UNLOAD_S + .1)
    assert custody["phase"] == "prison_escort"
    _advance(world, custody, "prison_escort", world.NPC_CUSTODY_PRISON_ESCORT_S + .1)
    assert custody["phase"] == "jailed"
    assert 59 <= custody["jail_until"] - time.time() <= 61

    world.add_or_update("observer", "Observer", {})
    snap = world.snapshot_for("observer")["d"]
    prisoner = next(q for q in snap["npc_custodies"] if q["bot_id"] == offender["id"])
    assert prisoner["prisoner"] and prisoner["jail_in"] in (59, 60)

    custody["jail_until"] = time.time() - .1
    world._tick_npc_custodies(.12, time.time())
    assert custody["phase"] == "released"
    assert (custody["x"], custody["y"]) == (
        world.NPC_CUSTODY_RELEASE_X, world.NPC_CUSTODY_RELEASE_Y)
    _advance(world, custody, "released", 1.3)
    assert not offender.get("_custody_id")
    assert (offender["x"], offender["y"]) == (
        world.NPC_CUSTODY_RELEASE_X, world.NPC_CUSTODY_RELEASE_Y)

    # Lair offenders use the same exact state machine even though ordinary
    # player-wanted cops do not enter the Lair.
    lair_world = game.WorldSim()
    lair_world.aggro.clear()
    lair_world.cops.clear()
    lair_world._aggro_spawn("lair", lair_world.TERRITORIES_DEF["lair"])
    lair_bot = lair_world.aggro["lair"]["bots"][0]
    assert lair_world._flag_npc_murderer_by_ids("lair", lair_bot["id"], "player")
    lair_cop = next(c for c in lair_world.cops if c.get("target_gang_id") == "lair")
    lair_cop.update(x=lair_bot["x"] + .7, y=lair_bot["y"])
    assert any(p["kind"] == "npc_custody_started"
               for p in lair_world._tick_cop_vs_gang(lair_cop, .12))
    assert lair_bot.get("_custody_id")

    html = Path("world.html").read_text(encoding="utf-8")
    assert "suit:'#f07818'" in html
    assert "npc_custody_vehicle_" in html
    assert "_npcCustodyRemote" in html
    print("NPC_POLICE_CUSTODY_OK")


if __name__ == "__main__":
    run()
