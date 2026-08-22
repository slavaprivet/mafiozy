"""Pending interior raids cannot outlive war or property ownership authority."""

import asyncio
import os
import sqlite3
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


async def scalar(path, sql, args=()):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql, args)).fetchone()
        return row[0] if row else None


async def prepare_pending_raid(path: str, now: int) -> dict:
    await _base_db(path)
    async with aiosqlite.connect(path) as db:
        await db.executescript("""
            CREATE TABLE gang_members(
                id INTEGER PRIMARY KEY,telegram_id INTEGER,current_hp INTEGER);
            CREATE TABLE district_control(
                telegram_id INTEGER,loc_id TEXT,guard_json TEXT);
            INSERT INTO gang_members VALUES(1,101,100);
            INSERT INTO district_control VALUES(101,'north','[]');
            INSERT INTO player_businesses
                VALUES(101,'coffee',0,0,'ok',0,0,1,0,NULL);
        """)
        await db.execute(
            "INSERT INTO business_property_owners VALUES('coffee',101,'One',?,0)",
            (now - 100,))
        await db.execute(
            "INSERT OR REPLACE INTO npc_empire_relations "
            "VALUES('leila',101,-100,'war',?)", (now,))
        await db.execute(
            "INSERT OR REPLACE INTO npc_empire_player_wars "
            "VALUES('leila',101,?,0,'',0)", (now,))
        await db.execute(
            "UPDATE npc_empires SET status=CASE WHEN leader_id IN ('leila','marco') "
            "THEN 'active' ELSE 'ruined' END,members=12,strength=360,"
            "treasury=50000,next_action_at=?", (now + 10_000,))
        await db.commit()
    assigned = await ne.assign_holding_guards(
        path, owner_kind='player', owner_id='101',
        holding_ref='business:coffee', requested=1, now=now - 1)
    assert assigned['ok'] and assigned['holding_guards'] == 1
    state = await ne.state_for(path, 101, now=now)
    assert len(state['interior_raids']) == 1
    raid = state['interior_raids'][0]
    assert await scalar(
        path, "SELECT target_ref FROM npc_empire_interior_raids WHERE token=?",
        (raid['token'],)) == 'business:coffee'
    return raid


async def vassalization_terminalizes_pending() -> None:
    fd, path = tempfile.mkstemp(prefix='raid_vassal_generation_', suffix='.db')
    os.close(fd); now = 3_200_000_000
    try:
        raid = await prepare_pending_raid(path, now)
        async with aiosqlite.connect(path) as db:
            await db.execute("INSERT INTO district_control VALUES(202,'south','[]')")
            await db.execute(
                "INSERT INTO player_businesses "
                "VALUES(202,'donut',0,0,'ok',0,0,1,0,NULL)")
            await db.execute(
                "INSERT INTO business_property_owners "
                "VALUES('donut',202,'Two',?,0)", (now - 100,))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations "
                "VALUES('leila',202,-100,'war',?)", (now,))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars "
                "VALUES('leila',202,?,0,'',0)", (now,))
            await db.commit()
        other_owner_raid = (await ne.state_for(path, 202, now=now))['interior_raids'][0]
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            source = await (await db.execute(
                "SELECT * FROM npc_empire_interior_raids WHERE token=?",
                (other_owner_raid['token'],))).fetchone()
            isolated = dict(source)
            isolated['token'] = 'other-family-pending'
            isolated['leader_id'] = 'marco'
            columns = list(isolated)
            await db.execute(
                f"INSERT INTO npc_empire_interior_raids({','.join(columns)}) "
                f"VALUES({','.join('?' for _ in columns)})",
                tuple(isolated[name] for name in columns))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars "
                "VALUES('marco',202,?,0,'',0)", (now + 500,))
            await db.execute(
                "INSERT INTO npc_empire_assaults"
                "(token,telegram_id,leader_id,guard_hp_json,boss_hp,boss_max_hp,"
                "status,started_at,expires_at,last_hit_at) "
                "VALUES('won-vassal',101,'leila','[]',0,300,'active',?,?,?)",
                (now, now + 10_000, float(now)))
            await db.commit()
        result = await ne.resolve_assault(
            path, 101, 'won-vassal', 'vassalize', now=now + 1)
        assert result['ok'] and result['choice'] == 'vassalize'
        assert await scalar(
            path, "SELECT status||':'||resolution FROM npc_empire_interior_raids "
                  "WHERE token=?", (raid['token'],)) == 'resolved:diplomacy_changed'
        assert await scalar(
            path, "SELECT status||':'||resolution FROM npc_empire_interior_raids "
                  "WHERE token=?", (other_owner_raid['token'],)) \
            == 'resolved:diplomacy_changed'
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE leader_id='leila'") == 0
        assert await scalar(
            path, "SELECT status FROM npc_empire_interior_raids "
                  "WHERE token='other-family-pending'") == 'pending'
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE telegram_id=202 AND leader_id='marco'") == 1
        retry = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'captured',
            attacker_casualties=[], defender_casualties=[1], guard_casualties=[],
            now=now + raid['hold_seconds'])
        assert retry == {'ok': True, 'duplicate': True,
                         'resolution': 'diplomacy_changed'}
        other_retry = await ne.resolve_interior_raid(
            path, 202, other_owner_raid['token'], other_owner_raid['apt_key'],
            'captured', attacker_casualties=[], defender_casualties=[],
            guard_casualties=[], now=now + other_owner_raid['hold_seconds'])
        assert other_retry == {'ok': True, 'duplicate': True,
                               'resolution': 'diplomacy_changed'}
        assert await scalar(path, "SELECT current_hp FROM gang_members WHERE id=1") == 100
        assert await scalar(
            path, "SELECT blocked_until FROM player_businesses "
                  "WHERE telegram_id=101 AND biz_id='coffee'") == 0
        assert await scalar(
            path, "SELECT blocked_until FROM player_businesses "
                  "WHERE telegram_id=202 AND biz_id='donut'") == 0
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events "
                  "WHERE kind IN ('player_business_bombed','player_business_captured')") == 0
    finally:
        os.unlink(path)


async def pair_peace_terminalizes_pending(action: str, now: int) -> None:
    fd, path = tempfile.mkstemp(prefix=f'raid_{action}_generation_', suffix='.db')
    os.close(fd)
    try:
        raid = await prepare_pending_raid(path, now)
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empire_relations SET score=-60 "
                "WHERE leader_id='leila' AND telegram_id=101")
            await db.execute("INSERT INTO district_control VALUES(202,'south','[]')")
            await db.execute(
                "INSERT INTO player_businesses "
                "VALUES(202,'donut',0,0,'ok',0,0,1,0,NULL)")
            await db.execute(
                "INSERT INTO business_property_owners "
                "VALUES('donut',202,'Two',?,0)", (now - 100,))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations "
                "VALUES('leila',202,-100,'war',?)", (now,))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars "
                "VALUES('leila',202,?,0,'',0)", (now,))
            await db.commit()
        other_player_raid = (await ne.state_for(path, 202, now=now))['interior_raids'][0]
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            source = await (await db.execute(
                "SELECT * FROM npc_empire_interior_raids WHERE token=?",
                (other_player_raid['token'],))).fetchone()
            other_family = dict(source)
            other_family['token'] = f'other-family-{action}'
            other_family['leader_id'] = 'marco'
            columns = list(other_family)
            await db.execute(
                f"INSERT INTO npc_empire_interior_raids({','.join(columns)}) "
                f"VALUES({','.join('?' for _ in columns)})",
                tuple(other_family[name] for name in columns))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars "
                "VALUES('marco',202,?,0,'',0)", (now + 500,))
            await db.commit()

        hp_before = await scalar(
            path, "SELECT current_hp FROM gang_members WHERE id=1")
        cash_before = await scalar(
            path, "SELECT cash FROM characters WHERE telegram_id=101")
        transition_at = now + 1
        if action == 'truce':
            offer = await ne.conditional_truce_action(
                path, 101, 'leila', 'offer',
                f'stale-generation:{now}:truce-offer', now=transition_at)
            assert offer['ok'] and not offer['duplicate']
            agreement = offer['agreement']
            assert agreement['kind'] == 'conditional_truce'
            assert agreement['state'] == 'offered'
            assert agreement['action'] == 'fulfill'
            assert agreement['terms'] == [{
                'kind': 'compensation', 'label': 'Компенсация $300',
                'state': 'pending'}]
            async with aiosqlite.connect(path) as db:
                db.row_factory = aiosqlite.Row
                generation = int((await (await db.execute(
                    "SELECT comebacks FROM npc_empires WHERE leader_id='leila'"
                )).fetchone())[0])
                agreement_row = await (await db.execute(
                    "SELECT leader_id,leader_generation,telegram_id,term_kind,"
                    "term_amount,status,created_at,expires_at FROM "
                    "npc_empire_player_agreements WHERE agreement_id=?",
                    (agreement['agreement_id'],))).fetchone()
            assert dict(agreement_row) == {
                'leader_id': 'leila', 'leader_generation': generation,
                'telegram_id': 101, 'term_kind': 'compensation',
                'term_amount': 300, 'status': 'offered',
                'created_at': transition_at,
                'expires_at': transition_at + 1800,
            }
            assert await scalar(
                path, "SELECT pact FROM npc_empire_relations "
                      "WHERE leader_id='leila' AND telegram_id=101") == 'war'
            assert await scalar(
                path, "SELECT status FROM npc_empire_interior_raids "
                      "WHERE token=?", (raid['token'],)) == 'pending'
            assert await scalar(
                path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                      "WHERE leader_id='leila' AND telegram_id=101") == 1
            assert await scalar(
                path, "SELECT cash FROM characters WHERE telegram_id=101") \
                == cash_before
            transition_at += 1
            result = await ne.conditional_truce_action(
                path, 101, 'leila', 'fulfill',
                f'stale-generation:{now}:truce-fulfill',
                agreement['agreement_id'], transition_at)
            assert result['ok'] and not result['duplicate']
            assert result['relation'] == -20 and result['cost'] == 300
            assert result['cash'] == cash_before - 300
            assert result['agreement']['agreement_id'] == agreement['agreement_id']
            assert result['agreement']['state'] == 'fulfilled'
            assert result['agreement']['terms'][0]['state'] == 'met'
            assert await scalar(
                path, "SELECT cash FROM characters WHERE telegram_id=101") \
                == cash_before - 300
            assert await scalar(
                path, "SELECT status FROM npc_empire_player_agreements "
                      "WHERE agreement_id=?", (agreement['agreement_id'],)) \
                == 'fulfilled'
        else:
            result = await ne.diplomacy_action(
                path, 101, 'leila', action, now=transition_at)
        assert result['ok'] and result['pact'] == 'truce'
        assert await scalar(
            path, "SELECT status||':'||resolution FROM npc_empire_interior_raids "
                  "WHERE token=?", (raid['token'],)) == 'resolved:diplomacy_changed'
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE leader_id='leila' AND telegram_id=101") == 0
        assert await scalar(
            path, "SELECT status FROM npc_empire_interior_raids WHERE token=?",
            (other_player_raid['token'],)) == 'pending'
        assert await scalar(
            path, "SELECT status FROM npc_empire_interior_raids WHERE token=?",
            (other_family['token'],)) == 'pending'
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE leader_id='leila' AND telegram_id=202") == 1
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE leader_id='marco' AND telegram_id=202") == 1

        checkpoint = await ne.checkpoint_interior_raid_casualties(
            path, 101, raid['token'], raid['apt_key'], attacker_delta=[0],
            now=transition_at + 1)
        assert checkpoint == {
            'ok': True, 'duplicate': True, 'terminal': True,
            'resolution': 'diplomacy_changed', 'version': 0}
        checkpoint_retry = await ne.checkpoint_interior_raid_casualties(
            path, 101, raid['token'], raid['apt_key'], attacker_delta=[0],
            now=transition_at + 2)
        assert checkpoint_retry == checkpoint
        resolve_retry = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'captured',
            attacker_casualties=[0], defender_casualties=[1],
            guard_casualties=[], now=now + raid['hold_seconds'])
        assert resolve_retry == {'ok': True, 'duplicate': True,
                                 'resolution': 'diplomacy_changed'}
        assert await scalar(
            path, "SELECT casualty_version FROM npc_empire_interior_raids "
                  "WHERE token=?", (raid['token'],)) == 0
        assert await scalar(
            path, "SELECT attacker_down_json FROM npc_empire_interior_raids "
                  "WHERE token=?", (raid['token'],)) == '[]'
        assert await scalar(
            path, "SELECT current_hp FROM gang_members WHERE id=1") == hp_before == 100
    finally:
        os.unlink(path)


async def ruin_releases_family_player_wars() -> None:
    fd, path = tempfile.mkstemp(prefix='raid_ruin_generation_', suffix='.db')
    os.close(fd); now = 3_280_000_000
    try:
        raid = await prepare_pending_raid(path, now)
        async with aiosqlite.connect(path) as db:
            await db.execute("INSERT INTO district_control VALUES(202,'south','[]')")
            await db.execute(
                "INSERT INTO player_businesses "
                "VALUES(202,'donut',0,0,'ok',0,0,1,0,NULL)")
            await db.execute(
                "INSERT INTO business_property_owners "
                "VALUES('donut',202,'Two',?,0)", (now - 100,))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations "
                "VALUES('leila',202,-100,'war',?)", (now,))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars "
                "VALUES('leila',202,?,0,'',0)", (now,))
            await db.commit()
        other_player_raid = (await ne.state_for(path, 202, now=now))['interior_raids'][0]
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            source = await (await db.execute(
                "SELECT * FROM npc_empire_interior_raids WHERE token=?",
                (other_player_raid['token'],))).fetchone()
            other_family = dict(source)
            other_family['token'] = 'other-family-ruin'
            other_family['leader_id'] = 'marco'
            columns = list(other_family)
            await db.execute(
                f"INSERT INTO npc_empire_interior_raids({','.join(columns)}) "
                f"VALUES({','.join('?' for _ in columns)})",
                tuple(other_family[name] for name in columns))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars "
                "VALUES('marco',202,?,0,'',0)", (now + 500,))
            await db.execute(
                "INSERT INTO npc_empire_assaults"
                "(token,telegram_id,leader_id,guard_hp_json,boss_hp,boss_max_hp,"
                "status,started_at,expires_at,last_hit_at) "
                "VALUES('won-ruin',101,'leila','[]',0,300,'active',?,?,?)",
                (now, now + 10_000, float(now)))
            await db.commit()

        hp_before = await scalar(
            path, "SELECT current_hp FROM gang_members WHERE id=1")
        result = await ne.resolve_assault(
            path, 101, 'won-ruin', 'loot', now=now + 1)
        assert result['ok'] and result['choice'] == 'loot'
        assert await scalar(
            path, "SELECT status FROM npc_empires WHERE leader_id='leila'") == 'ruined'
        for token in (raid['token'], other_player_raid['token']):
            assert await scalar(
                path, "SELECT status||':'||resolution "
                      "FROM npc_empire_interior_raids WHERE token=?", (token,)) \
                == 'resolved:owner_ruined'
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE leader_id='leila'") == 0
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_relations "
                  "WHERE leader_id='leila' AND (score<>0 OR pact<>'none')") == 0
        assert await scalar(
            path, "SELECT status FROM npc_empire_interior_raids "
                  "WHERE token='other-family-ruin'") == 'pending'
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE leader_id='marco' AND telegram_id=202") == 1

        checkpoint = await ne.checkpoint_interior_raid_casualties(
            path, 101, raid['token'], raid['apt_key'], attacker_delta=[0],
            now=now + 2)
        assert checkpoint == {
            'ok': True, 'duplicate': True, 'terminal': True,
            'resolution': 'owner_ruined', 'version': 0}
        retry = await ne.resolve_interior_raid(
            path, 202, other_player_raid['token'], other_player_raid['apt_key'],
            'captured', attacker_casualties=[], defender_casualties=[],
            guard_casualties=[], now=now + other_player_raid['hold_seconds'])
        assert retry == {'ok': True, 'duplicate': True,
                         'resolution': 'owner_ruined'}
        assert await scalar(
            path, "SELECT current_hp FROM gang_members WHERE id=1") == hp_before == 100

        # A pre-fix stale row must be removed before a ruined generation returns,
        # so it cannot create false war upkeep, guard reserve or AI pressure.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars "
                "VALUES('leila',101,?,0,'',0)", (now + 500,))
            await db.execute(
                "UPDATE npc_empires SET comeback_at=? WHERE leader_id='leila'",
                (now + 2,))
            await db.commit()
        await ne.advance(path, now=now + 3)
        assert await scalar(
            path, "SELECT status FROM npc_empires WHERE leader_id='leila'") == 'rebuilding'
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE leader_id='leila'") == 0
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE leader_id='marco' AND telegram_id=202") == 1
    finally:
        os.unlink(path)


async def vassal_diplomacy_cannot_restore_player_war() -> None:
    fd, path = tempfile.mkstemp(prefix='vassal_diplomacy_authority_', suffix='.db')
    os.close(fd); now = 3_290_000_000
    try:
        await _base_db(path)
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            await db.execute(
                "UPDATE npc_empires SET status='vassal',members=12 "
                "WHERE leader_id='leila'")
            await db.execute(
                "UPDATE npc_empires SET status='active' WHERE leader_id='marco'")
            await db.executemany(
                "INSERT OR REPLACE INTO npc_empire_relations "
                "VALUES(?,?,?,?,?)",
                [('leila', 101, 80, 'vassal', now),
                 ('leila', 202, -10, 'none', now),
                 ('marco', 101, -10, 'none', now)])
            await ne._reconcile_npc_guards(db, 'leila', now)
            await db.commit()
        guards_before = await scalar(
            path, "SELECT COALESCE(SUM(living),0) FROM npc_empire_guard_assignments "
                  "WHERE owner_kind='npc' AND owner_id='leila'")

        concurrent = await asyncio.gather(
            ne.diplomacy_action(path, 101, 'leila', 'street_attack', now=now + 1),
            ne.diplomacy_action(path, 101, 'leila', 'street_attack', now=now + 1))
        assert all(item['ok'] and item['pact'] == 'vassal' for item in concurrent)
        assert await scalar(
            path, "SELECT score FROM npc_empire_relations "
                  "WHERE leader_id='leila' AND telegram_id=101") == -13
        assert await scalar(
            path, "SELECT pact FROM npc_empire_relations "
                  "WHERE leader_id='leila' AND telegram_id=101") == 'vassal'
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE leader_id='leila'") == 0
        assert await scalar(
            path, "SELECT COALESCE(SUM(living),0) FROM npc_empire_guard_assignments "
                  "WHERE owner_kind='npc' AND owner_id='leila'") == guards_before

        declared = await ne.diplomacy_action(
            path, 101, 'leila', 'declare_war', now=now + 2)
        assert declared == {'ok': False, 'error': 'leader vassal'}
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_relation_actions "
                  "WHERE leader_id='leila' AND telegram_id=101 "
                  "AND action_kind='declare_war'") == 0
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events "
                  "WHERE leader_id='leila' AND kind='player_attack' "
                  "AND target_id='101'") == 2

        other_player = await ne.diplomacy_action(
            path, 202, 'leila', 'street_attack', now=now + 3)
        assert other_player['ok'] and other_player['pact'] == 'none'
        assert await scalar(
            path, "SELECT pact FROM npc_empire_relations "
                  "WHERE leader_id='leila' AND telegram_id=101") == 'vassal'
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE leader_id='leila'") == 0

        rollback_score = await scalar(
            path, "SELECT score FROM npc_empire_relations "
                  "WHERE leader_id='leila' AND telegram_id=202")
        rollback_action_at = await scalar(
            path, "SELECT last_action_at FROM npc_empire_relation_actions "
                  "WHERE leader_id='leila' AND telegram_id=202 "
                  "AND action_kind='street_attack'")
        rollback_events = await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events "
                  "WHERE leader_id='leila' AND kind='player_attack'")
        async with aiosqlite.connect(path) as db:
            await db.execute("""
                CREATE TRIGGER reject_vassal_attack_event
                BEFORE INSERT ON npc_empire_events
                WHEN NEW.leader_id='leila' AND NEW.kind='player_attack'
                BEGIN SELECT RAISE(ABORT, 'forced vassal diplomacy rollback'); END
            """)
            await db.commit()
        try:
            await ne.diplomacy_action(
                path, 202, 'leila', 'street_attack', now=now + 4)
            raise AssertionError('forced vassal diplomacy failure did not abort')
        except sqlite3.IntegrityError as error:
            assert 'forced vassal diplomacy rollback' in str(error)
        finally:
            async with aiosqlite.connect(path) as db:
                await db.execute("DROP TRIGGER reject_vassal_attack_event")
                await db.commit()
        assert await scalar(
            path, "SELECT score FROM npc_empire_relations "
                  "WHERE leader_id='leila' AND telegram_id=202") == rollback_score
        assert await scalar(
            path, "SELECT last_action_at FROM npc_empire_relation_actions "
                  "WHERE leader_id='leila' AND telegram_id=202 "
                  "AND action_kind='street_attack'") == rollback_action_at
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events "
                  "WHERE leader_id='leila' AND kind='player_attack'") == rollback_events
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE leader_id='leila'") == 0
        assert await scalar(
            path, "SELECT COALESCE(SUM(living),0) FROM npc_empire_guard_assignments "
                  "WHERE owner_kind='npc' AND owner_id='leila'") == guards_before

        state = await ne.state_for(path, 101, now=now + 5)
        leila = next(item for item in state['empires']
                     if item['leader_id'] == 'leila')
        assert leila['status'] == 'vassal' and leila['pact'] == 'vassal'
        assert leila['war_pressure'] is None

        active_family = await ne.diplomacy_action(
            path, 101, 'marco', 'street_attack', now=now + 6)
        assert active_family['ok'] and active_family['pact'] == 'war'
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE leader_id='marco' AND telegram_id=101") == 1
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE leader_id='leila'") == 0
    finally:
        os.unlink(path)


async def ownership_generation_terminalizes_pending() -> None:
    fd, path = tempfile.mkstemp(prefix='raid_owner_generation_', suffix='.db')
    os.close(fd); now = 3_300_000_000
    try:
        raid = await prepare_pending_raid(path, now)
        members_before = await scalar(
            path, "SELECT members FROM npc_empires WHERE leader_id='leila'")
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            source = await (await db.execute(
                "SELECT * FROM npc_empire_interior_raids WHERE token=?",
                (raid['token'],))).fetchone()
            for token, telegram_id, leader_id in (
                    ('other-owner-checkpoint', 202, 'leila'),
                    ('other-family-checkpoint', 101, 'marco')):
                isolated = dict(source)
                isolated['token'] = token
                isolated['telegram_id'] = telegram_id
                isolated['leader_id'] = leader_id
                columns = list(isolated)
                await db.execute(
                    f"INSERT INTO npc_empire_interior_raids({','.join(columns)}) "
                    f"VALUES({','.join('?' for _ in columns)})",
                    tuple(isolated[name] for name in columns))
            await db.execute("DELETE FROM player_businesses WHERE biz_id='coffee'")
            await db.execute(
                "INSERT INTO player_businesses "
                "VALUES(202,'coffee',?,?,'ok',0,0,1,0,NULL)", (now + 1, now + 1))
            await db.execute(
                "UPDATE business_property_owners SET owner_uid=202,owner_name='Two',"
                "acquired_at=? WHERE biz_id='coffee'", (now + 1,))
            await db.commit()
        stale = await ne.checkpoint_interior_raid_casualties(
            path, 101, raid['token'], raid['apt_key'], attacker_delta=[0],
            now=now + 2)
        assert stale == {'ok': False, 'error': 'raid no longer active',
                         'resolution': 'ownership_changed'}
        assert await scalar(
            path, "SELECT casualty_version FROM npc_empire_interior_raids "
                  "WHERE token=?", (raid['token'],)) == 0
        assert await scalar(
            path, "SELECT attacker_down_json FROM npc_empire_interior_raids "
                  "WHERE token=?", (raid['token'],)) == '[]'
        for token in ('other-owner-checkpoint', 'other-family-checkpoint'):
            assert await scalar(
                path, "SELECT status FROM npc_empire_interior_raids WHERE token=?",
                (token,)) == 'pending'
            assert await scalar(
                path, "SELECT casualty_version FROM npc_empire_interior_raids "
                      "WHERE token=?", (token,)) == 0
        checkpoint_retry = await ne.checkpoint_interior_raid_casualties(
            path, 101, raid['token'], raid['apt_key'], attacker_delta=[0],
            now=now + 3)
        assert checkpoint_retry == {
            'ok': True, 'duplicate': True, 'terminal': True,
            'resolution': 'ownership_changed', 'version': 0}
        resolve_retry = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'captured',
            attacker_casualties=[], defender_casualties=[1], guard_casualties=[],
            now=now + raid['hold_seconds'])
        assert resolve_retry == {'ok': True, 'duplicate': True,
                                 'resolution': 'ownership_changed'}
        assert await scalar(
            path, "SELECT status||':'||resolution FROM npc_empire_interior_raids "
                  "WHERE token=?", (raid['token'],)) == 'resolved:ownership_changed'
        assert await scalar(path, "SELECT current_hp FROM gang_members WHERE id=1") == 100
        assert await scalar(
            path, "SELECT members FROM npc_empires WHERE leader_id='leila'") == members_before
        assert str(await scalar(
            path, "SELECT owner_uid FROM business_property_owners "
                  "WHERE biz_id='coffee'")) == '202'
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events "
                  "WHERE kind IN ('player_business_bombed','player_business_captured')") == 0
        retry = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'captured',
            attacker_casualties=[], defender_casualties=[1], guard_casualties=[],
            now=now + raid['hold_seconds'] + 1)
        assert retry == {'ok': True, 'duplicate': True,
                         'resolution': 'ownership_changed'}
    finally:
        os.unlink(path)


async def direct_resolve_stale_precedes_payload_validation() -> None:
    fd, path = tempfile.mkstemp(prefix='raid_direct_stale_', suffix='.db')
    os.close(fd); now = 3_400_000_000
    try:
        raid = await prepare_pending_raid(path, now)
        members_before = await scalar(
            path, "SELECT members FROM npc_empires WHERE leader_id='leila'")
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            source = await (await db.execute(
                "SELECT * FROM npc_empire_interior_raids WHERE token=?",
                (raid['token'],))).fetchone()
            for token, telegram_id, leader_id in (
                    ('direct-other-owner', 202, 'leila'),
                    ('direct-other-family', 101, 'marco')):
                isolated = dict(source)
                isolated['token'] = token
                isolated['telegram_id'] = telegram_id
                isolated['leader_id'] = leader_id
                columns = list(isolated)
                await db.execute(
                    f"INSERT INTO npc_empire_interior_raids({','.join(columns)}) "
                    f"VALUES({','.join('?' for _ in columns)})",
                    tuple(isolated[name] for name in columns))
            await db.execute(
                "UPDATE business_property_owners SET acquired_at=? WHERE biz_id='coffee'",
                (now + 1,))
            await db.commit()

        stale = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'captured',
            attacker_casualties=[], defender_casualties=[], guard_casualties=[],
            now=now + raid['hold_seconds'])
        assert stale == {'ok': False, 'error': 'raid no longer active',
                         'resolution': 'ownership_changed'}
        assert await scalar(
            path, "SELECT status||':'||resolution FROM npc_empire_interior_raids "
                  "WHERE token=?", (raid['token'],)) == 'resolved:ownership_changed'
        assert await scalar(
            path, "SELECT casualty_version FROM npc_empire_interior_raids "
                  "WHERE token=?", (raid['token'],)) == 0
        assert await scalar(
            path, "SELECT attacker_down_json FROM npc_empire_interior_raids "
                  "WHERE token=?", (raid['token'],)) == '[]'
        for token in ('direct-other-owner', 'direct-other-family'):
            assert await scalar(
                path, "SELECT status FROM npc_empire_interior_raids WHERE token=?",
                (token,)) == 'pending'
            assert await scalar(
                path, "SELECT casualty_version FROM npc_empire_interior_raids "
                      "WHERE token=?", (token,)) == 0

        retry = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'captured',
            attacker_casualties=[999], defender_casualties=[999],
            guard_casualties=[999], now=now + raid['hold_seconds'] + 1)
        assert retry == {'ok': True, 'duplicate': True,
                         'resolution': 'ownership_changed'}
        state = await ne.state_for(path, 101, now=now + raid['hold_seconds'] + 2)
        assert all(item['token'] != raid['token'] for item in state['interior_raids'])
        assert await scalar(path, "SELECT current_hp FROM gang_members WHERE id=1") == 100
        assert await scalar(
            path, "SELECT members FROM npc_empires WHERE leader_id='leila'") == members_before
        assert await scalar(
            path, "SELECT blocked_until FROM player_businesses "
                  "WHERE telegram_id=101 AND biz_id='coffee'") == 0
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events "
                  "WHERE kind IN ('player_business_bombed','player_business_captured')") == 0
    finally:
        os.unlink(path)


async def run() -> None:
    await vassalization_terminalizes_pending()
    await pair_peace_terminalizes_pending('truce', 3_250_000_000)
    await pair_peace_terminalizes_pending('compensation', 3_260_000_000)
    await ruin_releases_family_player_wars()
    await vassal_diplomacy_cannot_restore_player_war()
    await ownership_generation_terminalizes_pending()
    await direct_resolve_stale_precedes_payload_validation()
    print('stale raid generation: diplomacy/ownership terminal, no casualties or property mutation OK')


if __name__ == '__main__':
    asyncio.run(run())
