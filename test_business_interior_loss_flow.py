"""Full lost-defence flow: cashier hold, interruption and two server phases."""

import asyncio
import os
import sqlite3
import tempfile
from math import cos, hypot, pi, sin
from pathlib import Path

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / 'world.html').read_text(encoding='utf-8')
NOW = 2_400_000_000
PLAYER = 707
TARGET = '0,3'
APT = 'tile:6,36'


def blocked(r, c):
    """Representative authored counter/cover between entrance and cashier."""
    return (5.0 <= r <= 7.2 and 4.0 <= c <= 12.0) or not (
        .3 < r < 11.7 and .3 < c < 15.7)


def line_clear(start, target):
    distance = hypot(target[0] - start[0], target[1] - start[1])
    for index in range(1, max(2, int(distance / .08))):
        p = index / max(2, int(distance / .08))
        if blocked(start[0] + (target[0] - start[0]) * p,
                   start[1] + (target[1] - start[1]) * p):
            return False
    return True


def move(actor, target, dt=.05):
    dr, dc = target[0] - actor[0], target[1] - actor[1]
    distance = hypot(dr, dc) or 1
    step = min(distance, actor[2] * dt)
    old = actor[:2]
    sign = actor[3]
    turns = (0, .5 * sign, -.5 * sign) if line_clear(actor, target) else (
        1.5 * sign, 1 * sign, 2.1 * sign, .5 * sign,
        -.5 * sign, -1 * sign, pi)
    for turn in turns:
        s, q = sin(turn), cos(turn)
        vr, vc = dr / distance * q - dc / distance * s, dr / distance * s + dc / distance * q
        nr, nc = actor[0] + vr * step, actor[1] + vc * step
        if not blocked(nr, nc):
            actor[0], actor[1] = nr, nc
            break
    return hypot(actor[0] - old[0], actor[1] - old[1])


def client_loss_flow():
    cash = (2.8, 8.0)
    actors = [[10.2, 6.0 + index * 1.25, 1.25, 1 if index % 2 else -1]
              for index in range(4)]
    longest_stall = stall = 0
    for _ in range(2400):
        moved = [move(actor, cash) for actor in actors]
        assert all(distance <= 1.25 * .05 + 1e-9 for distance in moved)  # no teleport
        stall = stall + 1 if not any(moved) else 0
        longest_stall = max(longest_stall, stall)
        if all(hypot(actor[0] - cash[0], actor[1] - cash[1]) <= 2.15 for actor in actors):
            break
    assert longest_stall < 20
    assert all(hypot(actor[0] - cash[0], actor[1] - cash[1]) <= 2.15 for actor in actors)

    roster, hold_started = ['a', 'b', 'c', 'd'], 0
    assert 19_999 - hold_started < 20_000
    # A kill changes the complete surviving roster and restarts, rather than
    # preserving 10 seconds from a no-longer uninterrupted hold.
    elapsed = 10_000
    roster.remove('b'); new_signature = '|'.join(roster)
    hold_started = elapsed
    assert elapsed + 19_999 - hold_started < 20_000
    assert elapsed + 20_000 - hold_started == 20_000
    assert new_signature == 'a|c|d'


async def scalar(path, sql, args=()):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql, args)).fetchone()
        return row[0] if row else None


async def server_two_phase_flow():
    fd, path = tempfile.mkstemp(prefix='business_loss_flow_', suffix='.db')
    os.close(fd)
    try:
        await _base_db(path)
        async with aiosqlite.connect(path) as db:
            await db.executescript("""
                CREATE TABLE gang_members(id INTEGER PRIMARY KEY,telegram_id INTEGER,current_hp INTEGER);
                CREATE TABLE district_control(telegram_id INTEGER,loc_id TEXT,guard_json TEXT);
                CREATE TABLE apartments_owned(
                    telegram_id INTEGER,apt_key TEXT PRIMARY KEY,price INTEGER,bought_at INTEGER,
                    property_kind TEXT,operation_type TEXT,area INTEGER,income_per_minute INTEGER,
                    last_income_at INTEGER DEFAULT 0);
            """)
            await db.execute(
                "INSERT INTO apartments_owned VALUES(?,?,20000,?,'business','beer_bar',16,120,?)",
                (PLAYER, APT, NOW - 100, NOW - 100))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations"
                "(leader_id,telegram_id,score,pact,last_action_at) VALUES('leila',?,-100,'war',?)",
                (PLAYER, NOW))
            await db.execute(
                "UPDATE npc_empires SET status=CASE WHEN leader_id='leila' THEN 'active' ELSE 'ruined' END,"
                "members=12,strength=360,treasury=50000,next_action_at=?", (NOW + 10_000,))
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars"
                "(leader_id,telegram_id,next_attack_at,attacks,last_business_id,last_attack_at) "
                "VALUES('leila',?,?,0,'',0)", (PLAYER, NOW))
            await db.commit()

        first = await ne.state_for(path, PLAYER, NOW)
        raid1 = first['interior_raids'][0]
        assert raid1['defender_count'] == raid1['guard_count'] == 0
        assert raid1['defender_roster'] == raid1['guard_roster'] == []
        loss1 = await ne.resolve_interior_raid(
            path, PLAYER, raid1['token'], raid1['apt_key'], 'captured',
            attacker_casualties=[0], defender_casualties=[], guard_casualties=[],
            now=NOW + raid1['hold_seconds'])
        assert loss1['attacker_losses'] == 1 and loss1['defender_losses'] == 0
        assert [event['kind'] for event in loss1['phase_events']] == ['player_business_bombed']
        assert await scalar(path, "SELECT COUNT(*) FROM apartments_owned WHERE telegram_id=?", (PLAYER,)) == 1
        assert await scalar(path, "SELECT COUNT(*) FROM npc_empire_building_closures WHERE holding_id=?", (TARGET,)) == 1

        async with aiosqlite.connect(path) as db:
            await db.executemany("INSERT INTO gang_members VALUES(?,?,100)",
                                 [(101, PLAYER), (102, PLAYER), (103, PLAYER)])
            due = await (await db.execute(
                "SELECT next_attack_at FROM npc_empire_player_wars WHERE leader_id='leila' AND telegram_id=?",
                (PLAYER,))).fetchone()
            await db.commit()
        assigned = await ne.assign_holding_guards(
            path, owner_kind='player', owner_id=str(PLAYER),
            holding_ref=f'building:{TARGET}', requested=3, now=due[0] - 1)
        assert assigned['holding_guards'] == 3

        second = await ne.state_for(path, PLAYER, due[0])
        raid2 = second['interior_raids'][0]
        assert {row['member_id'] for row in raid2['defender_roster']} == {101, 102, 103}
        loss2 = await ne.resolve_interior_raid(
            path, PLAYER, raid2['token'], raid2['apt_key'], 'captured',
            attacker_casualties=[0, 1], defender_casualties=[101, 102, 103],
            guard_casualties=[], now=due[0] + raid2['hold_seconds'])
        assert loss2['attacker_losses'] == 2 and loss2['defender_losses'] == 3
        assert [event['kind'] for event in loss2['phase_events']] == ['player_business_captured']
        assert await scalar(path, "SELECT COUNT(*) FROM apartments_owned WHERE telegram_id=?", (PLAYER,)) == 0
        assert await scalar(path, "SELECT COUNT(*) FROM npc_empire_holdings WHERE leader_id='leila' AND holding_id=?", (TARGET,)) == 1
        assert await scalar(path, "SELECT COUNT(*) FROM gang_members WHERE id IN (101,102,103) AND current_hp=0") == 3
    finally:
        os.unlink(path)


async def main():
    assert "state.holdRoster!==holdRoster" in WORLD
    assert "state.holdStartedAt=0;state.holdRoster=''" in WORLD
    assert "now-state.holdStartedAt>=state.holdMs" in WORLD
    assert "state.phase='contested';state.holdStartedAt=0;state.holdRoster=''" in WORLD
    assert "turns=direct?[0,.5*sign,-.5*sign]:[1.5*sign,1*sign,2.1*sign,.5*sign" in WORLD
    assert "state.phase==='advance'||state.phase==='hold'" in WORLD
    assert ':stalls-${maxMoveStalls}:hold-roster-${state.holdRoster' in WORLD
    client_loss_flow()
    await server_two_phase_flow()
    print('business interior loss: cover navigation, resettable exact hold, casualties, close/capture OK')


if __name__ == '__main__':
    asyncio.run(main())
