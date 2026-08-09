"""Focused regression checks for the shared 2D/3D gang-world AI."""

import os
import time
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("BOT_TOKEN", "123456:gang-world-ai-regression")

import mafiozi_bot as game


def city_gang(world, faction, x, y):
    gang = world._spawn_city_gang(faction)
    assert gang and len(gang["bots"]) == world.CITY_GANG_SIZE
    for index, bot in enumerate(gang["bots"]):
        bot.update(x=x + index * .35, y=y + index * .6,
                   hp=120, max_hp=120, weapon="pistol",
                   _shot_t=0.0, _act="walk", _act_until=time.time() + 60)
    gang["_reinforcements"] = world.CITY_GANG_MAX_REINFORCEMENTS
    gang["_rival_replan_at"] = 0.0
    gang["_cops_dispatched"] = True
    return gang


def run():
    world = game.WorldSim()
    world.city_gangs.clear()
    world.cops.clear()
    world._city_gang_next_spawn_at = time.time() + 3600
    purple = city_gang(world, "purple", 10.0, 10.0)
    yellow = city_gang(world, "yellow", 14.0, 12.0)
    for gang in (purple, yellow):
        gang["bots"][1]["alive"] = gang["bots"][2]["alive"] = False

    # Street groups deliberately seek a nearby rival instead of wandering
    # forever, and a real exchange of fire brings police and scares civilians.
    with patch.object(game.random, "random", return_value=0.0):
        packets = world.tick_city_gangs(.12)
    assert purple["_rival_target_gid"] == yellow["id"]
    assert any(p.get("npc_gang_fight") for p in packets)
    assert any(p["kind"] == "city_gang_police_called" for p in packets)
    assert any(p["kind"] == "city_gang_civilians_flee" for p in packets)
    assert {str(c.get("target_gang_id")) for c in world.cops} >= {
        str(purple["id"]), str(yellow["id"])}

    # A gang returns fire on those cops even though no player started the war.
    for bot in purple["bots"]:
        bot["_shot_t"] = 0.0
        bot["_mag"] = 8
    for cop in world.cops:
        if str(cop.get("target_gang_id")) == str(purple["id"]):
            cop.update(x=purple["bots"][0]["x"] + 2.0,
                       y=purple["bots"][0]["y"] + 1.0, hp=100, alive=True)
    cop_packets = world._city_gang_fire_on_cops(
        purple, [purple["bots"][0]], time.time())
    assert any(p.get("kind") == "gang_shot_cop" for p in cop_packets)

    yellow["bots"][0]["hp"] = 1
    purple["bots"][0]["_shot_t"] = 0.0
    purple["bots"][0]["_mag"] = 8
    for encounter in world._city_gang_encounters.values():
        encounter["shot_at"] = 0.0
    with patch.object(game.random, "random", return_value=.5):
        control_packets = world.tick_city_gangs(.12)
    assert any(p.get("kind") == "city_gang_control" for p in control_packets)
    assert world._street_control

    # Casualties trigger one bounded reinforcement wave.
    backup_world = game.WorldSim()
    backup_world.city_gangs.clear()
    backup_world._city_gang_next_spawn_at = time.time() + 3600
    backup = city_gang(backup_world, "purple", 60.0, 60.0)
    backup["_reinforcements"] = 0
    backup["bots"][-1]["alive"] = False
    backup["_reinforce_at"] = time.time() - 1
    backup_packets = backup_world.tick_city_gangs(.1)
    assert len([b for b in backup["bots"] if b["alive"]]) == 3
    assert any(p["kind"] == "city_gang_backup_arrived" for p in backup_packets)

    # A critically wounded last survivor can surrender and is removed after
    # the visible hands-up grace period.
    surrender_world = game.WorldSim()
    surrender_world.city_gangs.clear()
    surrender_world._city_gang_next_spawn_at = time.time() + 3600
    surrender = city_gang(surrender_world, "yellow", 70.0, 70.0)
    surrender["_reinforcements"] = surrender_world.CITY_GANG_MAX_REINFORCEMENTS
    surrender["bots"][1]["alive"] = surrender["bots"][2]["alive"] = False
    surrender["bots"][0]["hp"] = 1
    with patch.object(game.random, "random", return_value=0.0):
        surrender_packets = surrender_world.tick_city_gangs(.1)
    assert any(p["kind"] == "city_gang_surrender" for p in surrender_packets)
    assert surrender["bots"][0].get("_combat_state") == "surrender"

    # Lair starts as a guarded camp, warns first, raises an alarm after the
    # grace period, dodges explosives and reacts when its boss falls.
    lair_world = game.WorldSim()
    lair_world.aggro.clear()
    lair_def = lair_world.TERRITORIES_DEF["lair"]
    lair_world._aggro_spawn("lair", lair_def)
    lair = lair_world.aggro["lair"]
    assert sum(bool(b.get("_sentry")) for b in lair["bots"]) == 4
    uid = "lair-tester"
    lair_world.add_or_update(uid, "Tester", {})
    lair_world.players[uid].update(x=float(lair_def["c"]),
                                   y=float(lair_def["r"]), _mode="pvp")
    warn_packets = lair_world.tick_aggro(.1)
    assert any(p["kind"] == "aggro_warn" for p in warn_packets)
    assert lair["_alarm_level"] == 1
    lair["_neutral_warned"][uid] = time.time() - lair_world.AGGRO_WARN_S - .2
    alarm_packets = lair_world.tick_aggro(.1)
    assert any(p["kind"] == "lair_alarm" for p in alarm_packets)
    assert lair["_alarm_level"] == 2

    lair_world.players[uid].update(x=lair["bots"][0]["x"] - 1.0,
                                   y=lair["bots"][0]["y"])
    throw = lair_world.register_gang_throwable(uid, {
        "kind": "grenade", "from_x": lair_world.players[uid]["x"],
        "from_y": lair_world.players[uid]["y"],
        "to_x": lair["bots"][0]["x"], "to_y": lair["bots"][0]["y"],
    })
    assert throw
    grenade_packets = lair_world.tick_aggro(.12)
    assert any(p["kind"] == "lair_grenade_alert" for p in grenade_packets)
    assert any(b.get("_dodge_kind") == "grenade" for b in lair["bots"])

    boss = next(b for b in lair["bots"] if b.get("kind") == "aggro_boss")
    boss["alive"] = False
    fallen_packets = lair_world.tick_aggro(.1)
    survivors = [b for b in lair["bots"] if b.get("alive")]
    assert any(p["kind"] == "lair_boss_fallen" for p in fallen_packets)
    assert any(b.get("_last_stand") for b in survivors)
    assert any(float(b.get("_panic_until") or 0) > time.time() for b in survivors)

    # Nearby clients receive combat FX, distant clients do not; strategic
    # control survives reconnect through the snapshot payload.
    filter_world = game.WorldSim()
    filter_world.add_or_update("near", "Near", {})
    filter_world.add_or_update("far", "Far", {})
    filter_world.players["near"].update(x=10.0, y=10.0)
    filter_world.players["far"].update(x=100.0, y=100.0)
    local_fx = {"kind": "aggro_hit", "sx": 11.0, "sy": 10.0}
    assert filter_world.world_event_visible_to("near", local_fx)
    assert not filter_world.world_event_visible_to("far", local_fx)
    filter_world._street_control["0:0"] = {
        "faction": "purple", "x": 10.0, "y": 10.0,
        "expires_at": time.time() + 120,
    }
    assert "0:0" in filter_world.snapshot_for("near")["d"]["street_control"]

    # Autonomous business sandbox: a patrol chooses a reachable business,
    # captures it only after a real hold, stays there as the visible garrison,
    # and a surviving rival can take the same point after clearing defenders.
    sandbox = game.WorldSim()
    sandbox.city_gangs.clear()
    sandbox.cops.clear()
    sandbox._city_gang_next_spawn_at = time.time() + 3600
    attackers = city_gang(sandbox, "purple", 13.0, 33.0)
    target_id = sandbox._city_gang_choose_business_target(
        attackers, 13.0, 33.0, time.time())
    assert target_id in game.BUSINESS_POIS_RC
    sandbox._city_gang_set_business_target(attackers, "coffee", time.time())
    for bot in attackers["bots"]:
        bot.update(x=13.0, y=33.0, _act="walk")
    attackers["_business_capture_started"] = (
        time.time() - sandbox.CITY_GANG_BUSINESS_CAPTURE_S - .2)
    capture_packets = sandbox.tick_city_gangs(.1)
    control = sandbox._npc_business_controls.get("coffee")
    assert control and control["faction"] == "purple"
    assert control["guard_gid"] == attackers["id"]
    assert attackers["_business_mode"] == "guard"
    assert any(p["kind"] == "npc_business_captured" for p in capture_packets)

    defenders = attackers
    rivals = city_gang(sandbox, "yellow", 13.4, 33.2)
    sandbox._city_gang_set_business_target(rivals, "coffee", time.time())
    assert sandbox._city_gang_business_rivals_must_fight(defenders, rivals)
    for bot in defenders["bots"]:
        bot["alive"] = False
    for bot in rivals["bots"]:
        bot.update(x=13.0, y=33.0, _act="walk")
    rivals["_business_capture_started"] = (
        time.time() - sandbox.CITY_GANG_BUSINESS_CAPTURE_S - .2)
    takeover_packets = sandbox.tick_city_gangs(.1)
    new_control = sandbox._npc_business_controls.get("coffee")
    assert new_control and new_control["faction"] == "yellow"
    assert new_control["guard_gid"] == rivals["id"]
    assert any(p["kind"] == "npc_business_captured"
               and p.get("previous_faction") == "purple"
               for p in takeover_packets)

    # An abandoned friendly point still requires the replacement patrol to
    # physically arrive; ownership cannot teleport a remote squad into guard.
    sandbox._npc_business_controls["bar"] = {
        "faction": "yellow", "guard_gid": "", "color": "#ffe34d"}
    relief = city_gang(sandbox, "yellow", 5.0, 5.0)
    sandbox._city_gang_set_business_target(relief, "bar", time.time())
    sandbox.tick_city_gangs(.1)
    assert relief["_business_mode"] != "guard"
    assert sandbox._npc_business_controls["bar"]["guard_gid"] == ""

    sandbox.add_or_update("observer", "Observer", {})
    sandbox.players["observer"].update(x=13.0, y=33.0)
    snap = sandbox.snapshot_for("observer")["d"]
    assert snap["npc_business_controls"]["coffee"]["faction"] == "yellow"
    assert snap["npc_business_dominance"]["yellow"] == 2

    # Faction economy is isolated from player/family money. Holdings generate
    # a bounded treasury while a faction with no holdings still receives a
    # small comeback reserve, so the map cannot permanently snowball.
    economy = game.WorldSim()
    economy.city_gangs.clear()
    economy._npc_business_controls = {
        "coffee": {"faction": "purple", "guard_gid": ""},
        "pizza": {"faction": "purple", "guard_gid": ""},
    }
    economy_now = time.time()
    for state in economy._npc_gang_economy.values():
        state["treasury"] = 0
        state["last_income_at"] = economy_now - economy.NPC_GANG_ECONOMY_TICK_S * 2.1
    economy_packets = economy._tick_npc_gang_economy(economy_now)
    assert economy._npc_gang_economy["purple"]["treasury"] > \
        economy._npc_gang_economy["yellow"]["treasury"] > 0
    assert any(p["kind"] == "npc_gang_income" for p in economy_packets)
    assert economy.NPC_GANG_PROFILES["purple"]["doctrine"] != \
        economy.NPC_GANG_PROFILES["yellow"]["doctrine"]

    # Reinforcements are no longer free: an empty treasury blocks the wave
    # without creating extra bots or a retry storm.
    broke_world = game.WorldSim()
    broke_world.city_gangs.clear()
    broke_world._city_gang_next_spawn_at = time.time() + 3600
    broke = city_gang(broke_world, "yellow", 50.0, 50.0)
    broke["_reinforcements"] = 0
    broke["bots"][-1]["alive"] = False
    broke["_reinforce_at"] = time.time() - 1
    broke_world._npc_gang_economy["yellow"]["treasury"] = 0
    broke_packets = broke_world.tick_city_gangs(.1)
    assert len([b for b in broke["bots"] if b["alive"]]) == 2
    assert any(p["kind"] == "city_gang_backup_denied" for p in broke_packets)

    fort_world = game.WorldSim()
    fort_world.city_gangs.clear()
    fort_guard = city_gang(fort_world, "purple", 13.0, 33.0)
    fort_now = time.time()
    fort_world._npc_business_controls["coffee"] = {
        "faction": "purple", "guard_gid": fort_guard["id"],
        "defense_level": 1, "captured_at": fort_now - 500,
        "last_fortified_at": fort_now - fort_world.NPC_GANG_FORTIFY_GAP_S - 1,
    }
    fort_world._npc_gang_economy["purple"].update(
        treasury=500, last_income_at=fort_now)
    fort_packets = fort_world._tick_npc_gang_economy(fort_now)
    assert fort_world._npc_business_controls["coffee"]["defense_level"] == 2
    assert fort_world._npc_gang_economy["purple"]["treasury"] < 500
    assert any(p["kind"] == "npc_business_fortified" for p in fort_packets)

    # A player/family business war has priority over ambient NPC racket. The
    # old NPC flag is released instead of running two ownership state machines
    # on the same building.
    conflict_world = game.WorldSim()
    conflict_world.city_gangs.clear()
    conflict_guard = city_gang(conflict_world, "purple", 13.0, 33.0)
    conflict_world._npc_business_controls["coffee"] = {
        "faction": "purple", "guard_gid": conflict_guard["id"],
        "defense_level": 1,
    }
    conflict_guard.update(_business_mode="guard", _business_guard_id="coffee")
    conflict_world._business_family_wars["coffee"] = {"expires_at": time.time()+60}
    conflict_packets = conflict_world.tick_city_gangs(.1)
    assert "coffee" not in conflict_world._npc_business_controls
    assert conflict_guard["_business_mode"] == ""
    assert any(p["kind"] == "npc_business_released" for p in conflict_packets)
    assert not conflict_world._city_gang_set_business_target(
        conflict_guard, "coffee", time.time())

    # A reconnect receives both strategic strength and live operation phases;
    # this payload is display-only and cannot overwrite player business state.
    strategy_snap = sandbox.snapshot_for("observer")["d"]
    assert set(strategy_snap["npc_gang_economy"]) == {"purple", "yellow"}
    assert any(op["biz_id"] == "bar" for op in strategy_snap["npc_business_operations"])
    assert "treasury" not in strategy_snap["npc_business_controls"]["coffee"]

    world_source = Path("world.html").read_text(encoding="utf-8")
    preview_source = Path("three_preview.js").read_text(encoding="utf-8")
    preview_server_source = Path("_preview_ws_server.py").read_text(encoding="utf-8")
    for marker in ("city_gang_surrender", "street_control", "ceasefire",
                   "lair_boss_fallen", "_gangSquadMorale",
                   "npc_business_controls", "npc_gang_economy",
                   "npc_business_operations", "drawNpcBusinessControl"):
        assert marker in world_source
    assert "sentry-last-stand-retreat-surrender" in preview_source
    assert "businessControl" in preview_source
    assert 'f"{req.scheme}://{req.host}"' in preview_server_source
    assert '{"base": "http://127.0.0.1:8080"}' not in preview_server_source
    # The authoritative controls must be applied at the start of a snapshot,
    # never from the interior movement loop (where `d` is not a packet).
    control_apply = "if (d.npc_business_controls !== undefined)"
    assert world_source.count(control_apply) == 1
    assert world_source.index(control_apply) < world_source.index("_updateFactionWarHud(d.faction_war)")
    print("OK: street wars, business sandbox, police, lair and 2D/3D states")


if __name__ == "__main__":
    run()
