"""A family remembers a repulsed holding raid and changes a rational next target."""

import asyncio
import importlib
import os
import sqlite3
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


async def _row(path, sql, params=()):
    async with aiosqlite.connect(path) as db:
        db.row_factory = aiosqlite.Row
        return await (await db.execute(sql, params)).fetchone()


async def _targets(path, uid=101):
    async with aiosqlite.connect(path) as db:
        db.row_factory = aiosqlite.Row
        return await ne._player_business_targets(db, uid)


async def _select(path, uid, leader, targets, attacks=0, last_ref='', now=0):
    async with aiosqlite.connect(path) as db:
        db.row_factory = aiosqlite.Row
        return await ne._select_player_business_target_smart(
            db, uid, leader, targets, attacks, last_ref, now)


async def _create(path, uid, leader, target, attack_no, now):
    async with aiosqlite.connect(path) as db:
        db.row_factory = aiosqlite.Row
        await db.execute('BEGIN IMMEDIATE')
        raid = await ne._create_interior_raid(db, uid, leader, target, attack_no, now)
        await db.commit()
        return raid


async def run():
    fd, path = tempfile.mkstemp(prefix='npc_raid_target_memory_', suffix='.db')
    os.close(fd)
    now = 2_500_000_000
    passed = []
    try:
        await _base_db(path)
        async with aiosqlite.connect(path) as db:
            await db.executescript("""
                CREATE TABLE gang_members(
                    id INTEGER PRIMARY KEY,telegram_id INTEGER,current_hp INTEGER);
                CREATE TABLE apartments_owned(
                    telegram_id INTEGER,apt_key TEXT PRIMARY KEY,price INTEGER,bought_at INTEGER,
                    property_kind TEXT,operation_type TEXT,area INTEGER,income_per_minute INTEGER,
                    last_income_at INTEGER DEFAULT 0);
            """)
            await db.executemany(
                "INSERT INTO apartments_owned"
                "(telegram_id,apt_key,price,bought_at,property_kind,operation_type,area,income_per_minute) "
                "VALUES(101,?,?,?,'business','pawnshop',?,120)",
                [('tile:6,36', 20000, now, 24), ('tile:6,46', 18000, now, 24)])
            for leader in ('leila', 'marco', 'niko'):
                await db.execute(
                    "INSERT OR REPLACE INTO npc_empire_relations"
                    "(leader_id,telegram_id,score,pact,last_action_at) VALUES(?,101,-100,'war',?)",
                    (leader, now))
                await db.execute(
                    "UPDATE npc_empires SET members=12,strength=360,treasury=50000 "
                    "WHERE leader_id=?", (leader,))
                await db.execute(
                    "INSERT OR REPLACE INTO npc_empire_player_wars"
                    "(leader_id,telegram_id,next_attack_at,attacks) VALUES(?,101,?,0)",
                    (leader, now + 99999))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations"
                "(leader_id,telegram_id,score,pact,last_action_at) "
                "VALUES('leila',202,-100,'war',?)", (now,))
            await db.commit()

        targets = await _targets(path)
        preferred = next(item for item in targets if item['ref'] == 'building:0,3')
        alternate = next(item for item in targets if item['ref'] == 'building:0,4')
        assert (await _select(path, 101, 'leila', targets, now=now))['ref'] == preferred['ref']
        marco_baseline = (await _select(path, 101, 'marco', targets, now=now))['ref']

        # 1. A server-validated defended result writes one exact target memory.
        raid = await _create(path, 101, 'leila', preferred, 0, now)
        defended = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'defended',
            attacker_casualties=list(range(raid['force'])), defender_casualties=[],
            guard_casualties=[], now=now + ne.PLAYER_INTERIOR_RAID_MIN_SECONDS)
        assert defended['ok']
        memory = await _row(path,
            "SELECT event_key,leader_id,leader_generation,subject_kind,subject_id,"
            "subject_generation,kind,outcome,magnitude,expires_at "
            "FROM npc_empire_memory_events WHERE event_key=?",
            (f"interior-raid:{raid['token']}:defended-target",))
        memory_until = now + ne.PLAYER_INTERIOR_RAID_MIN_SECONDS + ne.NPC_BOSS_MEMORY_REPULSED_RAID_TTL_SECONDS
        assert tuple(memory)[3:] == (
            'player_holding', '101|building:0,3', now, 'raid_defended',
            'defended', raid['force'], memory_until)
        passed.append('exact-memory')

        # 2. Duplicate resolution cannot extend or duplicate the observation.
        duplicate = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'defended',
            now=now + 1000)
        assert duplicate == {'ok': True, 'duplicate': True, 'resolution': 'defended'}
        assert int((await _row(path,
            "SELECT COUNT(*) n FROM npc_empire_memory_events WHERE kind='raid_defended'"))['n']) == 1
        assert int((await _row(path,
            "SELECT expires_at FROM npc_empire_memory_events WHERE event_key=?",
            (f"interior-raid:{raid['token']}:defended-target",)))['expires_at']) == memory_until
        passed.append('replay-idempotent')

        # 3. A comparable unremembered target wins before old-target stickiness.
        learned = await _select(
            path, 101, 'leila', targets, attacks=1,
            last_ref=preferred['ref'], now=now + 100)
        assert learned['ref'] == alternate['ref']
        assert learned['_raid']['target_reason'] == 'remembered-defeat'
        assert learned['_raid']['metrics']['memory'] == 'repulsed-target-avoided'
        passed.append('rational-switch')

        # 4. The only feasible target is never blocked by memory.
        lone = await _select(path, 101, 'leila', [preferred], attacks=1,
                             last_ref=preferred['ref'], now=now + 101)
        assert lone and lone['ref'] == preferred['ref']
        passed.append('single-target-fallback')

        # 5. The target decision reason is persisted for reload/reconnect.
        next_raid = await _create(path, 101, 'leila', learned, 1, now + 200)
        persisted = await _row(path,
            "SELECT selection_reason FROM npc_empire_interior_raids WHERE token=?",
            (next_raid['token'],))
        assert persisted['selection_reason'] == 'remembered-defeat'
        state = await ne.state_for(path, 101, now=now + 201)
        public_raid = next(item for item in state['interior_raids']
                           if item['token'] == next_raid['token'])
        assert public_raid['target_reason'] == 'remembered-defeat'
        reloaded = importlib.reload(ne)
        reconnect = await reloaded.state_for(path, 101, now=now + 202)
        assert next(item for item in reconnect['interior_raids']
                    if item['token'] == next_raid['token'])['target_reason'] == 'remembered-defeat'
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empire_interior_raids SET status='resolved',"
                "resolution='test_snapshot',resolved_at=? WHERE token=?",
                (now + 203, next_raid['token']))
            await db.commit()
        passed.append('reload-reason')

        # 6. At the exact TTL boundary the old preferred target is eligible again.
        after_ttl = await _select(path, 101, 'leila', targets, now=memory_until)
        assert after_ttl['ref'] == preferred['ref']
        passed.append('ttl-boundary')

        # 7. Memory is isolated by player and family.
        other_player = await _select(path, 202, 'leila', targets, now=now + 100)
        other_family = await _select(path, 101, 'marco', targets, now=now + 100)
        assert other_player['ref'] == preferred['ref']
        assert other_family['ref'] == marco_baseline
        passed.append('player-family-isolation')

        # 8. Reacquisition and a family comeback do not inherit old memory.
        reacquired = [{**item, 'acquired_at': now + 1} for item in targets]
        assert (await _select(path, 101, 'leila', reacquired, now=now + 100))['ref'] == preferred['ref']
        async with aiosqlite.connect(path) as db:
            await db.execute("UPDATE npc_empires SET comebacks=comebacks+1 WHERE leader_id='leila'")
            await db.commit()
        assert (await _select(path, 101, 'leila', targets, now=now + 100))['ref'] == preferred['ref']
        passed.append('generation-isolation')

        # 9. A late memory failure rolls back casualties, resolution and schedule.
        niko_raid = await _create(path, 101, 'niko', preferred, 0, now + 300)
        before = tuple(await _row(path,
            "SELECT e.members,r.status,w.next_attack_at FROM npc_empires e "
            "JOIN npc_empire_interior_raids r ON r.leader_id=e.leader_id "
            "JOIN npc_empire_player_wars w ON w.leader_id=e.leader_id "
            "AND w.telegram_id=r.telegram_id WHERE r.token=?", (niko_raid['token'],)))
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "CREATE TRIGGER reject_raid_memory BEFORE INSERT ON npc_empire_memory_events "
                "WHEN NEW.kind='raid_defended' BEGIN SELECT RAISE(ABORT,'raid memory rollback'); END")
            await db.commit()
        try:
            await reloaded.resolve_interior_raid(
                path, 101, niko_raid['token'], niko_raid['apt_key'], 'defended',
                attacker_casualties=list(range(niko_raid['force'])),
                defender_casualties=[], guard_casualties=[],
                now=now + 300 + reloaded.PLAYER_INTERIOR_RAID_MIN_SECONDS)
            raise AssertionError('forced memory failure must abort')
        except sqlite3.IntegrityError as exc:
            assert 'raid memory rollback' in str(exc)
        after = tuple(await _row(path,
            "SELECT e.members,r.status,w.next_attack_at FROM npc_empires e "
            "JOIN npc_empire_interior_raids r ON r.leader_id=e.leader_id "
            "JOIN npc_empire_player_wars w ON w.leader_id=e.leader_id "
            "AND w.telegram_id=r.telegram_id WHERE r.token=?", (niko_raid['token'],)))
        assert after == before and after[1] == 'pending'
        passed.append('late-rollback')

        # 10. The public UI maps the safe server reason without exposing identity keys.
        world = open('world.html', encoding='utf-8').read()
        assert '"remembered-defeat":\'босс помнит провал на прошлой цели и сменил направление\'' in world
        assert 'selection_reason' in open('npc_empire.py', encoding='utf-8').read()
        assert '101|building:0,3' not in world
        passed.append('safe-ui-contract')

        assert len(passed) == 10, passed
        print('raid target memory: 10/10 focused gates OK — ' + ', '.join(passed))
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
