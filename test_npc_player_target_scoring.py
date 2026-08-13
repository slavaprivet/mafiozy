"""Deterministic target intelligence for NPC attacks on player businesses."""

import asyncio
import os
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


async def run() -> None:
    target = {'ref': 'building:0,3', 'kind': 'building',
              'holding_id': '0,3', 'income': 120}
    cautious = ne.score_player_business_target(
        target, distance=20, guards=3, force=4, quality=50,
        relation=0, aggression=20)
    hostile = ne.score_player_business_target(
        target, distance=20, guards=3, force=4, quality=50,
        relation=-100, aggression=80)
    assert not cautious['feasible'] and hostile['feasible']
    assert hostile['loss_budget'] > cautious['loss_budget']
    assert hostile['expected_losses'] == cautious['expected_losses'] == 3
    rich = ne.score_player_business_target(
        {**target, 'income': 4750}, distance=20, guards=0,
        force=4, quality=50, relation=-100, aggression=80)
    far = ne.score_player_business_target(
        {**target, 'income': 4750}, distance=160, guards=0,
        force=4, quality=50, relation=-100, aggression=80)
    assert rich['score'] > hostile['score'] and rich['score'] > far['score']

    fd, path = tempfile.mkstemp(prefix='npc_target_score_', suffix='.db')
    os.close(fd)
    try:
        await _base_db(path); now = 2_500_000_000
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
                "INSERT INTO gang_members VALUES(?,101,100)",
                [(member_id,) for member_id in range(1, 9)])
            await db.execute(
                "INSERT INTO apartments_owned"
                "(telegram_id,apt_key,price,bought_at,property_kind,operation_type,area,income_per_minute) "
                "VALUES(101,'tile:6,36',20000,?,'business','pawnshop',16,120)", (now,))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations"
                "(leader_id,telegram_id,score,pact,last_action_at) "
                "VALUES('leila',101,-100,'war',?)", (now,))
            await db.execute(
                "UPDATE npc_empires SET members=2,strength=40,treasury=1000 "
                "WHERE leader_id='leila'")
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars"
                "(leader_id,telegram_id,next_attack_at,attacks,last_business_id) "
                "VALUES('leila',101,?,0,'')", (now,))
            await db.commit()

        assigned = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101',
            holding_ref='building:0,3', requested=3, now=now)
        assert assigned['ok'] and assigned['holding_guards'] == 3
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            targets = await ne._player_business_targets(db, 101)
            allocation = await ne._npc_attack_allocation(db, 'leila')
            assert allocation['count'] == 2 and allocation['cost'] > 0
            assert await ne._select_player_business_target_smart(
                db, 101, 'leila', targets, 0, '') is None

        # The real due-war path postpones the impossible raid without charging
        # money, incrementing attack phase, or creating synthetic attackers.
        before_treasury = 1000
        assert await ne._apply_player_war_pressure(path, 101, now) == []
        async with aiosqlite.connect(path) as db:
            row = await (await db.execute(
                "SELECT attacks,next_attack_at FROM npc_empire_player_wars "
                "WHERE leader_id='leila' AND telegram_id=101")).fetchone()
            assert row[0] == 0 and row[1] > now
            treasury = (await (await db.execute(
                "SELECT treasury FROM npc_empires WHERE leader_id='leila'"
            )).fetchone())[0]
            raids = (await (await db.execute(
                "SELECT COUNT(*) FROM npc_empire_interior_raids"
            )).fetchone())[0]
            assert treasury == before_treasury and raids == 0

        # With a paid strong roster, distance wins between comparable venues.
        await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101',
            holding_ref='building:0,3', requested=0, now=now+1)
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET members=20,strength=500,treasury=100000 "
                "WHERE leader_id='leila'")
            await db.execute(
                "INSERT INTO apartments_owned"
                "(telegram_id,apt_key,price,bought_at,property_kind,operation_type,area,income_per_minute) "
                "VALUES(101,'tile:16,176',30000,?,'business','print_shop',27,200)", (now,))
            await db.commit()
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            targets = await ne._player_business_targets(db, 101)
            close = await ne._select_player_business_target_smart(
                db, 101, 'leila', targets, 0, '')
            assert close['ref'] == 'building:0,3', close
            close_score = close['_raid']['score']

            # A real holding near the remote high-income venue changes the
            # logistics origin; the same scorer now prefers that venue.
            await db.execute(
                "INSERT INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at) "
                "VALUES('building','1,16','leila',100,50,?)", (now,))
            await db.commit()
            targets = await ne._player_business_targets(db, 101)
            remote = await ne._select_player_business_target_smart(
                db, 101, 'leila', targets, 0, '')
            assert remote['ref'] == 'building:1,17', remote
            assert remote['_raid']['distance'] < close['_raid']['distance']
            assert remote['_raid']['score'] > close_score

            # First follow-up stays on its previous viable target while it is
            # within the bounded score tolerance.
            followup = await ne._select_player_business_target_smart(
                db, 101, 'leila', targets, 1, 'building:0,3')
            assert followup['ref'] == 'building:0,3', followup

        # Concrete guards make that old venue irrational; follow-up switches to
        # the still-reasonable alternative instead of blindly repeating it.
        await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101',
            holding_ref='building:0,3', requested=3, now=now+2)
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            targets = await ne._player_business_targets(db, 101)
            switched = await ne._select_player_business_target_smart(
                db, 101, 'leila', targets, 1, 'building:0,3')
            assert switched['ref'] == 'building:1,17', switched
            assert switched['_raid']['expected_losses'] == 0
        print('npc player target scoring: income, logistics, concrete guards, hostility, '
              'paid roster, loss deferral and rational follow-up OK')
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
