"""End-to-end NPC building capture, revenue and visual-skin contract."""

import asyncio
import os
import sqlite3
import tempfile
from pathlib import Path

import aiosqlite

import npc_empire as ne


ROOT = Path(__file__).resolve().parent


async def run() -> None:
    operation_ids = set(ne.BUILDING_OPERATIONS)
    assert len(operation_ids) == 8

    # Every boss rolls against the complete eight-operation table.  The roll is
    # deterministic for one capture nonce, but repeated captures cover all skins.
    for profile in ne.PROFILES:
        rolled = {
            ne.choose_building_operation(profile, "4,4", nonce)
            for nonce in range(512)
        }
        assert rolled == operation_ids, (profile.leader_id, rolled)
    for previous in operation_ids:
        rerolls = {
            ne.choose_captured_building_operation(
                ne.PROFILE_BY_ID["viktor"], "4,4", previous, nonce
            )
            for nonce in range(512)
        }
        assert previous not in rerolls and rerolls == operation_ids - {previous}

    # $/minute generic buildings and legacy landmark businesses use their own
    # economy scales.  One five-minute tick pays the full advertised amount.
    holdings = [
        {"kind": "building", "income": 70},
        {"kind": "building", "income": 175},
        {"kind": "business", "income": 2880},
    ]
    assert ne.empire_holding_income_per_tick(holdings) == (70 + 175) * 5 + 10

    handle, path = tempfile.mkstemp(prefix="boss_capture_cycle_", suffix=".db")
    os.close(handle)
    start = 2_000_100_000
    initial_members = 20
    initial_active_wars = 1
    initial_guard_slots = 0
    rich_cash = 2 * ne.operating_reserve(
        initial_members, initial_guard_slots, initial_active_wars
    )
    rich_budget = ne.boss_budget_state(
        treasury=rich_cash,
        members=initial_members,
        guard_slots=initial_guard_slots,
        active_wars=initial_active_wars,
    )
    assert rich_budget["band"] == "rich"
    assert rich_budget["allows"]["aggressive_spend"] is True
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
            # Isolate one overwhelming aggressor and one target. Other families
            # stay ruined beyond the test window and cannot mutate the scenario.
            await db.execute(
                "UPDATE npc_empires SET status='ruined',comeback_at=?,last_tick=?",
                (start + 100_000, start),
            )
            await db.execute(
                "UPDATE npc_empires SET status='active',comeback_at=0,treasury=?,"
                "members=?,strength=10000,last_tick=? WHERE leader_id='viktor'",
                (rich_cash, initial_members, start),
            )
            await db.execute(
                "UPDATE npc_empires SET status='active',comeback_at=0,treasury=0,"
                "members=1,strength=20,last_tick=? WHERE leader_id='rustam'",
                (start,),
            )
            await db.execute(
                "DELETE FROM npc_empire_holdings WHERE kind<>'hq' OR leader_id NOT IN ('viktor','rustam')"
            )
            old_operation = "beer_bar"
            old_income = ne.building_operation_income(old_operation, 16)
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                "VALUES('building','4,4','rustam',?,1,?,?,16)",
                (old_income, start, old_operation),
            )
            left, right = sorted(("viktor", "rustam"))
            await db.execute(
                "UPDATE npc_empire_diplomacy SET score=-100,pact='war',tension=100,last_event_at=? "
                "WHERE leader_a=? AND leader_b=?", (start, left, right),
            )
            await db.commit()

        with sqlite3.connect(path) as db:
            eligible_targets = db.execute(
                "SELECT kind,holding_id,leader_id FROM npc_empire_holdings "
                "WHERE leader_id='rustam' AND kind IN ('building','business') "
                "ORDER BY kind,holding_id"
            ).fetchall()
            owner_before, operation_before, acquired_before = db.execute(
                "SELECT leader_id,operation_type,acquired_at "
                "FROM npc_empire_holdings WHERE kind='building' AND holding_id='4,4'"
            ).fetchone()
            wins_before = db.execute(
                "SELECT wins FROM npc_empires WHERE leader_id='viktor'"
            ).fetchone()[0]
        assert "4,4" in ne.GENERIC_BUILDINGS
        assert eligible_targets == [("building", "4,4", "rustam")]
        assert (owner_before, operation_before, acquired_before, wins_before) == (
            "rustam", old_operation, start, 0
        )

        captured_at = start + ne.TICK_SECONDS
        capture_events = await ne.advance(path, now=captured_at)

        with sqlite3.connect(path) as db:
            row = db.execute(
                "SELECT leader_id,operation_type,area,income,acquired_at "
                "FROM npc_empire_holdings WHERE kind='building' AND holding_id='4,4'"
            ).fetchone()
            wins_after = db.execute(
                "SELECT wins FROM npc_empires WHERE leader_id='viktor'"
            ).fetchone()[0]
        owner, operation, area, income, acquired_at = row
        expected_operation = ne.choose_captured_building_operation(
            ne.PROFILE_BY_ID["viktor"], "4,4", old_operation,
            captured_at + wins_before,
        )
        assert owner == "viktor" and operation == expected_operation
        assert operation in operation_ids and operation != old_operation
        assert area == 16 and income == ne.building_operation_income(operation, area)
        assert acquired_at == captured_at
        assert wins_after == wins_before + 1
        assert any(
            event.get("leader_id") == "viktor"
            and event.get("kind") == "war_won"
            and event.get("target_id") == "rustam"
            and event.get("operation_type") == operation
            for event in capture_events
        )

        # The next tick deposits the converted building's exact per-minute
        # revenue into the boss treasury (plus base economy, minus upkeep).
        with sqlite3.connect(path) as db:
            treasury_before, members_before = db.execute(
                "SELECT treasury,members FROM npc_empires WHERE leader_id='viktor'"
            ).fetchone()
            holding_rows = db.execute(
                "SELECT kind,holding_id,income FROM npc_empire_holdings "
                "WHERE leader_id='viktor' ORDER BY kind,holding_id"
            ).fetchall()
            guard_rows = db.execute(
                "SELECT holding_ref,assigned,living "
                "FROM npc_empire_guard_assignments "
                "WHERE owner_kind='npc' AND owner_id='viktor' "
                "ORDER BY holding_ref"
            ).fetchall()
            guard_slots = sum(int(row[2] or 0) for row in guard_rows)
            active_wars = db.execute(
                "SELECT COUNT(*) FROM npc_empire_diplomacy "
                "WHERE (leader_a='viktor' OR leader_b='viktor') AND pact='war'"
            ).fetchone()[0]
            active_wars += db.execute(
                "SELECT COUNT(*) FROM npc_empire_player_wars WHERE leader_id='viktor'"
            ).fetchone()[0]
        authoritative_holdings = [
            {"kind": kind, "holding_id": holding_id, "income": holding_income}
            for kind, holding_id, holding_income in holding_rows
        ]
        expected_gross = ne.empire_holding_income_per_tick(authoritative_holdings)
        expected_upkeep = (
            max(4, members_before * ne.NPC_MEMBER_UPKEEP_PER_TICK)
            + guard_slots * ne.NPC_HOLDING_GUARD_UPKEEP_PER_TICK
            + active_wars * ne.NPC_ACTIVE_WAR_UPKEEP_PER_TICK
        )
        expected_net = expected_gross - expected_upkeep
        assert guard_rows == [("building:4,4", 3, 3)]
        assert active_wars == 0
        assert expected_gross == income * 5 + ne.NPC_HQ_FRONT_INCOME_PER_MINUTE * 5
        assert expected_upkeep == 75 and expected_net == 760
        capture_state = await ne.state_for(path, 101, now=captured_at)
        capture_viktor = next(
            item for item in capture_state["empires"]
            if item["leader_id"] == "viktor"
        )
        assert capture_viktor["budget"]["band"] == "rich"
        assert capture_viktor["budget"]["allows"]["aggressive_spend"] is True
        assert "treasury" not in capture_viktor and "economy" not in capture_viktor
        next_tick = captured_at + ne.TICK_SECONDS
        await ne.advance(path, now=next_tick)
        with sqlite3.connect(path) as db:
            treasury_after = db.execute(
                "SELECT treasury FROM npc_empires WHERE leader_id='viktor'"
            ).fetchone()[0]
        # Economy A keeps cash private, so derive the exact authoritative net
        # from persisted holdings/guards/wars and the shared production constants.
        assert treasury_after - treasury_before == expected_net, (
            treasury_before, treasury_after, expected_gross, expected_upkeep,
            expected_net, operation, income
        )

        state = await ne.state_for(path, 101, now=next_tick)
        viktor = next(item for item in state["empires"] if item["leader_id"] == "viktor")
        holding = next(item for item in viktor["holdings"] if item["holding_id"] == "4,4")
        assert holding["operation_type"] == operation
        assert holding["operation_name"] == ne.BUILDING_OPERATIONS[operation]["name"]
        assert holding["operation_icon"] == ne.BUILDING_OPERATIONS[operation]["icon"]
        assert holding["income"] == income and holding["income_unit"] == "minute"

        world = (ROOT / "world.html").read_text(encoding="utf-8")
        three = (ROOT / "three_preview.js").read_text(encoding="utf-8")
        for operation_id in operation_ids:
            assert f"op==='{operation_id}'" in world
            assert operation_id in three
        assert "operationType:String(holding.operation_type||'')" in world
        assert "acquiredAt:+holding.acquired_at||0" in world
        assert "src.operationType||''" in three
        assert "interiorData.apartment.operationType||''" in three
        assert "delete renderer.domElement.dataset.convertedBuildingSkin" in three
        print(
            "boss building capture: owner, 8-way reroll, exact revenue, "
            "exterior and interior skin bridge OK"
        )
    finally:
        try:
            os.remove(path)
        except PermissionError:
            pass


if __name__ == "__main__":
    asyncio.run(run())
