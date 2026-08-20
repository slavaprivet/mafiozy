"""Twelve-minute physical player-business raid and reload stress."""

import asyncio
import importlib
import os
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_business_reload import make_db, row, empire, holding


NOW = 2_300_000_000
PLAYER = 404
TARGET = '0,3'
SNAPSHOT_STEP = 5
STRESS_SECONDS = 12 * 60
FIRST_DUE = 30
FIRST_RESOLVE = 50
FOLLOWUP_DUE = FIRST_RESOLVE + ne.PLAYER_WAR_CAPTURE_FOLLOWUP_SECONDS
FOLLOWUP_RESOLVE = FOLLOWUP_DUE + ne.PLAYER_INTERIOR_RAID_HOLD_SECONDS


def raid_signature(raid: dict) -> tuple:
    """Everything a reconnect must reconstruct for one paid physical roster."""
    attackers = tuple(
        (int(actor['slot']), int(actor['hp']), float(actor['accuracy']),
         int(actor['weapon_budget']), int(actor['tier']), int(actor['quality']))
        for actor in raid['attacker_roster']
    )
    defenders = tuple(sorted(int(actor['member_id'])
                             for actor in raid['defender_roster']))
    guards = tuple(sorted(int(actor['member_id'])
                          for actor in raid['guard_roster']))
    return (
        raid['token'], raid['apt_key'], raid['target_id'], raid['leader_id'],
        int(raid['force']), int(raid['quality']), int(raid['tier']),
        int(raid['started_at']), int(raid['hold_seconds']), int(raid['expires_at']),
        attackers, defenders, guards,
    )


def exact_capture_casualties(raid: dict) -> dict:
    """Reachable capture: one attacker loss, all concrete defenders down."""
    assert int(raid['force']) >= 2
    return {
        'attacker_casualties': [0],
        'defender_casualties': [int(actor['member_id'])
                                 for actor in raid['defender_roster']],
        'guard_casualties': [int(actor['member_id'])
                             for actor in raid['guard_roster']],
    }


async def scalar(path: str, sql: str, args=()):
    async with aiosqlite.connect(path) as db:
        value = await (await db.execute(sql, args)).fetchone()
        return value[0] if value else None


async def run():
    global ne
    handle, path = tempfile.mkstemp(prefix='npc_business_physical_stress_', suffix='.db')
    os.close(handle)
    try:
        await make_db(path)
        area = ne.BUILDING_AREAS[TARGET]
        original_operation = 'beer_bar'
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "CREATE TABLE gang_members("
                "id INTEGER PRIMARY KEY,telegram_id INTEGER NOT NULL,current_hp INTEGER NOT NULL)"
            )
            await db.execute(
                "UPDATE npc_empires SET status='ruined',comeback_at=? WHERE leader_id<>'marco'",
                (NOW + 100000,),
            )
            await db.execute(
                "UPDATE npc_empires SET members=20,treasury=50000,last_tick=?,next_action_at=? "
                "WHERE leader_id='marco'", (NOW, NOW + 100000),
            )
            await db.execute(
                "INSERT INTO apartments_owned"
                "(telegram_id,apt_key,price,bought_at,property_kind,operation_type,area,"
                "income_per_minute,last_income_at) VALUES(?,?,?,?, 'business',?,?,?,?)",
                (PLAYER, TARGET, 12000, NOW - 50, original_operation, area,
                 ne.building_operation_income(original_operation, area), NOW - 50),
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations"
                "(leader_id,telegram_id,score,pact,last_action_at) "
                "VALUES('marco',?,-100,'war',?)", (PLAYER, NOW),
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars"
                "(leader_id,telegram_id,next_attack_at,attacks,last_business_id,last_attack_at) "
                "VALUES('marco',?,?,0,'',0)", (PLAYER, NOW + FIRST_DUE),
            )
            await db.commit()

        raid1 = raid2 = None
        signature1 = signature2 = None
        roster_treasury = None
        interior_events = bombed_events = captured_events = 0
        snapshot_count = 0

        for seconds in range(0, STRESS_SECONDS + 1, SNAPSHOT_STEP):
            snapshot = await ne.state_for(path, PLAYER, NOW + seconds)
            snapshot_count += 1
            events = snapshot['player_war_events']
            interior_events += sum(event['kind'] == 'player_business_interior_raid'
                                   for event in events)

            if seconds < FIRST_DUE:
                assert snapshot['interior_raids'] == []
                assert events == []
                route = empire(snapshot, 'marco')['activity']
                assert route['kind'] == 'player_business_raid'
                assert route['target_id'] == TARGET

            elif seconds < FIRST_RESOLVE:
                assert len(snapshot['interior_raids']) == 1
                current = snapshot['interior_raids'][0]
                if raid1 is None:
                    raid1, signature1 = current, raid_signature(current)
                    assert seconds == FIRST_DUE
                    assert [event['kind'] for event in events] == [
                        'player_business_interior_raid']
                    assert current['objective'] == 'first-close'
                    assert current['started_at'] == NOW + FIRST_DUE
                    roster_treasury = await scalar(
                        path, "SELECT treasury FROM npc_empires WHERE leader_id='marco'")
                    replay = await ne.state_for(path, PLAYER, NOW + seconds)
                    assert replay['player_war_events'] == []
                    assert raid_signature(replay['interior_raids'][0]) == signature1
                else:
                    assert events == []
                    assert raid_signature(current) == signature1
                    assert await scalar(
                        path, "SELECT treasury FROM npc_empires WHERE leader_id='marco'") \
                        == roster_treasury
                assert await scalar(
                    path, "SELECT COUNT(*) FROM npc_empire_interior_raids "
                          "WHERE telegram_id=? AND leader_id='marco' AND status='pending'",
                    (PLAYER,)) == 1
                assert await scalar(
                    path, "SELECT next_attack_at FROM npc_empire_player_wars "
                          "WHERE telegram_id=? AND leader_id='marco'", (PLAYER,)) \
                    == raid1['expires_at'] + 1

                if seconds == 40:
                    ne = importlib.reload(ne)
                    reloaded = await ne.state_for(path, PLAYER, NOW + seconds)
                    assert reloaded['player_war_events'] == []
                    assert raid_signature(reloaded['interior_raids'][0]) == signature1

            elif seconds == FIRST_RESOLVE:
                assert events == []
                assert len(snapshot['interior_raids']) == 1
                assert raid_signature(snapshot['interior_raids'][0]) == signature1

            elif seconds < FOLLOWUP_DUE:
                assert snapshot['interior_raids'] == []
                assert events == []
                assert await row(
                    path, "SELECT operation_type,last_income_at FROM apartments_owned "
                          "WHERE telegram_id=? AND apt_key=?", (PLAYER, TARGET)) == {
                              'operation_type': original_operation,
                              'last_income_at': NOW + FOLLOWUP_DUE,
                          }
                closure = await row(
                    path, "SELECT closed_until FROM npc_empire_building_closures "
                          "WHERE holding_id=?", (TARGET,))
                assert closure == {'closed_until': NOW + FOLLOWUP_DUE}
                if seconds == 300:
                    ne = importlib.reload(ne)
                    replay = await ne.state_for(path, PLAYER, NOW + seconds)
                    assert replay['player_war_events'] == []
                    assert replay['interior_raids'] == []

            elif seconds < FOLLOWUP_RESOLVE:
                assert len(snapshot['interior_raids']) == 1
                current = snapshot['interior_raids'][0]
                if raid2 is None:
                    raid2, signature2 = current, raid_signature(current)
                    assert seconds == FOLLOWUP_DUE
                    assert [event['kind'] for event in events] == [
                        'player_business_interior_raid']
                    assert current['objective'] == 'followup-capture'
                    assert current['started_at'] == NOW + FOLLOWUP_DUE
                    assert current['token'] != raid1['token']
                    replay = await ne.state_for(path, PLAYER, NOW + seconds)
                    assert replay['player_war_events'] == []
                    assert raid_signature(replay['interior_raids'][0]) == signature2
                else:
                    assert events == []
                    assert raid_signature(current) == signature2
                if seconds == FOLLOWUP_DUE + 5:
                    ne = importlib.reload(ne)
                    reloaded = await ne.state_for(path, PLAYER, NOW + seconds)
                    assert reloaded['player_war_events'] == []
                    assert raid_signature(reloaded['interior_raids'][0]) == signature2

            elif seconds == FOLLOWUP_RESOLVE:
                assert events == []
                assert len(snapshot['interior_raids']) == 1
                assert raid_signature(snapshot['interior_raids'][0]) == signature2

            else:
                assert snapshot['interior_raids'] == []
                assert events == []
                assert await row(
                    path, "SELECT 1 present FROM apartments_owned "
                          "WHERE telegram_id=? AND apt_key=?", (PLAYER, TARGET)) is None

            if seconds == FIRST_RESOLVE - 5:
                early = await ne.resolve_interior_raid(
                    path, PLAYER, raid1['token'], raid1['apt_key'], 'captured',
                    now=NOW + FIRST_RESOLVE - 1, **exact_capture_casualties(raid1))
                assert early == {'ok': False, 'error': 'raid still active',
                                 'retry_after': 1}

            if seconds == FIRST_RESOLVE:
                result = await ne.resolve_interior_raid(
                    path, PLAYER, raid1['token'], raid1['apt_key'], 'captured',
                    now=NOW + seconds, **exact_capture_casualties(raid1))
                assert result['ok'] and result['resolution'] == 'captured'
                assert [event['kind'] for event in result['phase_events']] == [
                    'player_business_bombed']
                bombed_events += 1
                duplicate = await ne.resolve_interior_raid(
                    path, PLAYER, raid1['token'], raid1['apt_key'], 'defended',
                    now=NOW + seconds, attacker_casualties=[],
                    defender_casualties=[], guard_casualties=[])
                assert duplicate == {'ok': True, 'duplicate': True,
                                     'resolution': 'captured'}

            if seconds == FOLLOWUP_RESOLVE - 5:
                early = await ne.resolve_interior_raid(
                    path, PLAYER, raid2['token'], raid2['apt_key'], 'captured',
                    now=NOW + FOLLOWUP_RESOLVE - 1, **exact_capture_casualties(raid2))
                assert early == {'ok': False, 'error': 'raid still active',
                                 'retry_after': 1}

            if seconds == FOLLOWUP_RESOLVE:
                result = await ne.resolve_interior_raid(
                    path, PLAYER, raid2['token'], raid2['apt_key'], 'captured',
                    now=NOW + seconds, **exact_capture_casualties(raid2))
                assert result['ok'] and result['resolution'] == 'captured'
                assert [event['kind'] for event in result['phase_events']] == [
                    'player_business_captured']
                captured_events += 1
                duplicate = await ne.resolve_interior_raid(
                    path, PLAYER, raid2['token'], raid2['apt_key'], 'captured',
                    now=NOW + seconds, **exact_capture_casualties(raid2))
                assert duplicate == {'ok': True, 'duplicate': True,
                                     'resolution': 'captured'}

        assert snapshot_count == STRESS_SECONDS // SNAPSHOT_STEP + 1 == 145
        assert (interior_events, bombed_events, captured_events) == (2, 1, 1)
        assert raid1['token'] != raid2['token']
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_interior_raids "
                  "WHERE telegram_id=? AND status='pending'", (PLAYER,)) == 0
        assert await scalar(
            path, "SELECT COUNT(*) FROM npc_empire_interior_raids "
                  "WHERE telegram_id=? AND resolution='expired'", (PLAYER,)) == 0

        ne = importlib.reload(ne)
        final = await ne.state_for(path, PLAYER, NOW + STRESS_SECONDS)
        captured = holding(final, 'marco', TARGET)
        assert captured['operation_type'] in ne.BUILDING_OPERATIONS
        assert captured['operation_type'] != original_operation
        assert captured['income'] == ne.building_operation_income(
            captured['operation_type'], area)
        assert captured['building_status'] == 'open'
        assert captured['closed_until'] == 0
        assert await row(
            path, "SELECT 1 present FROM npc_empire_building_closures "
                  "WHERE holding_id=?", (TARGET,)) is None
        assert 1 <= captured['guard_count'] <= 3
        assert captured['guard_count'] <= empire(final, 'marco')['members'] - 2

        print('npc business physical raid stress: 12m, 145 snapshots, two persisted '
              'sessions, explicit close/capture and reload idempotency OK')
    finally:
        try:
            os.unlink(path)
        except PermissionError:
            pass


if __name__ == '__main__':
    asyncio.run(run())
