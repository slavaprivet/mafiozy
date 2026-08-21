"""A pending interior raid freezes only its exact player holding roster."""

import asyncio
import os
import tempfile
from pathlib import Path

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


async def rows(path: str, sql: str, args=()):
    async with aiosqlite.connect(path) as db:
        return await (await db.execute(sql, args)).fetchall()


async def run() -> None:
    handle, path = tempfile.mkstemp(prefix='property_guard_pending_raid_', suffix='.db')
    os.close(handle)
    now = 2_900_000_000
    a, b, other = 'building:0,3', 'building:0,4', 'building:0,5'
    try:
        await _base_db(path)
        async with aiosqlite.connect(path) as db:
            await db.executescript("""
                CREATE TABLE gang_members(
                    id INTEGER PRIMARY KEY,telegram_id INTEGER,current_hp INTEGER);
                CREATE TABLE district_control(
                    telegram_id INTEGER,loc_id TEXT,guard_json TEXT);
                CREATE TABLE apartments_owned(
                    telegram_id INTEGER,apt_key TEXT PRIMARY KEY,price INTEGER,bought_at INTEGER,
                    property_kind TEXT,operation_type TEXT,area INTEGER,income_per_minute INTEGER,
                    last_income_at INTEGER DEFAULT 0);
            """)
            await db.executemany(
                "INSERT INTO gang_members VALUES(?,101,100)", [(1,), (2,), (3,), (4,)])
            await db.executemany(
                "INSERT INTO gang_members VALUES(?,202,100)", [(20,), (21,), (22,)])
            await db.executemany(
                "INSERT INTO apartments_owned VALUES(101,?,10000,?,'business','pawnshop',16,120,?)",
                [('tile:6,36', now, now), ('tile:6,46', now, now)])
            await db.execute(
                "INSERT INTO apartments_owned VALUES(202,'tile:6,56',10000,?,'business',"
                "'pawnshop',16,120,?)", (now, now))
            await db.commit()
        await ne.ensure_schema(path)
        assert (await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=a,
            requested=2, now=now))['ok']
        assert (await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='202', holding_ref=other,
            requested=2, now=now))['ok']
        before = await rows(path,
            "SELECT member_id,owner_uid,holding_ref FROM npc_empire_player_guard_members "
            "ORDER BY member_id")
        async with aiosqlite.connect(path) as db:
            await db.executemany(
                "INSERT INTO npc_empire_interior_raids("
                "token,telegram_id,leader_id,apt_key,target_ref,target_kind,holding_id,force,"
                "attacker_cost,tier,quality,hp,accuracy,weapon_budget,defender_ids_json,"
                "started_at,hold_seconds,expires_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                [('pending-a', 101, 'marco', 'tile:6,36', a, 'building', '0,3', 3,
                  300, 1, 1, 100, .5, 100, '[1,2]', now, 30, now + 120),
                 ('future-a', 101, 'leila', 'tile:6,36', a, 'building', '0,3', 3,
                  300, 1, 1, 100, .5, 100, '[1,2]', now, 30, now + 240)])
            await db.commit()

        locked = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=a,
            requested=0, now=now + 1)
        assert locked == {'ok': False, 'error': 'raid in progress'}
        assert await rows(path,
            "SELECT member_id,owner_uid,holding_ref FROM npc_empire_player_guard_members "
            "ORDER BY member_id") == before
        assert await rows(path,
            "SELECT assigned,living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='player' AND owner_id='101' AND holding_ref=?", (a,)) == [(2, 2)]
        assert await rows(path,
            "SELECT status FROM npc_empire_interior_raids WHERE token='pending-a'") == [('pending',)]

        concurrent_locked = await asyncio.gather(
            ne.assign_holding_guards(
                path, owner_kind='player', owner_id='101', holding_ref=a,
                requested=0, now=now + 1),
            ne.assign_holding_guards(
                path, owner_kind='player', owner_id='101', holding_ref=a,
                requested=1, now=now + 1))
        assert concurrent_locked == [
            {'ok': False, 'error': 'raid in progress'},
            {'ok': False, 'error': 'raid in progress'}]
        assert await rows(path,
            "SELECT member_id,owner_uid,holding_ref FROM npc_empire_player_guard_members "
            "ORDER BY member_id") == before

        # The lock is exact: another holding and another owner are untouched.
        assert (await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=b,
            requested=1, now=now + 2))['ok']
        assert (await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='202', holding_ref=other,
            requested=1, now=now + 2))['ok']
        async with aiosqlite.connect(path) as db:
            await db.executemany(
                "INSERT INTO npc_empire_interior_raids("
                "token,telegram_id,leader_id,apt_key,target_ref,target_kind,holding_id,force,"
                "attacker_cost,tier,quality,hp,accuracy,weapon_budget,defender_ids_json,"
                "started_at,hold_seconds,expires_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                [('other-holding', 101, 'rustam', 'tile:6,46', b, 'building', '0,4', 3,
                  300, 1, 1, 100, .5, 100, '[3]', now, 30, now + 500),
                 ('other-owner', 202, 'niko', 'tile:6,56', other, 'building', '0,5', 3,
                  300, 1, 1, 100, .5, 100, '[20]', now, 30, now + 500)])
            await db.commit()

        still_locked = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=a,
            requested=0, now=now + 121)
        assert still_locked == {'ok': False, 'error': 'raid in progress'}
        assert await rows(
            path, "SELECT token,status,resolution FROM npc_empire_interior_raids "
                  "WHERE token IN ('pending-a','future-a') ORDER BY token") == [
                      ('future-a', 'pending', ''),
                      ('pending-a', 'resolved', 'expired')]
        assert await rows(
            path, "SELECT token,status FROM npc_empire_interior_raids "
                  "WHERE token IN ('other-holding','other-owner') ORDER BY token") == [
                      ('other-holding', 'pending'), ('other-owner', 'pending')]
        isolated_before = await rows(
            path, "SELECT member_id,owner_uid,holding_ref "
                  "FROM npc_empire_player_guard_members WHERE holding_ref<>? "
                  "ORDER BY member_id", (a,))

        concurrent_release = await asyncio.gather(
            ne.assign_holding_guards(
                path, owner_kind='player', owner_id='101', holding_ref=a,
                requested=0, now=now + 241),
            ne.assign_holding_guards(
                path, owner_kind='player', owner_id='101', holding_ref=a,
                requested=0, now=now + 241))
        assert all(item['ok'] and item['holding_guards'] == 0
                   for item in concurrent_release)
        assert await rows(
            path, "SELECT status,resolution FROM npc_empire_interior_raids "
                  "WHERE token='future-a'") == [('resolved', 'expired')]
        retry = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=a,
            requested=0, now=now + 242)
        assert retry['ok'] and retry['holding_guards'] == 0
        reassigned = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref=a,
            requested=1, now=now + 243)
        assert reassigned['ok'] and reassigned['holding_guards'] == 1
        assert await rows(
            path, "SELECT member_id,owner_uid,holding_ref "
                  "FROM npc_empire_player_guard_members WHERE holding_ref<>? "
                  "ORDER BY member_id", (a,)) == isolated_before
        assert await rows(
            path, "SELECT token,status FROM npc_empire_interior_raids "
                  "WHERE token IN ('other-holding','other-owner') ORDER BY token") == [
                      ('other-holding', 'pending'), ('other-owner', 'pending')]

        world = Path(__file__).with_name('world.html').read_text(encoding='utf-8')
        assert 'Во время активного штурма состав этого отряда менять нельзя.' in world
        print('pending raid guard lock: active/future frozen, exact expiry release, '
              'concurrency and owner/family/holding isolation OK')
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
