"""Deterministic long-run contracts for the nineteen autonomous economies."""

import asyncio
import os
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


async def _row(path: str, sql: str, params=()):
    async with aiosqlite.connect(path) as db:
        db.row_factory = aiosqlite.Row
        return await (await db.execute(sql, params)).fetchone()


async def run() -> None:
    profile = ne.PROFILE_BY_ID['leila']
    solvent = ne.apply_operating_budget(
        profile, treasury=1000, members=10, strength=180,
        income_per_tick=120, guard_slots=4, active_wars=1, ticks=6,
    )
    expected_upkeep = 10 * ne.NPC_MEMBER_UPKEEP_PER_TICK \
        + 4 * ne.NPC_HOLDING_GUARD_UPKEEP_PER_TICK \
        + ne.NPC_ACTIVE_WAR_UPKEEP_PER_TICK
    assert solvent['treasury'] == 1000 + 6 * (120 - expected_upkeep)
    assert solvent['upkeep_paid'] == 6 * expected_upkeep
    assert solvent['members'] == 10 and solvent['insolvent_ticks'] == 0

    bankrupt = ne.apply_operating_budget(
        profile, treasury=0, members=20, strength=300,
        income_per_tick=0, guard_slots=6, active_wars=2, ticks=6,
    )
    assert bankrupt['treasury'] == 0 and bankrupt['insolvent_ticks'] == 6
    assert bankrupt['members'] == 17 and bankrupt['strength'] < 300
    recovered = ne.apply_operating_budget(
        profile, treasury=1000, members=3, strength=80,
        income_per_tick=100, guard_slots=0, active_wars=0, ticks=3,
        insolvent_ticks=3,
    )
    assert recovered['insolvent_ticks'] == 0 and recovered['members'] == 3
    assert ne.empire_holding_income_per_tick([
        {'kind': 'building', 'income': 175},
        {'kind': 'business', 'income': 2880},
    ]) == 885
    reserve = ne.operating_reserve(10, 4, 1)
    assert reserve == expected_upkeep * ne.NPC_OPERATING_RESERVE_TICKS
    supported = {'treasury': 0, 'members': 10, 'strength': 180,
                 'insolvent_ticks': 0,
                 'recovery_ticks_remaining': ne.NPC_RECOVERY_STIPEND_TICKS}
    stipend_total = 0
    for _ in range(20):
        supported = ne.apply_operating_budget(
            profile, treasury=supported['treasury'], members=supported['members'],
            strength=supported['strength'], income_per_tick=0, guard_slots=0,
            active_wars=0, ticks=ne.MAX_OFFLINE_TICKS,
            insolvent_ticks=supported['insolvent_ticks'],
            recovery_ticks_remaining=supported['recovery_ticks_remaining'],
        )
        stipend_total += supported['recovery_stipend']
        if not supported['recovery_ticks_remaining']:
            break
    assert stipend_total == (
        ne.NPC_RECOVERY_STIPEND_PER_TICK * ne.NPC_RECOVERY_STIPEND_TICKS)
    assert supported['recovery_ticks_remaining'] == 0
    exhausted = ne.apply_operating_budget(
        profile, treasury=supported['treasury'], members=supported['members'],
        strength=supported['strength'], income_per_tick=0, guard_slots=0,
        active_wars=0, ticks=ne.MAX_OFFLINE_TICKS,
        insolvent_ticks=supported['insolvent_ticks'],
        recovery_ticks_remaining=supported['recovery_ticks_remaining'],
    )
    assert exhausted['recovery_stipend'] == 0
    assert exhausted['treasury'] < supported['treasury']

    fd, path = tempfile.mkstemp(prefix='npc_empire_economy_', suffix='.db')
    os.close(fd)
    try:
        await _base_db(path)
        now = 2_100_000_000
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET treasury=1000,members=8,last_recruit_at=0 "
                "WHERE leader_id='leila'"
            )
            await db.commit()
        cost = ne.recruitment_cost(8)
        hired = await ne.recruit_street_fighter(
            path, 'leila', 'paid-street-1', 'bellini', now=now)
        assert hired['ok'] and hired['budget']['band'] in {'stable', 'rich'}
        assert not {'treasury', 'reserve', 'cost'} & set(hired)
        after_hire = await _row(
            path, "SELECT treasury,members FROM npc_empires WHERE leader_id='leila'")
        assert tuple(after_hire) == (1000 - cost, 9)
        duplicate = await ne.recruit_street_fighter(
            path, 'leila', 'paid-street-1', 'bellini', now=now + 20)
        after_duplicate = await _row(
            path, "SELECT treasury,members FROM npc_empires WHERE leader_id='leila'")
        assert duplicate['ok'] and duplicate['duplicate'] and tuple(after_duplicate) == tuple(after_hire)
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET treasury=0,last_recruit_at=0 WHERE leader_id='leila'")
            await db.commit()
        refused = await ne.recruit_street_fighter(
            path, 'leila', 'unpaid-street-2', 'moretti', now=now + 40)
        assert not refused['ok'] and refused['error'] == 'budget constrained'
        assert (await _row(path,
            "SELECT members FROM npc_empires WHERE leader_id='leila'"))[0] == 9

        left, right = sorted(('leila', 'rustam'))
        async with aiosqlite.connect(path) as db:
            await db.execute("UPDATE npc_empires SET last_tick=?", (now,))
            await db.execute(
                "UPDATE npc_empires SET treasury=0,members=20,strength=300,insolvent_ticks=0,"
                "recovery_ticks_remaining=0 "
                "WHERE leader_id='leila'"
            )
            await db.execute(
                "UPDATE npc_empire_holdings SET income=1 WHERE leader_id='leila' AND kind='hq'"
            )
            await db.execute(
                "UPDATE npc_empire_diplomacy SET score=-100,pact='war',tension=0,last_event_at=? "
                "WHERE leader_a=? AND leader_b=?", (now, left, right))
            await db.commit()
        bankrupt_events = await ne.advance(path, now=now + 6 * ne.TICK_SECONDS)
        bankrupt_row = await _row(
            path, "SELECT treasury,members,insolvent_ticks FROM npc_empires WHERE leader_id='leila'")
        assert tuple(bankrupt_row) == (0, 17, 6), tuple(bankrupt_row)
        assert any(event['leader_id'] == 'leila' and event['kind'] == 'bankrupt'
                   for event in bankrupt_events)
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "INSERT INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                "VALUES('building','0,3','leila',200,80,?,'print_shop',16)",
                (now + 6 * ne.TICK_SECONDS,))
            await db.commit()
        recovery_events = await ne.advance(path, now=now + 12 * ne.TICK_SECONDS)
        recovered_row = await _row(
            path, "SELECT treasury,insolvent_ticks FROM npc_empires WHERE leader_id='leila'")
        assert recovered_row['treasury'] > 0 and recovered_row['insolvent_ticks'] == 0
        assert any(event['leader_id'] == 'leila' and event['kind'] == 'solvency_recovered'
                   for event in recovery_events)

        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            await db.execute('BEGIN IMMEDIATE')
            await db.execute(
                "UPDATE npc_empire_diplomacy SET score=-100,pact='war',tension=75,last_event_at=? "
                "WHERE leader_a=? AND leader_b=?", (now + 12 * ne.TICK_SECONDS, left, right))
            state = {(left, right): {'score': -100, 'pact': 'war',
                                     'tension': 75, 'last_event_at': now + 12 * ne.TICK_SECONDS}}
            events = []
            await ne._react_to_npc_attack(
                db, state, 'leila', 'rustam', now + 12 * ne.TICK_SECONDS + 1, events)
            assert state[(left, right)]['pact'] == 'truce'
            assert any(event['kind'] == 'truce_formed' for event in events)
            await ne._advance_npc_peace(
                db, state, now + 12 * ne.TICK_SECONDS + 1
                + 12 * ne.NPC_DIPLOMACY_PEACE_STEP_SECONDS,
                events)
            assert state[(left, right)]['pact'] == 'none'
            await ne._change_npc_diplomacy(
                db, state, left, right, score=60, pact='none', tension=0,
                now=now + 12 * ne.TICK_SECONDS + 2
                + 12 * ne.NPC_DIPLOMACY_PEACE_STEP_SECONDS)
            rows = await (await db.execute(
                "SELECT * FROM npc_empires WHERE status IN ('active','rebuilding','vassal')"
            )).fetchall()
            await ne._advance_npc_alliances(
                db, state, {str(row['leader_id']): row for row in rows},
                now + 12 * ne.TICK_SECONDS + 3
                + 12 * ne.NPC_DIPLOMACY_PEACE_STEP_SECONDS, events)
            assert state[(left, right)]['pact'] == 'alliance'
            await db.commit()

        # Fifteen days in bounded six-hour catch-up windows exercise the full
        # SQLite decision loop; the separate year audit covers 365 days.
        base = int((await _row(path, "SELECT MIN(last_tick) FROM npc_empires"))[0])
        minima = {'treasury': 10**12, 'members': 10**12, 'strength': 10**12}
        maxima = {'treasury': 0, 'members': 0, 'strength': 0}
        for step in range(1, 61):
            await ne.advance(path, now=base + step * ne.MAX_OFFLINE_TICKS * ne.TICK_SECONDS)
            async with aiosqlite.connect(path) as db:
                db.row_factory = aiosqlite.Row
                rows = await (await db.execute(
                    "SELECT treasury,members,strength,status,insolvent_ticks FROM npc_empires"
                )).fetchall()
            assert len(rows) == len(ne.PROFILES) == 19
            assert all(int(row['treasury']) >= 0 and int(row['insolvent_ticks']) >= 0 for row in rows)
            assert all(0 <= int(row['members']) <= ne.NPC_EMPIRE_MAX_FIGHTERS for row in rows)
            assert all(int(row['strength']) >= 0 for row in rows)
            assert all((int(row['members']) >= 1 and int(row['strength']) >= 20)
                       if str(row['status']) in {'active', 'rebuilding', 'vassal'} else True
                       for row in rows)
            for key in minima:
                minima[key] = min(minima[key], *(int(row[key]) for row in rows))
                maxima[key] = max(maxima[key], *(int(row[key]) for row in rows))

        snapshot = await ne.state_for(
            path, 101, now=base + 61 * ne.MAX_OFFLINE_TICKS * ne.TICK_SECONDS)
        portfolio = await _row(
            path, "SELECT COUNT(*) total,COUNT(DISTINCT leader_id) owners "
                  "FROM npc_empire_holdings WHERE kind IN ('building','business')")
        assert portfolio['total'] > 0 and portfolio['owners'] > 0
        assert len(snapshot['empires']) == 19
        assert all(set(empire['budget']) == {'band', 'label', 'summary', 'allows'}
                   and 'treasury' not in empire and 'economy' not in empire
                   for empire in snapshot['empires'])
        assert {row['district_id'] for row in snapshot['districts']} == set(ne.DISTRICTS)
        assert all(row['control_state'] in {'neutral', 'contested', 'leader'}
                   and 0 <= row['control_percent'] <= 100
                   for row in snapshot['districts'])
        print('npc empire economy: 19 families x 15 integration days; real income/min, reserve policy, '
              f'paid guards/wars/recruits; {portfolio["total"]} purchased assets by '
              f'{portfolio["owners"]} families; finite recovery stipend; '
              f'bounded ranges {minima}..{maxima}; bankruptcy recovery and diplomacy OK')
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
