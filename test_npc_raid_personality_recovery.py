"""Repulsed raids produce bounded, personality-aware, durable recovery."""

import asyncio
import importlib
import os
import sqlite3
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db
from test_npc_raid_target_memory import _create, _row, _targets


async def _defend(path, uid, raid, now):
    return await ne.resolve_interior_raid(
        path, uid, raid['token'], raid['apt_key'], 'defended',
        attacker_casualties=list(range(raid['force'])),
        defender_casualties=[], guard_casualties=[], now=now)


async def _war_row(path, leader, uid=101):
    return await _row(
        path, "SELECT next_attack_at,last_attack_at FROM npc_empire_player_wars "
        "WHERE leader_id=? AND telegram_id=?", (leader, uid))


async def run():
    fd, path = tempfile.mkstemp(prefix='npc_raid_personality_recovery_', suffix='.db')
    os.close(fd)
    now = 2_600_000_000
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
            for leader in ('leila', 'zara', 'emil', 'niko', 'marco', 'sofia'):
                await db.execute(
                    "INSERT OR REPLACE INTO npc_empire_relations"
                    "(leader_id,telegram_id,score,pact,last_action_at) "
                    "VALUES(?,101,-100,'war',?)", (leader, now))
                await db.execute(
                    "UPDATE npc_empires SET members=12,strength=360,treasury=50000 "
                    "WHERE leader_id=?", (leader,))
                await db.execute(
                    "INSERT OR REPLACE INTO npc_empire_player_wars"
                    "(leader_id,telegram_id,next_attack_at,attacks,last_attack_at) "
                    "VALUES(?,101,?,0,0)", (leader, now + 99999))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations"
                "(leader_id,telegram_id,score,pact,last_action_at) "
                "VALUES('leila',202,-100,'war',?)", (now,))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars"
                "(leader_id,telegram_id,next_attack_at,attacks,last_attack_at) "
                "VALUES('leila',202,?,0,0)", (now + 99999,))
            await db.commit()

        base = 1800
        leila = ne.PROFILE_BY_ID['leila']
        # 1. The pure boundary never shortens cadence; zero loss is unchanged.
        assert ne._repulsed_raid_recovery_delay(leila, base, 0, 8) == base
        severe = ne._repulsed_raid_recovery_delay(leila, base, 8, 8)
        assert base < severe <= base * 2
        passed.append('hard-boundaries')

        # 2. Temperament changes equal-loss recovery, not the global base interval.
        patient = ne._repulsed_raid_recovery_delay(
            ne.PROFILE_BY_ID['zara'], base, 8, 8)
        aggressive = ne._repulsed_raid_recovery_delay(
            ne.PROFILE_BY_ID['emil'], base, 8, 8)
        assert patient > aggressive > base
        passed.append('personality-order')

        # 3. Authoritative absolute losses distinguish a probe from a full squad.
        light = ne._repulsed_raid_recovery_delay(leila, base, 2, 8)
        heavy = ne._repulsed_raid_recovery_delay(leila, base, 8, 8)
        assert base < light < heavy
        passed.append('loss-severity')

        targets = await _targets(path)
        first, second = targets[:2]
        # 4. A defended raid persists the exact personality recovery schedule.
        raid = await _create(path, 101, 'leila', first, 0, now)
        resolved_at = now + ne.PLAYER_INTERIOR_RAID_MIN_SECONDS
        result = await _defend(path, 101, raid, resolved_at)
        assert result['ok'] and result['attacker_losses'] == raid['force']
        expected = ne._repulsed_raid_recovery_delay(
            leila, ne._player_war_interval(leila), raid['force'], raid['force'])
        assert int((await _war_row(path, 'leila'))['next_attack_at']) == resolved_at + expected
        passed.append('persisted-schedule')

        # 5. Reload/reconnect exposes only a qualitative server-authored reason.
        state = await ne.state_for(path, 101, now=resolved_at + 1)
        leila_state = next(e for e in state['empires'] if e['leader_id'] == 'leila')
        assert leila_state['war_pressure']['recovery'] == {
            'state': 'regrouping',
            'label': 'Семья перегруппировывается после отражённого налёта'}
        reloaded = importlib.reload(ne)
        reconnect = await reloaded.state_for(path, 101, now=resolved_at + 2)
        assert next(e for e in reconnect['empires'] if e['leader_id'] == 'leila')[
            'war_pressure']['recovery']['state'] == 'regrouping'
        other_player = await reloaded.state_for(path, 202, now=resolved_at + 2)
        assert 'recovery' not in next(e for e in other_player['empires']
                                      if e['leader_id'] == 'leila')['war_pressure']
        passed.append('reload-public-isolation')

        # 6. Sequential replay cannot extend the persisted deadline.
        before_replay = int((await _war_row(path, 'leila'))['next_attack_at'])
        duplicate = await _defend(path, 101, raid, resolved_at + 500)
        assert duplicate == {'ok': True, 'duplicate': True, 'resolution': 'defended'}
        assert int((await _war_row(path, 'leila'))['next_attack_at']) == before_replay
        passed.append('replay-once')

        # 7. An active tribute composes exactly once with personality recovery.
        async with aiosqlite.connect(path) as db:
            generation = int((await (await db.execute(
                "SELECT comebacks FROM npc_empires WHERE leader_id='sofia'")).fetchone())[0])
            await db.execute(
                "INSERT INTO npc_empire_player_tribute_agreements"
                "(leader_id,leader_generation,telegram_id,agreement_id,offer_request_key,"
                "accept_request_key,term_amount,term_seconds,status,relation_at_offer,"
                "pact_at_offer,created_at,offer_expires_at,accepted_at,active_until) "
                "VALUES('sofia',?,101,'recovery-tribute','offer-recovery','accept-recovery',"
                "150,3600,'active',-100,'war',?,?,?,?)",
                (generation, now, now + 1800, now, now + 7200))
            await db.commit()
        tribute_raid = await _create(path, 101, 'sofia', second, 0, now + 100)
        tribute_at = now + 100 + reloaded.PLAYER_INTERIOR_RAID_MIN_SECONDS
        assert (await _defend(path, 101, tribute_raid, tribute_at))['ok']
        sofia = reloaded.PROFILE_BY_ID['sofia']
        normal_recovery = reloaded._repulsed_raid_recovery_delay(
            sofia, reloaded._player_war_interval(sofia),
            tribute_raid['force'], tribute_raid['force'])
        assert int((await _war_row(path, 'sofia'))['next_attack_at']) == (
            tribute_at + normal_recovery * reloaded.NPC_PLAYER_TRIBUTE_DELAY_MULTIPLIER)
        passed.append('tribute-compose-once')

        # 8. Two concurrent resolvers produce one schedule and one duplicate.
        concurrent_raid = await _create(path, 101, 'marco', first, 0, now + 200)
        concurrent_at = now + 200 + reloaded.PLAYER_INTERIOR_RAID_MIN_SECONDS
        replies = await asyncio.gather(*[
            _defend(path, 101, concurrent_raid, concurrent_at) for _ in range(2)])
        assert sum(bool(reply.get('duplicate')) for reply in replies) == 1
        marco = reloaded.PROFILE_BY_ID['marco']
        marco_delay = reloaded._repulsed_raid_recovery_delay(
            marco, reloaded._player_war_interval(marco),
            concurrent_raid['force'], concurrent_raid['force'])
        assert int((await _war_row(path, 'marco'))['next_attack_at']) == concurrent_at + marco_delay
        passed.append('concurrent-once')

        # 9. A late schedule failure rolls back raid, casualties, memory and time.
        rollback_raid = await _create(path, 101, 'niko', second, 0, now + 300)
        before = tuple(await _row(path,
            "SELECT e.members,r.status,w.next_attack_at FROM npc_empires e "
            "JOIN npc_empire_interior_raids r ON r.leader_id=e.leader_id "
            "JOIN npc_empire_player_wars w ON w.leader_id=e.leader_id "
            "AND w.telegram_id=r.telegram_id WHERE r.token=?", (rollback_raid['token'],)))
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "CREATE TRIGGER reject_recovery BEFORE UPDATE OF next_attack_at "
                "ON npc_empire_player_wars WHEN NEW.leader_id='niko' "
                "BEGIN SELECT RAISE(ABORT,'recovery rollback'); END")
            await db.commit()
        try:
            await _defend(
                path, 101, rollback_raid,
                now + 300 + reloaded.PLAYER_INTERIOR_RAID_MIN_SECONDS)
            raise AssertionError('forced recovery failure must abort')
        except sqlite3.IntegrityError as exc:
            assert 'recovery rollback' in str(exc)
        after = tuple(await _row(path,
            "SELECT e.members,r.status,w.next_attack_at FROM npc_empires e "
            "JOIN npc_empire_interior_raids r ON r.leader_id=e.leader_id "
            "JOIN npc_empire_player_wars w ON w.leader_id=e.leader_id "
            "AND w.telegram_id=r.telegram_id WHERE r.token=?", (rollback_raid['token'],)))
        assert after == before and after[1] == 'pending'
        assert not await _row(path,
            "SELECT 1 FROM npc_empire_memory_events WHERE leader_id='niko' "
            "AND kind='raid_defended'")
        passed.append('late-rollback')

        # 10. Impossible/captured outcomes do not create a recovery witness.
        impossible = await _create(path, 101, 'emil', first, 0, now + 400)
        old_emil = int((await _war_row(path, 'emil'))['next_attack_at'])
        rejected = await reloaded.resolve_interior_raid(
            path, 101, impossible['token'], impossible['apt_key'], 'defended',
            attacker_casualties=[], defender_casualties=[], guard_casualties=[],
            now=now + 400 + reloaded.PLAYER_INTERIOR_RAID_MIN_SECONDS)
        assert not rejected['ok'] and rejected['error'] == 'impossible defended outcome'
        assert int((await _war_row(path, 'emil'))['next_attack_at']) == old_emil
        world = open('world.html', encoding='utf-8').read()
        assert 'data-ne-recovery-state="regrouping"' in world
        assert 'Семья перегруппировывается после отражённого налёта' in world
        passed.append('rejected-safe-ui')

        assert len(passed) == 10, passed
        print('raid personality recovery: 10/10 focused gates OK — ' + ', '.join(passed))
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
