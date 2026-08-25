"""P0: a marching business-raid boss is damageable, reactive and reload-stable."""

import asyncio
import os
import tempfile
from pathlib import Path
from unittest.mock import patch

import npc_empire as ne
import mafiozi_bot as game
from test_npc_empire import _base_db


ROOT = Path(__file__).resolve().parent
NOW = 2_010_000_000


async def run() -> None:
    os.makedirs(r"D:\CodexTemp", exist_ok=True)
    handle, path = tempfile.mkstemp(
        prefix="boss_capture_p0_", suffix=".db", dir=r"D:\CodexTemp")
    os.close(handle)
    try:
        await _base_db(path)
        state = await ne.state_for(path, 3101, NOW)
        empire = next(item for item in state["empires"] if item["leader_id"] == "vera")
        activity = empire["activity"]
        target_r = float(activity.get("target_r", empire["hq_r"]))
        target_c = float(activity.get("target_c", empire["hq_c"]))
        hq_r = float(empire["hq_r"]); hq_c = float(empire["hq_c"])

        # HTTP actor coordinates are only a hint. The server projects the
        # authoritative live player onto its own authored route corridor.
        fake_route = [(target_c, target_r)]
        mid_r = hq_r + (target_r - hq_r) * .45
        mid_c = hq_c + (target_c - hq_c) * .45
        with patch.object(game, "_world_bot_passable", return_value=True), \
                patch.object(game, "_world_bot_path", return_value=fake_route):
            witness = game._npc_empire_field_route_witness(empire, mid_r + 1, mid_c)
            outside = game._npc_empire_field_route_witness(empire, mid_r + 30, mid_c)
        assert witness["ok"] and witness["distance"] <= 1.01
        assert not outside["ok"] and outside["error"] == "player outside activity corridor"

        first = await ne.prepare_field_encounter(
            path, 3101, "vera", mid_r + 1, mid_c, NOW + 1,
            server_activity=activity, actor_r=witness["r"], actor_c=witness["c"])
        assert first["ok"] and first["shot_contract"] == 2
        start_hp = first["boss"]["hp"]
        hit = await ne.assault_field_hit_authorized(
            path, 3101, first["token"], 1, "pistol", 31, NOW + 2)
        assert hit["ok"] and hit["boss_hp"] == start_hp - 31

        # The same activity generation advances more than the old ten-tile
        # destination anchor without creating a fresh HP pool.
        second_r = hq_r + (target_r - hq_r) * .9
        second_c = hq_c + (target_c - hq_c) * .9
        second = await ne.prepare_field_encounter(
            path, 3101, "vera", second_r, second_c, NOW + 3,
            server_activity=activity, actor_r=second_r, actor_c=second_c)
        assert second["ok"] and second["duplicate"]
        assert second["encounter_id"] == first["encounter_id"]
        assert second["boss"]["hp"] == start_hp - 31
        assert abs(second["anchor"]["r"] - second_r) < .01
        assert abs(second["anchor"]["c"] - second_c) < .01
        context = await ne.field_hit_context(
            path, 3101, first["token"], 2, NOW + 4)
        assert context["ok"]
        assert abs(context["anchor_r"] - second_r) < .01

        reload_state = await ne.state_for(path, 3101, NOW + 4)
        reloaded = next(item for item in reload_state["empires"]
                        if item["leader_id"] == "vera")["field_encounter"]
        assert reloaded["hp"] == start_hp - 31
        assert reloaded["max_hp"] == start_hp
        assert reloaded["position_authority"] == "server-route-v1"
        assert abs(reloaded["anchor"]["r"] - second_r) < .01

        world = (ROOT / "world.html").read_text(encoding="utf-8")
        bot = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")
        assert "actor_r:hitR,actor_c:hitC" in world
        assert "_npc_empire_field_route_witness(empire or {},r,c)" in bot
        assert "position_authority']='server-route-v1'" in bot
        assert "_hydrateNpcEmpireFieldEncounter(npc,empire)" in world
        assert "_empireDisplayHealth(npc,!!npc.dead)" in world
        assert "health=_empireDisplayHealth(x,death.dead)" in world
        assert "provoked=now<(+n._empirePlayerProvokedUntil||0)" in world
        assert "playerProvoked=playerBusinessRaid&&now<(+leader._empirePlayerProvokedUntil||0)" in world
        provoke = world.split("async function _recordNpcEmpireStreetAttack", 1)[1].split(
            "function _queueNpcEmpireBossHit", 1)[0]
        assert "_playerBusinessRaidBreaches" not in provoke
        assert "_markPlayerBusinessRaidBreached" not in provoke
        assert "ФАЗА ${alert.plan.phaseStep}" in world
        assert "?'ЗАХВАТЫВАЮТ':alert.plan?.exteriorPhase==='fight'?'БОЙ У ОБЪЕКТА':'ПРИБЛИЖАЮТСЯ'" in world
        assert "phase=String(activity?._displayPhase||'')" in world
        print("business capture boss P0: corridor, shared HP, reload, retaliation and phases OK")
    finally:
        try:
            os.unlink(path)
        except (FileNotFoundError, PermissionError):
            pass


if __name__ == "__main__":
    asyncio.run(run())
