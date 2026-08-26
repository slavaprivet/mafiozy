"""Regression coverage for server-authoritative apartment upgrades."""

import asyncio
import os
import sqlite3
import tempfile
from pathlib import Path

import mafiozi_bot as bot


EXPECTED = {
    "safe": ("safe_level", (700, 1225, 2144)),
    "weapon_rack": ("weapon_rack_level", (900, 1575, 2756)),
    "garage": ("garage_level", (1400, 2450, 4288)),
    "cameras": ("cameras_level", (1100, 1925, 3369)),
    "repair": ("repair_level", (500, 875, 1531)),
}


async def run():
    handle, path = tempfile.mkstemp(prefix="apartment_upgrade_authority_", suffix=".db")
    os.close(handle)
    original = bot.DB_PATH
    bot.DB_PATH = path
    try:
        await bot.ensure_apartment_tables()
        with sqlite3.connect(path) as db:
            db.executescript("""
                CREATE TABLE characters(
                    telegram_id INTEGER PRIMARY KEY, cash INTEGER,
                    mafia_family TEXT, name TEXT
                );
                INSERT INTO characters VALUES(1,10000,'moretti','Tester');
                INSERT INTO characters VALUES(2,700,'','Concurrent');
                INSERT INTO apartments_owned(telegram_id,apt_key,price,bought_at)
                    VALUES(1,'tile:16,16',6500,1);
                INSERT INTO apartments_owned(telegram_id,apt_key,price,bought_at)
                    VALUES(2,'tile:26,26',6500,1);
            """)

        assert set(bot.APARTMENT_UPGRADES) == set(EXPECTED)
        for upgrade, (column, costs) in EXPECTED.items():
            assert bot.APARTMENT_UPGRADES[upgrade]["column"] == column
            assert tuple(bot.apartment_upgrade_cost(upgrade, level)
                         for level in range(3)) == costs

        # A forged client price is impossible: the primitive accepts no cost
        # and derives each debit from the level locked by BEGIN IMMEDIATE.
        first = await bot.upgrade_apartment_db(1, 'tile:16,16', 'safe')
        assert first['ok'] and first['cost'] == 700 and first['level'] == 1
        assert first['cash'] == 9300
        assert first['owned']['tile:16,16']['safe_level'] == 1
        second = await bot.upgrade_apartment_db(1, 'tile:16,16', 'safe')
        third = await bot.upgrade_apartment_db(1, 'tile:16,16', 'safe')
        assert (second['cost'], second['level']) == (1225, 2)
        assert (third['cost'], third['level'], third['cash']) == (2144, 3, 5931)
        capped = await bot.upgrade_apartment_db(1, 'tile:16,16', 'safe')
        assert capped == {'ok': False, 'error': 'maxed', 'cash': 5931, 'level': 3}

        # Two simultaneous attempts cannot both spend the same $700 balance.
        concurrent = await asyncio.gather(
            bot.upgrade_apartment_db(2, 'tile:26,26', 'safe'),
            bot.upgrade_apartment_db(2, 'tile:26,26', 'safe'),
        )
        assert sum(bool(result.get('ok')) for result in concurrent) == 1
        with sqlite3.connect(path) as db:
            assert db.execute("SELECT cash FROM characters WHERE telegram_id=2").fetchone()[0] == 0
            assert db.execute("SELECT safe_level FROM apartments_owned WHERE telegram_id=2").fetchone()[0] == 1

        invalid = await bot.upgrade_apartment_db(1, 'tile:16,16', 'missing')
        assert invalid['error'] == 'bad upgrade'
        missing = await bot.upgrade_apartment_db(1, 'tile:99,99', 'repair')
        assert missing['error'] == 'not owned'

        world = Path(__file__).with_name('world.html').read_text(encoding='utf-8')
        upgrade_block = world.split('async function upgradeCurrentApartment(upgrade)', 1)[1].split(
            'function showApartmentUpgradeMenu()', 1)[0]
        assert "JSON.stringify({ apt_key: key, upgrade })" in upgrade_block
        assert "upgrade, cost" not in upgrade_block
        assert "+j.level||lvl+1" in upgrade_block
        assert "+j.cost||cost" in upgrade_block
        for snippet in (
            "safe:        { label: '💰 Сейф',           base: 700,  desc: 'Хранение наличных и ценных вещей' }",
            "weapon_rack: { label: '🔫 Оружейный шкаф', base: 900,  desc: 'Хранение оружия дома' }",
            "garage:      { label: '🚗 Гараж',          base: 1400, desc: 'Место для машины у дома' }",
            "cameras:     { label: '🎥 Камеры',         base: 1100, desc: 'Защита и будущие уведомления' }",
            "repair:      { label: '🛠 Отделка',        base: 500,  desc: 'Качество и статус помещения' }",
        ):
            assert snippet in world
        print('apartment upgrade authority: OK')
    finally:
        bot.DB_PATH = original
        try:
            os.unlink(path)
        except PermissionError:
            pass


def test_apartment_upgrade_authority():
    asyncio.run(run())


if __name__ == '__main__':
    test_apartment_upgrade_authority()
