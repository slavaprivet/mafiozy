"""Monotonic server checkpoint for irreversible interior-raid casualties."""

import asyncio
import os
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


async def run() -> None:
    fd, path = tempfile.mkstemp(prefix="raid_casualty_checkpoint_", suffix=".db")
    os.close(fd)
    now = 2_200_000_000
    try:
        await _base_db(path)
        async with aiosqlite.connect(path) as db:
            # npc_empire.ensure_schema owns the empire tables; gang_members is
            # supplied by mafiozi_bot.init_db in production.  Model that exact
            # table and concrete defenders so final casualty writes are real.
            await db.execute("""
                CREATE TABLE gang_members (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    telegram_id INTEGER,
                    member_name TEXT,
                    role TEXT,
                    role_display TEXT,
                    last_collected INTEGER DEFAULT 0,
                    current_hp INTEGER DEFAULT NULL
                )
            """)
            await db.executemany(
                "INSERT INTO gang_members"
                "(id,telegram_id,member_name,role,role_display,last_collected,current_hp) "
                "VALUES(?,?,?,?,?,?,?)",
                ((11, 101, "Defender 11", "fighter", "Боец", 0, 100),
                 (12, 101, "Defender 12", "fighter", "Боец", 0, 100)),
            )
            columns = {row[1] for row in await (await db.execute(
                "PRAGMA table_info(npc_empire_interior_raids)"
            )).fetchall()}
            assert {"attacker_down_json", "defender_down_json", "guard_down_json",
                    "casualty_version"} <= columns
            await db.execute(
                "INSERT INTO npc_empire_interior_raids"
                "(token,telegram_id,leader_id,apt_key,target_ref,target_kind,holding_id,"
                "operation_type,business_label,force,attacker_cost,tier,quality,hp,accuracy,"
                "weapon_budget,defender_ids_json,guard_ids_json,guard_count,attack_no,"
                "started_at,hold_seconds,expires_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                ("casualty-token", 101, "leila", "business:coffee", "business:coffee",
                 "business", "coffee", "", "Coffee", 4, 400, 2, 50, 90, .65,
                 300, "[11,12]", "[21]", 3, 0, now, 20, now + 600))
            await db.commit()

        first = await ne.checkpoint_interior_raid_casualties(
            path, 101, "casualty-token", "business:coffee", attacker_delta=[0])
        assert first["ok"] and first["version"] == 1 and not first["duplicate"]
        second = await ne.checkpoint_interior_raid_casualties(
            path, 101, "casualty-token", "business:coffee",
            attacker_delta=[0, 2], defender_delta=[11])
        assert second["attacker_down_slots"] == [0, 2]
        assert second["defender_down_ids"] == [11] and second["version"] == 2
        subset = await ne.checkpoint_interior_raid_casualties(
            path, 101, "casualty-token", "business:coffee", attacker_delta=[2])
        assert subset["duplicate"] and subset["version"] == 2

        concurrent = await asyncio.gather(
            ne.checkpoint_interior_raid_casualties(
                path, 101, "casualty-token", "business:coffee", attacker_delta=[1]),
            ne.checkpoint_interior_raid_casualties(
                path, 101, "casualty-token", "business:coffee",
                attacker_delta=[3], defender_delta=[12], guard_delta=[21]),
        )
        assert all(item["ok"] for item in concurrent)
        final = max(concurrent, key=lambda item: item["version"])
        assert final["attacker_down_slots"] == [0, 1, 2, 3]
        assert final["defender_down_ids"] == [11, 12]
        assert final["guard_down_ids"] == [21] and final["version"] == 4

        for kwargs in (
            {"telegram_id": 999, "apt_key": "business:coffee", "attacker_delta": [0]},
            {"telegram_id": 101, "apt_key": "wrong", "attacker_delta": [0]},
            {"telegram_id": 101, "apt_key": "business:coffee", "attacker_delta": [99]},
            {"telegram_id": 101, "apt_key": "business:coffee", "defender_delta": [99]},
        ):
            bad = await ne.checkpoint_interior_raid_casualties(
                path, kwargs.pop("telegram_id"), "casualty-token", kwargs.pop("apt_key"),
                **kwargs)
            assert not bad["ok"]

        state = await ne.state_for(path, 101, now=now + 5)
        raid = next(item for item in state["interior_raids"]
                    if item["token"] == "casualty-token")
        assert raid["casualties"] == {
            "attacker_slots": [0, 1, 2, 3], "defender_ids": [11, 12],
            "guard_ids": [21], "version": 4,
        }
        assert all(row["dead"] and row["hp"] == 0 for row in raid["attacker_roster"])
        assert all(row["dead"] and row["hp"] == 0 for row in raid["defender_roster"])
        assert raid["guard_roster"][0]["dead"] and raid["guard_roster"][0]["hp"] == 0

        # An empty final payload cannot shrink persisted deaths; effective union
        # permits the authoritative defended outcome immediately.
        resolved = await ne.resolve_interior_raid(
            path, 101, "casualty-token", "business:coffee", "defended", now=now + 6,
            attacker_casualties=[], defender_casualties=[], guard_casualties=[])
        assert resolved["ok"] and resolved["attacker_losses"] == 4
        assert resolved["defender_losses"] == 2
        async with aiosqlite.connect(path) as db:
            defender_hp = await (await db.execute(
                "SELECT id,current_hp FROM gang_members WHERE telegram_id=101 "
                "ORDER BY id"
            )).fetchall()
        assert defender_hp == [(11, 0), (12, 0)]
        terminal = await ne.checkpoint_interior_raid_casualties(
            path, 101, "casualty-token", "business:coffee", attacker_delta=[0])
        assert terminal["ok"] and terminal["duplicate"] and terminal["terminal"]
        assert terminal["version"] == 4
    finally:
        os.unlink(path)


if __name__ == "__main__":
    asyncio.run(run())
    print("npc interior casualty checkpoint: schema, union, concurrency, snapshot and resolve OK")
