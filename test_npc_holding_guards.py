"""Authoritative count and world behavior contract for captured-property guards."""

import asyncio
import os
import tempfile
from pathlib import Path

import aiosqlite

import npc_empire as ne


ROOT = Path(__file__).resolve().parent


async def run() -> None:
    rolls = {
        ne.holding_guard_count(profile.leader_id, "building", key, acquired)
        for profile in ne.PROFILES
        for key in list(ne.GENERIC_BUILDINGS)[:24]
        for acquired in range(2_000_000_000, 2_000_000_012)
    }
    assert rolls == {1, 2, 3}
    assert ne.holding_guard_count("viktor", "hq", "12,1", 1) == 0
    assert ne.holding_guard_count("viktor", "building", "4,4", 12345) == ne.holding_guard_count(
        "viktor", "building", "4,4", 12345
    )

    handle, path = tempfile.mkstemp(prefix="npc_holding_guards_", suffix=".db")
    os.close(handle)
    now = 2_000_300_000
    try:
        async with aiosqlite.connect(path) as db:
            await db.executescript("""
                CREATE TABLE characters(
                    telegram_id INTEGER PRIMARY KEY, cash INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE business_property_owners(
                    biz_id TEXT PRIMARY KEY,owner_uid INTEGER,owner_name TEXT,
                    acquired_at INTEGER,protected_until INTEGER);
                CREATE TABLE player_businesses(
                    telegram_id INTEGER,biz_id TEXT PRIMARY KEY,bought_at INTEGER,
                    last_collect INTEGER,status TEXT,blocked_until INTEGER,
                    last_event_at INTEGER,level INTEGER,guards INTEGER,
                    pending_notice TEXT);
            """)
            await db.commit()
        await ne.ensure_schema(path)
        async with aiosqlite.connect(path) as db:
            await db.execute("UPDATE npc_empires SET last_tick=?", (now,))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                "VALUES('building','4,4','viktor',100,50,?,'beer_bar',16)",
                (now,),
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at) "
                "VALUES('business','coffee','viktor',175,50,?)",
                (now + 1,),
            )
            await db.commit()

        state = await ne.state_for(path, 777, now=now)
        viktor = next(empire for empire in state["empires"] if empire["leader_id"] == "viktor")
        guarded = [holding for holding in viktor["holdings"] if holding["kind"] in {"building", "business"}]
        assert len(guarded) == 2
        assert all(1 <= holding["guard_count"] <= 3 for holding in guarded)
        hq = next(holding for holding in viktor["holdings"] if holding["kind"] == "hq")
        assert hq["guard_count"] == 0

        world = (ROOT / "world.html").read_text(encoding="utf-8")
        required = (
            "const EMPIRE_HOLDING_GUARDS=[]",
            "EMPIRE_VISIBLE_HOLDING_GUARD_CAP=18",
            "_syncEmpireHoldingGuards(now)",
            "role:'gang_guard'",
            "_empireHoldingGuard:true",
            "_nearestHostileEmpireLeader(guard)",
            "_empireRelationIsHostile",
            "target._empireHoldingGuard",
            "_empireEnemyLeaderId=sourceLeaderId",
            "now<(guard._empireTargetLockUntil||0)",
            "const occupiedSlots=new Set",
            "'empire_holding_guard'",
            "empireHoldingGuard:!!x._empireHoldingGuard",
            "guardCount:Math.max(0,Math.min(3,+holding.guard_count||0))",
            "previewholdingguards",
        )
        for marker in required:
            assert marker in world, marker
        print("npc holding guards: stable 1-3 count, family patrol and hostile retaliation bridge OK")
    finally:
        try:
            os.remove(path)
        except PermissionError:
            pass


if __name__ == "__main__":
    asyncio.run(run())
