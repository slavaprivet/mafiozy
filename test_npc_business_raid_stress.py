"""Fifteen-minute deterministic stress for player-business raids and reloads."""

import asyncio
import importlib
import os
import tempfile
from pathlib import Path

import aiosqlite

import npc_empire as ne
from test_npc_business_reload import make_db, row, empire, holding


NOW = 2_300_000_000
PLAYER = 404
TARGET = '0,3'
SNAPSHOT_STEP = 5
STRESS_SECONDS = 15 * 60


def apply_snapshot(fixture, phase, target, now_ms):
    """Deterministic mirror of the preview target+phase identity rules."""
    fixture_id = f'{phase}:{target}'
    if fixture and fixture['fixture_id'] == fixture_id:
        fixture['reapply_count'] += 1
        return fixture
    continuing = bool(fixture and fixture['target'] == target)
    if continuing:
        fixture['fixture_id'] = fixture_id
        fixture['phase'] = phase
        fixture['guard_cap'] = 3 if phase == 'approach' else 0
        if not fixture['guard_cap']:
            fixture['guards'].clear()
        fixture['reapply_count'] = 0
        return fixture
    return {
        'fixture_id': fixture_id, 'phase': phase, 'target': target,
        'started_at': now_ms, 'start_distance': 20.04,
        'boss_distance': 20.04, 'crew_distances': [42.0 + slot for slot in range(8)],
        'guard_cap': 3, 'guards': {0: True, 1: True, 2: True},
        'reapply_count': 0,
    }


def replace_and_reconcile(fixture):
    """Replace all physical arrays, then bind fresh objects to checkpoints."""
    boss = {'distance': 36.83, 'position': (40.0, 40.0), 'activity': None}
    crew = []
    guards = []
    boss['activity'] = fixture['fixture_id']
    checkpoint = fixture['boss_checkpoint']
    if boss['distance'] > checkpoint['distance'] + .1:
        boss['distance'] = checkpoint['distance']
        boss['position'] = checkpoint['position']
    for slot, saved in fixture['crew_checkpoints'].items():
        crew.append({'slot': slot, 'distance': saved})
    for slot in range(fixture['guard_cap']):
        if slot not in fixture['dead_guard_slots']:
            guards.append({'slot': slot, 'alive': True})
    return boss, crew, guards


async def run():
    root = Path(__file__).resolve().parent
    world = (root / 'world.html').read_text(encoding='utf-8')
    assert "continuingTarget=previousFixture?.key===meta.key" in world
    assert "raidStartedAt=continuingTarget?" in world
    assert "if(!continuingTarget&&boss&&stage)" in world
    assert "guard_count:defended?3:0" in world
    assert "phase:raidPhase,stance:'assault'" in world

    handle, path = tempfile.mkstemp(prefix='npc_business_raid_stress_', suffix='.db')
    os.close(handle)
    try:
        await make_db(path)
        area = ne.BUILDING_AREAS[TARGET]
        original_operation = 'beer_bar'
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET status='ruined',comeback_at=? WHERE leader_id<>'marco'",
                (NOW + 100000,),
            )
            await db.execute(
                "UPDATE npc_empires SET members=20,last_tick=?,next_action_at=? WHERE leader_id='marco'",
                (NOW, NOW + 100000),
            )
            await db.execute(
                "INSERT INTO apartments_owned"
                "(telegram_id,apt_key,price,bought_at,property_kind,operation_type,area,income_per_minute,last_income_at) "
                "VALUES(?,?,?,?, 'business',?,?,?,?)",
                (PLAYER, TARGET, 12000, NOW - 50, original_operation, area,
                 ne.building_operation_income(original_operation, area), NOW - 50),
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations"
                "(leader_id,telegram_id,score,pact,last_action_at) VALUES('marco',?,-100,'war',?)",
                (PLAYER, NOW),
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars"
                "(leader_id,telegram_id,next_attack_at,attacks,last_business_id,last_attack_at) "
                "VALUES('marco',?,?,0,'',0)", (PLAYER, NOW + 300),
            )
            await db.commit()

        fixture = None
        identity = None
        elapsed_samples = []
        previous_boss = float('inf')
        previous_crew = [float('inf')] * 8
        killed_slots = set()
        first_close_count = capture_count = 0
        reapply_total = 0

        # 181 authoritative snapshots, including both endpoints. Client motion
        # happens between polls; reapply must never undo it.
        for seconds in range(0, STRESS_SECONDS + 1, SNAPSHOT_STEP):
            snapshot = await ne.state_for(path, PLAYER, NOW + seconds)
            events = snapshot['player_war_events']
            first_close_count += sum(e['kind'] == 'player_business_bombed' for e in events)
            capture_count += sum(e['kind'] == 'player_business_captured' for e in events)
            phase = ('approach' if seconds < 300 else
                     'first-close' if seconds < STRESS_SECONDS else 'followup-capture')
            if fixture and fixture['fixture_id'] == f'{phase}:{TARGET}':
                reapply_total += 1
            fixture = apply_snapshot(fixture, phase, TARGET, seconds * 1000)
            identity = identity or fixture
            assert fixture is identity

            # Deterministic collision-safe progress. The important invariant is
            # that snapshot reapply cannot increase either distance.
            fixture['boss_distance'] = max(.8, fixture['boss_distance'] - .16)
            fixture['crew_distances'] = [
                max(1.8 + slot * .18, distance - .28)
                for slot, distance in enumerate(fixture['crew_distances'])
            ]
            assert fixture['boss_distance'] <= previous_boss
            assert all(current <= previous for current, previous in zip(
                fixture['crew_distances'], previous_crew))
            previous_boss = fixture['boss_distance']
            previous_crew = list(fixture['crew_distances'])

            if seconds in (100, 180, 260):
                slot = (100, 180, 260).index(seconds)
                fixture['guards'][slot] = False
                killed_slots.add(slot)
            assert len(fixture['guards']) <= fixture['guard_cap']
            assert len(set(fixture['guards'])) == len(fixture['guards'])
            assert all(0 <= slot < fixture['guard_cap'] for slot in fixture['guards'])
            if phase == 'approach':
                assert all(not fixture['guards'].get(slot, False) for slot in killed_slots)
            else:
                assert fixture['guard_cap'] == 0 and fixture['guards'] == {}

            elapsed_samples.append(seconds * 1000 - fixture['started_at'])
            fixture['boss_checkpoint'] = {
                'distance': fixture['boss_distance'],
                'position': (fixture['boss_distance'], 3.0),
            }
            fixture['crew_checkpoints'] = {
                slot: distance for slot, distance in enumerate(fixture['crew_distances'])
            }
            fixture['dead_guard_slots'] = set(killed_slots)
            if seconds in (200, 400, 700):
                saved_boss = fixture['boss_distance']
                saved_crew = list(fixture['crew_distances'])
                boss, replacement_crew, replacement_guards = replace_and_reconcile(fixture)
                assert boss['activity'] == fixture['fixture_id']
                assert boss['distance'] == saved_boss
                assert [member['distance'] for member in replacement_crew] == saved_crew
                assert {guard['slot'] for guard in replacement_guards}.isdisjoint(killed_slots)
                assert len(replacement_guards) <= fixture['guard_cap']
            if seconds == 300:
                assert [e['kind'] for e in events] == ['player_business_bombed']
                closure = await row(path,
                    "SELECT closed_until FROM npc_empire_building_closures WHERE holding_id=?",
                    (TARGET,))
                assert closure['closed_until'] == NOW + 900
                owned = await row(path,
                    "SELECT operation_type,last_income_at FROM apartments_owned "
                    "WHERE telegram_id=? AND apt_key=?", (PLAYER, TARGET))
                assert owned == {'operation_type': original_operation, 'last_income_at': NOW + 900}
            if seconds == 600:
                globals()['ne'] = importlib.reload(ne)
                closed = await ne.state_for(path, PLAYER, NOW + seconds)
                assert empire(closed, 'marco')['activity']['phase'] == 'capture'
                assert await row(path,
                    "SELECT operation_type FROM apartments_owned WHERE telegram_id=? AND apt_key=?",
                    (PLAYER, TARGET)) == {'operation_type': original_operation}

        assert all(later > earlier for earlier, later in zip(
            elapsed_samples, elapsed_samples[1:]))
        assert elapsed_samples[-1] == STRESS_SECONDS * 1000
        assert len(elapsed_samples) == 181 and reapply_total == 178
        assert first_close_count == 1 and capture_count == 1

        # Reconnect after the follow-up reconstructs one authoritative NPC
        # holding with a rebranded operation and no stale CLOSED/player owner.
        globals()['ne'] = importlib.reload(ne)
        final = await ne.state_for(path, PLAYER, NOW + STRESS_SECONDS + 1)
        captured = holding(final, 'marco', TARGET)
        assert captured['operation_type'] in ne.BUILDING_OPERATIONS
        assert captured['operation_type'] != original_operation
        assert captured['income'] == ne.building_operation_income(
            captured['operation_type'], area)
        assert captured['building_status'] == 'open' and captured['closed_until'] == 0
        assert await row(path,
            "SELECT 1 present FROM apartments_owned WHERE telegram_id=? AND apt_key=?",
            (PLAYER, TARGET)) is None
        assert await row(path,
            "SELECT 1 present FROM npc_empire_building_closures WHERE holding_id=?",
            (TARGET,)) is None

        print('npc business raid stress: 15m, 181 snapshots, no reset/revive, close/capture/reload OK')
    finally:
        try:
            os.unlink(path)
        except PermissionError:
            pass


if __name__ == '__main__':
    asyncio.run(run())
