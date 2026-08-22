"""Focused Economy A contract: causal bands, atomic spend and private cash."""

import asyncio
import os
import sqlite3
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


async def _row(path: str, sql: str, params=()):
    async with aiosqlite.connect(path) as db:
        db.row_factory = aiosqlite.Row
        return await (await db.execute(sql, params)).fetchone()


async def run() -> None:
    members, guards, wars = 8, 2, 1
    reserve = ne.operating_reserve(members, guards, wars)
    poor = ne.boss_budget_state(
        treasury=reserve - 1, members=members, guard_slots=guards,
        active_wars=wars)
    stable_low = ne.boss_budget_state(
        treasury=reserve, members=members, guard_slots=guards,
        active_wars=wars)
    stable_high = ne.boss_budget_state(
        treasury=reserve * 2 - 1, members=members, guard_slots=guards,
        active_wars=wars)
    rich = ne.boss_budget_state(
        treasury=reserve * 2, members=members, guard_slots=guards,
        active_wars=wars)
    forced_poor = ne.boss_budget_state(
        treasury=reserve * 20, members=members, guard_slots=guards,
        active_wars=wars, recovery_ticks_remaining=1)
    assert [poor['band'], stable_low['band'], stable_high['band'], rich['band']] == [
        'poor', 'stable', 'stable', 'rich']
    assert not any(poor['allows'].values())
    assert stable_low['allows'] == {
        'hire': True, 'fortify': True, 'aggressive_spend': False}
    assert all(rich['allows'].values()) and forced_poor['band'] == 'poor'
    for state in (poor, stable_low, stable_high, rich, forced_poor):
        assert not {'treasury', 'reserve', 'amount', 'cash'} & set(state)

    holding = {'kind': 'building', 'holding_id': '1,1', 'income': 120,
               'defense': 60}
    stable_plan = ne._boss_brain(
        ne.PROFILE_BY_ID['zara'],
        {'treasury': reserve, 'members': members, 'strength': 150,
         'status': 'active', 'hospital_until': 0},
        [holding], [], 2_420_000_000, active_wars=1,
        neutral_buildings=5, affordable_businesses=5,
        guard_slots=guards)
    poor_plan = ne._boss_brain(
        ne.PROFILE_BY_ID['zara'],
        {'treasury': reserve - 1, 'members': members, 'strength': 150,
         'status': 'active', 'hospital_until': 0},
        [holding], [], 2_420_000_000, active_wars=1,
        neutral_buildings=5, affordable_businesses=5,
        guard_slots=guards)
    assert stable_plan['strategy'] not in {'retaliate', 'acquire', 'expand'}
    assert poor_plan['strategy'] in {'recover', 'consolidate'}
    assert stable_plan['budget']['band'] == 'stable'
    assert poor_plan['budget']['band'] == 'poor'

    fd, path = tempfile.mkstemp(prefix='npc_budget_state_', suffix='.db')
    os.close(fd)
    try:
        await _base_db(path)
        now = 2_420_000_000
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET treasury=0,members=8,last_recruit_at=0 "
                "WHERE leader_id='leila'")
            await db.commit()
        before = await _row(
            path, "SELECT treasury,members,strength FROM npc_empires WHERE leader_id='leila'")
        refused = await ne.recruit_street_fighter(
            path, 'leila', 'budget-poor', 'bellini', now=now)
        after = await _row(
            path, "SELECT treasury,members,strength FROM npc_empires WHERE leader_id='leila'")
        assert not refused['ok'] and refused['error'] == 'budget constrained'
        assert tuple(after) == tuple(before)
        assert not {'treasury', 'reserve', 'cost'} & set(refused)

        cost = ne.recruitment_cost(8)
        reserve_after = ne.operating_reserve(9, 0, 0)
        rich_cash = max(ne.operating_reserve(8, 0, 0) * 2, reserve_after + cost)
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET treasury=?,last_recruit_at=0 "
                "WHERE leader_id='leila'", (rich_cash,))
            await db.commit()
        hired = await ne.recruit_street_fighter(
            path, 'leila', 'budget-idempotent', 'bellini', now=now + 20)
        charged = await _row(
            path, "SELECT treasury,members,strength FROM npc_empires WHERE leader_id='leila'")
        replay = await ne.recruit_street_fighter(
            path, 'leila', 'budget-idempotent', 'bellini', now=now + 40)
        replayed = await _row(
            path, "SELECT treasury,members,strength FROM npc_empires WHERE leader_id='leila'")
        assert hired['ok'] and replay['ok'] and replay['duplicate']
        assert tuple(charged) == tuple(replayed)
        assert not {'treasury', 'reserve', 'cost'} & set(hired)

        rollback_cash = max(ne.operating_reserve(9, 0, 0) * 2,
                            ne.operating_reserve(10, 0, 0) + ne.recruitment_cost(9))
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET treasury=?,last_recruit_at=0 "
                "WHERE leader_id='leila'", (rollback_cash,))
            await db.execute(
                "CREATE TRIGGER fail_budget_event BEFORE INSERT ON npc_empire_events "
                "WHEN NEW.kind='street_recruit' BEGIN SELECT RAISE(ABORT,'budget rollback'); END")
            await db.commit()
        rollback_before = await _row(
            path, "SELECT treasury,members,strength FROM npc_empires WHERE leader_id='leila'")
        try:
            await ne.recruit_street_fighter(
                path, 'leila', 'budget-rollback', 'moretti', now=now + 60)
            raise AssertionError('injected write failure must propagate')
        except sqlite3.IntegrityError as exc:
            assert 'budget rollback' in str(exc)
        rollback_after = await _row(
            path, "SELECT treasury,members,strength FROM npc_empires WHERE leader_id='leila'")
        assert tuple(rollback_after) == tuple(rollback_before)
        assert not await _row(
            path, "SELECT source_id FROM npc_empire_street_recruits WHERE source_id='budget-rollback'")

        snapshot = await ne.state_for(path, 101, now=now + 61)
        assert len(snapshot['empires']) == 19
        assert all(set(empire['budget']) == {'band', 'label', 'summary', 'allows'}
                   for empire in snapshot['empires'])
        assert all('treasury' not in empire and 'economy' not in empire
                   for empire in snapshot['empires'])

        world = open('world.html', encoding='utf-8').read()
        preview = open('_preview_ws_server.py', encoding='utf-8').read()
        assert 'data-ne-budget-band' in world and 'budget.summary' in world
        assert 'empire.treasury' not in world
        assert '<small>КАЗНА</small><b>$${(+empire.' not in world
        assert "empires[-1]['budget'] = empires[-1]['brain']['budget']" in preview
        assert '"weapon_base": profile.weapon_base, "treasury"' not in preview
        print('Economy A: exact poor/stable/rich boundaries; poor spend blocked; '
              'success idempotent; injected failure rolled back; public API/UI hide cash')
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
