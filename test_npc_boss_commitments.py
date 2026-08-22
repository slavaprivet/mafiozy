"""Economy B: real upkeep pressure and atomic idempotent procurement."""

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
    payroll = ne.boss_commitment_state(
        income_per_tick=10, members=12, guard_slots=1, active_wars=0,
        budget_band='poor', strength=90)
    security = ne.boss_commitment_state(
        income_per_tick=100, members=2, guard_slots=8, active_wars=0,
        budget_band='stable', strength=30)
    war = ne.boss_commitment_state(
        income_per_tick=200, members=2, guard_slots=0, active_wars=3,
        budget_band='rich', strength=50)
    assert payroll['dominant'] == 'payroll' and payroll['pressure'] == 'critical'
    assert security['dominant'] == 'security' and security['pressure'] == 'managed'
    assert war['dominant'] == 'war' and war['pressure'] == 'comfortable'
    assert payroll['procurement'] == 'frozen'
    assert not any(isinstance(value, (int, float)) for state in (payroll, security, war)
                   for value in state.values())

    profile = ne.PROFILE_BY_ID['leila']
    budget_tick = ne.apply_operating_budget(
        profile, treasury=5000, members=10, strength=80,
        income_per_tick=100, guard_slots=2, active_wars=1, ticks=1)
    expected_upkeep = (10 * ne.NPC_MEMBER_UPKEEP_PER_TICK
                       + 2 * ne.NPC_HOLDING_GUARD_UPKEEP_PER_TICK
                       + ne.NPC_ACTIVE_WAR_UPKEEP_PER_TICK)
    assert budget_tick['upkeep_paid'] == expected_upkeep
    assert budget_tick['treasury'] == 5000 + 100 - expected_upkeep

    fd, path = tempfile.mkstemp(prefix='npc_commitments_', suffix='.db')
    os.close(fd)
    try:
        await _base_db(path)
        now = 2_430_000_000
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET treasury=5000,members=10,strength=70 "
                "WHERE leader_id='leila'")
            await db.commit()
        before = await _row(
            path, "SELECT treasury,strength FROM npc_empires WHERE leader_id='leila'")
        bought = await ne.procure_boss_supplies(
            path, 'leila', 'economy-b:success', now=now)
        after = await _row(
            path, "SELECT treasury,strength FROM npc_empires WHERE leader_id='leila'")
        assert bought['ok'] and not bought['duplicate']
        assert after['treasury'] < before['treasury'] and after['strength'] > before['strength']
        assert not {'treasury', 'cost', 'reserve', 'strength_gain'} & set(bought)
        assert await _row(path,
            "SELECT request_key FROM npc_empire_procurements "
            "WHERE request_key='economy-b:success'")

        replay = await ne.procure_boss_supplies(
            path, 'leila', 'economy-b:success', now=now + 1)
        replayed = await _row(
            path, "SELECT treasury,strength FROM npc_empires WHERE leader_id='leila'")
        assert replay['ok'] and replay['duplicate'] and tuple(replayed) == tuple(after)

        # A retry token is scoped to one family generation, not globally.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET treasury=5000,members=10,strength=70 "
                "WHERE leader_id='rustam'")
            await db.commit()
        other_family = await ne.procure_boss_supplies(
            path, 'rustam', 'economy-b:success', now=now + 1)
        assert other_family['ok'] and not other_family['duplicate']
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET comebacks=comebacks+1,treasury=5000,"
                "members=10,strength=70 WHERE leader_id='leila'")
            await db.commit()
        next_generation = await ne.procure_boss_supplies(
            path, 'leila', 'economy-b:success', now=now + 1)
        assert next_generation['ok'] and not next_generation['duplicate']
        receipt_count = await _row(
            path, "SELECT COUNT(*) AS n FROM npc_empire_procurements "
                  "WHERE request_key='economy-b:success'")
        assert receipt_count['n'] == 3

        # BEGIN IMMEDIATE serializes a concurrent replay into one paid action.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET treasury=5000,members=10,strength=70 "
                "WHERE leader_id='leila'")
            before_version = int((await (await db.execute(
                "SELECT version FROM npc_empires WHERE leader_id='leila'"
            )).fetchone())[0])
            player_cash = [tuple(row) for row in await (await db.execute(
                "SELECT telegram_id,cash FROM characters ORDER BY telegram_id"
            )).fetchall()]
            await db.commit()
        concurrent = await asyncio.gather(*(
            ne.procure_boss_supplies(path, 'leila', 'economy-b:concurrent',
                                     now=now + 2)
            for _ in range(2)))
        assert sum(bool(item.get('duplicate')) for item in concurrent) == 1
        concurrent_row = await _row(
            path, "SELECT version FROM npc_empires WHERE leader_id='leila'")
        concurrent_receipts = await _row(
            path, "SELECT COUNT(*) AS n FROM npc_empire_procurements "
                  "WHERE leader_id='leila' AND request_key='economy-b:concurrent'")
        concurrent_events = await _row(
            path, "SELECT COUNT(*) AS n FROM npc_empire_events "
                  "WHERE leader_id='leila' AND kind='supplies_bought' "
                  "AND target_id='economy-b:concurrent'")
        async with aiosqlite.connect(path) as db:
            cash_after = [tuple(row) for row in await (await db.execute(
                "SELECT telegram_id,cash FROM characters ORDER BY telegram_id"
            )).fetchall()]
        assert int(concurrent_row['version']) == before_version + 1
        assert concurrent_receipts['n'] == concurrent_events['n'] == 1
        assert cash_after == player_cash

        # Rich-looking cash still cannot bypass the exact post-cost reserve.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET treasury=839,members=10,strength=70,"
                "insolvent_ticks=0,recovery_ticks_remaining=0 WHERE leader_id='leila'")
            await db.commit()
        reserve_refusal = await ne.procure_boss_supplies(
            path, 'leila', 'economy-b:reserve-refusal', now=now + 3)
        assert not reserve_refusal['ok'] and reserve_refusal['error'] == 'budget constrained'
        assert not await _row(path,
            "SELECT request_key FROM npc_empire_procurements "
            "WHERE request_key='economy-b:reserve-refusal'")
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET treasury=840 WHERE leader_id='leila'")
            await db.commit()
        reserve_edge = await ne.procure_boss_supplies(
            path, 'leila', 'economy-b:reserve-edge', now=now + 3)
        assert reserve_edge['ok'] and not reserve_edge['duplicate']

        # Economy A insolvency/recovery authority overrides a large treasury.
        for field in ('insolvent_ticks', 'recovery_ticks_remaining'):
            async with aiosqlite.connect(path) as db:
                await db.execute(
                    f"UPDATE npc_empires SET treasury=5000,strength=70,"
                    f"insolvent_ticks=0,recovery_ticks_remaining=0,{field}=2 "
                    "WHERE leader_id='leila'")
                await db.commit()
            blocked = await ne.procure_boss_supplies(
                path, 'leila', f'economy-b:{field}', now=now + 3)
            assert not blocked['ok'] and blocked['error'] == 'budget constrained'
            assert not await _row(path,
                "SELECT request_key FROM npc_empire_procurements WHERE request_key=?",
                (f'economy-b:{field}',))

        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET treasury=5000,strength=220,"
                "insolvent_ticks=0,recovery_ticks_remaining=0 "
                "WHERE leader_id='leila'")
            await db.commit()
        ready_before = await _row(
            path, "SELECT treasury,strength FROM npc_empires WHERE leader_id='leila'")
        ready = await ne.procure_boss_supplies(
            path, 'leila', 'economy-b:ready', now=now + 2)
        ready_after = await _row(
            path, "SELECT treasury,strength FROM npc_empires WHERE leader_id='leila'")
        assert not ready['ok'] and ready['error'] == 'arsenal ready'
        assert tuple(ready_after) == tuple(ready_before)

        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET treasury=0,strength=70,"
                "insolvent_ticks=0,recovery_ticks_remaining=0 "
                "WHERE leader_id='leila'")
            await db.commit()
        poor_before = await _row(
            path, "SELECT treasury,strength FROM npc_empires WHERE leader_id='leila'")
        poor = await ne.procure_boss_supplies(
            path, 'leila', 'economy-b:poor', now=now + 3)
        poor_after = await _row(
            path, "SELECT treasury,strength FROM npc_empires WHERE leader_id='leila'")
        assert not poor['ok'] and poor['error'] == 'budget constrained'
        assert tuple(poor_after) == tuple(poor_before)
        long_key = await ne.procure_boss_supplies(
            path, 'leila', 'x' * 129, now=now + 3)
        assert not long_key['ok'] and long_key['error'] == 'bad request key'

        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET treasury=5000,strength=70,"
                "insolvent_ticks=0,recovery_ticks_remaining=0 "
                "WHERE leader_id='leila'")
            await db.execute(
                "CREATE TRIGGER fail_supply_event BEFORE INSERT ON npc_empire_events "
                "WHEN NEW.kind='supplies_bought' "
                "BEGIN SELECT RAISE(ABORT,'supply rollback'); END")
            await db.commit()
        rollback_before = await _row(
            path, "SELECT treasury,strength FROM npc_empires WHERE leader_id='leila'")
        try:
            await ne.procure_boss_supplies(
                path, 'leila', 'economy-b:rollback', now=now + 4)
            raise AssertionError('injected event failure must propagate')
        except sqlite3.IntegrityError as exc:
            assert 'supply rollback' in str(exc)
        rollback_after = await _row(
            path, "SELECT treasury,strength FROM npc_empires WHERE leader_id='leila'")
        assert tuple(rollback_after) == tuple(rollback_before)
        assert not await _row(path,
            "SELECT request_key FROM npc_empire_procurements "
            "WHERE request_key='economy-b:rollback'")
        async with aiosqlite.connect(path) as db:
            await db.execute("DROP TRIGGER fail_supply_event")
            await db.commit()

        snapshot = await ne.state_for(path, 101, now=now + 5)
        assert all(set(empire['commitments']) == {
            'dominant', 'dominant_label', 'pressure', 'pressure_label',
            'readiness', 'readiness_label', 'procurement', 'income_outlook'}
                   for empire in snapshot['empires'])
        assert all(not any(isinstance(value, (int, float))
                           for value in empire['commitments'].values())
                   for empire in snapshot['empires'])
        world = open('world.html', encoding='utf-8').read()
        assert 'data-ne-commitment' in world and 'commitments.pressure_label' in world
        assert 'commitments.cost' not in world and 'commitments.upkeep' not in world
        assert 'Доход со всей сети за минуту' not in world
        assert 'Состав защитников будет подтверждён только после контакта' in world
        assert 'охрана не подтверждена' in world

        # The real tick path pays once, reports the decision and does not also hire.
        auto_fd, auto_path = tempfile.mkstemp(prefix='npc_commitments_auto_', suffix='.db')
        os.close(auto_fd)
        try:
            await _base_db(auto_path)
            await ne.ensure_schema(auto_path)
            auto_now = now + ne.TICK_SECONDS * 20
            async with aiosqlite.connect(auto_path) as db:
                await db.execute("UPDATE npc_empires SET status='ruined'")
                await db.execute(
                    "UPDATE npc_empires SET status='active',treasury=5000,members=10,"
                    "strength=70,last_tick=?,next_action_at=0,pending_recruits=0,"
                    "insolvent_ticks=0,recovery_ticks_remaining=0 WHERE leader_id='leila'",
                    (auto_now - ne.TICK_SECONDS,))
                await db.commit()
            original_brain = ne._boss_brain
            original_due = ne._strategy_execution_due
            ne._boss_brain = lambda *args, **kwargs: {'strategy': 'fortify'}
            ne._strategy_execution_due = (
                lambda profile, action, tick: action == 'fortify')
            try:
                auto_before = await _row(
                    auto_path, "SELECT treasury,strength,members,pending_recruits,version "
                               "FROM npc_empires WHERE leader_id='leila'")
                auto_events = await ne.advance(auto_path, now=auto_now)
                auto_after = await _row(
                    auto_path, "SELECT treasury,strength,members,pending_recruits,version "
                               "FROM npc_empires WHERE leader_id='leila'")
                assert any(event['kind'] == 'supplies_bought' for event in auto_events)
                assert auto_after['treasury'] < auto_before['treasury']
                assert auto_after['strength'] > auto_before['strength']
                assert auto_after['members'] == auto_before['members']
                assert auto_after['pending_recruits'] == 0
                receipt_before_replay = await _row(
                    auto_path, "SELECT COUNT(*) AS n FROM npc_empire_procurements")
                event_before_replay = await _row(
                    auto_path, "SELECT COUNT(*) AS n FROM npc_empire_events "
                               "WHERE kind='supplies_bought'")
                replay_events = await ne.advance(auto_path, now=auto_now)
                auto_replayed = await _row(
                    auto_path, "SELECT treasury,strength,members,pending_recruits,version "
                               "FROM npc_empires WHERE leader_id='leila'")
                receipt_after_replay = await _row(
                    auto_path, "SELECT COUNT(*) AS n FROM npc_empire_procurements")
                event_after_replay = await _row(
                    auto_path, "SELECT COUNT(*) AS n FROM npc_empire_events "
                               "WHERE kind='supplies_bought'")
                assert not any(event['kind'] == 'supplies_bought'
                               for event in replay_events)
                assert tuple(auto_replayed) == tuple(auto_after)
                assert receipt_after_replay['n'] == receipt_before_replay['n'] == 1
                assert event_after_replay['n'] == event_before_replay['n'] == 1
            finally:
                ne._boss_brain = original_brain
                ne._strategy_execution_due = original_due
        finally:
            os.unlink(auto_path)
        print('Economy B: real payroll; qualitative pressure; paid supply step; '
              'impossible spend blocked; retry idempotent; injected failure rolled back')
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
