"""NPC wars use concrete guards and persist symmetric bounded outcomes."""

import asyncio
import os
import sqlite3
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


NOW = 2_000_500_000


class _FixedRoll:
    def random(self) -> float:
        return 0.5


async def run() -> None:
    assert ne._npc_holding_guard_power(ne.PROFILE_BY_ID['rustam'], 3) > \
        ne._npc_holding_guard_power(ne.PROFILE_BY_ID['rustam'], 0)
    handle, path = tempfile.mkstemp(prefix='npc_war_guards_', suffix='.db')
    os.close(handle)
    original_brain = ne._boss_brain
    original_roll = ne._decision_roll
    try:
        await _base_db(path)
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET status='ruined',comeback_at=?,last_tick=?",
                (NOW + 100_000, NOW - ne.TICK_SECONDS),
            )
            await db.execute(
                "UPDATE npc_empires SET status='active',comeback_at=0,treasury=500000,"
                "members=20,strength=10000,last_tick=? WHERE leader_id='viktor'",
                (NOW - ne.TICK_SECONDS,),
            )
            # The defender is hospitalized only to prevent a second personal
            # order; its family, properties and concrete guards still defend.
            await db.execute(
                "UPDATE npc_empires SET status='active',comeback_at=0,treasury=500000,"
                "members=10,strength=220,last_tick=?,hospital_until=? "
                "WHERE leader_id='rustam'",
                (NOW - ne.TICK_SECONDS, NOW + 3600),
            )
            await db.execute(
                "DELETE FROM npc_empire_holdings WHERE kind<>'hq' OR "
                "leader_id NOT IN ('viktor','rustam')"
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                "VALUES('building','4,4','rustam',1000,10,?,'beer_bar',16)",
                (NOW - 1000,),
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                "VALUES('building','5,5','rustam',1,10,?,'pawnshop',16)",
                (NOW - 1000,),
            )
            left, right = sorted(('viktor', 'rustam'))
            await db.execute(
                "UPDATE npc_empire_diplomacy SET score=-100,pact='war',tension=40,last_event_at=? "
                "WHERE leader_a=? AND leader_b=?", (NOW, left, right),
            )
            # Both participants already have more history than the retention
            # window. The new symmetric result must prune each family alone.
            for leader_id in ('viktor', 'rustam', 'sofia'):
                await db.executemany(
                    "INSERT INTO npc_empire_events"
                    "(leader_id,kind,target_id,summary,created_at) VALUES(?,?,?,?,?)",
                    [(leader_id, 'old', '', f'old-{index}', NOW - 1000 - index)
                     for index in range(ne.NPC_EVENT_MEMORY_LIMIT + 5)],
                )
            await db.commit()

        ne._boss_brain = lambda *args, **kwargs: {
            'strategy': 'retaliate', 'adaptation': {'mode': 'balanced'},
        }
        ne._decision_roll = lambda *args, **kwargs: _FixedRoll()
        events = await ne.advance(path, NOW)

        with sqlite3.connect(path) as db:
            owner = db.execute(
                "SELECT leader_id FROM npc_empire_holdings "
                "WHERE kind='building' AND holding_id='5,5'"
            ).fetchone()[0]
            viktor = db.execute(
                "SELECT members,strength,wins,losses FROM npc_empires "
                "WHERE leader_id='viktor'"
            ).fetchone()
            rustam = db.execute(
                "SELECT members,strength,wins,losses FROM npc_empires "
                "WHERE leader_id='rustam'"
            ).fetchone()
            counts = dict(db.execute(
                "SELECT leader_id,COUNT(*) FROM npc_empire_events "
                "WHERE leader_id IN ('viktor','rustam','sofia') GROUP BY leader_id"
            ).fetchall())
            target_assignment = db.execute(
                "SELECT COUNT(*) FROM npc_empire_guard_assignments "
                "WHERE owner_kind='npc' AND owner_id='rustam' "
                "AND holding_ref='building:5,5'"
            ).fetchone()[0]

        assert owner == 'viktor', (owner, events)
        assert viktor[0] < 20 and viktor[1] < 10000 and viktor[2:] == (1, 0)
        assert rustam[0] < 10 and rustam[1] < 220 and rustam[2:] == (0, 1)
        # Capture clears the surviving assignment; casualties were charged to
        # members before that clear and therefore are not counted twice.
        assert target_assignment == 0
        war_events = {(event['leader_id'], event['kind'], event['target_id'])
                      for event in events if event['kind'] in {'war_won', 'war_lost'}}
        assert ('viktor', 'war_won', 'rustam') in war_events
        assert ('rustam', 'war_lost', 'viktor') in war_events
        assert counts == {'rustam': ne.NPC_EVENT_MEMORY_LIMIT,
                          'sofia': ne.NPC_EVENT_MEMORY_LIMIT,
                          'viktor': ne.NPC_EVENT_MEMORY_LIMIT}

        # Same-tick stale snapshot regression: Leila acts before Viktor and
        # reduces him to one survivor. Viktor then gets his own turn against
        # Rustam. His final UPDATE must start from the freshly damaged row and
        # must not restore the opening ten-member snapshot.
        next_now = NOW + 10_000
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET status='ruined',comeback_at=?,last_tick=?,"
                "hospital_until=0", (next_now + 100_000, next_now - ne.TICK_SECONDS),
            )
            await db.execute(
                "UPDATE npc_empires SET status='active',comeback_at=0,treasury=500000,"
                "members=10,strength=3000,last_tick=? WHERE leader_id='leila'",
                (next_now - ne.TICK_SECONDS,),
            )
            await db.execute(
                "UPDATE npc_empires SET status='active',comeback_at=0,treasury=500000,"
                "members=10,strength=1000,last_tick=? WHERE leader_id='viktor'",
                (next_now - ne.TICK_SECONDS,),
            )
            await db.execute(
                "UPDATE npc_empires SET status='active',comeback_at=0,treasury=500000,"
                "members=10,strength=220,last_tick=?,hospital_until=? "
                "WHERE leader_id='rustam'",
                (next_now - ne.TICK_SECONDS, next_now + 3600),
            )
            await db.execute("DELETE FROM npc_empire_holdings WHERE kind<>'hq'")
            for key, owner, income in (
                    ('3,4', 'viktor', 1000), ('3,5', 'viktor', 10),
                    ('4,4', 'rustam', 1000), ('5,5', 'rustam', 10)):
                await db.execute(
                    "INSERT OR REPLACE INTO npc_empire_holdings"
                    "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                    "VALUES('building',?,?,?,?,?,'beer_bar',16)",
                    (key, owner, income, 5, next_now - 1000),
                )
            await db.execute(
                "UPDATE npc_empire_diplomacy SET score=0,pact='none',tension=0,last_event_at=?",
                (next_now,),
            )
            for left_id, right_id in (('leila', 'viktor'), ('rustam', 'viktor')):
                left_id, right_id = sorted((left_id, right_id))
                await db.execute(
                    "UPDATE npc_empire_diplomacy SET score=-100,pact='war',tension=40,last_event_at=? "
                    "WHERE leader_a=? AND leader_b=?", (next_now, left_id, right_id),
                )
            await db.commit()
        second_events = await ne.advance(path, next_now)
        with sqlite3.connect(path) as db:
            viktor_members = db.execute(
                "SELECT members FROM npc_empires WHERE leader_id='viktor'"
            ).fetchone()[0]
        assert viktor_members == 1, (viktor_members, second_events)
        assert ('leila', 'war_won', 'viktor') in {
            (event['leader_id'], event['kind'], event.get('target_id'))
            for event in second_events
        }
        print('npc war guards: local defense, symmetric casualties/stats/events, bounded memory OK')
    finally:
        ne._boss_brain = original_brain
        ne._decision_roll = original_roll
        if os.path.exists(path):
            try:
                os.unlink(path)
            except PermissionError:
                pass


if __name__ == '__main__':
    asyncio.run(run())
