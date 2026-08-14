"""Reject expired and physically impossible interior-raid outcomes atomically."""

import asyncio
import json
import os
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


NOW = 2_600_000_000
PLAYER = 808


async def insert_raid(path: str, token: str, leader: str, *, expired: bool = False) -> None:
    async with aiosqlite.connect(path) as db:
        await db.execute(
            "INSERT INTO npc_empire_interior_raids"
            "(token,telegram_id,leader_id,apt_key,target_ref,target_kind,holding_id,"
            "operation_type,business_label,force,attacker_cost,tier,quality,hp,accuracy,"
            "weapon_budget,defender_ids_json,guard_ids_json,guard_count,attack_no,"
            "started_at,hold_seconds,expires_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (token, PLAYER, leader, f"apt:{token}", f"building:{token}", "building",
             token, "beer_bar", token, 2, 100, 1, 1, 80, .6, 100,
             json.dumps([11]), "[]", 1, 0, NOW, 20,
             NOW + (10 if expired else 720)),
        )
        await db.commit()


async def status(path: str, token: str):
    async with aiosqlite.connect(path) as db:
        return await (await db.execute(
            "SELECT status,resolution,resolved_at FROM npc_empire_interior_raids WHERE token=?",
            (token,))).fetchone()


async def run() -> None:
    fd, path = tempfile.mkstemp(prefix="raid_resolve_hardening_", suffix=".db")
    os.close(fd)
    try:
        await _base_db(path)
        await insert_raid(path, "expired", "leila", expired=True)
        await insert_raid(path, "partial-defence", "rustam")
        await insert_raid(path, "dead-captors", "marco")
        await insert_raid(path, "living-defender", "vera")

        expired = await ne.resolve_interior_raid(
            path, PLAYER, "expired", "apt:expired", "defended",
            attacker_casualties=[0, 1], defender_casualties=[11],
            guard_casualties=[], now=NOW + 10)
        assert expired == {"ok": False, "error": "raid expired"}
        assert tuple(await status(path, "expired")) == ("resolved", "expired", NOW + 10)

        partial = await ne.resolve_interior_raid(
            path, PLAYER, "partial-defence", "apt:partial-defence", "defended",
            attacker_casualties=[0], defender_casualties=[], guard_casualties=[],
            now=NOW + ne.PLAYER_INTERIOR_RAID_MIN_SECONDS)
        assert partial == {"ok": False, "error": "impossible defended outcome"}
        assert tuple(await status(path, "partial-defence")) == ("pending", "", 0)

        dead_captors = await ne.resolve_interior_raid(
            path, PLAYER, "dead-captors", "apt:dead-captors", "captured",
            attacker_casualties=[0, 1], defender_casualties=[11],
            guard_casualties=[], now=NOW + 20)
        assert dead_captors == {"ok": False, "error": "impossible captured outcome"}
        assert tuple(await status(path, "dead-captors")) == ("pending", "", 0)

        living_defender = await ne.resolve_interior_raid(
            path, PLAYER, "living-defender", "apt:living-defender", "captured",
            attacker_casualties=[0], defender_casualties=[], guard_casualties=[],
            now=NOW + 20)
        assert living_defender == {"ok": False, "error": "impossible captured outcome"}
        assert tuple(await status(path, "living-defender")) == ("pending", "", 0)
    finally:
        os.unlink(path)


if __name__ == "__main__":
    asyncio.run(run())
    print("npc empire resolve hardening: OK")
