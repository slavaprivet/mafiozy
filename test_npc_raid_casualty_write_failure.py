"""A failed defender-death write rolls back the complete raid resolution."""

import asyncio
import os
import tempfile
from pathlib import Path

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


ROOT = Path(__file__).resolve().parent


async def scalar(path: str, sql: str, args=()):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql, args)).fetchone()
        return row[0]


async def run() -> None:
    world = (ROOT / 'world.html').read_text(encoding='utf-8')
    assert 'при ошибке сервер не засчитывает результат' in world

    fd, path = tempfile.mkstemp(prefix='raid_casualty_write_failure_', suffix='.db')
    os.close(fd)
    try:
        await _base_db(path)
        now = 2_800_000_000
        async with aiosqlite.connect(path) as db:
            await db.executescript("""
                CREATE TABLE gang_members(
                    id INTEGER PRIMARY KEY,telegram_id INTEGER,current_hp INTEGER);
                CREATE TABLE district_control(
                    telegram_id INTEGER,loc_id TEXT,guard_json TEXT);
                INSERT INTO gang_members VALUES(1,101,100);
                INSERT INTO district_control VALUES(101,'northside','[]');
                INSERT INTO player_businesses
                    VALUES(101,'coffee',0,0,'ok',0,0,1,0,NULL);
                INSERT INTO business_property_owners
                    VALUES('coffee',101,'Test',2800000000,0);
                INSERT OR REPLACE INTO npc_empire_relations
                    (leader_id,telegram_id,score,pact,last_action_at)
                    VALUES('leila',101,-100,'war',2800000000);
                INSERT OR REPLACE INTO npc_empire_player_wars
                    (leader_id,telegram_id,next_attack_at,attacks,last_business_id,last_attack_at)
                    VALUES('leila',101,2800000000,0,'',0);
            """)
            await db.execute(
                "UPDATE npc_empires SET status=CASE WHEN leader_id='leila' THEN 'active' ELSE 'ruined' END,"
                "members=12,strength=360,treasury=50000,next_action_at=?", (now + 10_000,))
            await db.commit()

        assigned = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101',
            holding_ref='business:coffee', requested=1, now=now)
        assert assigned['holding_guards'] == 1
        state = await ne.state_for(path, 101, now=now)
        raid = state['interior_raids'][0]
        assert [row['member_id'] for row in raid['defender_roster']] == [1]

        # A failure at the final business event must also roll back every
        # casualty and the close/capture phase from the same transaction.
        phase_members_before = await scalar(
            path, "SELECT members FROM npc_empires WHERE leader_id='leila'")
        async with aiosqlite.connect(path) as db:
            await db.execute("""
                CREATE TRIGGER reject_atomic_raid_phase
                BEFORE INSERT ON npc_empire_events
                WHEN NEW.kind='player_business_bombed'
                BEGIN SELECT RAISE(ABORT, 'forced raid phase rollback'); END
            """)
            await db.commit()
        try:
            await ne.resolve_interior_raid(
                path, 101, raid['token'], raid['apt_key'], 'captured',
                attacker_casualties=[], defender_casualties=[1],
                guard_casualties=[], now=now + raid['hold_seconds'])
            raise AssertionError('failed business phase must abort resolution')
        except aiosqlite.Error as error:
            assert 'forced raid phase rollback' in str(error)
        finally:
            async with aiosqlite.connect(path) as db:
                await db.execute("DROP TRIGGER reject_atomic_raid_phase")
                await db.commit()
        assert await scalar(path,
            "SELECT status FROM npc_empire_interior_raids WHERE token=?",
            (raid['token'],)) == 'pending'
        assert await scalar(path,
            "SELECT current_hp FROM gang_members WHERE id=1") == 100
        assert await scalar(path,
            "SELECT COUNT(*) FROM npc_empire_player_guard_members WHERE member_id=1") == 1
        assert await scalar(path,
            "SELECT living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='player' AND owner_id='101' AND holding_ref='business:coffee'") == 1
        assert await scalar(path,
            "SELECT members FROM npc_empires WHERE leader_id='leila'") == phase_members_before
        assert await scalar(path,
            "SELECT attacks FROM npc_empire_player_wars "
            "WHERE leader_id='leila' AND telegram_id=101") == 0
        assert await scalar(path,
            "SELECT blocked_until FROM player_businesses WHERE biz_id='coffee'") == 0

        members_before = await scalar(
            path, "SELECT members FROM npc_empires WHERE leader_id='leila'")
        war_before = await scalar(
            path, "SELECT next_attack_at FROM npc_empire_player_wars "
                  "WHERE leader_id='leila' AND telegram_id=101")
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "ALTER TABLE gang_members RENAME COLUMN current_hp TO broken_hp")
            await db.commit()

        try:
            await ne.resolve_interior_raid(
                path, 101, raid['token'], raid['apt_key'], 'captured',
                attacker_casualties=[], defender_casualties=[1],
                guard_casualties=[], now=now + raid['hold_seconds'])
            raise AssertionError('failed casualty write must abort resolution')
        except aiosqlite.Error:
            pass

        assert await scalar(path,
            "SELECT status FROM npc_empire_interior_raids WHERE token=?",
            (raid['token'],)) == 'pending'
        assert await scalar(path,
            "SELECT COUNT(*) FROM npc_empire_player_guard_members WHERE member_id=1") == 1
        assert await scalar(path,
            "SELECT living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='player' AND owner_id='101' AND holding_ref='business:coffee'") == 1
        assert await scalar(path,
            "SELECT members FROM npc_empires WHERE leader_id='leila'") == members_before
        assert await scalar(path,
            "SELECT next_attack_at FROM npc_empire_player_wars "
            "WHERE leader_id='leila' AND telegram_id=101") == war_before
        assert await scalar(path,
            "SELECT COUNT(*) FROM player_businesses WHERE telegram_id=101 AND biz_id='coffee'") == 1
        print('raid atomic failure: casualty and business phase rollback OK')
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
