"""Concurrent lifecycle regression for concrete property guard assignments."""

import asyncio
import os
import tempfile
from pathlib import Path

import aiosqlite

import mafiozi_bot as bot
import npc_empire as ne
from test_npc_empire import _base_db


async def rows(path, sql, params=()):
    async with aiosqlite.connect(path) as db:
        return await (await db.execute(sql, params)).fetchall()


async def property_snapshot(path):
    original_db_path = bot.DB_PATH
    try:
        bot.DB_PATH = path
        return await bot.get_player_building_properties()
    finally:
        bot.DB_PATH = original_db_path


async def run() -> None:
    world = (Path(__file__).resolve().parent / 'world.html').read_text(encoding='utf-8')
    assert 'dataset.playerPropertyGuardAssignment=`${holdingRef}:here-${property.holding_guards}:' in world
    assert ':assigned-${property.guard_assigned}:free-${property.guard_free}:server`' in world
    fd, path = tempfile.mkstemp(prefix='property_guard_stress_', suffix='.db')
    os.close(fd)
    try:
        await _base_db(path); now = 2_300_000_000
        async with aiosqlite.connect(path) as db:
            await db.execute("ALTER TABLE characters ADD COLUMN name TEXT")
            await db.execute("ALTER TABLE characters ADD COLUMN mafia_family TEXT")
            await db.executescript("""
                CREATE TABLE gang_members(
                    id INTEGER PRIMARY KEY,telegram_id INTEGER,current_hp INTEGER);
                CREATE TABLE district_control(
                    telegram_id INTEGER,loc_id TEXT,guard_json TEXT);
                CREATE TABLE apartments_owned(
                    telegram_id INTEGER,apt_key TEXT PRIMARY KEY,price INTEGER,bought_at INTEGER,
                    property_kind TEXT,operation_type TEXT,area INTEGER,income_per_minute INTEGER,
                    last_income_at INTEGER DEFAULT 0);
                CREATE TABLE custom_gang_members(telegram_id INTEGER,gang_id INTEGER);
                CREATE TABLE custom_gangs(
                    id INTEGER PRIMARY KEY,name TEXT,flag_primary TEXT,
                    flag_secondary TEXT,flag_emblem TEXT);
            """)
            await db.execute("UPDATE characters SET name='Tester',mafia_family='moretti' WHERE telegram_id=101")
            await db.execute("UPDATE characters SET name='Second',mafia_family='bellini' WHERE telegram_id=202")
            await db.executemany(
                "INSERT INTO gang_members VALUES(?,101,100)", [(i,) for i in range(1, 9)])
            await db.executemany(
                "INSERT INTO gang_members VALUES(?,202,100)", [(i,) for i in range(20, 24)])
            await db.execute("INSERT INTO district_control VALUES(101,'north','[1]')")
            await db.executemany(
                "INSERT INTO apartments_owned VALUES(101,?,10000,?,'business','pawnshop',16,120,?)",
                [('tile:6,36', now, now), ('tile:6,46', now, now)])
            await db.execute(
                "INSERT INTO apartments_owned VALUES(202,'tile:6,56',10000,?,'business','pawnshop',16,120,?)",
                (now, now))
            await db.commit()
        await ne.ensure_schema(path)
        a, b, other = 'building:0,3', 'building:0,4', 'building:0,5'

        # A second online owner already has concrete defenders. Any operation
        # by player 101 must leave both their ids and aggregate assignment exact.
        second = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='202', holding_ref=other,
            requested=2, now=now)
        assert second['ok'] and second['holding_guards'] == 2
        second_before = await rows(path,
            "SELECT owner_uid,member_id,holding_ref FROM npc_empire_player_guard_members "
            "WHERE owner_uid=202 ORDER BY member_id")
        assert second_before == [(202, 20, other), (202, 21, other)]

        # An unavailable roster is not an authoritative empty roster. Fail
        # closed before reconciliation so another holding keeps its exact rows.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "INSERT INTO npc_empire_player_guard_members VALUES(2,101,?,?)",
                (a, now-12))
            await db.execute(
                "INSERT INTO npc_empire_guard_assignments VALUES"
                "('player','101',?,1,1,?)", (a, now-12))
            await db.execute(
                "INSERT INTO npc_empire_guard_assignments VALUES"
                "('npc','leila','building:sentinel',2,2,?)", (now-12,))
            await db.execute("ALTER TABLE gang_members RENAME TO gang_members_unavailable")
            await db.commit()
        try:
            await ne.assign_holding_guards(
                path, owner_kind='player', owner_id='101', holding_ref=b,
                requested=0, now=now-11)
            raise AssertionError('unavailable roster did not fail closed')
        except aiosqlite.OperationalError as error:
            assert 'gang_members' in str(error)
        finally:
            async with aiosqlite.connect(path) as db:
                await db.execute(
                    "ALTER TABLE gang_members_unavailable RENAME TO gang_members")
                await db.commit()
        assert await rows(path,
            "SELECT owner_uid,member_id,holding_ref FROM npc_empire_player_guard_members "
            "WHERE owner_uid=101") == [(101, 2, a)]
        assert await rows(path,
            "SELECT assigned,living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='player' AND owner_id='101' AND holding_ref=?", (a,)) == [(1, 1)]
        assert await rows(path,
            "SELECT owner_uid,member_id,holding_ref FROM npc_empire_player_guard_members "
            "WHERE owner_uid=202 ORDER BY member_id") == second_before
        assert await rows(path,
            "SELECT assigned,living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='npc' AND owner_id='leila' AND holding_ref='building:sentinel'") == [(2, 2)]
        async with aiosqlite.connect(path) as db:
            await db.execute("UPDATE gang_members SET current_hp=0 WHERE telegram_id=101")
            await db.commit()
        empty_roster = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=b,
            requested=0, now=now-10)
        assert empty_roster['ok'] and empty_roster['total'] == 0
        assert not await rows(path,
            "SELECT 1 FROM npc_empire_player_guard_members WHERE owner_uid=101")
        assert await rows(path,
            "SELECT assigned,living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='player' AND owner_id='101' AND holding_ref=?", (a,)) == [(1, 0)]
        async with aiosqlite.connect(path) as db:
            await db.execute("UPDATE gang_members SET current_hp=100 WHERE telegram_id=101")
            await db.commit()
        cleared = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=a,
            requested=0, now=now-10)
        assert cleared['ok'] and not await rows(path,
            "SELECT 1 FROM npc_empire_player_guard_members WHERE owner_uid=101")

        # Legacy versions could delete concrete rows while leaving aggregate
        # living counts behind.  A valid owner-local assignment repairs those
        # ghosts before capacity is checked, without touching another owner.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "INSERT INTO npc_empire_guard_assignments VALUES"
                "('player','101',?,4,4,?)", (a, now-10))
            await db.execute(f"""
                CREATE TRIGGER reject_reconciled_target
                BEFORE INSERT ON npc_empire_guard_assignments
                WHEN NEW.owner_kind='player' AND NEW.owner_id='101'
                     AND NEW.holding_ref='{b}'
                BEGIN SELECT RAISE(ABORT, 'forced guard repair rollback'); END
            """)
            await db.commit()
        invalid = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101',
            holding_ref='building:9,9', requested=0, now=now-9)
        assert invalid == {'ok': False, 'error': 'holding not owned'}
        assert await rows(path,
            "SELECT assigned,living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='player' AND owner_id='101' AND holding_ref=?", (a,)) == [(4, 4)]
        try:
            await ne.assign_holding_guards(
                path, owner_kind='player', owner_id='101', holding_ref=b,
                requested=4, now=now-9)
            raise AssertionError('guard repair failure did not roll back')
        except aiosqlite.IntegrityError as error:
            assert 'forced guard repair rollback' in str(error)
        finally:
            async with aiosqlite.connect(path) as db:
                await db.execute("DROP TRIGGER reject_reconciled_target")
                await db.commit()
        assert await rows(path,
            "SELECT assigned,living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='player' AND owner_id='101' AND holding_ref=?", (a,)) == [(4, 4)]
        assert not await rows(path,
            "SELECT 1 FROM npc_empire_player_guard_members WHERE owner_uid=101")

        repaired = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=b,
            requested=4, now=now-8)
        assert repaired == {'ok': True, 'total': 8, 'assigned': 5,
                            'free': 3, 'holding_guards': 4}
        assert await rows(path,
            "SELECT assigned,living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='player' AND owner_id='101' AND holding_ref=?", (a,)) == [(4, 0)]
        assert not await rows(path,
            "SELECT 1 FROM npc_empire_player_guard_members "
            "WHERE owner_uid=101 AND holding_ref=?", (a,))
        assert await rows(path,
            "SELECT owner_uid,member_id,holding_ref FROM npc_empire_player_guard_members "
            "WHERE owner_uid=202 ORDER BY member_id") == second_before
        assert await rows(path,
            "SELECT assigned,living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='npc' AND owner_id='leila' AND holding_ref='building:sentinel'") == [(2, 2)]

        # Reverse and partial mismatches converge without fabricating fighters:
        # concrete rows missing an aggregate are inserted, while historical
        # assigned stays above the exact living survivor count.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "DELETE FROM npc_empire_guard_assignments WHERE owner_kind='player' "
                "AND owner_id='101' AND holding_ref=?", (b,))
            await db.commit()
        b_ids = await rows(path,
            "SELECT member_id FROM npc_empire_player_guard_members "
            "WHERE owner_uid=101 AND holding_ref=? ORDER BY member_id", (b,))
        reverse = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=a,
            requested=2, now=now-7)
        assert reverse['ok'] and reverse['assigned'] == 7 and reverse['free'] == 1
        assert await rows(path,
            "SELECT assigned,living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='player' AND owner_id='101' AND holding_ref=?", (b,)) == [(4, 4)]
        assert await rows(path,
            "SELECT member_id FROM npc_empire_player_guard_members "
            "WHERE owner_uid=101 AND holding_ref=? ORDER BY member_id", (b,)) == b_ids

        await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=a,
            requested=0, now=now-6)
        await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=b,
            requested=0, now=now-6)
        async with aiosqlite.connect(path) as db:
            await db.executemany(
                "INSERT INTO npc_empire_player_guard_members VALUES(?,?,?,?)",
                [(2, 101, a, now-5), (3, 101, a, now-5)])
            await db.execute(
                "INSERT INTO npc_empire_guard_assignments VALUES"
                "('player','101',?,5,5,?)", (a, now-5))
            await db.execute("UPDATE gang_members SET current_hp=0 WHERE id=2")
            await db.commit()
        partial = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=b,
            requested=4, now=now-4)
        assert partial['ok'] and partial['assigned'] == 6 and partial['free'] == 1
        assert await rows(path,
            "SELECT assigned,living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='player' AND owner_id='101' AND holding_ref=?", (a,)) == [(5, 1)]
        assert not await rows(path,
            "SELECT 1 FROM npc_empire_player_guard_members WHERE member_id=2")
        assert await rows(path,
            "SELECT owner_uid,member_id,holding_ref FROM npc_empire_player_guard_members "
            "WHERE owner_uid=202 ORDER BY member_id") == second_before
        async with aiosqlite.connect(path) as db:
            await db.execute("UPDATE gang_members SET current_hp=100 WHERE id=2")
            await db.commit()
        await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=a,
            requested=0, now=now-3)
        await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=b,
            requested=0, now=now-3)

        zero = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=a,
            requested=0, now=now)
        assert zero == {'ok': True, 'total': 8, 'assigned': 1,
                        'free': 7, 'holding_guards': 0}
        assert await rows(path,
            "SELECT owner_uid,member_id,holding_ref FROM npc_empire_player_guard_members "
            "WHERE owner_uid=202 ORDER BY member_id") == second_before
        assert await rows(path,
            "SELECT living FROM npc_empire_guard_assignments WHERE owner_kind='player' "
            "AND owner_id='202' AND holding_ref=?", (other,)) == [(2,)]
        maximum = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=a,
            requested=7, now=now+1)
        assert maximum['ok'] and maximum['assigned'] == 8 and maximum['free'] == 0
        assert [row[0] for row in await rows(path,
            "SELECT member_id FROM npc_empire_player_guard_members WHERE owner_uid=101 ORDER BY member_id")] == list(range(2, 9))
        snap = await property_snapshot(path)
        first = next(item for item in snap if item['apt_key'] == 'tile:6,36')
        assert (first['holding_guards'], first['guard_total'], first['guard_assigned'],
                first['guard_free']) == (7, 8, 8, 0), first

        # Reassign A -> B: releasing A returns all seven survivors, and B gets
        # those exact ids; district guard 1 is never cloned.
        await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=a,
            requested=0, now=now+2)
        moved = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=b,
            requested=7, now=now+3)
        assert moved['ok'] and moved['free'] == 0
        assert set(await rows(path,
            "SELECT member_id,holding_ref FROM npc_empire_player_guard_members WHERE owner_uid=101")) == {
                (member_id, b) for member_id in range(2, 9)}

        # Two independent requests race for seven free ids. BEGIN IMMEDIATE
        # serializes them: at most one four-man assignment can succeed.
        await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=b,
            requested=0, now=now+4)
        concurrent = await asyncio.gather(
            ne.assign_holding_guards(path, owner_kind='player', owner_id='101',
                                     holding_ref=a, requested=4, now=now+5),
            ne.assign_holding_guards(path, owner_kind='player', owner_id='101',
                                     holding_ref=b, requested=4, now=now+5),
        )
        assert sum(bool(result['ok']) for result in concurrent) == 1, concurrent
        assigned_ids = [row[0] for row in await rows(path,
            "SELECT member_id FROM npc_empire_player_guard_members WHERE owner_uid=101")]
        assert len(assigned_ids) == len(set(assigned_ids)) == 4 and 1 not in assigned_ids

        # Concurrent duplicate requests converge to one stable assignment.
        winner_ref = a if concurrent[0]['ok'] else b
        duplicate = await asyncio.gather(
            ne.assign_holding_guards(path, owner_kind='player', owner_id='101',
                                     holding_ref=winner_ref, requested=4, now=now+6),
            ne.assign_holding_guards(path, owner_kind='player', owner_id='101',
                                     holding_ref=winner_ref, requested=4, now=now+6),
        )
        assert all(result['ok'] for result in duplicate)
        assert len(await rows(path,
            "SELECT member_id FROM npc_empire_player_guard_members WHERE owner_uid=101")) == 4

        # Cross-owner concurrent changes serialize but never prune each other.
        cross_owner = await asyncio.gather(
            ne.assign_holding_guards(path, owner_kind='player', owner_id='101',
                                     holding_ref=winner_ref, requested=3, now=now+6),
            ne.assign_holding_guards(path, owner_kind='player', owner_id='202',
                                     holding_ref=other, requested=3, now=now+6),
        )
        assert all(result['ok'] for result in cross_owner), cross_owner
        owner_rows = await rows(path,
            "SELECT owner_uid,COUNT(*) FROM npc_empire_player_guard_members "
            "GROUP BY owner_uid ORDER BY owner_uid")
        assert owner_rows == [(101, 3), (202, 3)], owner_rows
        aggregate_rows = await rows(path,
            "SELECT owner_id,SUM(living) FROM npc_empire_guard_assignments "
            "WHERE owner_kind='player' GROUP BY owner_id ORDER BY owner_id")
        assert aggregate_rows == [('101', 3), ('202', 3)], aggregate_rows

        # Reconnect preserves concrete ids. A dead assigned merc is pruned and
        # can never return when ownership cleanup releases survivors.
        before = await rows(path,
            "SELECT member_id,holding_ref FROM npc_empire_player_guard_members WHERE owner_uid=101 ORDER BY member_id")
        await ne.ensure_schema(path)
        assert await rows(path,
            "SELECT member_id,holding_ref FROM npc_empire_player_guard_members WHERE owner_uid=101 ORDER BY member_id") == before
        reconnect = await property_snapshot(path)
        current = next(item for item in reconnect
                       if item['building_key'] == winner_ref.removeprefix('building:'))
        assert current['holding_guards'] == 3 and current['guard_free'] == 4, current
        dead_id = before[0][0]
        async with aiosqlite.connect(path) as db:
            await db.execute('BEGIN IMMEDIATE')
            await db.execute("UPDATE gang_members SET current_hp=0 WHERE id=?", (dead_id,))
            released = await ne._clear_holding_guard_assignment(
                db, 'player', '101', winner_ref)
            await db.commit()
        assert released == 3
        assert not await rows(path,
            "SELECT 1 FROM npc_empire_player_guard_members WHERE holding_ref=?", (winner_ref,))
        after_sale = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101',
            holding_ref=winner_ref, requested=4, now=now+7)
        assert after_sale['ok']
        assert dead_id not in {row[0] for row in await rows(path,
            "SELECT member_id FROM npc_empire_player_guard_members WHERE owner_uid=101")}

        # An ownership transfer clears mappings atomically. Surviving ids become
        # free; dead ids remain dead and are never reconstructed.
        async with aiosqlite.connect(path) as db:
            await db.execute('BEGIN IMMEDIATE')
            await db.execute("DELETE FROM apartments_owned WHERE telegram_id=101 AND apt_key=?",
                             ('tile:6,36' if winner_ref == a else 'tile:6,46',))
            await ne._clear_holding_guard_assignment(db, 'player', '101', winner_ref)
            await db.commit()
        assert not await rows(path,
            "SELECT 1 FROM npc_empire_guard_assignments WHERE owner_kind='player' AND owner_id='101' AND holding_ref=?",
            (winner_ref,))
        assert all(item['building_key'] != winner_ref.removeprefix('building:')
                   for item in await property_snapshot(path))
        not_owned = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=winner_ref,
            requested=1, now=now+8)
        assert not_owned == {'ok': False, 'error': 'holding not owned'}

        # Exercise the real sale path too: ownership and both assignment
        # representations disappear in the same BEGIN IMMEDIATE transaction.
        sale_ref = b if winner_ref == a else a
        sale_apt = 'tile:6,46' if sale_ref == b else 'tile:6,36'
        sale_assignment = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=sale_ref,
            requested=1, now=now+9)
        assert sale_assignment['ok']
        original_db_path = bot.DB_PATH
        try:
            bot.DB_PATH = path
            sale = await bot.sell_apartment_db(101, sale_apt)
            assert sale and sale['refund'] == 9000
        finally:
            bot.DB_PATH = original_db_path
        assert not await rows(path,
            "SELECT 1 FROM npc_empire_player_guard_members WHERE holding_ref=?", (sale_ref,))
        assert not await rows(path,
            "SELECT 1 FROM npc_empire_guard_assignments WHERE holding_ref=?", (sale_ref,))
        assert len(await rows(path,
            "SELECT member_id FROM npc_empire_player_guard_members WHERE owner_uid=202")) == 3
        print('property guard assignment stress: legacy aggregate repair, 0/max/reassign, '
              'district exclusion, cross-owner isolation, concurrent duplicate '
              'serialization, reconnect, death and sale/capture cleanup OK')
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
