"""Pending interior raids cannot outlive war or property ownership authority."""

import asyncio
import os
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


async def scalar(path, sql, args=()):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql, args)).fetchone()
        return row[0] if row else None


async def prepare_pending_raid(path: str, now: int) -> dict:
    await _base_db(path)
    async with aiosqlite.connect(path) as db:
        await db.executescript("""
            CREATE TABLE gang_members(
                id INTEGER PRIMARY KEY,telegram_id INTEGER,current_hp INTEGER);
            CREATE TABLE district_control(
                telegram_id INTEGER,loc_id TEXT,guard_json TEXT);
            INSERT INTO gang_members VALUES(1,101,100);
            INSERT INTO district_control VALUES(101,'north','[]');
            INSERT INTO player_businesses
                VALUES(101,'coffee',0,0,'ok',0,0,1,0,NULL);
        """)
        await db.execute(
            "INSERT INTO business_property_owners VALUES('coffee',101,'One',?,0)",
            (now - 100,))
        await db.execute(
            "INSERT OR REPLACE INTO npc_empire_relations "
            "VALUES('leila',101,-100,'war',?)", (now,))
        await db.execute(
            "INSERT OR REPLACE INTO npc_empire_player_wars "
            "VALUES('leila',101,?,0,'',0)", (now,))
        await db.execute(
            "UPDATE npc_empires SET status=CASE WHEN leader_id='leila' "
            "THEN 'active' ELSE 'ruined' END,members=12,strength=360,"
            "treasury=50000,next_action_at=?", (now + 10_000,))
        await db.commit()
    assigned = await ne.assign_holding_guards(
        path, owner_kind='player', owner_id='101',
        holding_ref='business:coffee', requested=1, now=now - 1)
    assert assigned['ok'] and assigned['holding_guards'] == 1
    state = await ne.state_for(path, 101, now=now)
    assert len(state['interior_raids']) == 1
    raid = state['interior_raids'][0]
    assert await scalar(
        path, "SELECT target_ref FROM npc_empire_interior_raids WHERE token=?",
        (raid['token'],)) == 'business:coffee'
    return raid


async def vassalization_terminalizes_pending() -> None:
    fd, path = tempfile.mkstemp(prefix='raid_vassal_generation_', suffix='.db')
    os.close(fd); now = 3_200_000_000
    try:
        raid = await prepare_pending_raid(path, now)
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "INSERT INTO npc_empire_assaults"
                "(token,telegram_id,leader_id,guard_hp_json,boss_hp,boss_max_hp,"
                "status,started_at,expires_at,last_hit_at) "
                "VALUES('won-vassal',101,'leila','[]',0,300,'active',?,?,?)",
                (now, now + 10_000, float(now)))
            await db.commit()
        result = await ne.resolve_assault(
            path, 101, 'won-vassal', 'vassalize', now=now + 1)
        assert result['ok'] and result['choice'] == 'vassalize'
        assert await scalar(
            path, "SELECT status||':'||resolution FROM npc_empire_interior_raids "
                  "WHERE token=?", (raid['token'],)) == 'resolved:diplomacy_changed'
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE telegram_id=101 AND leader_id='leila'") == 0
        retry = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'captured',
            attacker_casualties=[], defender_casualties=[1], guard_casualties=[],
            now=now + raid['hold_seconds'])
        assert retry == {'ok': True, 'duplicate': True,
                         'resolution': 'diplomacy_changed'}
        assert await scalar(path, "SELECT current_hp FROM gang_members WHERE id=1") == 100
        assert await scalar(
            path, "SELECT blocked_until FROM player_businesses "
                  "WHERE telegram_id=101 AND biz_id='coffee'") == 0
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events "
                  "WHERE kind IN ('player_business_bombed','player_business_captured')") == 0
    finally:
        os.unlink(path)


async def ownership_generation_terminalizes_pending() -> None:
    fd, path = tempfile.mkstemp(prefix='raid_owner_generation_', suffix='.db')
    os.close(fd); now = 3_300_000_000
    try:
        raid = await prepare_pending_raid(path, now)
        members_before = await scalar(
            path, "SELECT members FROM npc_empires WHERE leader_id='leila'")
        async with aiosqlite.connect(path) as db:
            await db.execute("DELETE FROM player_businesses WHERE biz_id='coffee'")
            await db.execute(
                "INSERT INTO player_businesses "
                "VALUES(202,'coffee',?,?,'ok',0,0,1,0,NULL)", (now + 1, now + 1))
            await db.execute(
                "UPDATE business_property_owners SET owner_uid=202,owner_name='Two',"
                "acquired_at=? WHERE biz_id='coffee'", (now + 1,))
            await db.commit()
        stale = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'captured',
            attacker_casualties=[], defender_casualties=[1], guard_casualties=[],
            now=now + raid['hold_seconds'])
        assert stale == {'ok': False, 'error': 'raid no longer active',
                         'resolution': 'ownership_changed'}
        assert await scalar(
            path, "SELECT status||':'||resolution FROM npc_empire_interior_raids "
                  "WHERE token=?", (raid['token'],)) == 'resolved:ownership_changed'
        assert await scalar(path, "SELECT current_hp FROM gang_members WHERE id=1") == 100
        assert await scalar(
            path, "SELECT members FROM npc_empires WHERE leader_id='leila'") == members_before
        assert str(await scalar(
            path, "SELECT owner_uid FROM business_property_owners "
                  "WHERE biz_id='coffee'")) == '202'
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events "
                  "WHERE kind IN ('player_business_bombed','player_business_captured')") == 0
        retry = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'captured',
            attacker_casualties=[], defender_casualties=[1], guard_casualties=[],
            now=now + raid['hold_seconds'] + 1)
        assert retry == {'ok': True, 'duplicate': True,
                         'resolution': 'ownership_changed'}
    finally:
        os.unlink(path)


async def run() -> None:
    await vassalization_terminalizes_pending()
    await ownership_generation_terminalizes_pending()
    print('stale raid generation: diplomacy/ownership terminal, no casualties or property mutation OK')


if __name__ == '__main__':
    asyncio.run(run())
