"""Hospital treatment freezes a boss, not the passive family economy."""

import asyncio
import os
import sqlite3
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


NOW = 2_000_300_000


class _AlwaysAct:
    def random(self) -> float:
        return 0.0


async def run() -> None:
    handle, path = tempfile.mkstemp(prefix="npc_hospital_strategy_", suffix=".db")
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
                "members=3,strength=100,last_tick=?,hospital_until=?,hospital_id='hospital' "
                "WHERE leader_id='leila'",
                (NOW - ne.TICK_SECONDS, NOW + 600),
            )
            await db.execute(
                "UPDATE npc_empires SET status='active',comeback_at=0,treasury=0,"
                "members=3,strength=60,last_tick=? WHERE leader_id='rustam'",
                (NOW - ne.TICK_SECONDS,),
            )
            await db.execute(
                "DELETE FROM npc_empire_holdings WHERE leader_id NOT IN ('leila','rustam')"
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at) "
                "VALUES('building','4,4','rustam',175,1,?)",
                (NOW - 1000,),
            )
            left, right = sorted(('leila', 'rustam'))
            await db.execute(
                "UPDATE npc_empire_diplomacy SET score=-100,pact='war',tension=80 "
                "WHERE leader_a=? AND leader_b=?", (left, right),
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars"
                "(leader_id,telegram_id,next_attack_at) VALUES('leila',101,?)",
                (NOW + 5000,),
            )
            await db.commit()

        ne._boss_brain = lambda *args, **kwargs: {
            'strategy': 'retaliate', 'adaptation': {'mode': 'balanced'},
        }
        ne._decision_roll = lambda *args, **kwargs: _AlwaysAct()
        with sqlite3.connect(path) as db:
            before = db.execute(
                "SELECT treasury,members,strength,wins,last_tick FROM npc_empires "
                "WHERE leader_id='leila'"
            ).fetchone()
            holdings_before = db.execute(
                "SELECT kind,holding_id,leader_id,defense FROM npc_empire_holdings "
                "ORDER BY kind,holding_id"
            ).fetchall()

        events = await ne.advance(path, NOW)

        with sqlite3.connect(path) as db:
            after = db.execute(
                "SELECT treasury,members,strength,wins,last_tick FROM npc_empires "
                "WHERE leader_id='leila'"
            ).fetchone()
            holdings_after = db.execute(
                "SELECT kind,holding_id,leader_id,defense FROM npc_empire_holdings "
                "ORDER BY kind,holding_id"
            ).fetchall()
        # Economy/payroll advances, but the treated boss neither recruits nor
        # changes strength, holdings, fortifications or war statistics.
        assert after[0] != before[0] and after[4] == NOW
        assert after[1:4] == before[1:4]
        assert holdings_after == holdings_before
        assert not ({'recruit_completed', 'expand', 'business_bought',
                     'fortify', 'war_won', 'war_lost'}
                    & {event['kind'] for event in events
                       if event.get('leader_id') == 'leila'})

        # Exercise the dedicated fortification branch as well. All other
        # probabilistic branches were made due above by _AlwaysAct.
        ne._boss_brain = lambda *args, **kwargs: {
            'strategy': 'fortify', 'adaptation': {'mode': 'balanced'},
        }
        fortify_before = [row for row in holdings_after if row[2] == 'leila']
        fortify_events = await ne.advance(path, NOW + ne.TICK_SECONDS)
        with sqlite3.connect(path) as db:
            fortify_after = db.execute(
                "SELECT kind,holding_id,leader_id,defense FROM npc_empire_holdings "
                "WHERE leader_id='leila' ORDER BY kind,holding_id"
            ).fetchall()
        assert fortify_after == fortify_before, (fortify_before, fortify_after)
        assert not ({'recruit_completed', 'expand', 'business_bought',
                     'fortify', 'war_won', 'war_lost'}
                    & {event['kind'] for event in fortify_events
                       if event.get('leader_id') == 'leila'})

        state = await ne.state_for(path, 101, NOW + ne.TICK_SECONDS + 1)
        leila = next(item for item in state['empires']
                     if item['leader_id'] == 'leila')
        assert leila['hospital_until'] == NOW + 600
        assert leila['activity']['kind'] == 'hospital'
        assert leila['activity']['phase'] == 'treatment'
        assert leila['activity']['target_id'] == 'hospital'
        assert leila['activity']['kind'] not in {'gang_war', 'player_business_raid'}
        print('npc empire hospital strategy: passive economy, no personal orders, stable activity OK')
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
