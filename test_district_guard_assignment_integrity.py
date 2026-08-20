"""District guards are living, owner-scoped and exclusive with property guards."""

import asyncio
import os
import tempfile
from pathlib import Path

import aiosqlite

import mafiozi_bot as bot
import npc_empire as ne
from test_npc_empire import _base_db


async def scalar(path: str, sql: str, args=()):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql, args)).fetchone()
        return row[0] if row else None


async def run() -> None:
    handle, path = tempfile.mkstemp(prefix='district_guard_integrity_', suffix='.db')
    os.close(handle)
    original = bot.DB_PATH
    try:
        await _base_db(path)
        async with aiosqlite.connect(path) as db:
            await db.executescript("""
                CREATE TABLE gang_members(
                    id INTEGER PRIMARY KEY,telegram_id INTEGER,current_hp INTEGER);
                CREATE TABLE district_control(
                    location_id TEXT PRIMARY KEY,telegram_id INTEGER,guard_json TEXT);
                CREATE TABLE apartments_owned(
                    telegram_id INTEGER,apt_key TEXT PRIMARY KEY,price INTEGER,bought_at INTEGER,
                    property_kind TEXT,operation_type TEXT,area INTEGER,income_per_minute INTEGER,
                    last_income_at INTEGER DEFAULT 0);
                INSERT INTO gang_members VALUES(1,101,100);
                INSERT INTO gang_members VALUES(2,101,100);
                INSERT INTO gang_members VALUES(20,202,100);
                INSERT INTO district_control VALUES('north',101,'[]');
                INSERT INTO district_control VALUES('south',202,'[20]');
                INSERT INTO apartments_owned VALUES(
                    101,'tile:6,36',10000,1,'business','pawnshop',16,120,1);
            """)
            await db.commit()
        await ne.ensure_schema(path)
        assert (await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref='building:0,3',
            requested=1, now=2_900_000_000))['ok']
        bot.DB_PATH = path

        shared = await bot.update_district_guard(101, 'north', [1])
        assert shared == {'ok': False, 'error': 'guard already assigned'}
        assert await scalar(path,
            "SELECT guard_json FROM district_control WHERE location_id='north'") == '[]'

        dead = await bot.update_district_guard(101, 'north', [999])
        assert dead == {'ok': False, 'error': 'guard unavailable'}
        wrong_owner = await bot.update_district_guard(101, 'south', [2])
        assert wrong_owner == {'ok': False, 'error': 'district not owned'}
        assert await scalar(path,
            "SELECT guard_json FROM district_control WHERE location_id='south'") == '[20]'

        exact = await bot.update_district_guard(101, 'north', [2, 2])
        assert exact == {'ok': True, 'guard_ids': [2]}
        assert await scalar(path,
            "SELECT guard_json FROM district_control WHERE location_id='north'") == '[2]'
        assert await scalar(path,
            "SELECT COUNT(*) FROM npc_empire_player_guard_members WHERE member_id=1") == 1

        world = Path(__file__).with_name('world.html').read_text(encoding='utf-8')
        assert 'Один боец не может одновременно охранять район и бизнес.' in world
        print('district guard integrity: living/exclusive/owner-scoped transaction OK')
    finally:
        bot.DB_PATH = original
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
