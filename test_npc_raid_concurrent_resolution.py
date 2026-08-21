"""At most one NPC raid may resolve one player holding generation."""

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


async def run() -> None:
    handle, path = tempfile.mkstemp(prefix='raid_concurrent_resolution_', suffix='.db')
    os.close(handle); now = 3_000_000_000
    try:
        await _base_db(path)
        async with aiosqlite.connect(path) as db:
            await db.executescript("""
                CREATE TABLE gang_members(
                    id INTEGER PRIMARY KEY,telegram_id INTEGER,current_hp INTEGER);
                CREATE TABLE district_control(
                    telegram_id INTEGER,loc_id TEXT,guard_json TEXT);
                INSERT INTO gang_members VALUES(1,101,100);
                INSERT INTO gang_members VALUES(20,202,100);
                INSERT INTO district_control VALUES(101,'north','[]');
                INSERT INTO district_control VALUES(202,'south','[]');
                INSERT INTO player_businesses VALUES(101,'coffee',0,0,'ok',0,0,1,0,NULL);
                INSERT INTO business_property_owners VALUES('coffee',101,'One',3000000000,0);
                INSERT INTO player_businesses VALUES(202,'donut',0,0,'ok',0,0,1,0,NULL);
                INSERT INTO business_property_owners VALUES('donut',202,'Two',3000000000,0);
                INSERT OR REPLACE INTO npc_empire_relations VALUES('leila',101,-100,'war',3000000000);
                INSERT OR REPLACE INTO npc_empire_relations VALUES('marco',101,-100,'war',3000000000);
                INSERT OR REPLACE INTO npc_empire_player_wars VALUES('leila',101,3000000000,0,'',0);
                INSERT OR REPLACE INTO npc_empire_player_wars VALUES('marco',101,3000000000,0,'',0);
            """)
            await db.execute(
                "UPDATE npc_empires SET status=CASE WHEN leader_id IN ('leila','marco') "
                "THEN 'active' ELSE 'ruined' END,members=12,strength=360,treasury=50000,"
                "next_action_at=?", (now + 10000,))
            await db.commit()
        assert (await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101', holding_ref='business:coffee',
            requested=1, now=now))['ok']
        assert (await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='202', holding_ref='business:donut',
            requested=1, now=now))['ok']

        state = await ne.state_for(path, 101, now=now)
        raids = state['interior_raids']
        assert len(raids) == 1, f'duplicate live tokens for one holding: {len(raids)}'
        first = raids[0]
        second_leader = 'marco' if first['leader_id'] == 'leila' else 'leila'
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            source = await (await db.execute(
                "SELECT * FROM npc_empire_interior_raids WHERE token=?",
                (first['token'],))).fetchone()
            values = dict(source); values['token'] = 'legacy-concurrent-token'
            values['leader_id'] = second_leader
            columns = list(values)
            await db.execute(
                f"INSERT INTO npc_empire_interior_raids({','.join(columns)}) "
                f"VALUES({','.join('?' for _ in columns)})", tuple(values[name] for name in columns))
            await db.commit()

        members_before = await scalar(
            path, "SELECT SUM(members) FROM npc_empires WHERE leader_id IN ('leila','marco')")
        results = await asyncio.gather(*[
            ne.resolve_interior_raid(
                path, 101, raid['token'], raid['apt_key'], 'captured',
                attacker_casualties=[0], defender_casualties=[1], guard_casualties=[],
                now=now + raid['hold_seconds'])
            for raid in (first, {**first, 'token': 'legacy-concurrent-token'})
        ])
        phase_kinds = [event['kind'] for result in results for event in result.get('phase_events', [])]
        assert phase_kinds == ['player_business_bombed'], (results, phase_kinds)
        loser = next(result for result in results if result.get('duplicate'))
        assert loser['resolution'] == 'superseded'
        assert await scalar(path,
            "SELECT COUNT(*) FROM npc_empire_events WHERE kind='player_business_bombed' "
            "AND target_id='101'") == 1
        assert await scalar(path,
            "SELECT SUM(attacks) FROM npc_empire_player_wars WHERE telegram_id=101") == 1
        assert await scalar(path,
            "SELECT current_hp FROM gang_members WHERE id=1") == 0
        assert await scalar(path,
            "SELECT SUM(members) FROM npc_empires WHERE leader_id IN ('leila','marco')") == members_before - 1
        assert await scalar(path,
            "SELECT current_hp FROM gang_members WHERE id=20") == 100
        assert await scalar(path,
            "SELECT COUNT(*) FROM npc_empire_player_guard_members WHERE owner_uid=202") == 1
        assert str(await scalar(path,
            "SELECT owner_uid FROM business_property_owners WHERE biz_id='donut'")) == '202'
        retry = await ne.resolve_interior_raid(
            path, 101, first['token'], first['apt_key'], 'captured', now=now + 99,
            attacker_casualties=[], defender_casualties=[1], guard_casualties=[])
        assert retry['ok'] and retry['duplicate']
        print('concurrent raid resolution: one phase, loser superseded, retry/other owner exact OK')
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
