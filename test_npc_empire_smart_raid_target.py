"""Stress contracts for smart, persistent player-business raid targeting."""

import asyncio
import os
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


async def scalar(path: str, sql: str, params=()):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql, params)).fetchone()
        return row[0]


async def run() -> None:
    assert ne._player_business_raid_objective(
        1, 'building:0,3', 'building:0,4', '0,4') == 'first-close'
    fd, path = tempfile.mkstemp(prefix='smart_raid_target_', suffix='.db')
    os.close(fd)
    try:
        await _base_db(path)
        now = 2_700_000_000
        async with aiosqlite.connect(path) as db:
            await db.executescript("""
                CREATE TABLE gang_members(
                    id INTEGER PRIMARY KEY,telegram_id INTEGER,current_hp INTEGER);
                CREATE TABLE district_control(
                    telegram_id INTEGER,loc_id TEXT,guard_json TEXT);
                CREATE TABLE apartments_owned(
                    telegram_id INTEGER,apt_key TEXT PRIMARY KEY,price INTEGER,bought_at INTEGER,
                    property_kind TEXT,operation_type TEXT,area INTEGER,income_per_minute INTEGER,
                    last_income_at INTEGER DEFAULT 0);
            """)
            await db.executemany(
                "INSERT INTO gang_members(id,telegram_id,current_hp) VALUES(?,101,100)",
                [(member_id,) for member_id in range(1, 9)],
            )
            await db.executemany(
                "INSERT INTO apartments_owned"
                "(telegram_id,apt_key,price,bought_at,property_kind,operation_type,area,income_per_minute) "
                "VALUES(101,?,?,?,'business',?,?,?)",
                [
                    ('tile:6,36', 20000, now, 'print_shop', 27, 200),
                    ('tile:6,46', 18000, now, 'poker_club', 27, 185),
                ],
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations"
                "(leader_id,telegram_id,score,pact,last_action_at) "
                "VALUES('leila',101,-100,'war',?)", (now,),
            )
            await db.execute(
                "UPDATE npc_empires SET members=12,strength=360,treasury=30000 "
                "WHERE leader_id='leila'",
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars"
                "(leader_id,telegram_id,next_attack_at,attacks) VALUES('leila',101,?,0)",
                (now,),
            )
            await db.commit()

        guarded = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101',
            holding_ref='building:0,3', requested=3, now=now,
        )
        assert guarded['ok'] and guarded['holding_guards'] == 3

        state = await ne.state_for(path, 101, now=now)
        assert len(state['interior_raids']) == 1
        raid = state['interior_raids'][0]
        assert raid['objective'] == 'first-close'
        assert raid['target_kind'] == 'building' and raid['target_id'] == '0,4', raid
        empire = next(item for item in state['empires'] if item['leader_id'] == 'leila')
        activity = empire['activity']
        assert (activity['raid_token'], activity['target_id'], activity['target_kind']) == (
            raid['token'], raid['target_id'], raid['target_kind'])
        assert (activity['target_r'], activity['target_c']) == (
            raid['target_r'], raid['target_c'])
        assert await scalar(
            path, "SELECT next_attack_at FROM npc_empire_player_wars "
                  "WHERE leader_id='leila' AND telegram_id=101",
        ) == raid['expires_at'] + 1

        # Reverse the preferred weak point after the raid has started. Forty
        # reconnect-like snapshots must retain the immutable raid target/token
        # and must not emit another event or keep a due row hot.
        await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101',
            holding_ref='building:0,3', requested=0, now=now + 1,
        )
        await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101',
            holding_ref='building:0,4', requested=4, now=now + 2,
        )
        # Simulate a legacy/hot due row plus roster shrink while the raid is
        # pending. Persisted work must be checked before a fresh score can call
        # the assault irrational and postpone it beyond its own expiry.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET members=2 WHERE leader_id='leila'")
            await db.execute(
                "UPDATE npc_empire_player_wars SET next_attack_at=? "
                "WHERE leader_id='leila' AND telegram_id=101", (now + 3,))
            await db.commit()
        hot_reconnect = await ne.state_for(path, 101, now=now + 3)
        assert hot_reconnect['interior_raids'][0]['token'] == raid['token']
        assert await scalar(
            path, "SELECT next_attack_at FROM npc_empire_player_wars "
                  "WHERE leader_id='leila' AND telegram_id=101",
        ) == raid['expires_at'] + 1
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET members=12 WHERE leader_id='leila'")
            await db.commit()
        for offset in range(1, 41):
            snapshot = await ne.state_for(path, 101, now=now + offset)
            current = snapshot['interior_raids'][0]
            current_empire = next(item for item in snapshot['empires']
                                  if item['leader_id'] == 'leila')
            assert current['token'] == raid['token']
            assert current['objective'] == 'first-close'
            assert current_empire['activity']['raid_token'] == raid['token']
            assert current_empire['activity']['target_id'] == '0,4'
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events "
                  "WHERE kind='player_business_interior_raid' AND target_id='101'",
        ) == 1
        assert await scalar(
            path, "SELECT next_attack_at FROM npc_empire_player_wars "
                  "WHERE leader_id='leila' AND telegram_id=101",
        ) >= raid['expires_at'] + 1

        # An abandoned pending session expires silently. Exactly one bounded
        # reschedule then selects the newly weak building, and more snapshots
        # cannot fan out duplicate events.
        expired = await ne.state_for(path, 101, now=raid['expires_at'])
        assert not expired['interior_raids']
        assert await scalar(
            path, "SELECT resolution FROM npc_empire_interior_raids WHERE token=?",
            (raid['token'],),
        ) == 'expired'
        rescheduled = await ne.state_for(path, 101, now=raid['expires_at'] + 1)
        assert len(rescheduled['interior_raids']) == 1
        next_raid = rescheduled['interior_raids'][0]
        assert next_raid['token'] != raid['token']
        assert next_raid['target_kind'] == 'building' and next_raid['target_id'] == '0,3'
        for offset in range(2, 12):
            await ne.state_for(path, 101, now=raid['expires_at'] + offset)
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events "
                  "WHERE kind='player_business_interior_raid' AND target_id='101'",
        ) == 2

        async with aiosqlite.connect(path) as db:
            plan = await (await db.execute(
                "EXPLAIN QUERY PLAN SELECT holding_ref,living "
                "FROM npc_empire_guard_assignments "
                "WHERE owner_kind='player' AND owner_id='101'",
            )).fetchall()
        assert any('INDEX' in str(row[3]).upper() for row in plan), plan
        print('smart raid target: scored guard snapshot, atomic pending target, '
              '40 reconnects, silent expiry and bounded reschedule OK')
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
