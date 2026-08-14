"""Phase 2 field shots: rolling v1 and server-authoritative v2."""

import asyncio
import os
import tempfile
from unittest.mock import patch

import aiosqlite

os.environ.setdefault("BOT_TOKEN", "123456:npc-field-weapon-auth")

import mafiozi_bot as game
import npc_empire as ne
from test_npc_empire import _base_db


NOW = 2_003_000_000


async def run() -> None:
    handle, path = tempfile.mkstemp(prefix="npc_field_weapon_", suffix=".db")
    os.close(handle)
    try:
        await _base_db(path)
        await ne.ensure_schema(path)
        async with aiosqlite.connect(path) as db:
            assault_cols = {row[1] for row in await (await db.execute(
                "PRAGMA table_info(npc_empire_assaults)")).fetchall()}
            field_cols = {row[1] for row in await (await db.execute(
                "PRAGMA table_info(npc_empire_field_encounters)")).fetchall()}
            hit_pk = await (await db.execute(
                "PRAGMA table_info(npc_empire_field_hits)")).fetchall()
        assert "last_shot_seq" in assault_cols
        assert "shot_contract" in field_cols
        assert {row[1] for row in hit_pk if row[5]} == {"token", "shot_seq"}

        state = await ne.state_for(path, 901, NOW)
        vera = next(item for item in state["empires"]
                    if item["leader_id"] == "vera")
        activity = vera["activity"]
        r = float(activity.get("target_r", vera["hq_r"]))
        c = float(activity.get("target_c", vera["hq_c"]))
        prepared = await ne.prepare_field_encounter(
            path, 901, "vera", r, c, NOW + 1, server_activity=activity)
        assert prepared["shot_contract"] == 2
        assert prepared["next_shot_seq"] == 1
        token = prepared["token"]

        untrusted = await ne.assault_hit(
            path, 901, token, "boss", None, 35, NOW + 2)
        assert not untrusted["ok"] and untrusted["error"] == "authorized shot required"

        context = await ne.field_hit_context(path, 901, token, 1, NOW + 2)
        assert context["ok"] and not context["duplicate"]
        first = await ne.assault_field_hit_authorized(
            path, 901, token, 1, "pistol", 24, NOW + 2)
        replay = await ne.assault_field_hit_authorized(
            path, 901, token, 1, "pistol", 999, NOW + 2.1)
        assert first["ok"] and replay["ok"] and replay["duplicate"]
        assert replay["boss_hp"] == first["boss_hp"]
        assert replay["damage"] == 24

        same_seq = await asyncio.gather(
            ne.assault_field_hit_authorized(
                path, 901, token, 2, "pistol", 24, NOW + 3),
            ne.assault_field_hit_authorized(
                path, 901, token, 2, "pistol", 24, NOW + 3),
        )
        assert all(item["ok"] for item in same_seq)
        assert sum(bool(item["duplicate"]) for item in same_seq) == 1
        assert {item["boss_hp"] for item in same_seq} == {first["boss_hp"] - 24}
        gap = await ne.assault_field_hit_authorized(
            path, 901, token, 4, "pistol", 24, NOW + 4)
        assert not gap["ok"] and gap["error"] == "bad shot sequence"

        # Existing contract-1 generations keep draining through the legacy
        # HTTP/body shape during a rolling deployment.
        alisa = next(item for item in state["empires"]
                     if item["leader_id"] == "alisa")
        old = await ne.prepare_field_encounter(
            path, 902, "alisa", float(alisa["activity"].get("target_r", alisa["hq_r"])),
            float(alisa["activity"].get("target_c", alisa["hq_c"])), NOW + 1,
            server_activity=alisa["activity"])
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empire_field_encounters SET shot_contract=1 "
                "WHERE encounter_id=?", (old["encounter_id"],))
            await db.commit()
        legacy = await ne.assault_hit(
            path, 902, old["token"], "boss", None, 17, NOW + 2)
        assert legacy["ok"] and legacy["boss_hp"] == old["boss"]["hp"] - 17

        world = game.WorldSim()
        world.add_or_update("901", "Shooter", {})
        live = world.players["901"]
        live.update(x=c, y=r + 1, dead=False, last_seen=float(NOW),
                    _in_interior=False, _weapon_classes={"pistol", "sniper"})
        geometry_context = {"anchor_r": r, "anchor_c": c}
        with patch.object(game, "_world_los", return_value=True):
            geometry = game._npc_empire_field_shot_geometry(
                world, 901, geometry_context, "pistol", r, c, NOW)
        assert geometry["ok"] and geometry["distance"] == 1
        with patch.object(game, "_world_los", return_value=False):
            blocked = game._npc_empire_field_shot_geometry(
                world, 901, geometry_context, "pistol", r, c, NOW)
        assert blocked["error"] == "blocked shot"
        far = game._npc_empire_field_shot_geometry(
            world, 901, geometry_context, "pistol", r, c + 9, NOW)
        assert far["error"] == "out of range"
        live.update(x=c + 11, y=r)
        anchor_spoof = game._npc_empire_field_shot_geometry(
            world, 901, geometry_context, "sniper", r, c + 11, NOW)
        assert anchor_spoof["error"] == "bad hit position"

        live.update(x=c, y=r + 1, last_seen=float(NOW), _weapon_shot_t=0.0)
        with patch.object(game.time, "time", return_value=float(NOW)), \
                patch.object(game.random, "random", return_value=1.0):
            profile = world._authorize_weapon_shot(live, "pistol")
            assert profile is not None
            assert world._weapon_damage("pistol", 1.0, profile) == 24
            assert world._authorize_weapon_shot(live, "pistol") is None

        source = open("mafiozi_bot.py", encoding="utf-8").read()
        handler = source.split("async def h_npc_empire_assault_hit(req):", 1)[1].split(
            "async def h_npc_empire_assault_resolve(req):", 1)[0]
        for contract in ("field_hit_context", "_npc_empire_field_shot_geometry",
                         "_authorize_weapon_shot", "_weapon_damage",
                         "assault_field_hit_authorized"):
            assert contract in handler
        assert "body.get('damage')" in handler  # legacy branch only
        assert handler.index("if 'shot_seq' not in body") < handler.index("body.get('damage')")
        print("npc field weapon auth: rolling schema, idempotence, geometry and cadence OK")
    finally:
        try:
            os.unlink(path)
        except (FileNotFoundError, PermissionError):
            pass


if __name__ == "__main__":
    asyncio.run(run())
