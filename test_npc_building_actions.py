"""Server-authoritative sale and sabotage contracts for NPC buildings."""

import asyncio
import os
import sqlite3
import tempfile

import aiosqlite

import npc_empire as ne


async def _make_db(path: str) -> None:
    async with aiosqlite.connect(path) as db:
        await db.executescript("""
        CREATE TABLE characters(telegram_id INTEGER PRIMARY KEY,cash INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE business_property_owners(biz_id TEXT PRIMARY KEY,owner_uid TEXT,owner_name TEXT,acquired_at INTEGER,protected_until INTEGER);
        CREATE TABLE player_businesses(telegram_id INTEGER,biz_id TEXT PRIMARY KEY,bought_at INTEGER,last_collect INTEGER,status TEXT,blocked_until INTEGER,last_event_at INTEGER,level INTEGER,guards INTEGER,pending_notice TEXT);
        CREATE TABLE apartments_owned(telegram_id INTEGER,apt_key TEXT,price INTEGER,bought_at INTEGER,property_kind TEXT,operation_type TEXT,area INTEGER,income_per_minute INTEGER,last_income_at INTEGER,PRIMARY KEY(telegram_id,apt_key));
        CREATE TABLE inventory(id INTEGER PRIMARY KEY AUTOINCREMENT,telegram_id INTEGER,item_id TEXT,quantity INTEGER DEFAULT 1);
        INSERT INTO characters VALUES(101,1000000),(202,1000000);
        """)
        await db.commit()
    await ne.ensure_schema(path)


async def _seed(path: str, key: str, leader: str = "leila", relation: int = 0) -> None:
    area = ne.BUILDING_AREAS[key]
    async with aiosqlite.connect(path) as db:
        await db.execute("INSERT OR REPLACE INTO npc_empire_holdings(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) VALUES('building',?,?,?,?,?,?,?)", (key, leader, ne.building_operation_income('beer_bar', area), 50, 2_000_000_000, 'beer_bar', area))
        await db.execute("INSERT OR REPLACE INTO npc_empire_relations(leader_id,telegram_id,score,pact,last_action_at) VALUES(?,?,?,?,?)", (leader, 101, relation, 'none', 0))
        await db.commit()


async def run() -> None:
    assert ne.npc_building_sale_chance(-1) == 0
    assert ne.npc_building_sale_chance(0) == 50
    assert ne.npc_building_sale_chance(1) == 70
    assert ne.npc_building_sale_chance(40) == 80
    assert ne.npc_building_sale_chance(70) == 90
    handle, path = tempfile.mkstemp(prefix='npc_building_action_', suffix='.db');os.close(handle)
    now = 2_000_000_000
    try:
        await _make_db(path)
        first, second, third = list(ne.BUILDING_AREAS)[:3]
        await _seed(path, first)
        refused = await ne.npc_building_action(path, 101, 'leila', first, 'purchase', now=now, roll=51)
        assert refused['ok'] and not refused['sold'] and refused['sale_chance'] == 50
        async with aiosqlite.connect(path) as db:
            assert (await (await db.execute('SELECT cash FROM characters WHERE telegram_id=101')).fetchone())[0] == 1_000_000
        sold = await ne.npc_building_action(path, 101, 'leila', first, 'purchase', now=now, roll=50)
        assert sold['sold'] and sold['cash'] == 1_000_000 - sold['price']
        async with aiosqlite.connect(path) as db:
            db.row_factory = sqlite3.Row
            own = await (await db.execute('SELECT * FROM apartments_owned WHERE telegram_id=101 AND apt_key=?', (first,))).fetchone()
            assert own and own['property_kind'] == 'business' and own['operation_type'] == 'beer_bar'
            assert not await (await db.execute("SELECT 1 FROM npc_empire_holdings WHERE kind='building' AND holding_id=?", (first,))).fetchone()

        await _seed(path, second, relation=-4)
        negative = await ne.npc_building_action(path, 101, 'leila', second, 'purchase', now=now, roll=1)
        assert negative['ok'] and not negative['sold'] and negative['sale_chance'] == 0

        await _seed(path, third, relation=10)
        missing_c4 = await ne.npc_building_action(
            path, 101, 'leila', third, 'sabotage', now=now,
            request_key='c4-missing-0001')
        assert not missing_c4['ok'] and missing_c4['error'] == 'no c4'
        async with aiosqlite.connect(path) as db:
            await db.execute("INSERT INTO inventory(telegram_id,item_id,quantity) VALUES(101,'c4',2)")
            await db.commit()
        sabotaged = await ne.npc_building_action(
            path, 101, 'leila', third, 'sabotage', now=now,
            request_key='c4-success-0001')
        assert sabotaged['sabotaged'] and sabotaged['closed_until'] == now + 303
        assert sabotaged['armed'] and sabotaged['detonate_at'] == now + 3
        assert sabotaged['fuse_s'] == 3 and sabotaged['c4_left'] == 1
        assert -30 <= sabotaged['relation_delta'] <= -20
        async with aiosqlite.connect(path) as db:
            assert (await (await db.execute("SELECT quantity FROM inventory WHERE telegram_id=101 AND item_id='c4'")).fetchone())[0] == 1
        locked = await ne.npc_building_action(path, 101, 'leila', third, 'purchase', now=now + 1, roll=1)
        assert not locked['ok'] and locked['error'] == 'armed'
        state = await ne.state_for(path, 101, now=now + 2)
        holding = next(h for e in state['empires'] if e['leader_id'] == 'leila' for h in e['holdings'] if h.get('holding_id') == third)
        assert holding['building_status'] == 'armed' and holding['fuse_s'] == 1
        assert holding['closed_s'] == 300 and holding['sabotage_action_id'] == 'c4-success-0001'
        detonated = await ne.state_for(path, 101, now=now + 3)
        holding = next(h for e in detonated['empires'] if e['leader_id'] == 'leila' for h in e['holdings'] if h.get('holding_id') == third)
        assert holding['building_status'] == 'closed' and holding['closed_s'] == 300
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
