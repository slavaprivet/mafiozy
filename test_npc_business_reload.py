"""Persistence/reconnect regression for the complete converted-business cycle."""

import asyncio
import ast
import importlib
import os
import sqlite3
import tempfile
import time
from pathlib import Path

import aiosqlite

import npc_empire as ne


NOW = 2_200_000_000
PLAYER = 404


async def make_db(path):
    async with aiosqlite.connect(path) as db:
        await db.executescript("""
        CREATE TABLE characters(telegram_id INTEGER PRIMARY KEY,cash INTEGER DEFAULT 0);
        CREATE TABLE business_property_owners(biz_id TEXT PRIMARY KEY,owner_uid TEXT,owner_name TEXT,acquired_at INTEGER,protected_until INTEGER);
        CREATE TABLE player_businesses(telegram_id INTEGER,biz_id TEXT PRIMARY KEY,bought_at INTEGER,last_collect INTEGER,status TEXT,blocked_until INTEGER,last_event_at INTEGER,level INTEGER,guards INTEGER,pending_notice TEXT);
        CREATE TABLE apartments_owned(telegram_id INTEGER,apt_key TEXT,price INTEGER,bought_at INTEGER,safe_level INTEGER DEFAULT 0,weapon_rack_level INTEGER DEFAULT 0,garage_level INTEGER DEFAULT 0,cameras_level INTEGER DEFAULT 0,repair_level INTEGER DEFAULT 0,stolen_bags INTEGER DEFAULT 0,property_kind TEXT,operation_type TEXT,area INTEGER,income_per_minute INTEGER,last_income_at INTEGER,PRIMARY KEY(telegram_id,apt_key));
        CREATE TABLE inventory(id INTEGER PRIMARY KEY AUTOINCREMENT,telegram_id INTEGER,item_id TEXT,quantity INTEGER DEFAULT 1);
        INSERT INTO characters VALUES(404,1000000);
        INSERT INTO inventory(telegram_id,item_id,quantity) VALUES(404,'c4',2);
        """)
        await db.commit()
    await ne.ensure_schema(path)
    async with aiosqlite.connect(path) as db:
        await db.execute(
            "UPDATE npc_empires SET last_tick=?,next_action_at=?,members=12,strength=210,treasury=40000",
            (NOW, NOW + 100 * ne.TICK_SECONDS),
        )
        await db.commit()


async def row(path, sql, args=()):
    async with aiosqlite.connect(path) as db:
        db.row_factory = sqlite3.Row
        value = await (await db.execute(sql, args)).fetchone()
        return dict(value) if value else None


def empire(state, leader_id):
    return next(item for item in state['empires'] if item['leader_id'] == leader_id)


def holding(state, leader_id, key):
    return next(item for item in empire(state, leader_id)['holdings']
                if item['kind'] == 'building' and item['holding_id'] == key)


def exterior_signature(owner, item):
    return (owner, item['holding_id'], item['operation_type'], item['operation_name'],
            item['operation_icon'], item['area'], item['income'], item['acquired_at'],
            item['closed_until'], item['building_status'])


def interior_signature(owner, item):
    # Mirrors the persisted fields consumed by getInteriorState/aptSig.
    return (owner, 'business', item['operation_type'], item['operation_name'],
            item['operation_icon'], item['acquired_at'], item['closed_until'],
            item['building_status'])


async def run():
    root = Path(__file__).resolve().parent
    world = (root / 'world.html').read_text(encoding='utf-8')
    three = (root / 'three_preview.js').read_text(encoding='utf-8')
    bot = (root / 'mafiozi_bot.py').read_text(encoding='utf-8')
    assert "operationType:String(holding.operation_type||'')" in world
    assert "closedUntil:+holding.closed_until||0" in world
    assert "operationType:String(apartmentInfo.operation_type||'')" in world
    assert "closedUntil:+apartmentInfo.closed_until||0" in world
    assert "operationType:interiorData.apartment.operationType||''" in three
    assert "closedUntil:interiorData.apartment.closedUntil||0" in three
    assert "src.operationType||''" in three and "property.operationType||'headquarters'" in three
    owned_api = bot.split("async def get_apartments_owned", 1)[1].split(
        "async def get_player_building_properties", 1
    )[0]
    assert "SELECT holding_id,closed_until FROM npc_empire_building_closures" in owned_api
    assert "closures =" in owned_api
    assert "captured=phase==='followup-capture'" in world
    assert "operation=captured?'print_shop':'beer_bar'" in world

    # Compile the production reconnect function without importing the bot
    # process (which intentionally has startup side effects).
    owned_node = next(
        node for node in ast.parse(bot).body
        if isinstance(node, ast.AsyncFunctionDef) and node.name == 'get_apartments_owned'
    )

    handle, path = tempfile.mkstemp(prefix='npc_business_reload_', suffix='.db')
    os.close(handle)
    try:
        await make_db(path)
        npc_key, player_key = list(ne.BUILDING_AREAS)[:2]
        npc_area, player_area = ne.BUILDING_AREAS[npc_key], ne.BUILDING_AREAS[player_key]
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "INSERT INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                "VALUES('building',?,?,?,?,?,?,?)",
                (npc_key, 'leila', ne.building_operation_income('pawnshop', npc_area),
                 66, NOW - 500, 'pawnshop', npc_area),
            )
            await db.execute(
                "INSERT INTO apartments_owned"
                "(telegram_id,apt_key,price,bought_at,property_kind,operation_type,area,income_per_minute,last_income_at) "
                "VALUES(?,?,?,?, 'business',?,?,?,?)",
                (PLAYER, player_key, 12000, NOW - 400, 'beer_bar', player_area,
                 ne.building_operation_income('beer_bar', player_area), NOW - 400),
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations"
                "(leader_id,telegram_id,score,pact,last_action_at) VALUES('marco',?,-100,'war',?)",
                (PLAYER, NOW),
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars"
                "(leader_id,telegram_id,next_attack_at,attacks,last_business_id,last_attack_at) "
                "VALUES('marco',?,?,0,'',0)", (PLAYER, NOW + 20),
            )
            await db.commit()

        initial = await ne.state_for(path, PLAYER, NOW)
        initial_holding = holding(initial, 'leila', npc_key)
        initial_exterior = exterior_signature('leila', initial_holding)
        initial_interior = interior_signature('npc:leila', initial_holding)
        initial_guards = initial_holding['guard_count']
        assert 1 <= initial_guards <= 3

        # Sabotage is committed in one transaction. A new module instance and
        # fresh SQLite connection must reconstruct the same CLOSED skin,
        # operation, economy, relation and deterministic garrison.
        sabotaged = await ne.npc_building_action(
            path, PLAYER, 'leila', npc_key, 'sabotage', now=NOW + 1)
        assert sabotaged['ok'] and sabotaged['closed_until'] == NOW + 301
        ne_reloaded = importlib.reload(ne)
        after_reload = await ne_reloaded.state_for(path, PLAYER, NOW + 2)
        closed_holding = holding(after_reload, 'leila', npc_key)
        assert closed_holding['operation_type'] == 'pawnshop'
        assert closed_holding['area'] == npc_area
        assert closed_holding['income'] == ne_reloaded.building_operation_income('pawnshop', npc_area)
        assert closed_holding['building_status'] == 'closed' and closed_holding['closed_s'] == 299
        assert closed_holding['guard_count'] == initial_guards
        assert empire(after_reload, 'leila')['relation'] == sabotaged['relation']
        assert exterior_signature('leila', closed_holding) != initial_exterior
        assert interior_signature('npc:leila', closed_holding) != initial_interior
        assert exterior_signature('leila', closed_holding)[2:8] == initial_exterior[2:8]
        assert interior_signature('npc:leila', closed_holding)[2:6] == initial_interior[2:6]

        # Reconnecting before a due raid must preserve the selected target and
        # exact route. Repeating the same timestamp is idempotent.
        before_raid = await ne_reloaded.state_for(path, PLAYER, NOW + 19)
        route = empire(before_raid, 'marco')['activity']
        assert route['kind'] == 'player_business_raid' and route['target_id'] == player_key
        assert (route['target_r'], route['target_c']) == ne_reloaded._hq_coords(player_key)
        first = await ne_reloaded.state_for(path, PLAYER, NOW + 20)
        assert [event['kind'] for event in first['player_war_events']] == ['player_business_bombed']
        duplicate = await ne_reloaded.state_for(path, PLAYER, NOW + 20)
        assert duplicate['player_war_events'] == []
        war = await row(path,
            "SELECT attacks,last_business_id,last_attack_at,next_attack_at FROM npc_empire_player_wars "
            "WHERE leader_id='marco' AND telegram_id=?", (PLAYER,))
        assert war['attacks'] == 1 and war['last_business_id'] == f'building:{player_key}'
        assert war['last_attack_at'] == NOW + 20
        player_closed = await row(path,
            "SELECT leader_id,closed_until FROM npc_empire_building_closures WHERE holding_id=?",
            (player_key,))
        assert player_closed == {'leader_id': 'marco',
                                 'closed_until': NOW + 20 + ne_reloaded.PLAYER_WAR_BUSINESS_BLOCK_SECONDS}
        async def no_schema_side_effect():
            return None

        owned_namespace = {
            'aiosqlite': aiosqlite,
            'DB_PATH': path,
            'time': time,
            'ensure_apartment_tables': no_schema_side_effect,
            'apartment_empire_building_key': lambda key: key,
            'apartment_operation_payload': lambda operation, area: {
                'operation_type': operation,
                'operation_name': operation,
            },
            'PLAYER_BUILDING_INCOME_CATCHUP_MINUTES': 24 * 60,
        }
        exec(compile(ast.Module(body=[owned_node], type_ignores=[]),
                     str(root / 'mafiozi_bot.py'), 'exec'), owned_namespace)
        original_time = owned_namespace['time'].time
        owned_namespace['time'].time = lambda: NOW + 21
        try:
            reconnected_apartments = await owned_namespace['get_apartments_owned'](PLAYER)
        finally:
            owned_namespace['time'].time = original_time
        assert reconnected_apartments[player_key]['closed_until'] == player_closed['closed_until']
        assert reconnected_apartments[player_key]['building_status'] == 'closed'
        assert reconnected_apartments[player_key]['income_ready'] == 0
        assert (await row(path,
            "SELECT score,pact FROM npc_empire_relations WHERE leader_id='marco' AND telegram_id=?",
            (PLAYER,))) == {'score': -100, 'pact': 'war'}

        # A second process sees the pending capture, resolves it once, then a
        # third process reconstructs the new owner, rebrand, income and guards.
        ne_reloaded = importlib.reload(ne_reloaded)
        reconnect = await ne_reloaded.state_for(path, PLAYER, NOW + 21)
        pressure = empire(reconnect, 'marco')['war_pressure']
        assert pressure['attacks'] == 1 and pressure['last_business_id'] == f'building:{player_key}'
        assert empire(reconnect, 'marco')['activity']['phase'] == 'capture'
        followup = NOW + 20 + ne_reloaded.PLAYER_WAR_CAPTURE_FOLLOWUP_SECONDS
        takeover = await ne_reloaded.state_for(path, PLAYER, followup)
        capture_event = next(event for event in takeover['player_war_events']
                             if event['kind'] == 'player_business_captured')
        assert capture_event['operation_type'] in ne_reloaded.BUILDING_OPERATIONS
        assert capture_event['operation_type'] != 'beer_bar'
        assert await row(path,
            "SELECT 1 present FROM apartments_owned WHERE telegram_id=? AND apt_key=?",
            (PLAYER, player_key)) is None
        assert await row(path,
            "SELECT 1 present FROM npc_empire_building_closures WHERE holding_id=?",
            (player_key,)) is None

        ne_reloaded = importlib.reload(ne_reloaded)
        final = await ne_reloaded.state_for(path, PLAYER, followup + 1)
        captured = holding(final, 'marco', player_key)
        assert captured['operation_type'] == capture_event['operation_type']
        assert captured['area'] == player_area
        assert captured['income'] == ne_reloaded.building_operation_income(
            captured['operation_type'], player_area)
        assert captured['building_status'] == 'open' and captured['closed_until'] == 0
        assert 1 <= captured['guard_count'] <= 3
        assert captured['guard_count'] == ne_reloaded.holding_guard_count(
            'marco', 'building', player_key, captured['acquired_at'])
        assert empire(final, 'marco')['relation'] == -100
        assert empire(final, 'marco')['pact'] == 'war'

        # The captured operation contributes its advertised per-minute rate to
        # family treasury exactly once per five-minute tick. Replaying the same
        # timestamp after reconnect is a no-op.
        economy_start = followup + 2
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET status='ruined',comeback_at=? WHERE leader_id<>'marco'",
                (economy_start + 100000,),
            )
            await db.execute(
                "UPDATE npc_empires SET treasury=50000,members=20,last_tick=?,next_action_at=? "
                "WHERE leader_id='marco'", (economy_start, economy_start + 100000),
            )
            await db.commit()
        income = captured['income']
        await ne_reloaded.advance(path, economy_start + ne_reloaded.TICK_SECONDS)
        treasury_after_open = (await row(
            path, "SELECT treasury FROM npc_empires WHERE leader_id='marco'"))['treasury']
        open_tick_delta = treasury_after_open - 50000
        assert open_tick_delta >= income * 5
        ne_reloaded = importlib.reload(ne_reloaded)
        await ne_reloaded.advance(path, economy_start + ne_reloaded.TICK_SECONDS)
        assert (await row(path,
            "SELECT treasury FROM npc_empires WHERE leader_id='marco'"))['treasury'] == treasury_after_open

        # CLOSED suppresses the whole operation interval. Expiry/reconnect may
        # not back-pay it; only the first complete interval after reopening is
        # eligible for the new operation's income.
        closed_at = economy_start + ne_reloaded.TICK_SECONDS + 1
        sabotaged_capture = await ne_reloaded.npc_building_action(
            path, PLAYER, 'marco', player_key, 'sabotage', now=closed_at)
        assert sabotaged_capture['ok'] and sabotaged_capture['closed_until'] == closed_at + 300
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET last_tick=?,next_action_at=? WHERE leader_id='marco'",
                (closed_at, closed_at + 100000),
            )
            await db.commit()
        treasury_before_closed = (await row(
            path, "SELECT treasury FROM npc_empires WHERE leader_id='marco'"))['treasury']
        await ne_reloaded.advance(path, closed_at + ne_reloaded.TICK_SECONDS)
        treasury_after_closed = (await row(
            path, "SELECT treasury FROM npc_empires WHERE leader_id='marco'"))['treasury']
        closed_tick_delta = treasury_after_closed - treasury_before_closed
        assert open_tick_delta - closed_tick_delta == income * 5
        ne_reloaded = importlib.reload(ne_reloaded)
        await ne_reloaded.advance(path, closed_at + ne_reloaded.TICK_SECONDS)
        assert (await row(path,
            "SELECT treasury FROM npc_empires WHERE leader_id='marco'"))['treasury'] == treasury_after_closed
        await ne_reloaded.advance(path, closed_at + 2 * ne_reloaded.TICK_SECONDS)
        treasury_after_reopen = (await row(
            path, "SELECT treasury FROM npc_empires WHERE leader_id='marco'"))['treasury']
        expected_after_reopen = treasury_after_closed + open_tick_delta
        assert treasury_after_reopen == expected_after_reopen, (
            treasury_after_reopen, expected_after_reopen, treasury_after_closed,
            closed_tick_delta, income, await row(path,
                "SELECT income,leader_id,operation_type FROM npc_empire_holdings "
                "WHERE kind='building' AND holding_id=?", (player_key,)),
        )

        # Both render signatures necessarily change after takeover: owner and
        # operation are inputs to the cached exterior skin and entered-room
        # aptSig. This guards against a server-correct but visually stale reload.
        before_visual = ('player:404', player_key, 'beer_bar', player_area,
                         ne_reloaded.building_operation_income('beer_bar', player_area))
        after_exterior = exterior_signature('marco', captured)
        after_interior = interior_signature('npc:marco', captured)
        assert before_visual[0] != after_exterior[0]
        assert before_visual[2] != after_exterior[2]
        assert before_visual[0] != after_interior[0]
        assert before_visual[2] != after_interior[2]
        print('npc business reload: ownership, skins, CLOSED, war, raid, takeover, guards and treasury OK')
    finally:
        try:
            os.unlink(path)
        except PermissionError:
            pass


if __name__ == '__main__':
    asyncio.run(run())
