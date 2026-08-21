"""Typed, bounded and pair-isolated memory for a won HQ assault."""

import asyncio
import json
import os
import sqlite3
import tempfile
from pathlib import Path

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


NOW = 2_100_900_000


async def _scalar(path: str, sql: str, args=()):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql, args)).fetchone()
        return row[0] if row else None


async def _won_hq(path: str, player: int, leader_id: str, now: int) -> dict:
    profile = ne.PROFILE_BY_ID[leader_id]
    hq_r, hq_c = ne._hq_coords(profile.hq_key)
    assault = await ne.prepare_assault(
        path, player, leader_id, hq_r, hq_c, now=now)
    assert assault['ok']
    async with aiosqlite.connect(path) as db:
        await db.execute(
            "UPDATE npc_empire_assaults SET guard_hp_json=?,boss_hp=0 "
            "WHERE token=?",
            (json.dumps([0] * len(assault['guards'])), assault['token']),
        )
        await db.commit()
    return assault


async def _record(path: str, key: str, *, leader: str = 'marco',
                  generation: int = 0, player: str = '101', now: int = NOW,
                  commit: bool = True) -> bool:
    async with aiosqlite.connect(path) as db:
        await db.execute('BEGIN IMMEDIATE')
        inserted = await ne._record_boss_memory_fact(
            db, event_key=key, leader_id=leader,
            leader_generation=generation, subject_kind='player',
            subject_id=player, subject_generation=0, kind='hq_defeat',
            outcome='loot', magnitude=300, certainty_milli=1000,
            observed_at=now,
            expires_at=now + ne.NPC_BOSS_MEMORY_HQ_TTL_SECONDS,
            defeats=1, own_losses=2, harm=300,
        )
        if commit:
            await db.commit()
        else:
            await db.rollback()
        return inserted


async def run() -> None:
    handle, path = tempfile.mkstemp(prefix='npc_boss_memory_', suffix='.db')
    os.close(handle)
    try:
        await _base_db(path)
        leila = await _won_hq(path, 101, 'leila', NOW)

        # A failure after the ledger INSERT rolls back the assault, reward,
        # family collapse, event and both memory tables together.
        async with aiosqlite.connect(path) as db:
            await db.execute("""
                CREATE TRIGGER reject_memory_aggregate
                BEFORE INSERT ON npc_empire_memory_aggregates
                WHEN NEW.leader_id='leila'
                BEGIN SELECT RAISE(ABORT, 'forced memory rollback'); END
            """)
            await db.commit()
        try:
            await ne.resolve_assault(
                path, 101, leila['token'], 'loot', now=NOW + 1)
            raise AssertionError('memory aggregate failure did not abort')
        except sqlite3.IntegrityError as error:
            assert 'forced memory rollback' in str(error)
        finally:
            async with aiosqlite.connect(path) as db:
                await db.execute('DROP TRIGGER reject_memory_aggregate')
                await db.commit()
        assert await _scalar(
            path, "SELECT status FROM npc_empire_assaults WHERE token=?",
            (leila['token'],)) == 'active'
        assert await _scalar(
            path, "SELECT status FROM npc_empires WHERE leader_id='leila'") == 'active'
        assert await _scalar(path, 'SELECT COUNT(*) FROM npc_empire_memory_events') == 0
        assert await _scalar(path, 'SELECT COUNT(*) FROM npc_empire_memory_aggregates') == 0

        resolved = await ne.resolve_assault(
            path, 101, leila['token'], 'loot', now=NOW + 2)
        assert resolved['ok'] and resolved['choice'] == 'loot'
        event_key = f"assault:{leila['token']}:outcome"
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            event = await (await db.execute(
                "SELECT * FROM npc_empire_memory_events WHERE event_key=?",
                (event_key,))).fetchone()
            aggregate = await (await db.execute(
                "SELECT * FROM npc_empire_memory_aggregates "
                "WHERE leader_id='leila' AND leader_generation=0 "
                "AND subject_kind='player' AND subject_id='101'",
            )).fetchone()
        assert dict(event) == {
            'event_key': event_key, 'leader_id': 'leila',
            'leader_generation': 0, 'subject_kind': 'player',
            'subject_id': '101', 'subject_generation': 0,
            'kind': 'hq_defeat', 'outcome': 'loot',
            'magnitude': int(leila['boss']['max_hp']),
            'certainty_milli': 1000, 'observed_at': NOW + 2,
            'expires_at': NOW + 2 + ne.NPC_BOSS_MEMORY_HQ_TTL_SECONDS,
        }
        assert aggregate['defeats'] == 1
        assert aggregate['own_losses'] == len(leila['guards']) + 1
        assert aggregate['harm'] == int(leila['boss']['max_hp'])
        async with aiosqlite.connect(path) as db:
            plan = await (await db.execute(
                "EXPLAIN QUERY PLAN SELECT m.* "
                "FROM npc_empire_memory_aggregates m JOIN npc_empires e "
                "ON e.leader_id=m.leader_id AND e.comebacks=m.leader_generation "
                "WHERE m.subject_kind='player' AND m.subject_id=? "
                "AND m.subject_generation=0 AND (m.expires_at=0 OR m.expires_at>?)",
                ('101', NOW),
            )).fetchall()
        assert any('ix_npc_empire_memory_subject' in str(step[3]) for step in plan)

        # The source token is the idempotency key. Concurrent projection of
        # one observation produces one ledger row and one aggregate increment.
        concurrent = await asyncio.gather(
            _record(path, 'assault:concurrent:outcome'),
            _record(path, 'assault:concurrent:outcome'),
        )
        assert sorted(concurrent) == [False, True]
        assert await _scalar(
            path, "SELECT defeats FROM npc_empire_memory_aggregates "
                  "WHERE leader_id='marco' AND subject_id='101'") == 1
        assert not await _record(path, 'assault:concurrent:outcome')

        # One different family/player outcome cannot contaminate Leila/101.
        vera = await _won_hq(path, 202, 'vera', NOW + 3)
        assert (await ne.resolve_assault(
            path, 202, vera['token'], 'vassalize', now=NOW + 4))['ok']
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_memory_aggregates "
                  "WHERE leader_id='leila' AND subject_id='202'") == 0
        assert await _scalar(
            path, "SELECT defeats FROM npc_empire_memory_aggregates "
                  "WHERE leader_id='vera' AND subject_id='202'") == 1

        state_101 = await ne.state_for(path, 101, now=NOW + 5)
        by_id_101 = {item['leader_id']: item for item in state_101['empires']}
        assert by_id_101['leila']['player_memory']['known']
        assert by_id_101['leila']['player_memory']['defeats'] == 1
        assert not by_id_101['vera']['player_memory']['known']
        state_202 = await ne.state_for(path, 202, now=NOW + 5)
        by_id_202 = {item['leader_id']: item for item in state_202['empires']}
        assert by_id_202['vera']['player_memory']['defeats'] == 1
        assert not by_id_202['leila']['player_memory']['known']

        # Retention is per stable family generation: 64 facts and 32 subjects.
        async with aiosqlite.connect(path) as db:
            await db.execute('BEGIN IMMEDIATE')
            for index in range(70):
                assert await ne._record_boss_memory_fact(
                    db, event_key=f'assault:cap:{index}:outcome',
                    leader_id='alisa', leader_generation=0,
                    subject_kind='player', subject_id=str(1000 + index),
                    subject_generation=0, kind='hq_defeat', outcome='loot',
                    magnitude=200, certainty_milli=1000,
                    observed_at=NOW + 100 + index,
                    expires_at=NOW + ne.NPC_BOSS_MEMORY_HQ_TTL_SECONDS,
                    defeats=1, own_losses=1, harm=200)
            await db.commit()
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_memory_events "
                  "WHERE leader_id='alisa' AND leader_generation=0") == 64
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_memory_aggregates "
                  "WHERE leader_id='alisa' AND leader_generation=0") == 32
        assert await _record(
            path, 'assault:new-generation:outcome', leader='alisa',
            generation=1, player='9999', now=NOW + 500)
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_memory_events "
                  "WHERE leader_id='alisa' AND leader_generation=1") == 1
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_memory_events "
                  "WHERE leader_id='alisa' AND leader_generation=0") == 64

        # A rolled-back direct projection leaves neither half behind.
        assert await _record(
            path, 'assault:manual-rollback:outcome', leader='niko',
            commit=False)
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_memory_events "
                  "WHERE leader_id='niko'") == 0
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_memory_aggregates "
                  "WHERE leader_id='niko'") == 0

        decayed = ne._boss_pair_memory_payload(
            aggregate, NOW + 2 + 10 * 24 * 60 * 60, 0)
        assert decayed['known'] and decayed['certainty'] == 75
        assert decayed['defeats'] == 1 and decayed['harm'] > 0

        world = (Path(__file__).resolve().parent / 'world.html').read_text(
            encoding='utf-8')
        assert 'empire.player_memory||{}' in world
        assert 'ЧТО БОСС ПОМНИТ О ВАС' in world
        print('boss memory foundation: HQ token idempotency, caps, rollback, '
              'generation/family/player isolation, decay and pair dossier OK')
    finally:
        if os.path.exists(path):
            try:
                os.unlink(path)
            except PermissionError:
                pass


if __name__ == '__main__':
    asyncio.run(run())
