"""A field defeat token, not a client leader_id, authorizes hospitalization."""

import asyncio
import os
import sqlite3
import tempfile
from pathlib import Path

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


NOW = 2_001_000_000


async def _scalar(path: str, sql: str, args=()):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql, args)).fetchone()
        return row[0] if row else None


async def _insert_defeated(path: str, token: str, leader_id: str,
                           uid: int, defeated_at: int) -> None:
    async with aiosqlite.connect(path) as db:
        await db.execute(
            "INSERT INTO npc_empire_assaults"
            "(token,telegram_id,leader_id,guard_hp_json,boss_hp,boss_max_hp,"
            "status,started_at,expires_at,encounter_kind,defeated_at) "
            "VALUES(?,?,?,'[]',0,300,'active',?,?,'field',?)",
            (token, uid, leader_id, defeated_at - 10,
             defeated_at + ne.FIELD_ENCOUNTER_SECONDS, defeated_at),
        )
        await db.commit()


async def run() -> None:
    handle, path = tempfile.mkstemp(prefix='npc_field_proof_', suffix='.db')
    os.close(handle)
    try:
        await _base_db(path)
        await ne.ensure_schema(path)

        # A legacy insert omitting all new columns remains an HQ assault and
        # can never become a hospital proof.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "INSERT INTO npc_empire_assaults"
                "(token,telegram_id,leader_id,guard_hp_json,boss_hp,boss_max_hp,"
                "status,started_at,expires_at) "
                "VALUES('legacy-hq',101,'marco','[0]',0,300,'active',?,?)",
                (NOW - 5, NOW + 500),
            )
            await db.commit()
        assert await _scalar(
            path, "SELECT encounter_kind FROM npc_empire_assaults "
                  "WHERE token='legacy-hq'") == 'hq'
        rejected_hq = await ne.hospitalize_boss_from_proof(
            path, 101, 'legacy-hq', now=NOW)
        assert not rejected_hq['ok'] and rejected_hq['error'] == 'invalid_proof'

        # Field prepare binds the selected boss to a server-derived activity
        # anchor and reuses the current assault HP machine.
        state = await ne.state_for(path, 101, NOW)
        marco_state = next(item for item in state['empires']
                           if item['leader_id'] == 'marco')
        marco_activity = marco_state['activity']
        hq_blocks_field = await ne.prepare_field_encounter(
            path, 101, 'marco',
            float(marco_activity.get('target_r', marco_state['hq_r'])),
            float(marco_activity.get('target_c', marco_state['hq_c'])),
            NOW + 1, server_activity=marco_activity)
        assert (not hq_blocks_field['ok']
                and hq_blocks_field['error'] == 'headquarters assault active')
        assert await _scalar(
            path, "SELECT status FROM npc_empire_assaults "
                  "WHERE token='legacy-hq'") == 'active'
        leila = next(item for item in state['empires']
                     if item['leader_id'] == 'leila')
        activity = leila['activity']
        prepared = await ne.prepare_field_encounter(
            path, 101, 'leila', float(activity.get('target_r', leila['hq_r'])),
            float(activity.get('target_c', leila['hq_c'])), NOW + 1)
        assert prepared['ok'] and prepared['encounter_kind'] == 'field'
        token = prepared['token']
        alive = await ne.hospitalize_boss_from_proof(
            path, 101, token, now=NOW + 2)
        assert not alive['ok'] and alive['error'] == 'invalid_proof'
        wrong_uid = await ne.hospitalize_boss_from_proof(
            path, 999, token, now=NOW + 2)
        assert not wrong_uid['ok'] and wrong_uid['error'] == 'invalid_proof'

        hit_at = NOW + 2.0
        boss_hp = prepared['boss']['hp']
        while boss_hp > 0:
            hit = await ne.assault_hit(
                path, 101, token, 'boss', None, 35, now=hit_at)
            assert hit['ok']
            boss_hp = hit['boss_hp']
            hit_at += .12
        assert hit['proof_ready'] and hit['encounter_kind'] == 'field'
        field_blocks_hq = await ne.prepare_assault(
            path, 101, 'leila', leila['hq_r'], leila['hq_c'], now=NOW + 9)
        assert (not field_blocks_hq['ok']
                and field_blocks_hq['error'] == 'field encounter active')
        assert await _scalar(
            path, "SELECT status FROM npc_empire_assaults WHERE token=?",
            (token,)) == 'active'
        cannot_annex = await ne.resolve_assault(
            path, 101, token, 'annex', now=NOW + 10)
        assert not cannot_annex['ok'] and cannot_annex['error'] == 'not won'

        before_version = int(await _scalar(
            path, "SELECT version FROM npc_empires WHERE leader_id='leila'"))
        result = await ne.hospitalize_boss_from_proof(
            path, 101, token, 'hospital_east', now=NOW + 10)
        assert result['ok'] and not result['duplicate']
        assert result['leader_id'] == 'leila'
        assert result['hospital_id'] == 'hospital_east'
        assert result['hospital_until'] == NOW + 70
        assert int(await _scalar(
            path, "SELECT version FROM npc_empires WHERE leader_id='leila'")) == before_version + 1
        assert int(await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events "
                  "WHERE leader_id='leila' AND kind='hospitalized'")) == 1

        replay = await ne.hospitalize_boss_from_proof(
            path, 101, token, 'hospital', now=NOW + 11)
        assert replay['ok'] and replay['duplicate']
        assert replay['hospital_id'] == result['hospital_id']
        assert replay['hospital_until'] == result['hospital_until']
        assert int(await _scalar(
            path, "SELECT version FROM npc_empires WHERE leader_id='leila'")) == before_version + 1
        assert int(await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events "
                  "WHERE leader_id='leila' AND kind='hospitalized'")) == 1

        # Twenty simultaneous deliveries consume one proof exactly once.
        await _insert_defeated(path, 'rustam-field', 'rustam', 202, NOW + 20)
        rustam_version = int(await _scalar(
            path, "SELECT version FROM npc_empires WHERE leader_id='rustam'"))
        replies = await asyncio.gather(*(
            ne.hospitalize_boss_from_proof(
                path, 202, 'rustam-field', 'hospital', NOW + 21)
            for _ in range(20)
        ))
        assert all(item['ok'] and item['leader_id'] == 'rustam' for item in replies)
        assert sum(not item['duplicate'] for item in replies) == 1
        assert len({item['hospital_until'] for item in replies}) == 1
        assert int(await _scalar(
            path, "SELECT version FROM npc_empires WHERE leader_id='rustam'")) == rustam_version + 1
        assert int(await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events "
                  "WHERE leader_id='rustam' AND kind='hospitalized'")) == 1

        # Hospitalizing one globally rendered boss closes other players' field
        # copies so their independent HP sessions cannot remain actionable.
        await _insert_defeated(path, 'marco-a', 'marco', 501, NOW + 24)
        await _insert_defeated(path, 'marco-b', 'marco', 502, NOW + 24)
        marco = await ne.hospitalize_boss_from_proof(
            path, 501, 'marco-a', 'hospital', NOW + 25)
        assert marco['ok']
        assert await _scalar(
            path, "SELECT resolution FROM npc_empire_assaults "
                  "WHERE token='marco-b'") == 'boss_hospitalized_elsewhere'

        # A second valid proof is consumed without extending active treatment.
        until = replies[0]['hospital_until']
        await _insert_defeated(path, 'rustam-second', 'rustam', 202, NOW + 22)
        second = await ne.hospitalize_boss_from_proof(
            path, 202, 'rustam-second', 'hospital_east', NOW + 23)
        assert not second['ok'] and second['error'] == 'invalid_proof'
        assert int(await _scalar(
            path, "SELECT hospital_until FROM npc_empires "
                  "WHERE leader_id='rustam'")) == until
        assert int(await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events "
                  "WHERE leader_id='rustam' AND kind='hospitalized'")) == 1
        assert await _scalar(
            path, "SELECT resolution FROM npc_empire_assaults "
                  "WHERE token='rustam-second'") == 'legacy_owner_unavailable'

        await _insert_defeated(path, 'late-field', 'giulia', 303, NOW)
        late = await ne.hospitalize_boss_from_proof(
            path, 303, 'late-field', now=NOW + ne.FIELD_HOSPITAL_CLAIM_SECONDS + 1)
        assert not late['ok'] and late['error'] == 'invalid_proof'

        await _insert_defeated(path, 'ruined-field', 'musa', 404, NOW + 30)
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET status='ruined' WHERE leader_id='musa'")
            await db.commit()
        ruined = await ne.hospitalize_boss_from_proof(
            path, 404, 'ruined-field', now=NOW + 31)
        assert not ruined['ok'] and ruined['error'] == 'invalid_proof'
        assert await _scalar(
            path, "SELECT resolution FROM npc_empire_assaults "
                  "WHERE token='ruined-field'") == 'legacy_owner_unavailable'

        bot_source = Path('mafiozi_bot.py').read_text(encoding='utf-8')
        handler = bot_source.split(
            'async def h_npc_empire_hospitalize(req):', 1)[1].split(
                'async def h_npc_empire_street_recruit(req):', 1)[0]
        assert 'hospitalize_boss_from_proof' in handler
        assert "body.get('token')" in handler
        assert "body.get('leader_id')" not in handler
        prepare_handler = bot_source.split(
            'async def h_npc_empire_assault_prepare(req):', 1)[1].split(
                'async def h_npc_empire_assault_hit(req):', 1)[0]
        assert '_npc_empire_live_field_position(_WORLD,uid)' in prepare_handler
        assert "{'ok':False,'error':'player not in world'}" in prepare_handler
        assert 'server_activity=(empire or {}).get(\'activity\')' in prepare_handler

        print('npc field hospital proof: binding, migration, replay and concurrency OK')
    finally:
        if os.path.exists(path):
            try:
                os.unlink(path)
            except PermissionError:
                pass


if __name__ == '__main__':
    asyncio.run(run())
