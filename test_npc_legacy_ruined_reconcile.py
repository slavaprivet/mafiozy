import asyncio
import json
import os
import sqlite3
import tempfile

import aiosqlite

import npc_empire as ne


async def scalar(path, query, params=()):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(query, params)).fetchone()
        return row[0] if row else None


async def seed_unavailable(path, leader_id, telegram_id, status, suffix):
    async with aiosqlite.connect(path) as db:
        await db.execute(
            "UPDATE npc_empires SET status=?,treasury=900,members=9,strength=190,"
            "comeback_at=0 WHERE leader_id=?", (status, leader_id)
        )
        await db.execute(
            "INSERT OR REPLACE INTO npc_empire_holdings"
            "(kind,holding_id,leader_id,income,defense,acquired_at) "
            "VALUES('building',?,?,20,20,1)", (f'legacy-{suffix}', leader_id)
        )
        await db.execute(
            "INSERT INTO npc_empire_assaults"
            "(token,telegram_id,leader_id,guard_hp_json,boss_hp,boss_max_hp,status,"
            "started_at,expires_at,encounter_kind) VALUES(?,?,?,?,100,100,'active',1,"
            "9999999999,'hq')",
            (f'hq-{suffix}', telegram_id, leader_id, json.dumps([100])),
        )
        await db.execute(
            "INSERT INTO npc_empire_player_wars(leader_id,telegram_id,next_attack_at) "
            "VALUES(?,?,9999999999)", (leader_id, telegram_id)
        )
        await db.execute(
            "INSERT INTO npc_empire_guard_assignments"
            "(owner_kind,owner_id,holding_ref,assigned,living,updated_at) "
            "VALUES('npc',?,'hq:legacy',2,2,1)", (leader_id,)
        )
        await db.execute(
            "INSERT INTO npc_empire_interior_raids"
            "(token,telegram_id,leader_id,apt_key,target_ref,target_kind,holding_id,"
            "force,attacker_cost,tier,quality,hp,accuracy,weapon_budget,started_at,"
            "hold_seconds,expires_at) VALUES(?,?,?,'apt','business:test','business',"
            "'test',2,10,1,1,100,.5,10,1,10,9999999999)",
            (f'raid-{suffix}', telegram_id, leader_id),
        )
        await db.execute(
            "INSERT OR REPLACE INTO npc_empire_relations"
            "(leader_id,telegram_id,score,pact,last_action_at) "
            "VALUES(?,?,90,'war',1)", (leader_id, telegram_id)
        )
        await db.execute(
            "INSERT OR REPLACE INTO npc_empire_relation_actions"
            "(leader_id,telegram_id,action_kind,last_action_at) "
            "VALUES(?,?,'threaten',1)", (leader_id, telegram_id)
        )
        await db.commit()


async def run():
    fd, path = tempfile.mkstemp(suffix='.db')
    os.close(fd)
    try:
        await ne.ensure_schema(path)
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "CREATE TABLE business_property_owners("
                "biz_id TEXT PRIMARY KEY,owner_uid INTEGER NOT NULL)"
            )
            await db.execute(
                "INSERT INTO business_property_owners VALUES('niko-biz',?)",
                (ne.npc_owner_uid('niko'),),
            )
            await db.execute(
                "INSERT INTO business_property_owners VALUES('player-biz',101)"
            )
            await db.execute(
                "INSERT INTO npc_empire_field_encounters"
                "(encounter_id,leader_id,boss_hp,boss_max_hp,status,started_at,expires_at) "
                "VALUES('field-proof','niko',0,100,'defeated',1,9999999999)"
            )
            await db.execute(
                "INSERT INTO npc_empire_assaults"
                "(token,telegram_id,leader_id,guard_hp_json,boss_hp,boss_max_hp,status,"
                "started_at,expires_at,encounter_kind,field_encounter_id) "
                "VALUES('field-token',303,'niko','[]',0,100,'active',1,9999999999,"
                "'field','field-proof')"
            )
            await db.commit()
        await seed_unavailable(path, 'niko', 101, 'defeated', 'defeated')
        await seed_unavailable(path, 'sofia', 202, 'ruined', 'partial')

        await ne.ensure_schema(path)

        assert await scalar(path,
            "SELECT status||':'||treasury||':'||members||':'||strength||':'||"
            "COALESCE(hq_key,'') FROM npc_empires WHERE leader_id='niko'") == \
            'ruined:0:0:0:'
        assert int(await scalar(path,
            "SELECT comeback_at FROM npc_empires WHERE leader_id='niko'")) > 0
        for leader_id in ('niko', 'sofia'):
            assert await scalar(path,
                "SELECT COUNT(*) FROM npc_empire_holdings WHERE leader_id=?",
                (leader_id,)) == 0
            assert await scalar(path,
                "SELECT COUNT(*) FROM npc_empire_player_wars WHERE leader_id=?",
                (leader_id,)) == 0
            assert await scalar(path,
                "SELECT COUNT(*) FROM npc_empire_guard_assignments "
                "WHERE owner_kind='npc' AND owner_id=?", (leader_id,)) == 0
        assert await scalar(path,
            "SELECT status||':'||resolution FROM npc_empire_assaults "
            "WHERE token='hq-defeated'") == 'resolved:leader_ruined'
        assert await scalar(path,
            "SELECT status||':'||resolution FROM npc_empire_assaults "
            "WHERE token='hq-partial'") == 'resolved:leader_ruined'
        assert await scalar(path,
            "SELECT status||':'||resolution FROM npc_empire_interior_raids "
            "WHERE token='raid-defeated'") == 'resolved:owner_ruined'
        assert await scalar(path,
            "SELECT status FROM npc_empire_assaults WHERE token='field-token'") == 'active'
        assert await scalar(path,
            "SELECT status FROM npc_empire_field_encounters "
            "WHERE encounter_id='field-proof'") == 'defeated'
        assert await scalar(path,
            "SELECT COUNT(*) FROM business_property_owners WHERE biz_id='niko-biz'") == 0
        assert await scalar(path,
            "SELECT owner_uid FROM business_property_owners WHERE biz_id='player-biz'") == 101
        assert await scalar(path,
            "SELECT score||':'||pact FROM npc_empire_relations "
            "WHERE leader_id='niko' AND telegram_id=101") == '0:none'
        assert await scalar(path,
            "SELECT COUNT(*) FROM npc_empire_relation_actions WHERE leader_id='niko'") == 0
        assert await ne.assault_hit(
            path, 101, 'hq-defeated', 'boss', 0, 50, now=20.0
        ) == {'ok': True, 'duplicate': True, 'terminal': True,
              'resolution': 'leader_ruined'}
        assert await ne.resolve_assault(
            path, 202, 'hq-partial', 'annex', now=20
        ) == {'ok': True, 'duplicate': True, 'terminal': True,
              'resolution': 'leader_ruined'}

        snapshot = (
            await scalar(path, "SELECT COUNT(*) FROM npc_empire_assaults"),
            await scalar(path, "SELECT COUNT(*) FROM npc_empire_player_wars"),
            await scalar(path, "SELECT COUNT(*) FROM npc_empire_holdings"),
        )
        await ne.ensure_schema(path)
        assert snapshot == (
            await scalar(path, "SELECT COUNT(*) FROM npc_empire_assaults"),
            await scalar(path, "SELECT COUNT(*) FROM npc_empire_player_wars"),
            await scalar(path, "SELECT COUNT(*) FROM npc_empire_holdings"),
        )
    finally:
        os.unlink(path)

    fd, rollback_path = tempfile.mkstemp(suffix='.db')
    os.close(fd)
    try:
        await ne.ensure_schema(rollback_path)
        await seed_unavailable(rollback_path, 'niko', 101, 'defeated', 'rollback')
        async with aiosqlite.connect(rollback_path) as db:
            await db.execute("""
                CREATE TRIGGER reject_legacy_terminal
                BEFORE UPDATE OF status ON npc_empire_assaults
                WHEN OLD.token='hq-rollback' AND NEW.status='resolved'
                BEGIN SELECT RAISE(ABORT, 'forced legacy rollback'); END
            """)
            await db.commit()
        try:
            await ne.ensure_schema(rollback_path)
            raise AssertionError('forced legacy rollback did not abort')
        except sqlite3.IntegrityError as error:
            assert 'forced legacy rollback' in str(error)
        assert await scalar(rollback_path,
            "SELECT status FROM npc_empires WHERE leader_id='niko'") == 'defeated'
        assert await scalar(rollback_path,
            "SELECT status FROM npc_empire_assaults WHERE token='hq-rollback'") == 'active'
        assert await scalar(rollback_path,
            "SELECT COUNT(*) FROM npc_empire_player_wars WHERE leader_id='niko'") == 1
        assert await scalar(rollback_path,
            "SELECT COUNT(*) FROM npc_empire_holdings WHERE leader_id='niko'") > 0
    finally:
        os.unlink(rollback_path)

    print('legacy ruined reconciliation: atomic authority cleanup and isolation OK')


if __name__ == '__main__':
    asyncio.run(run())
