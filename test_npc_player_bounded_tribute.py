"""Diplomacy B: bounded tribute, atomic receipts and pressure lifecycle."""

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


async def _war(path, uid, leader, score=-61, cash=1000, next_attack=9_999_999_999):
    async with aiosqlite.connect(path) as db:
        await db.execute(
            "INSERT INTO npc_empire_relations(leader_id,telegram_id,score,pact,last_action_at) "
            "VALUES(?,? ,?,'war',0) ON CONFLICT(leader_id,telegram_id) DO UPDATE SET "
            "score=excluded.score,pact='war',last_action_at=0", (leader, uid, score))
        await db.execute(
            "INSERT INTO npc_empire_player_wars(leader_id,telegram_id,next_attack_at) "
            "VALUES(?,?,?) ON CONFLICT(leader_id,telegram_id) DO UPDATE SET "
            "next_attack_at=excluded.next_attack_at", (leader, uid, next_attack))
        await db.execute("UPDATE characters SET cash=? WHERE telegram_id=?", (cash, uid))
        await db.commit()


async def _offer(path, uid, leader, key, now):
    return await ne.bounded_tribute_action(path, uid, leader, 'offer', key, now=now)


async def _accept(path, uid, leader, key, agreement_id, now):
    return await ne.bounded_tribute_action(
        path, uid, leader, 'accept', key, agreement_id, now)


async def run():
    fd, path = tempfile.mkstemp(prefix='npc_bounded_tribute_', suffix='.db')
    os.close(fd)
    now = 2_480_000_000
    passed = []
    try:
        await _base_db(path)

        # 1. Eligibility is disjoint from Diplomacy A at the -60/-61 boundary.
        await _war(path, 101, 'leila', score=-60)
        blocked = await _offer(path, 101, 'leila', 'boundary:-60', now)
        assert not blocked['ok'] and blocked['error'] == 'tribute unavailable'
        await _war(path, 101, 'leila', score=-61)
        offered = await _offer(path, 101, 'leila', 'boundary:-61', now + 1)
        assert offered['ok'] and offered['agreement']['state'] == 'offered'
        passed.append('eligibility')

        # 2. The row and public contract lock the exact visible amount/window.
        tribute_id = offered['agreement']['agreement_id']
        locked = await _row(path,
            "SELECT term_amount,term_seconds,relation_at_offer,pact_at_offer "
            "FROM npc_empire_player_tribute_agreements WHERE agreement_id=?",
            (tribute_id,))
        assert tuple(locked) == (150, 3600, -61, 'war')
        assert set(offered['agreement']) == {
            'kind', 'state', 'status_label', 'summary', 'agreement_id',
            'term', 'window', 'obligations', 'consequences', 'action'}
        assert not ({'treasury', 'reserve', 'chance', 'roll', 'generation',
                     'request_key', 'multiplier', 'next_attack_at'} & set(offered['agreement']))
        passed.append('locked-public-contract')

        # 3. Insufficient cash is a byte-for-byte economic/state no-write.
        await _war(path, 101, 'leila', score=-61, cash=149)
        before = tuple(await _row(path,
            "SELECT c.cash,e.treasury,e.version,r.score,r.pact,w.next_attack_at,t.status "
            "FROM characters c,npc_empires e,npc_empire_relations r,"
            "npc_empire_player_wars w,npc_empire_player_tribute_agreements t "
            "WHERE c.telegram_id=101 AND e.leader_id='leila' "
            "AND r.leader_id='leila' AND r.telegram_id=101 "
            "AND w.leader_id='leila' AND w.telegram_id=101 AND t.agreement_id=?",
            (tribute_id,)))
        no_cash = await _accept(path, 101, 'leila', 'accept:no-cash', tribute_id, now + 2)
        after = tuple(await _row(path,
            "SELECT c.cash,e.treasury,e.version,r.score,r.pact,w.next_attack_at,t.status "
            "FROM characters c,npc_empires e,npc_empire_relations r,"
            "npc_empire_player_wars w,npc_empire_player_tribute_agreements t "
            "WHERE c.telegram_id=101 AND e.leader_id='leila' "
            "AND r.leader_id='leila' AND r.telegram_id=101 "
            "AND w.leader_id='leila' AND w.telegram_id=101 AND t.agreement_id=?",
            (tribute_id,)))
        assert not no_cash['ok'] and no_cash['error'] == 'no cash' and after == before
        passed.append('no-cash-no-write')

        # 4. Acceptance debits/credits once and preserves the live war/relation.
        await _war(path, 101, 'leila', score=-61, cash=150, next_attack=now + 10)
        treasury_before = int((await _row(path,
            "SELECT treasury FROM npc_empires WHERE leader_id='leila'"))[0])
        accepted = await _accept(path, 101, 'leila', 'accept:leila', tribute_id, now + 3)
        assert accepted['ok'] and not accepted['duplicate'] and accepted['cash'] == 0
        assert accepted['pact'] == 'war' and accepted['relation'] == -61
        assert int((await _row(path,
            "SELECT treasury FROM npc_empires WHERE leader_id='leila'"))[0]) == treasury_before + 150
        assert (await _row(path,
            "SELECT pact FROM npc_empire_relations WHERE leader_id='leila' AND telegram_id=101"))[0] == 'war'
        passed.append('atomic-accept')

        # 5. Sequential stable-key replay returns the receipt without spend.
        replay_cash = int((await _row(path,
            "SELECT cash FROM characters WHERE telegram_id=101"))[0])
        replay = await _accept(path, 101, 'leila', 'accept:leila', tribute_id, now + 4)
        assert replay['ok'] and replay['duplicate']
        assert int((await _row(path,
            "SELECT cash FROM characters WHERE telegram_id=101"))[0]) == replay_cash
        passed.append('sequential-replay')

        # 6. Concurrent acceptance serializes to one payment and one event.
        await _war(path, 101, 'rustam', cash=500)
        rustam_offer = await _offer(path, 101, 'rustam', 'offer:rustam', now + 5)
        rustam_id = rustam_offer['agreement']['agreement_id']
        concurrent = await asyncio.gather(*(
            _accept(path, 101, 'rustam', 'accept:rustam', rustam_id, now + 6)
            for _ in range(2)))
        assert sum(not result.get('duplicate', False) for result in concurrent) == 1
        assert int((await _row(path,
            "SELECT COUNT(*) FROM npc_empire_events WHERE leader_id='rustam' "
            "AND kind='tribute_activated'"))[0]) == 1
        passed.append('concurrent-replay')

        # 7. A late event failure rolls back debit, credit, status and schedule.
        await _war(path, 101, 'marco', cash=150, next_attack=now + 20)
        marco_offer = await _offer(path, 101, 'marco', 'offer:rollback', now + 7)
        marco_id = marco_offer['agreement']['agreement_id']
        rollback_before = tuple(await _row(path,
            "SELECT c.cash,e.treasury,e.version,w.next_attack_at,t.status "
            "FROM characters c,npc_empires e,npc_empire_player_wars w,"
            "npc_empire_player_tribute_agreements t WHERE c.telegram_id=101 "
            "AND e.leader_id='marco' AND w.leader_id='marco' AND w.telegram_id=101 "
            "AND t.agreement_id=?", (marco_id,)))
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "CREATE TRIGGER reject_tribute_event BEFORE INSERT ON npc_empire_events "
                "WHEN NEW.kind='tribute_activated' BEGIN SELECT RAISE(ABORT,'tribute rollback'); END")
            await db.commit()
        try:
            await _accept(path, 101, 'marco', 'accept:rollback', marco_id, now + 8)
            raise AssertionError('forced rollback must abort')
        except sqlite3.IntegrityError as exc:
            assert 'tribute rollback' in str(exc)
        rollback_after = tuple(await _row(path,
            "SELECT c.cash,e.treasury,e.version,w.next_attack_at,t.status "
            "FROM characters c,npc_empires e,npc_empire_player_wars w,"
            "npc_empire_player_tribute_agreements t WHERE c.telegram_id=101 "
            "AND e.leader_id='marco' AND w.leader_id='marco' AND w.telegram_id=101 "
            "AND t.agreement_id=?", (marco_id,)))
        assert rollback_after == rollback_before
        async with aiosqlite.connect(path) as db:
            await db.execute("DROP TRIGGER reject_tribute_event"); await db.commit()
        passed.append('late-rollback')

        # 8. Active delay is private 2x; exact end terminalizes before pressure.
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            base = ne._player_war_interval(ne.PROFILE_BY_ID['leila'])
            assert await ne._player_war_delay_tx(db, 101, 'leila', base, now + 4) == base * 2
        active_until = int((await _row(path,
            "SELECT active_until FROM npc_empire_player_tribute_agreements WHERE agreement_id=?",
            (tribute_id,)))[0])
        await ne.state_for(path, 101, now=active_until)
        assert (await _row(path,
            "SELECT status FROM npc_empire_player_tribute_agreements WHERE agreement_id=?",
            (tribute_id,)))[0] == 'expired'
        assert await _row(path,
            "SELECT 1 FROM npc_empire_player_wars WHERE leader_id='leila' AND telegram_id=101")
        passed.append('delay-expiry-boundary')

        # 9. A successful authoritative street attack breaches once, no refund.
        await _war(path, 101, 'niko', cash=300)
        niko_offer = await _offer(path, 101, 'niko', 'offer:niko', now + 9)
        niko_id = niko_offer['agreement']['agreement_id']
        await _accept(path, 101, 'niko', 'accept:niko', niko_id, now + 10)
        cash_after_payment = int((await _row(path,
            "SELECT cash FROM characters WHERE telegram_id=101"))[0])
        attacked = await ne.diplomacy_action(path, 101, 'niko', 'street_attack', now + 11)
        assert attacked['ok']
        assert (await _row(path,
            "SELECT status FROM npc_empire_player_tribute_agreements WHERE agreement_id=?",
            (niko_id,)))[0] == 'breached'
        assert int((await _row(path,
            "SELECT cash FROM characters WHERE telegram_id=101"))[0]) == cash_after_payment
        assert int((await _row(path,
            "SELECT COUNT(*) FROM npc_empire_events WHERE leader_id='niko' "
            "AND kind='tribute_breached'"))[0]) == 1
        passed.append('authoritative-breach')

        # 10. Pact change invalidates offered/active rows without restoring war.
        await _war(path, 101, 'vera', cash=300)
        vera_offer = await _offer(path, 101, 'vera', 'offer:vera', now + 12)
        async with aiosqlite.connect(path) as db:
            await db.execute("UPDATE npc_empire_relations SET pact='truce' "
                             "WHERE leader_id='vera' AND telegram_id=101")
            await db.commit()
        changed = await _accept(path, 101, 'vera', 'accept:vera',
                                vera_offer['agreement']['agreement_id'], now + 13)
        assert not changed['ok'] and changed['error'] == 'pact changed'
        assert (await _row(path,
            "SELECT pact FROM npc_empire_relations WHERE leader_id='vera' AND telegram_id=101"))[0] == 'truce'
        passed.append('pact-invalidation')

        # 11. Comeback/player/family scopes isolate identical request keys.
        await _war(path, 101, 'alisa'); await _war(path, 202, 'alisa')
        pair_a = await _offer(path, 101, 'alisa', 'same-key', now + 14)
        pair_b = await _offer(path, 202, 'alisa', 'same-key', now + 14)
        await _war(path, 101, 'sofia')
        family_b = await _offer(path, 101, 'sofia', 'same-key', now + 14)
        assert all(result['ok'] and not result['duplicate']
                   for result in (pair_a, pair_b, family_b))
        async with aiosqlite.connect(path) as db:
            await db.execute("UPDATE npc_empires SET comebacks=comebacks+1 "
                             "WHERE leader_id='alisa'"); await db.commit()
        stale = await _accept(path, 101, 'alisa', 'old-generation',
                              pair_a['agreement']['agreement_id'], now + 15)
        assert not stale['ok'] and stale['error'] == 'stale agreement'
        passed.append('generation-pair-isolation')

        # 12. Reload/UI/API source contract keeps server authority and no leaks.
        public = await ne.state_for(path, 101, now=now + 16)
        sofia = next(empire for empire in public['empires'] if empire['leader_id'] == 'sofia')
        assert sofia['player_tribute']['state'] == 'offered'
        world = open('world.html', encoding='utf-8').read()
        bot = open('mafiozi_bot.py', encoding='utf-8').read()
        preview = open('_preview_ws_server.py', encoding='utf-8').read()
        assert all(token in world for token in (
            'dataset.neTributeState', 'data-ne-tribute-action', 'ДАНЬ',
            'tribute-accept:${agreementId}', 'void loadNpcEmpireState(false)'))
        assert "{'tribute_offer','tribute_accept'}" in bot
        assert 'preview_empire_tribute_agreements' in preview
        assert all(secret not in str(sofia['player_tribute'])
                   for secret in ('treasury', 'reserve', 'chance', 'roll',
                                  'next_attack_at', 'multiplier'))
        passed.append('reload-api-ui-allowlist')

        assert len(passed) == 12, passed
        print('bounded tribute: 12/12 focused gates OK — ' + ', '.join(passed))
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
