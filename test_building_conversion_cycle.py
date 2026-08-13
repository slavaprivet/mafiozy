"""Server-authoritative conversion regression for generic buildings."""

import asyncio
import os
import sqlite3
import tempfile
from pathlib import Path

import aiosqlite

import npc_empire as ne


async def run() -> None:
    costs = [int(ne.BUILDING_OPERATIONS[key]["fitout_cost"]) for key in ne.BUILDING_OPERATIONS]
    assert costs == sorted(costs) and len(set(costs)) == 8
    assert ne.building_purchase_price(3500, "business", "beer_bar", 4) == 6000
    assert ne.building_purchase_price(3500, "business", "print_shop", 4) == 17000
    assert ne.building_purchase_price(3500, "hq", area=4) == 12500
    for profile in ne.PROFILES:
        for previous in ne.BUILDING_OPERATIONS:
            rebranded = ne.choose_captured_building_operation(
                profile, "1,1", previous, 2_000_000_000)
            assert rebranded in ne.BUILDING_OPERATIONS and rebranded != previous
    world = (Path(__file__).resolve().parent / "world.html").read_text(encoding="utf-8")
    three = (Path(__file__).resolve().parent / "three_preview.js").read_text(encoding="utf-8")
    preview = (Path(__file__).resolve().parent / "_preview_ws_server.py").read_text(encoding="utf-8")
    for operation, meta in ne.BUILDING_OPERATIONS.items():
        assert f"{operation}:{{name:" in world
        assert f"fitout:{int(meta['fitout_cost'])}" in world
    assert "openNpcAnnexBuildingChoice" in world
    assert "operation_type:operationType" in world
    assert "data-annex-building" in world and "operation_map:operationMap||{}" in world
    assert "loadNpcEmpireState(),loadApartmentState(),syncMyBusinesses()" in world
    assert "operationType:interiorData.apartment.operationType" in three
    assert "acquiredAt:interiorData.apartment.acquiredAt||0" in three
    assert "ПОД НОВЫМ УПРАВЛЕНИЕМ" in three
    assert "dataset.activeBuildingConversions" in three
    assert "conversionAge>=0&&conversionAge<12" in three
    assert "acquiredAt:+apartmentInfo.acquired_at" in world
    assert "delete renderer.domElement.dataset.convertedBuildingSkin" in three
    assert "dataset.convertedBuildingSkin" in three
    assert "disposeTransientObjectTree(child)" in three
    assert "npc_empire.building_purchase_price(" in preview

    handle, path = tempfile.mkstemp(prefix="building_conversion_", suffix=".db")
    os.close(handle)
    try:
        async with aiosqlite.connect(path) as db:
            await db.executescript("""
                CREATE TABLE characters(telegram_id INTEGER PRIMARY KEY, cash INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE business_property_owners(
                    biz_id TEXT PRIMARY KEY,owner_uid TEXT,owner_name TEXT,
                    acquired_at INTEGER,protected_until INTEGER);
                CREATE TABLE player_businesses(
                    telegram_id INTEGER,biz_id TEXT PRIMARY KEY,bought_at INTEGER,
                    last_collect INTEGER,status TEXT,blocked_until INTEGER,
                    last_event_at INTEGER,level INTEGER,guards INTEGER,pending_notice TEXT);
                CREATE TABLE apartments_owned(
                    telegram_id INTEGER,apt_key TEXT,price INTEGER,bought_at INTEGER,
                    property_kind TEXT,operation_type TEXT,area INTEGER,
                    income_per_minute INTEGER,last_income_at INTEGER,
                    PRIMARY KEY(telegram_id,apt_key));
                INSERT INTO characters VALUES(101,10000);
            """)
            await db.commit()
        await ne.ensure_schema(path)
        token = "conversion-win"
        oversized = await ne.resolve_assault(
            path, 101, token, "annex", "",
            {f"building-{index}": "beer_bar" for index in range(65)},
            now=2_000_000_098)
        assert not oversized["ok"] and oversized["error"] == "bad operation map"
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                "VALUES('building','1,1','leila',70,50,2000000000,'beer_bar',16)")
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                "VALUES('building','1,2','leila',175,50,2000000000,'print_shop',20)")
            await db.execute(
                "INSERT INTO npc_empire_assaults"
                "(token,telegram_id,leader_id,guard_hp_json,boss_hp,boss_max_hp,status,started_at,expires_at,last_hit_at) "
                "VALUES(?,101,'leila','[0]',0,300,'active',2000000000,2000010000,2000000000)",
                (token,))
            await db.commit()
        rejected = await ne.resolve_assault(
            path, 101, token, "annex", "", {"9,9": "beer_bar"},
            now=2_000_000_099)
        assert not rejected["ok"] and rejected["error"] == "unknown building"
        with sqlite3.connect(path) as db:
            assert db.execute("SELECT COUNT(*) FROM apartments_owned").fetchone()[0] == 0
            assert db.execute(
                "SELECT status FROM npc_empire_assaults WHERE token=?", (token,)
            ).fetchone()[0] == "active"
        result = await ne.resolve_assault(
            path, 101, token, "annex", "",
            {"1,1": "strip_club", "1,2": "chop_shop"}, now=2_000_000_100)
        assert result["ok"] and result["operation_map"] == {
            "1,1": "strip_club", "1,2": "chop_shop"}
        assert result["captured_buildings"] == [
            {"building_key": "1,1", "apt_key": "tile:16,16",
             "previous_operation_type": "beer_bar",
             "operation_type": "strip_club", "operation_name": "Стрип-клуб",
             "income_per_minute": ne.building_operation_income("strip_club", 16)},
            {"building_key": "1,2", "apt_key": "tile:16,26",
             "previous_operation_type": "print_shop",
             "operation_type": "chop_shop", "operation_name": "Авторазборка",
             "income_per_minute": ne.building_operation_income("chop_shop", 20)},
        ]
        with sqlite3.connect(path) as db:
            row = db.execute(
                "SELECT property_kind,operation_type,area,income_per_minute "
                "FROM apartments_owned WHERE telegram_id=101 AND apt_key='tile:16,16'").fetchone()
        assert row == ("business", "strip_club", 16,
                       ne.building_operation_income("strip_club", 16))
        duplicate = await ne.resolve_assault(
            path, 101, token, "annex", "print_shop", now=2_000_000_101)
        assert not duplicate["ok"] and duplicate["error"] == "not won"
        with sqlite3.connect(path) as db:
            assert db.execute(
                "SELECT COUNT(*) FROM apartments_owned WHERE telegram_id=101"
            ).fetchone()[0] == 2
        print("building conversion cycle: authoritative prices and annex conversion OK")
    finally:
        try:
            os.remove(path)
        except PermissionError:
            pass


if __name__ == "__main__":
    asyncio.run(run())
