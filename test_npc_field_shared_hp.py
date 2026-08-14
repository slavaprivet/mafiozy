"""One physical field boss has one canonical HP pool for every participant."""

import asyncio
import os
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


NOW = 2_002_000_000


async def _field(path: str, encounter_id: str):
    async with aiosqlite.connect(path) as db:
        db.row_factory = aiosqlite.Row
        return await (await db.execute(
            "SELECT * FROM npc_empire_field_encounters WHERE encounter_id=?",
            (encounter_id,))).fetchone()


async def run() -> None:
    handle, path = tempfile.mkstemp(prefix='npc_shared_field_', suffix='.db')
    os.close(handle)
    try:
        await _base_db(path)
        # Idempotent legacy migration groups independent field rows under one
        # generation and preserves the lowest already-observed HP.
        async with aiosqlite.connect(path) as db:
            for token, uid, hp, started in (
                    ('legacy-a', 601, 240, NOW - 20),
                    ('legacy-b', 602, 175, NOW - 10)):
                await db.execute(
                    "INSERT INTO npc_empire_assaults"
                    "(token,telegram_id,leader_id,guard_hp_json,boss_hp,boss_max_hp,"
                    "status,started_at,expires_at,encounter_kind,anchor_r,anchor_c,"
                    "anchor_id,anchor_at) VALUES(?,?,?,'[]',?,300,'active',?,?,"
                    "'field',10,20,'legacy-anchor',?)",
                    (token, uid, 'alisa', hp, started, NOW + 100, started))
            await db.commit()
        await ne.ensure_schema(path)
        await ne.ensure_schema(path)
        async with aiosqlite.connect(path) as db:
            migrated = await (await db.execute(
                "SELECT encounter_id,boss_hp,boss_max_hp FROM "
                "npc_empire_field_encounters WHERE leader_id='alisa' "
                "AND status='active'")).fetchall()
            attached = await (await db.execute(
                "SELECT DISTINCT field_encounter_id,boss_hp FROM npc_empire_assaults "
                "WHERE token IN ('legacy-a','legacy-b')")).fetchall()
        assert len(migrated) == 1 and migrated[0][1:] == (175, 300)
        assert attached == [(migrated[0][0], 175)]

        state = await ne.state_for(path, 701, NOW)
        empire = next(item for item in state['empires'] if item['leader_id'] == 'vera')
        activity = empire['activity']
        r = float(activity.get('target_r', empire['hq_r']))
        c = float(activity.get('target_c', empire['hq_c']))

        first, second = await asyncio.gather(
            ne.prepare_field_encounter(path, 701, 'vera', r, c, NOW + 1,
                                       server_activity=activity),
            ne.prepare_field_encounter(path, 702, 'vera', r, c, NOW + 1,
                                       server_activity=activity),
        )
        assert first['ok'] and second['ok']
        assert first['token'] != second['token']
        assert first['encounter_id'] == second['encounter_id']
        assert first['boss'] == second['boss'] and first['shared'] and second['shared']
        encounter_id = first['encounter_id']
        start_hp = first['boss']['hp']

        hit_a, hit_b = await asyncio.gather(
            ne.assault_field_hit_authorized(
                path, 701, first['token'], 1, 'pistol', 30, NOW + 2.00),
            ne.assault_field_hit_authorized(
                path, 702, second['token'], 1, 'pistol', 25, NOW + 2.00),
        )
        assert hit_a['ok'] and hit_b['ok']
        canonical = await _field(path, encounter_id)
        assert int(canonical['boss_hp']) == start_hp - 55
        async with aiosqlite.connect(path) as db:
            mirrors = [int(row[0]) for row in await (await db.execute(
                "SELECT boss_hp FROM npc_empire_assaults WHERE field_encounter_id=?",
                (encounter_id,))).fetchall()]
        assert mirrors == [start_hp - 55, start_hp - 55]

        mid = await ne.prepare_field_encounter(
            path, 703, 'vera', r, c, NOW + 3, server_activity=activity)
        assert mid['ok'] and mid['encounter_id'] == encounter_id
        assert mid['boss']['hp'] == start_hp - 55

        # Separate participant tokens avoid per-token rate limits while the
        # canonical BEGIN IMMEDIATE transition remains exactly-once at zero.
        participants = [first, second, mid]
        sequences = [2, 2, 1]
        hit_at = NOW + 4.0
        while int((await _field(path, encounter_id))['boss_hp']) > 105:
            replies = await asyncio.gather(*(
                ne.assault_field_hit_authorized(
                    path, uid, item['token'], sequences[index], 'pistol', 35,
                    hit_at + index * .001)
                for index, (uid, item) in enumerate(zip((701, 702, 703), participants))
            ))
            assert all(reply['ok'] for reply in replies)
            sequences = [value + 1 for value in sequences]
            hit_at += .12
        lethal = await asyncio.gather(*(
            ne.assault_field_hit_authorized(
                path, uid, item['token'], sequences[index], 'pistol', 35,
                hit_at + index * .001)
            for index, (uid, item) in enumerate(zip((701, 702, 703), participants))
        ))
        assert sum(bool(reply.get('proof_ready')) for reply in lethal) >= 1
        defeated = await _field(path, encounter_id)
        assert int(defeated['boss_hp']) == 0
        assert defeated['status'] == 'defeated'
        assert int(defeated['defeated_at']) > 0
        assert int(defeated['defeated_by']) in {701, 702, 703}

        newcomer = await ne.prepare_field_encounter(
            path, 704, 'vera', r, c, int(defeated['defeated_at']) + 1,
            server_activity=activity)
        assert not newcomer['ok'] and newcomer['error'] == 'boss defeated'
        reconnect = await ne.prepare_field_encounter(
            path, 701, 'vera', r, c, int(defeated['defeated_at']) + 1,
            server_activity=activity)
        assert reconnect['ok'] and reconnect['duplicate'] and reconnect['proof_ready']

        # Stable state polling exposes shared HP but never mutates encounters.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET last_tick=?,next_action_at=?",
                (int(defeated['defeated_at']) + 1,
                 int(defeated['defeated_at']) + ne.TICK_SECONDS))
            await db.execute(
                "UPDATE npc_empire_diplomacy SET last_event_at=?",
                (int(defeated['defeated_at']) + 1,))
            await db.executescript("""
                CREATE TABLE field_write_audit(op TEXT NOT NULL);
                CREATE TRIGGER field_audit_update AFTER UPDATE ON npc_empire_field_encounters
                  BEGIN INSERT INTO field_write_audit VALUES('update'); END;
                CREATE TRIGGER field_audit_insert AFTER INSERT ON npc_empire_field_encounters
                  BEGIN INSERT INTO field_write_audit VALUES('insert'); END;
                CREATE TRIGGER field_audit_delete AFTER DELETE ON npc_empire_field_encounters
                  BEGIN INSERT INTO field_write_audit VALUES('delete'); END;
            """)
            await db.commit()
        snapshots = await asyncio.gather(*(
            ne.state_for(path, 800 + index, int(defeated['defeated_at']) + 1)
            for index in range(50)
        ))
        assert all(next(item for item in snap['empires']
                        if item['leader_id'] == 'vera')['field_encounter']['hp'] == 0
                   for snap in snapshots)
        async with aiosqlite.connect(path) as db:
            assert int((await (await db.execute(
                "SELECT COUNT(*) FROM field_write_audit")).fetchone())[0]) == 0

        hospitalized = await ne.hospitalize_boss_from_proof(
            path, 702, second['token'], 'hospital', int(defeated['defeated_at']) + 2)
        assert hospitalized['ok'] and not hospitalized['duplicate']
        async with aiosqlite.connect(path) as db:
            rows = await (await db.execute(
                "SELECT status,resolution,hospital_until FROM npc_empire_assaults "
                "WHERE field_encounter_id=? ORDER BY telegram_id", (encounter_id,))).fetchall()
        assert len(rows) == 3 and all(row[0] == 'resolved' and int(row[2]) > 0 for row in rows)
        assert sum(row[1] == 'hospitalized' for row in rows) == 1
        replay_other = await ne.hospitalize_boss_from_proof(
            path, 701, first['token'], 'hospital_east', int(defeated['defeated_at']) + 3)
        assert replay_other['ok'] and replay_other['duplicate']
        assert replay_other['hospital_until'] == hospitalized['hospital_until']
        print('npc shared field HP: participants, concurrency, defeat, hospital and read-only state OK')
    finally:
        if os.path.exists(path):
            try:
                os.unlink(path)
            except PermissionError:
                pass


if __name__ == '__main__':
    asyncio.run(run())
