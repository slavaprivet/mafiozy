import asyncio
import os
import sqlite3
import tempfile
import time

import mafiozi_bot as bot


async def run():
    handle, path = tempfile.mkstemp(suffix='.db')
    os.close(handle)
    original_path = bot.DB_PATH
    bot.DB_PATH = path
    try:
        await bot.ensure_apartment_tables()
        with sqlite3.connect(path) as db:
            db.executescript("""
                CREATE TABLE characters(
                    telegram_id INTEGER PRIMARY KEY, cash INTEGER,
                    mafia_family TEXT, name TEXT
                );
                CREATE TABLE custom_gangs(
                    id INTEGER PRIMARY KEY, leader_uid INTEGER, name TEXT,
                    hq_apt_key TEXT, flag_primary TEXT, flag_secondary TEXT,
                    flag_emblem TEXT
                );
                CREATE TABLE custom_gang_members(
                    gang_id INTEGER, telegram_id INTEGER UNIQUE, role TEXT,
                    joined_at INTEGER, invited_by INTEGER
                );
                CREATE TABLE npc_empire_holdings(
                    kind TEXT, holding_id TEXT, leader_id TEXT
                );
                INSERT INTO characters VALUES(1,100000,'moretti','Tester');
                INSERT INTO characters VALUES(2,100000,'','Civilian');
            """)

        business = await bot.buy_apartment_db(
            1, 'tile:6,36', 3500, 'business', 'beer_bar')
        assert business['ok']
        info = (await bot.get_apartments_owned(1))['tile:6,36']
        assert info['income_per_minute'] == 83

        assert (await bot.buy_apartment_db(
            1, 'tile:6,46', 3500, 'hq'))['ok']
        assert (await bot.buy_apartment_db(
            1, 'tile:6,56', 3500, 'hq'))['error'] == 'hq limit'
        assert (await bot.buy_apartment_db(
            2, 'tile:6,66', 3500, 'business', 'poker_club'))['error'] == 'mafia required'

        with sqlite3.connect(path) as db:
            db.execute(
                "UPDATE apartments_owned SET last_income_at=? "
                "WHERE telegram_id=1 AND apt_key='tile:6,36'",
                (int(time.time()) - 125,),
            )
        payout = await bot.collect_apartment_income_db(1, 'tile:6,36')
        assert payout['collected'] == 166
        properties = await bot.get_player_building_properties()
        assert len(properties) == 2
        assert properties[0]['family'] == 'moretti'
        print('player building business: OK')
    finally:
        bot.DB_PATH = original_path
        try:
            os.unlink(path)
        except PermissionError:
            pass


if __name__ == '__main__':
    asyncio.run(run())
