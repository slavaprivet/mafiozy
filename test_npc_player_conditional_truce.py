"""Diplomacy A: conditional truce terms, atomic fulfillment and replay safety."""

import asyncio
import os
import sqlite3
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


async def _row(path, sql, params=()):
    async with aiosqlite.connect(path) as db:
        db.row_factory = aiosqlite.Row
        return await (await db.execute(sql, params)).fetchone()


async def _war(path, uid, leader, score=-60, cash=None):
    async with aiosqlite.connect(path) as db:
        await db.execute(
            "INSERT INTO npc_empire_relations(leader_id,telegram_id,score,pact,last_action_at) "
            "VALUES(?,? ,?,'war',0) ON CONFLICT(leader_id,telegram_id) DO UPDATE SET "
            "score=excluded.score,pact='war',last_action_at=0", (leader, uid, score))
        await db.execute(
            "INSERT INTO npc_empire_player_wars(leader_id,telegram_id,next_attack_at) "
            "VALUES(?,?,9999999999) ON CONFLICT(leader_id,telegram_id) DO NOTHING",
            (leader, uid))
        if cash is not None:
            await db.execute("UPDATE characters SET cash=? WHERE telegram_id=?", (cash, uid))
        await db.commit()


async def run():
    fd, path = tempfile.mkstemp(prefix='npc_conditional_truce_', suffix='.db')
    os.close(fd)
    now = 2_470_000_000
    try:
        await _base_db(path)
        await _war(path, 101, 'leila', score=-61, cash=300)
        before = await _row(path, "SELECT cash FROM characters WHERE telegram_id=101")
        blocked = await ne.conditional_truce_action(
            path, 101, 'leila', 'offer', 'truce:blocked', now=now)
        assert not blocked['ok'] and blocked['error'] == 'relation too low'
        assert (await _row(path, "SELECT cash FROM characters WHERE telegram_id=101"))['cash'] == before['cash']
        assert not await _row(path, "SELECT agreement_id FROM npc_empire_player_agreements")

        await _war(path, 101, 'leila', score=-60, cash=299)
        offered = await ne.conditional_truce_action(
            path, 101, 'leila', 'offer', 'truce:offer', now=now + 1)
        agreement = offered['agreement']; agreement_id = agreement['agreement_id']
        assert offered['ok'] and not offered['duplicate']
        assert agreement['state'] == 'offered' and agreement['action'] == 'fulfill'
        assert agreement['terms'][0] == {
            'kind': 'compensation', 'label': 'Компенсация $300', 'state': 'pending'}
        assert not ({'treasury', 'reserve', 'chance', 'roll'} & set(agreement))
        no_cash = await ne.conditional_truce_action(
            path, 101, 'leila', 'fulfill', 'truce:fulfill', agreement_id, now + 2)
        assert not no_cash['ok'] and no_cash['error'] == 'no cash'
        assert (await _row(path, "SELECT pact FROM npc_empire_relations "
                           "WHERE leader_id='leila' AND telegram_id=101"))['pact'] == 'war'
        assert (await _row(path, "SELECT status FROM npc_empire_player_agreements "
                           "WHERE agreement_id=?", (agreement_id,)))['status'] == 'offered'

        async with aiosqlite.connect(path) as db:
            await db.execute("UPDATE characters SET cash=300 WHERE telegram_id=101")
            await db.commit()
        treasury_before = (await _row(path,
            "SELECT treasury FROM npc_empires WHERE leader_id='leila'"))['treasury']
        fulfilled = await ne.conditional_truce_action(
            path, 101, 'leila', 'fulfill', 'truce:fulfill', agreement_id, now + 3)
        assert fulfilled['ok'] and not fulfilled['duplicate'] and fulfilled['cash'] == 0
        assert fulfilled['pact'] == 'truce' and fulfilled['relation'] == -20
        assert fulfilled['agreement']['state'] == 'fulfilled'
        assert (await _row(path, "SELECT treasury FROM npc_empires "
                           "WHERE leader_id='leila'"))['treasury'] == treasury_before + 300
        assert not await _row(path, "SELECT leader_id FROM npc_empire_player_wars "
                              "WHERE leader_id='leila' AND telegram_id=101")
        state_after = tuple(await _row(path, "SELECT cash FROM characters WHERE telegram_id=101"))
        replay = await ne.conditional_truce_action(
            path, 101, 'leila', 'fulfill', 'truce:fulfill', agreement_id, now + 4)
        assert replay['ok'] and replay['duplicate']
        assert tuple(await _row(path, "SELECT cash FROM characters WHERE telegram_id=101")) == state_after

        # Concurrent fulfillment serializes to one paid transition and one replay.
        await _war(path, 101, 'rustam', score=-60, cash=1000)
        rustam_offer = await ne.conditional_truce_action(
            path, 101, 'rustam', 'offer', 'shared-offer', now=now + 5)
        rustam_id = rustam_offer['agreement']['agreement_id']
        concurrent = await asyncio.gather(*(
            ne.conditional_truce_action(
                path, 101, 'rustam', 'fulfill', 'shared-fulfill', rustam_id, now + 6)
            for _ in range(2)))
        assert sum(bool(result.get('duplicate')) for result in concurrent) == 1
        assert (await _row(path, "SELECT COUNT(*) AS n FROM npc_empire_events "
                           "WHERE leader_id='rustam' AND kind='conditional_truce_fulfilled'"))['n'] == 1

        # A failure at the final event rolls back cash, treasury, pact, war and ledger.
        await _war(path, 101, 'marco', score=-60, cash=300)
        marco_offer = await ne.conditional_truce_action(
            path, 101, 'marco', 'offer', 'rollback-offer', now=now + 7)
        marco_id = marco_offer['agreement']['agreement_id']
        rollback_before = tuple(await _row(path,
            "SELECT cash FROM characters WHERE telegram_id=101")) + tuple(await _row(path,
            "SELECT treasury FROM npc_empires WHERE leader_id='marco'"))
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "CREATE TRIGGER reject_truce_event BEFORE INSERT ON npc_empire_events "
                "WHEN NEW.kind='conditional_truce_fulfilled' "
                "BEGIN SELECT RAISE(ABORT,'truce rollback'); END")
            await db.commit()
        try:
            await ne.conditional_truce_action(
                path, 101, 'marco', 'fulfill', 'rollback-fulfill', marco_id, now + 8)
            raise AssertionError('forced failure must abort')
        except sqlite3.IntegrityError as exc:
            assert 'truce rollback' in str(exc)
        rollback_after = tuple(await _row(path,
            "SELECT cash FROM characters WHERE telegram_id=101")) + tuple(await _row(path,
            "SELECT treasury FROM npc_empires WHERE leader_id='marco'"))
        assert rollback_after == rollback_before
        assert (await _row(path, "SELECT pact FROM npc_empire_relations "
                           "WHERE leader_id='marco' AND telegram_id=101"))['pact'] == 'war'
        assert (await _row(path, "SELECT status FROM npc_empire_player_agreements "
                           "WHERE agreement_id=?", (marco_id,)))['status'] == 'offered'
        assert await _row(path, "SELECT leader_id FROM npc_empire_player_wars "
                          "WHERE leader_id='marco' AND telegram_id=101")
        async with aiosqlite.connect(path) as db:
            await db.execute("DROP TRIGGER reject_truce_event")
            await db.commit()
        retry = await ne.conditional_truce_action(
            path, 101, 'marco', 'fulfill', 'rollback-fulfill', marco_id, now + 9)
        assert retry['ok'] and not retry['duplicate']

        # Changed pact and a boss comeback invalidate stale terms without a spend.
        await _war(path, 101, 'vera', score=-60, cash=600)
        vera_offer = await ne.conditional_truce_action(
            path, 101, 'vera', 'offer', 'stale-offer', now=now + 10)
        async with aiosqlite.connect(path) as db:
            await db.execute("UPDATE npc_empire_relations SET pact='alliance' "
                             "WHERE leader_id='vera' AND telegram_id=101")
            await db.commit()
        stale_cash = (await _row(path, "SELECT cash FROM characters WHERE telegram_id=101"))['cash']
        stale = await ne.conditional_truce_action(
            path, 101, 'vera', 'fulfill', 'stale-fulfill',
            vera_offer['agreement']['agreement_id'], now + 11)
        assert not stale['ok'] and stale['error'] == 'pact changed'
        assert (await _row(path, "SELECT cash FROM characters WHERE telegram_id=101"))['cash'] == stale_cash

        await _war(path, 101, 'alisa', score=-60, cash=600)
        old = await ne.conditional_truce_action(
            path, 101, 'alisa', 'offer', 'generation-key', now=now + 12)
        async with aiosqlite.connect(path) as db:
            await db.execute("UPDATE npc_empires SET comebacks=comebacks+1 "
                             "WHERE leader_id='alisa'")
            await db.commit()
        old_reply = await ne.conditional_truce_action(
            path, 101, 'alisa', 'fulfill', 'old-generation',
            old['agreement']['agreement_id'], now + 13)
        assert not old_reply['ok'] and old_reply['error'] == 'stale agreement'
        new = await ne.conditional_truce_action(
            path, 101, 'alisa', 'offer', 'generation-key', now=now + 14)
        assert new['ok'] and not new['duplicate']

        # Identical client keys stay independent across players and families.
        await _war(path, 101, 'niko', score=-60, cash=600)
        await _war(path, 202, 'niko', score=-60, cash=600)
        pair_a = await ne.conditional_truce_action(
            path, 101, 'niko', 'offer', 'pair-key', now=now + 15)
        pair_b = await ne.conditional_truce_action(
            path, 202, 'niko', 'offer', 'pair-key', now=now + 15)
        await _war(path, 101, 'sofia', score=-60)
        family_b = await ne.conditional_truce_action(
            path, 101, 'sofia', 'offer', 'pair-key', now=now + 15)
        assert all(result['ok'] and not result['duplicate']
                   for result in (pair_a, pair_b, family_b))

        public = await ne.state_for(path, 101, now=now + 16)
        niko = next(empire for empire in public['empires'] if empire['leader_id'] == 'niko')
        assert niko['player_agreement']['state'] == 'offered'
        assert set(niko['player_agreement']) == {
            'kind', 'state', 'status_label', 'summary', 'agreement_id',
            'terms', 'consequences', 'action'}
        world = open('world.html', encoding='utf-8').read()
        assert 'data-ne-truce-state' not in world  # DOM dataset uses camelCase source.
        assert 'dataset.neTruceState' in world and 'data-ne-term-state' in world
        assert 'УСЛОВНОЕ ПЕРЕМИРИЕ' in world and 'truce_fulfill' in world
        print('conditional truce: locked visible terms, atomic payment, rollback, '
              'replay, pair and comeback isolation OK')
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
