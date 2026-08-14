"""Server contracts for roster-backed player-business interior raids."""

import asyncio
import os
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


async def scalar(path, sql, params=()):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql, params)).fetchone()
        return row[0]


async def run() -> None:
    low = ne.allocate_physical_roster(
        side='attacker', roster_available=2, members=2, strength=40,
        treasury=1000, aggression=10)
    high = ne.allocate_physical_roster(
        side='attacker', roster_available=20, members=20, strength=500,
        treasury=100000, aggression=95)
    assert low['count'] == 2 and high['count'] == 8
    assert high['tier'] > low['tier'] and high['weapon_budget'] > low['weapon_budget']
    assert ne.allocate_physical_roster(
        side='attacker', roster_available=1, members=20, strength=500,
        treasury=100000, aggression=95)['count'] == 1

    fd, path = tempfile.mkstemp(prefix='npc_interior_raid_', suffix='.db')
    os.close(fd)
    try:
        await _base_db(path); now = 2_200_000_000
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
                [(index,) for index in range(1, 7)])
            await db.execute(
                "INSERT INTO district_control VALUES(101,'northside','[1]')")
            await db.execute(
                "INSERT INTO apartments_owned"
                "(telegram_id,apt_key,price,bought_at,property_kind,operation_type,area,income_per_minute) "
                "VALUES(101,'tile:6,36',20000,?,'business','pawnshop',16,120)", (now,))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations"
                "(leader_id,telegram_id,score,pact,last_action_at) "
                "VALUES('leila',101,-100,'war',?)", (now,))
            await db.execute(
                "UPDATE npc_empires SET members=12,strength=360,treasury=30000 "
                "WHERE leader_id='leila'")
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars"
                "(leader_id,telegram_id,next_attack_at,attacks) VALUES('leila',101,?,0)", (now,))
            await db.commit()

        assigned = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101',
            holding_ref='building:0,3', requested=3, now=now)
        assert assigned == {'ok': True, 'total': 6, 'assigned': 4,
                            'free': 2, 'holding_guards': 3}
        guard_ids = []
        async with aiosqlite.connect(path) as db:
            guard_ids = [row[0] for row in await (await db.execute(
                "SELECT member_id FROM npc_empire_player_guard_members ORDER BY member_id"
            )).fetchall()]
        assert guard_ids == [2, 3, 4]  # district guard id=1 cannot be cloned.
        duplicate = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101',
            holding_ref='building:0,3', requested=3, now=now+1)
        assert duplicate['ok'] and duplicate['assigned'] == 4 and duplicate['free'] == 2
        removed = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101',
            holding_ref='building:0,3', requested=0, now=now+2)
        assert removed['ok'] and removed['assigned'] == 1 and removed['free'] == 5
        reassigned = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id='101',
            holding_ref='building:0,3', requested=3, now=now+3)
        assert reassigned['ok'] and reassigned['free'] == 2

        state = await ne.state_for(path, 101, now=now)
        assert len(state['interior_raids']) == 1, (state['player_war_events'], state['interior_raids'])
        raid = state['interior_raids'][0]
        assert raid['apt_key'] == 'tile:6,36' and 2 <= raid['force'] <= 8
        assert raid['guard_count'] == 3 and raid['defender_count'] == 3, raid
        assert all(key in raid for key in (
            'target_r','target_c','business_label','leader_name','gang_name',
            'quality','tier','expires_at','hold_seconds'))
        assert raid['hold_seconds'] == 20
        assert raid['objective'] == 'first-close'
        assert [slot['slot'] for slot in raid['attacker_roster']] == list(range(raid['force']))
        assert raid['guard_roster'] == []
        assert {row['member_id'] for row in raid['defender_roster']} == {2, 3, 4}
        assert await scalar(path,
            "SELECT COUNT(*) FROM apartments_owned WHERE telegram_id=101") == 1
        assert await scalar(path,
            "SELECT COUNT(*) FROM npc_empire_holdings WHERE holding_id='0,3'") == 0

        early = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'defended', now=now+10)
        assert not early['ok'] and early['error'] == 'raid still active'
        bad_ids = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'captured',
            attacker_casualties=[999], now=now+raid['hold_seconds'])
        assert not bad_ids['ok'] and bad_ids['error'] == 'bad attacker casualties'
        members_before = await scalar(path,
            "SELECT members FROM npc_empires WHERE leader_id='leila'")
        defended = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'defended',
            defender_casualties=[2],
            now=now+ne.PLAYER_INTERIOR_RAID_MIN_SECONDS)
        assert defended['ok'] and defended['attacker_losses'] > 0
        assert defended['defender_losses'] == 1
        assert await scalar(path,
            "SELECT current_hp FROM gang_members WHERE id=2") == 0
        assert await scalar(path,
            "SELECT COUNT(*) FROM npc_empire_player_guard_members WHERE member_id=2") == 0
        assert await scalar(path,
            "SELECT members FROM npc_empires WHERE leader_id='leila'") < members_before
        assert await scalar(path,
            "SELECT COUNT(*) FROM apartments_owned WHERE telegram_id=101") == 1
        repeat = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'captured', now=now+1000)
        assert repeat == {'ok': True, 'duplicate': True, 'resolution': 'defended'}

        # Force another due assault; capture of the interior invokes the old
        # first strike, which closes but does not transfer the property.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empire_player_wars SET next_attack_at=? WHERE leader_id='leila' AND telegram_id=101",
                (now+1000,)); await db.commit()
        state2 = await ne.state_for(path, 101, now=now+1000)
        raid2 = state2['interior_raids'][0]
        assert raid2['objective'] == 'first-close'
        captured = await ne.resolve_interior_raid(
            path, 101, raid2['token'], raid2['apt_key'], 'captured',
            attacker_casualties=[0], defender_casualties=[3],
            guard_casualties=[], now=now+1000+raid2['hold_seconds'])
        assert captured['ok']
        assert captured['attacker_losses'] == 1 and captured['defender_losses'] == 1
        assert any(event['kind'] == 'player_business_bombed'
                   for event in captured['phase_events'])
        assert await scalar(path,
            "SELECT COUNT(*) FROM apartments_owned WHERE telegram_id=101") == 1
        assert await scalar(path,
            "SELECT COUNT(*) FROM npc_empire_building_closures WHERE holding_id='0,3'") == 1
        living_guard_rows = await scalar(path,
            "SELECT living FROM npc_empire_guard_assignments "
            "WHERE owner_kind='player' AND owner_id='101' AND holding_ref='building:0,3'")
        dead_hired = await scalar(path,
            "SELECT COUNT(*) FROM gang_members WHERE telegram_id=101 AND id IN (2,3,4) AND current_hp=0")
        assert living_guard_rows + dead_hired == 3 and dead_hired == 2

        # The follow-up capture changes ownership. Its transaction must also
        # release the sole surviving assignee instead of leaving a ghost guard.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empire_player_wars SET next_attack_at=? WHERE leader_id='leila' AND telegram_id=101",
                (now+2000,)); await db.commit()
        state3 = await ne.state_for(path, 101, now=now+2000)
        raid3 = state3['interior_raids'][0]
        assert raid3['objective'] == 'followup-capture'
        takeover = await ne.resolve_interior_raid(
            path, 101, raid3['token'], raid3['apt_key'], 'captured',
            now=now+2000+raid3['hold_seconds'])
        assert takeover['ok']
        assert any(event['kind'] == 'player_business_captured'
                   for event in takeover['phase_events'])
        assert await scalar(path,
            "SELECT COUNT(*) FROM apartments_owned WHERE telegram_id=101") == 0
        assert await scalar(path,
            "SELECT COUNT(*) FROM npc_empire_player_guard_members WHERE owner_uid=101") == 0
        assert await scalar(path,
            "SELECT COUNT(*) FROM npc_empire_guard_assignments "
            "WHERE owner_kind='player' AND owner_id='101'") == 0
        print('npc interior raid: actual paid 2..8 attackers, concrete hired defenders, '
              'district/property assignment exclusion, timing/idempotency/casualties and '
              'existing first-close phase OK')
    finally:
        os.unlink(path)


if __name__ == '__main__':
    asyncio.run(run())
