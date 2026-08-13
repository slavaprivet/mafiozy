"""365-day deterministic capital and eight-district audit for 19 families."""

import asyncio
import os
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


def _simulate_year() -> dict:
    building_keys = sorted(ne.BUILDING_AREAS)
    family_results = {}
    total_hiring = total_purchases = total_distributed = 0
    for family_index, profile in enumerate(ne.PROFILES):
        cash = profile.starting_cash
        members = 4 + profile.loyalty // 18
        strength = 90 + profile.aggression + profile.loyalty // 2
        income_minute = ne.NPC_HQ_FRONT_INCOME_PER_MINUTE
        guard_slots = purchases = paid_hires = distributed = 0
        insolvency = recovery = 0
        quarterly = []
        for day in range(365):
            active_wars = 1 if (day + family_index) % 17 in range(4) else 0
            for _ in range(4):
                budget = ne.apply_operating_budget(
                    profile, treasury=cash, members=members, strength=strength,
                    income_per_tick=income_minute * 5,
                    guard_slots=guard_slots, active_wars=active_wars,
                    ticks=ne.MAX_OFFLINE_TICKS, insolvent_ticks=insolvency,
                    recovery_ticks_remaining=recovery,
                )
                cash, members, strength = (budget['treasury'], budget['members'],
                                            budget['strength'])
                insolvency = budget['insolvent_ticks']
                recovery = budget['recovery_ticks_remaining']
                liquid = ne.settle_operating_liquidity(
                    cash, income_minute * 5, members, guard_slots, active_wars)
                cash = liquid['treasury']; distributed += liquid['distributed']

            target_members = min(ne.NPC_EMPIRE_MAX_FIGHTERS,
                                 7 + profile.aggression // 13)
            if members < target_members:
                cost = ne.recruitment_cost(members)
                reserve = ne.operating_reserve(members + 1, guard_slots, active_wars)
                if cash - cost >= reserve:
                    cash -= cost; members += 1; paid_hires += cost

            if purchases < 8:
                key = building_keys[(family_index * 8 + purchases) % len(building_keys)]
                operation = tuple(ne.BUILDING_OPERATIONS)[purchases]
                area = ne.BUILDING_AREAS[key]
                cost = ne.building_purchase_price(
                    ne.building_shell_price(key), 'business', operation, area)
                next_guards = guard_slots + ne.holding_guard_count(
                    profile.leader_id, 'building', key, day * 86400)
                if cash - cost >= ne.operating_reserve(
                        members, next_guards, active_wars):
                    cash -= cost; purchases += 1; guard_slots = next_guards
                    income_minute += ne.building_operation_income(operation, area)

            if day in {89, 179, 269, 364}:
                ceiling = ne.settle_operating_liquidity(
                    cash, income_minute * 5, members, guard_slots, active_wars)['ceiling']
                quarterly.append((cash, ceiling, distributed))

        assert insolvency == 0, profile.leader_id
        assert recovery == 0, profile.leader_id
        assert paid_hires > 0 and purchases == 8 and guard_slots >= 8
        assert distributed > 0
        assert all(cash_at_quarter <= ceiling
                   for cash_at_quarter, ceiling, _ in quarterly)
        mature_daily_flow = [
            (quarterly[2][2] - quarterly[1][2]) / 90,
            (quarterly[3][2] - quarterly[2][2]) / 95,
        ]
        assert max(mature_daily_flow) <= min(mature_daily_flow) * 1.05
        family_results[profile.leader_id] = {
            'cash': cash, 'members': members, 'purchases': purchases,
            'guards': guard_slots, 'distributed': distributed,
        }
        total_hiring += paid_hires; total_purchases += purchases
        total_distributed += distributed

    # Recovery is finite even under repeated catch-up. Once its 12 grants are
    # consumed, an income-less family receives no more cash or free fighters.
    profile = ne.PROFILES[0]
    state = dict(treasury=0, members=10, strength=180, insolvent_ticks=0,
                 recovery_ticks_remaining=ne.NPC_RECOVERY_STIPEND_TICKS)
    stipend = 0
    for _ in range(365 * 4):
        state = ne.apply_operating_budget(
            profile, treasury=state['treasury'], members=state['members'],
            strength=state['strength'], income_per_tick=0, guard_slots=2,
            active_wars=1, ticks=ne.MAX_OFFLINE_TICKS,
            insolvent_ticks=state['insolvent_ticks'],
            recovery_ticks_remaining=state['recovery_ticks_remaining'])
        stipend += state['recovery_stipend']
    assert stipend == ne.NPC_RECOVERY_STIPEND_PER_TICK * ne.NPC_RECOVERY_STIPEND_TICKS
    assert state['recovery_ticks_remaining'] == 0 and state['treasury'] == 0
    assert state['members'] == 1 and state['insolvent_ticks'] > 0

    return {'families': len(family_results), 'purchases': total_purchases,
            'paid_hiring': total_hiring, 'distributed': total_distributed,
            'max_cash': max(row['cash'] for row in family_results.values())}


async def _district_audit() -> None:
    fd, path = tempfile.mkstemp(prefix='npc_empire_district_year_', suffix='.db')
    os.close(fd)
    try:
        await _base_db(path)
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            await db.execute('DELETE FROM npc_empire_holdings')
            await ne._recompute_districts(db, 10)
            rows = await (await db.execute(
                'SELECT * FROM npc_empire_districts')).fetchall()
            assert len(rows) == 8 and {row['district_id'] for row in rows} == set(ne.DISTRICTS)
            assert all(not row['leader_id'] and not row['contested'] for row in rows)

            # Equal HQ weights in the same client district are an exact tie.
            await db.executemany(
                "INSERT INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at) "
                "VALUES('hq',?,?,24,80,10)",
                [('0,1', 'leila'), ('0,2', 'rustam')])
            await ne._recompute_districts(db, 20)
            tie = await (await db.execute(
                "SELECT * FROM npc_empire_districts WHERE district_id='northside'"
            )).fetchone()
            assert tie['score'] == tie['runner_up_score'] == 10 and tie['contested'] == 1

            # Two additional holdings create an unambiguous leader.
            await db.executemany(
                "INSERT INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                "VALUES('building',?,'leila',175,50,21,'print_shop',4)",
                [('0,0',), ('0,3',)])
            await ne._recompute_districts(db, 30)
            lead = await (await db.execute(
                "SELECT * FROM npc_empire_districts WHERE district_id='northside'"
            )).fetchone()
            assert lead['leader_id'] == 'leila' and lead['contested'] == 0
            await db.commit()
    finally:
        os.unlink(path)


async def run() -> None:
    assert ne.NPC_HQ_FRONT_INCOME_PER_MINUTE == 24
    assert {operation: ne.building_operation_income(operation, 27)
            for operation in ne.BUILDING_OPERATIONS} == {
        'beer_bar': 95, 'pawnshop': 110, 'bookmaker': 120,
        'strip_club': 145, 'gun_shop': 155, 'chop_shop': 170,
        'poker_club': 185, 'print_shop': 200,
    }
    legacy = [{'kind': 'business', 'income': value}
              for value in ne.BUSINESS_INCOME.values()]
    assert ne.empire_holding_income_per_tick(legacy) == (
        sum(ne.BUSINESS_INCOME.values()) // 288)
    result = _simulate_year()
    await _district_audit()
    print('npc empire year: 19 families x 365 days; '
          f'{result["purchases"]} paid purchases, paid hiring ${result["paid_hiring"]}, '
          f'distributed surplus ${result["distributed"]}, max cash ${result["max_cash"]}; '
          'finite recovery and all 8 district neutral/tie/leader states OK')


if __name__ == '__main__':
    asyncio.run(run())
