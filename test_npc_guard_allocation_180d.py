"""Deterministic 19-family/180-day guard allocation and lifecycle audit."""

import asyncio
import os
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


def reserve_target(members: int, wars: int) -> int:
    return min(max(0, members), max(2, wars * 2 + 1))


async def assert_invariants(db, leader_id: str, members: int, wars: int) -> None:
    rows = await (await db.execute(
        "SELECT holding_ref,living FROM npc_empire_guard_assignments "
        "WHERE owner_kind='npc' AND owner_id=? ORDER BY holding_ref", (leader_id,)
    )).fetchall()
    assigned = sum(max(0, int(row[1] or 0)) for row in rows)
    assert assigned <= members, (leader_id, assigned, members)
    assert members - assigned >= reserve_target(members, wars), (
        leader_id, members, assigned, wars)
    assert len({str(row[0]) for row in rows}) == len(rows)
    for holding_ref, living in rows:
        kind, holding_id = str(holding_ref).split(':', 1)
        owner = await (await db.execute(
            "SELECT leader_id FROM npc_empire_holdings WHERE kind=? AND holding_id=?",
            (kind, holding_id))).fetchone()
        assert owner and str(owner[0]) == leader_id, (leader_id, holding_ref, owner)
        assert 0 < int(living) <= 3


async def run() -> None:
    fd, path = tempfile.mkstemp(prefix='npc_guard_180d_', suffix='.db')
    os.close(fd)
    try:
        await _base_db(path)
        start = 2_400_000_000
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            for family_index, profile in enumerate(ne.PROFILES):
                await db.execute(
                    "UPDATE npc_empires SET treasury=?,members=?,strength=?,last_tick=? "
                    "WHERE leader_id=?",
                    (profile.starting_cash, 7 + family_index % 7,
                     120 + family_index * 3, start, profile.leader_id))
                for slot, income in enumerate((40, 90, 160, 230)):
                    await db.execute(
                        "INSERT INTO npc_empire_holdings"
                        "(kind,holding_id,leader_id,income,defense,acquired_at) "
                        "VALUES('business',?,?,?,?,?)",
                        (f'guard-{family_index}-{slot}', profile.leader_id,
                         income, 45 + slot, start))
            await db.commit()

        # Production advance used to allocate for ten members, bankrupt the
        # family later in the same tick, and commit the stale larger count.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET treasury=0,members=10,strength=180,"
                "insolvent_ticks=?,recovery_ticks_remaining=0,last_tick=? "
                "WHERE leader_id='leila'",
                (0, start-ne.MAX_OFFLINE_TICKS*ne.TICK_SECONDS))
            await db.execute(
                "UPDATE npc_empire_holdings SET income=0 WHERE leader_id='leila'")
            await db.commit()
        original_budget = ne.apply_operating_budget
        def forced_casualty_budget(profile, **kwargs):
            result = original_budget(profile, **kwargs)
            result.update(treasury=0, members=2, strength=40)
            return result
        ne.apply_operating_budget = forced_casualty_budget
        try:
            await ne.advance(path, start)
        finally:
            ne.apply_operating_budget = original_budget
        async with aiosqlite.connect(path) as db:
            members_after_budget = int((await (await db.execute(
                "SELECT members FROM npc_empires WHERE leader_id='leila'"
            )).fetchone())[0])
            assigned_after_budget = int((await (await db.execute(
                "SELECT COALESCE(SUM(living),0) FROM npc_empire_guard_assignments "
                "WHERE owner_kind='npc' AND owner_id='leila'"
            )).fetchone())[0] or 0)
            assert members_after_budget < 10, (members_after_budget, assigned_after_budget)
            assert assigned_after_budget <= members_after_budget
            await db.execute(
                "UPDATE npc_empires SET treasury=?,members=7,strength=120,"
                "insolvent_ticks=0,recovery_ticks_remaining=0,last_tick=? "
                "WHERE leader_id='leila'",
                (ne.PROFILE_BY_ID['leila'].starting_cash, start))
            await db.execute(
                "UPDATE npc_empire_holdings SET income=24 "
                "WHERE leader_id='leila' AND kind='hq'")
            await db.executemany(
                "UPDATE npc_empire_holdings SET income=? "
                "WHERE leader_id='leila' AND kind='business' AND holding_id=?",
                [(income, f'guard-0-{slot}')
                 for slot, income in enumerate((40, 90, 160, 230))])
            await db.commit()

        # Scarce guards cover an explicitly threatened low-income property and
        # then the most valuable property; the war reserve is untouched.
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            holdings = await (await db.execute(
                "SELECT * FROM npc_empire_holdings WHERE leader_id='leila'"
            )).fetchall()
            await ne._rebalance_npc_holding_guards(
                db, 'leila', holdings, 5, 1, start,
                {'business:guard-0-0'})
            await db.commit()
        async with aiosqlite.connect(path) as db:
            rows = dict(await (await db.execute(
                "SELECT holding_ref,living FROM npc_empire_guard_assignments "
                "WHERE owner_kind='npc' AND owner_id='leila'"
            )).fetchall())
            assert rows == {'business:guard-0-0': 1,
                            'business:guard-0-3': 1}, rows

        ruined_id = ne.PROFILES[0].leader_id
        transferred_ref = 'business:guard-1-3'
        comeback_assignments = []
        total_casualties = 0
        for day in range(180):
            now = start + (day + 1) * 86400
            async with aiosqlite.connect(path) as db:
                db.row_factory = aiosqlite.Row
                await db.execute('BEGIN IMMEDIATE')

                # Ownership transfer must not leave the old owner's slot behind.
                if day == 45:
                    await ne._clear_holding_guard_assignment(
                        db, 'npc', ne.PROFILES[1].leader_id, transferred_ref)
                    await db.execute(
                        "UPDATE npc_empire_holdings SET leader_id=? "
                        "WHERE kind='business' AND holding_id='guard-1-3'",
                        (ne.PROFILES[2].leader_id,))

                if day == 80:
                    await ne._collapse_empire(
                        db, ruined_id, now, 'stress', 'deterministic guard stress')
                if day == 86:
                    await db.execute(
                        "UPDATE npc_empires SET comeback_at=? WHERE leader_id=?",
                        (now, ruined_id))
                    await ne._revive_due_empires(db, now, [])
                if day == 92:
                    await db.execute(
                        "INSERT INTO npc_empire_holdings"
                        "(kind,holding_id,leader_id,income,defense,acquired_at) "
                        "VALUES('business','guard-return',?,150,50,?)",
                        (ruined_id, now))

                empire_rows = await (await db.execute(
                    "SELECT * FROM npc_empires ORDER BY leader_id"
                )).fetchall()
                for family_index, empire in enumerate(empire_rows):
                    leader_id = str(empire['leader_id'])
                    status = str(empire['status'])
                    if status == 'ruined':
                        assert not await (await db.execute(
                            "SELECT 1 FROM npc_empire_guard_assignments "
                            "WHERE owner_kind='npc' AND owner_id=?", (leader_id,)
                        )).fetchone()
                        continue
                    wars = (day + family_index) % 3
                    members = max(0, int(empire['members'] or 0))
                    treasury = max(0, int(empire['treasury'] or 0))
                    strength = max(0, int(empire['strength'] or 0))
                    current_guards = int((await (await db.execute(
                        "SELECT COALESCE(SUM(living),0) FROM npc_empire_guard_assignments "
                        "WHERE owner_kind='npc' AND owner_id=?", (leader_id,)
                    )).fetchone())[0] or 0)
                    holdings = await (await db.execute(
                        "SELECT * FROM npc_empire_holdings WHERE leader_id=?", (leader_id,)
                    )).fetchall()
                    income = sum(max(0, int(item['income'] or 0)) for item in holdings)
                    budget = ne.apply_operating_budget(
                        ne.PROFILE_BY_ID[leader_id], treasury=treasury,
                        members=max(1, members), strength=max(20, strength),
                        income_per_tick=max(0, income), guard_slots=current_guards,
                        active_wars=wars, ticks=1,
                        insolvent_ticks=int(empire['insolvent_ticks'] or 0),
                        recovery_ticks_remaining=int(empire['recovery_ticks_remaining'] or 0))
                    members = int(budget['members'])
                    treasury = int(budget['treasury'])
                    strength = int(budget['strength'])
                    if day % 10 == family_index % 10 and members < 12:
                        hire_cost = ne.recruitment_cost(members)
                        if treasury - hire_cost >= ne.operating_reserve(
                                members + 1, current_guards, wars):
                            treasury -= hire_cost
                            members += 1
                            strength += 8

                    # Repeated bounded combat losses happen after the opening
                    # budget/allocation, matching the production ordering that
                    # previously left ghost assignments until the next poll.
                    if day % 13 == family_index % 13 and members > 2:
                        loss = min(2, members - 2)
                        members -= loss
                        strength = max(20, strength - loss * 5)
                        total_casualties += loss
                    await db.execute(
                        "UPDATE npc_empires SET treasury=?,members=?,strength=?,"
                        "insolvent_ticks=?,recovery_ticks_remaining=? WHERE leader_id=?",
                        (treasury, members, strength,
                         int(budget['insolvent_ticks']),
                         int(budget['recovery_ticks_remaining']), leader_id))
                    threatened = ({f"business:guard-{family_index}-0"}
                                  if day % 7 == 0 else set())
                    await ne._rebalance_npc_holding_guards(
                        db, leader_id, holdings, members, wars, now, threatened)
                    await assert_invariants(db, leader_id, members, wars)
                    if leader_id == ruined_id and day >= 86:
                        comeback_assignments.append(int((await (await db.execute(
                            "SELECT COALESCE(SUM(living),0) FROM npc_empire_guard_assignments "
                            "WHERE owner_kind='npc' AND owner_id=?", (leader_id,)
                        )).fetchone())[0] or 0))
                await db.commit()

        assert total_casualties > 100
        assert comeback_assignments and comeback_assignments[0] == 0
        assert max(comeback_assignments) > 0
        async with aiosqlite.connect(path) as db:
            assert not await (await db.execute(
                "SELECT 1 FROM npc_empire_guard_assignments "
                "WHERE owner_kind='npc' AND owner_id=? AND holding_ref=?",
                (ne.PROFILES[1].leader_id, transferred_ref))).fetchone()
            new_owner = await (await db.execute(
                "SELECT leader_id FROM npc_empire_holdings "
                "WHERE kind='business' AND holding_id='guard-1-3'"
            )).fetchone()
            assert new_owner and str(new_owner[0]) == ne.PROFILES[2].leader_id
        print('npc guard allocation: 19 families x 180 days, war reserves, '
              f'{total_casualties} casualties, threat/value priority, transfer, '
              'ruin and gradual comeback OK')
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
