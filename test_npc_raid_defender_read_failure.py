"""Interior raid creation fails closed when concrete defenders cannot be read."""

import asyncio
import os
import tempfile
from pathlib import Path

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


ROOT = Path(__file__).resolve().parent


async def scalar(path: str, sql: str):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql)).fetchone()
        return row[0]


async def run() -> None:
    world = (ROOT / 'world.html').read_text(encoding='utf-8')
    assert 'Если сервер не может подтвердить состав защитников, штурм не начинается.' in world

    fd, path = tempfile.mkstemp(prefix='raid_defender_read_failure_', suffix='.db')
    os.close(fd)
    try:
        await _base_db(path)
        now = 2_700_000_000
        async with aiosqlite.connect(path) as db:
            await db.executescript("""
                CREATE TABLE gang_members(
                    id INTEGER PRIMARY KEY,telegram_id INTEGER,current_hp INTEGER);
                INSERT INTO gang_members VALUES(1,101,100);
                INSERT INTO player_businesses
                    VALUES(101,'coffee',0,0,'ok',0,0,1,0,NULL);
                INSERT INTO business_property_owners
                    VALUES('coffee',101,'Test',2700000000,0);
                DROP TABLE npc_empire_player_guard_members;
                CREATE TABLE npc_empire_player_guard_members(
                    member_id INTEGER PRIMARY KEY);
            """)
            await db.execute(
                "UPDATE npc_empires SET status='active',members=12,strength=360,treasury=50000 "
                "WHERE leader_id='leila'")
            await db.commit()

        treasury_before = await scalar(
            path, "SELECT treasury FROM npc_empires WHERE leader_id='leila'")
        target = {
            'ref': 'business:coffee', 'kind': 'business',
            'holding_id': 'coffee', 'apt_key': 'business:coffee',
            'operation_type': '',
        }
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            await db.execute('BEGIN IMMEDIATE')
            try:
                await ne._create_interior_raid(db, 101, 'leila', target, 0, now)
                raise AssertionError('corrupt defender schema must abort raid creation')
            except aiosqlite.Error:
                await db.rollback()

        assert await scalar(path,
            "SELECT COUNT(*) FROM npc_empire_interior_raids") == 0
        assert await scalar(path,
            "SELECT treasury FROM npc_empires WHERE leader_id='leila'") == treasury_before
        print('raid defender read failure: no unguarded token and no treasury debit OK')
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
