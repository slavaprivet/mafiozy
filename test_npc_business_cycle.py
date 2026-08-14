"""Deterministic full-cycle regression for NPC converted businesses."""

import asyncio
import os
import sqlite3
import tempfile
from pathlib import Path

import aiosqlite

import npc_empire as ne


NOW = 2_100_000_000


async def scalar(path, sql, args=()):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql, args)).fetchone()
        return row[0] if row else None


async def make_db(path):
    async with aiosqlite.connect(path) as db:
        await db.executescript("""
        CREATE TABLE characters(telegram_id INTEGER PRIMARY KEY,cash INTEGER DEFAULT 0);
        CREATE TABLE business_property_owners(biz_id TEXT PRIMARY KEY,owner_uid TEXT,owner_name TEXT,acquired_at INTEGER,protected_until INTEGER);
        CREATE TABLE player_businesses(telegram_id INTEGER,biz_id TEXT PRIMARY KEY,bought_at INTEGER,last_collect INTEGER,status TEXT,blocked_until INTEGER,last_event_at INTEGER,level INTEGER,guards INTEGER,pending_notice TEXT);
        CREATE TABLE apartments_owned(telegram_id INTEGER,apt_key TEXT,price INTEGER,bought_at INTEGER,property_kind TEXT,operation_type TEXT,area INTEGER,income_per_minute INTEGER,last_income_at INTEGER,PRIMARY KEY(telegram_id,apt_key));
        INSERT INTO characters VALUES(101,50000);
        """)
        await db.commit()
    await ne.ensure_schema(path)
    async with aiosqlite.connect(path) as db:
        await db.execute(
            "UPDATE npc_empires SET last_tick=?,next_action_at=?,members=20,strength=280,treasury=50000",
            (NOW, NOW + ne.TICK_SECONDS),
        )
        await db.commit()


async def run():
    assert len(ne.BUILDING_OPERATIONS) == 8
    assert ne._player_business_raid_objective(
        1, 'building:0,3', 'building:0,4', '0,4') == 'first-close'
    assert ne._player_business_raid_objective(
        1, 'building:0,4', 'building:0,4', '0,4') == 'followup-capture'
    generated = {ne.choose_building_operation(ne.PROFILE_BY_ID['leila'], '0,3', nonce)
                 for nonce in range(256)}
    assert generated == set(ne.BUILDING_OPERATIONS)

    world = (Path(__file__).parent / 'world.html').read_text(encoding='utf-8')
    three = (Path(__file__).parent / 'three_preview.js').read_text(encoding='utf-8')
    bot_source = (Path(__file__).parent / 'mafiozi_bot.py').read_text(encoding='utf-8')
    for operation in ne.BUILDING_OPERATIONS:
        assert operation in world and operation in three
    assert 'closedUntil:+holding.closed_until||0' in world
    assert "loadApartmentState?.()" in world
    assert "if(property&&!property.owned)return null" in world
    assert "if (!owned&&foreignProperty)" in world
    assert "_deferBusinessActionCardForModeChoice?.();" in world
    assert "setTimeout(()=>_resumeDeferredBusinessActionCard?.(),0)" in world
    assert "if(_modeChoiceVisible()){_deferBusinessActionCardForModeChoice();return;}" in world
    assert "_businessActionDeferredForMode={kind,poi:" in world
    assert "_businessActionCard.classList.remove('show');return false" in world
    assert "if(_businessActionSelection||_businessActionCard.classList.contains('show'))" in world
    assert "if(!_LOCAL_PREVIEW||(!_UP.has('previewplayerbusinessraid')&&!_UP.has('previewraidalert'))" in world
    assert "['approach','first-close','followup-capture']" in world
    assert "kind:'player_business_raid'" in world
    assert "target_r:targetR,target_c:targetC" in world
    assert "actionKind==='player_business_raid'" in world
    assert "dataset.previewPlayerBusinessRaidTarget" in world
    assert "dataset.previewPlayerBusinessRaid=[fixture.phase" in world
    assert "`arrived-${arrived?1:0}`" in world
    assert "purpose-v4" in three and "interiorData.apartment.operationType" in three
    assert "out[str(r[0])][\"income_ready\"] = 0 if closed_until" in bot_source
    assert "return {'ok': False, 'error': 'closed'" in bot_source

    handle, path = tempfile.mkstemp(prefix='npc_business_cycle_', suffix='.db')
    os.close(handle)
    try:
        await make_db(path)

        # Force exactly one autonomous expansion tick.  It must choose and
        # persist one authoritative operation, area and per-minute income.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET last_tick=?,next_action_at=?,members=20,"
                "strength=280,treasury=50000 WHERE leader_id='leila'",
                (NOW - ne.TICK_SECONDS, NOW - 1),
            )
            await db.commit()
        original_brain = ne._boss_brain
        ne._boss_brain = lambda *args, **kwargs: {
            'strategy': 'expand', 'confidence': 90, 'reason': 'qa',
            'adaptation': {'mode': 'balanced'},
        }
        try:
            await ne.advance(path, NOW)
        finally:
            ne._boss_brain = original_brain
        async with aiosqlite.connect(path) as db:
            db.row_factory = sqlite3.Row
            captured = await (await db.execute(
                "SELECT * FROM npc_empire_holdings WHERE leader_id='leila' AND kind='building'"
            )).fetchone()
        assert captured and captured['operation_type'] in ne.BUILDING_OPERATIONS
        assert captured['area'] == ne.BUILDING_AREAS[captured['holding_id']]
        assert captured['income'] == ne.building_operation_income(
            captured['operation_type'], captured['area'])
        snapshot = await ne.state_for(path, 101, NOW)
        visible = next(h for e in snapshot['empires'] if e['leader_id'] == 'leila'
                       for h in e['holdings'] if h['kind'] == 'building')
        assert visible['operation_name'] and visible['operation_icon']
        assert visible['income_unit'] == 'minute'

        # The player's converted business is now a real war target.  First the
        # boss closes it and physically routes to it; the follow-up captures it,
        # preserves area, rerolls the skin and transfers income atomically.
        key = next(k for k in ne.BUILDING_AREAS if k != captured['holding_id'])
        previous = 'beer_bar'
        area = ne.BUILDING_AREAS[key]
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "INSERT INTO apartments_owned VALUES(101,?,9000,?,'business',?,?,?,?)",
                (key, NOW, previous, area,
                 ne.building_operation_income(previous, area), NOW - 600),
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations"
                "(leader_id,telegram_id,score,pact,last_action_at) VALUES('marco',101,-100,'war',?)",
                (NOW,),
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars"
                "(leader_id,telegram_id,next_attack_at,attacks,last_business_id,last_attack_at) "
                "VALUES('marco',101,?,0,'',0)", (NOW + 10,),
            )
            await db.commit()

        approaching = await ne.state_for(path, 101, NOW + 1)
        marco = next(e for e in approaching['empires'] if e['leader_id'] == 'marco')
        assert marco['activity']['kind'] == 'player_business_raid'
        assert marco['activity']['target_id'] == key
        assert (marco['activity']['target_r'], marco['activity']['target_c']) == ne._hq_coords(key)

        raid_state = await ne.state_for(path, 101, NOW + 10)
        raid = raid_state['interior_raids'][0]
        assert raid['objective'] == 'first-close'
        assert raid_state['player_war_events'][0]['kind'] == 'player_business_interior_raid'
        resolved = await ne.resolve_interior_raid(
            path, 101, raid['token'], raid['apt_key'], 'captured',
            NOW + 10 + raid['hold_seconds'])
        assert resolved.get('ok'), resolved
        event = resolved['phase_events'][0]
        assert event['kind'] == 'player_business_bombed'
        assert await scalar(path,
            "SELECT closed_until FROM npc_empire_building_closures WHERE holding_id=?", (key,)) \
            == NOW + 10 + raid['hold_seconds'] + ne.PLAYER_WAR_BUSINESS_BLOCK_SECONDS
        assert await scalar(path,
            "SELECT last_income_at FROM apartments_owned WHERE telegram_id=101 AND apt_key=?", (key,)) \
            == NOW + 10 + raid['hold_seconds'] + ne.PLAYER_WAR_BUSINESS_BLOCK_SECONDS
        followup = NOW + 10 + raid['hold_seconds'] + ne.PLAYER_WAR_CAPTURE_FOLLOWUP_SECONDS
        captured_state = await ne.state_for(path, 101, followup)
        followup_raid = captured_state['interior_raids'][0]
        assert followup_raid['objective'] == 'followup-capture'
        resolved_capture = await ne.resolve_interior_raid(
            path, 101, followup_raid['token'], followup_raid['apt_key'], 'captured',
            followup + followup_raid['hold_seconds'])
        event = resolved_capture['phase_events'][0]
        assert event['kind'] == 'player_business_captured'
        assert event['operation_type'] in ne.BUILDING_OPERATIONS
        assert event['operation_type'] != previous
        assert await scalar(path,
            "SELECT COUNT(*) FROM apartments_owned WHERE telegram_id=101 AND apt_key=?", (key,)) == 0
        async with aiosqlite.connect(path) as db:
            db.row_factory = sqlite3.Row
            row = await (await db.execute(
                "SELECT * FROM npc_empire_holdings WHERE kind='building' AND holding_id=?", (key,)
            )).fetchone()
        assert row['leader_id'] == 'marco' and row['operation_type'] == event['operation_type']
        assert row['income'] == ne.building_operation_income(row['operation_type'], row['area'])
        assert await scalar(path,
            "SELECT COUNT(*) FROM npc_empire_building_closures WHERE holding_id=?", (key,)) == 0
        print('npc business cycle: capture, 8 skins, income, raid, closure and takeover OK')
    finally:
        try:
            os.unlink(path)
        except PermissionError:
            pass


if __name__ == '__main__':
    asyncio.run(run())
