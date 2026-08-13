"""Regression coverage for exact-building purchases and readable failures."""

import asyncio
import os
import sqlite3
import tempfile
from pathlib import Path

import mafiozi_bot as bot


async def run():
    handle, path = tempfile.mkstemp(prefix="purchase_reasons_", suffix=".db")
    os.close(handle)
    original = bot.DB_PATH
    bot.DB_PATH = path
    try:
        await bot.ensure_apartment_tables()
        with sqlite3.connect(path) as db:
            db.executescript("""
                CREATE TABLE characters(telegram_id INTEGER PRIMARY KEY,cash INTEGER,mafia_family TEXT,name TEXT);
                CREATE TABLE custom_gang_members(gang_id INTEGER,telegram_id INTEGER,role TEXT,joined_at INTEGER,invited_by INTEGER);
                CREATE TABLE npc_empire_holdings(kind TEXT,holding_id TEXT,leader_id TEXT);
                INSERT INTO characters VALUES(1,100000,'moretti','Вячеслав');
                INSERT INTO characters VALUES(2,100000,'bellini','Сосед');
            """)

        # This exact industrial building was visible and offered for $7000,
        # but its legacy block 4,5 is absent from BUILDING_AREAS.
        first = await bot.buy_apartment_db(1, 'tile:46,56', 7000, 'business', 'pawnshop')
        assert first['ok'], first

        # A different roof tile of the same physical/block-level property must
        # not let a second player buy the shell again.
        second = await bot.buy_apartment_db(2, 'tile:47,57', 7000, 'business', 'beer_bar')
        assert second['error'] == 'building occupied'
        assert second['owner_name'] == 'Вячеслав'

        other_block = await bot.buy_apartment_db(2, 'tile:46,66', 7000, 'business', 'beer_bar')
        assert other_block['ok'], other_block

        bad_operation = await bot.buy_apartment_db(1, 'tile:48,58', 7000, 'business', 'missing')
        assert bad_operation['error'] == 'bad operation'
        assert bad_operation['message']

        world = Path(__file__).with_name('world.html').read_text(encoding='utf-8')
        assert 'async function loadApartmentState(force=false)' in world
        assert 'loadApartmentState(true)' in world
        assert "String(j.message||'').trim()" in world
        assert 'причина: ${j.error' in world
        assert '_playerPropertyBuildingPoints(holding)' in world
        assert 'const points=blockPoints.length?blockPoints' in world
        print('building purchase reasons: OK')
    finally:
        bot.DB_PATH = original
        try:
            os.unlink(path)
        except PermissionError:
            pass


if __name__ == '__main__':
    asyncio.run(run())
