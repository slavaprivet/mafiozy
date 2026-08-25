"""Focused durability, boundary and concurrency contract for NPC-building C4."""

import asyncio
import importlib
import os
import sqlite3
import tempfile

import aiosqlite

import npc_empire as ne
import mafiozi_bot as bot


NOW = 2_000_000_000


async def _make_db():
    handle, path = tempfile.mkstemp(prefix="npc_c4_fuse_", suffix=".sqlite3")
    os.close(handle)
    async with aiosqlite.connect(path) as db:
        await db.executescript("""
        CREATE TABLE characters(
            telegram_id INTEGER PRIMARY KEY,
            cash INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE business_property_owners(
            biz_id TEXT PRIMARY KEY,owner_uid TEXT,owner_name TEXT,
            acquired_at INTEGER,protected_until INTEGER
        );
        CREATE TABLE player_businesses(
            telegram_id INTEGER,biz_id TEXT PRIMARY KEY,bought_at INTEGER,
            last_collect INTEGER,status TEXT,blocked_until INTEGER,
            last_event_at INTEGER,level INTEGER,guards INTEGER,pending_notice TEXT
        );
        CREATE TABLE apartments_owned(
            telegram_id INTEGER,apt_key TEXT,price INTEGER,bought_at INTEGER,
            property_kind TEXT,operation_type TEXT,area INTEGER,
            income_per_minute INTEGER,last_income_at INTEGER,
            PRIMARY KEY(telegram_id,apt_key)
        );
        CREATE TABLE inventory(
            id INTEGER PRIMARY KEY AUTOINCREMENT,telegram_id INTEGER,
            item_id TEXT,quantity INTEGER DEFAULT 1
        );
        INSERT INTO characters VALUES(101,1000000),(202,1000000);
        """)
        await db.commit()
    await ne.ensure_schema(path)
    async with aiosqlite.connect(path) as db:
        await db.execute(
            "UPDATE npc_empires SET last_tick=?,next_action_at=?",
            (NOW, NOW + ne.TICK_SECONDS),
        )
        await db.commit()
    return path


async def _seed(path, holding_id, *, leader_id="leila", uid=101,
                c4=0, relation=20, pact="war"):
    area = ne.BUILDING_AREAS[holding_id]
    async with aiosqlite.connect(path) as db:
        db.row_factory = aiosqlite.Row
        await db.execute(
            "INSERT OR REPLACE INTO npc_empire_holdings"
            "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
            "VALUES('building',?,?,?,?,?,?,?)",
            (holding_id, leader_id,
             ne.building_operation_income("beer_bar", area),
             60, NOW - 1000, "beer_bar", area))
        await db.execute(
            "INSERT OR REPLACE INTO npc_empire_relations"
            "(leader_id,telegram_id,score,pact,last_action_at) VALUES(?,?,?,?,0)",
            (leader_id, uid, relation, pact))
        await db.execute(
            "DELETE FROM inventory WHERE telegram_id=? AND item_id='c4'", (uid,))
        if c4:
            await db.execute(
                "INSERT INTO inventory(telegram_id,item_id,quantity) VALUES(?,'c4',?)",
                (uid, c4))
        await ne._reconcile_npc_guards(db, leader_id, NOW)
        await db.commit()


async def _active_tribute(path, uid=101, leader_id="leila"):
    async with aiosqlite.connect(path) as db:
        generation = int((await (await db.execute(
            "SELECT comebacks FROM npc_empires WHERE leader_id=?", (leader_id,)
        )).fetchone())[0] or 0)
        await db.execute(
            "INSERT INTO npc_empire_player_tribute_agreements"
            "(leader_id,leader_generation,telegram_id,agreement_id,offer_request_key,"
            "accept_request_key,term_amount,term_seconds,status,relation_at_offer,"
            "pact_at_offer,created_at,offer_expires_at,accepted_at,active_until) "
            "VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (leader_id, generation, uid, f"tribute-{uid}", f"offer-{uid}",
             f"accept-{uid}", 150, 3600, "active", -50, "war",
             NOW - 10, NOW + 100, NOW - 5, NOW + 3600))
        await db.commit()


async def _row(path, sql, params=()):
    async with aiosqlite.connect(path) as db:
        db.row_factory = sqlite3.Row
        row = await (await db.execute(sql, params)).fetchone()
        return dict(row) if row else None


async def _scalar(path, sql, params=()):
    row = await _row(path, sql, params)
    return next(iter(row.values())) if row else None


def _empire(state, leader_id="leila"):
    return next(item for item in state["empires"] if item["leader_id"] == leader_id)


def _holding(state, holding_id, leader_id="leila"):
    return next(item for item in _empire(state, leader_id)["holdings"]
                if item.get("holding_id") == holding_id)


async def _arm(path, holding_id, key, *, uid=101, leader_id="leila", now=NOW):
    return await ne.npc_building_action(
        path, uid, leader_id, holding_id, "sabotage", now=now,
        request_key=key)


async def _effects(path, uid=101, leader_id="leila"):
    return {
        "c4": await _scalar(
            path, "SELECT COALESCE(MAX(quantity),0) q FROM inventory "
                  "WHERE telegram_id=? AND item_id='c4'", (uid,)),
        "relation": await _row(
            path, "SELECT score,pact FROM npc_empire_relations "
                  "WHERE telegram_id=? AND leader_id=?", (uid, leader_id)),
        "receipts": await _scalar(
            path, "SELECT COUNT(*) n FROM npc_empire_building_sabotage_receipts "
                  "WHERE telegram_id=?", (uid,)),
        "events": await _scalar(
            path, "SELECT COUNT(*) n FROM npc_empire_events "
                  "WHERE leader_id=? AND kind='building_sabotaged' AND target_id=?",
            (leader_id, str(uid))),
        "breaches": await _scalar(
            path, "SELECT COUNT(*) n FROM npc_empire_events "
                  "WHERE leader_id=? AND kind='tribute_breached' AND target_id=?",
            (leader_id, str(uid))),
    }


async def _case_boundaries_replay_and_expiry(passed):
    path = await _make_db()
    try:
        holding_id = list(ne.BUILDING_AREAS)[0]
        await _seed(path, holding_id, c4=3)
        await _active_tribute(path)
        before = await ne.state_for(path, 101, now=NOW)
        before_income = _empire(before)["income_per_tick"]
        before_guards = _holding(before, holding_id)["guard_count"]

        armed = await _arm(path, holding_id, "c4-boundary-0001")
        assert armed["ok"] and armed["armed"] and not armed["duplicate"]
        assert armed["detonate_at"] == NOW + 3
        assert armed["closed_until"] == NOW + 303
        assert armed["c4_left"] == 2 and armed["tribute_breached"]
        closure = await _row(
            path, "SELECT saboteur_uid,created_at,closed_until FROM "
                  "npc_empire_building_closures WHERE holding_id=?", (holding_id,))
        assert closure == {"saboteur_uid": 101, "created_at": NOW + 3,
                           "closed_until": NOW + 303}
        assert (await _effects(path))["events"] == 1
        passed.append("arm-atomic")

        at_zero = _holding(await ne.state_for(path, 101, now=NOW), holding_id)
        at_two = _holding(await ne.state_for(path, 101, now=NOW + 2), holding_id)
        assert at_zero["building_status"] == "armed" and at_zero["fuse_s"] == 3
        assert at_two["building_status"] == "armed" and at_two["fuse_s"] == 1
        assert at_two["closed_s"] == 300 and at_two["guard_count"] == before_guards
        assert _empire(await ne.state_for(path, 101, now=NOW + 2))["income_per_tick"] == before_income
        passed.append("fuse-keeps-income-guards")

        at_three = _holding(await ne.state_for(path, 101, now=NOW + 3), holding_id)
        at_302 = _holding(await ne.state_for(path, 101, now=NOW + 302), holding_id)
        assert at_three["building_status"] == "closed" and at_three["closed_s"] == 300
        assert at_302["building_status"] == "closed" and at_302["closed_s"] == 1
        assert _empire(await ne.state_for(path, 101, now=NOW + 3))["income_per_tick"] < before_income
        passed.append("exact-detonation-boundary")

        replay_before = await _arm(path, holding_id, "c4-boundary-0001", now=NOW + 1)
        replay_after = await _arm(path, holding_id, "c4-boundary-0001", now=NOW + 4)
        assert replay_before["duplicate"] and replay_after["duplicate"]
        for field in ("request_key", "detonate_at", "closed_until", "c4_left",
                      "relation", "relation_delta", "pact", "tribute_breached"):
            assert replay_before[field] == armed[field] == replay_after[field]
        effects = await _effects(path)
        assert effects["c4"] == 2 and effects["receipts"] == 1
        assert effects["events"] == 1 and effects["breaches"] == 1
        passed.append("sequential-replay-once")

        conflict = await _arm(path, holding_id, "c4-other-key-0001", now=NOW + 1)
        assert not conflict["ok"] and conflict["error"] == "armed"
        purchase = await ne.npc_building_action(
            path, 101, "leila", holding_id, "purchase", now=NOW + 1, roll=1)
        assert not purchase["ok"] and purchase["error"] == "armed"
        assert (await _effects(path))["c4"] == 2
        passed.append("different-key-blocked")

        reopened = _holding(await ne.state_for(path, 101, now=NOW + 303), holding_id)
        assert reopened["building_status"] == "open" and reopened["closed_until"] == 0
        expired_replay = await _arm(
            path, holding_id, "c4-boundary-0001", now=NOW + 303)
        assert expired_replay["duplicate"] and expired_replay["building_status"] == "open"
        second = await _arm(path, holding_id, "c4-after-expiry-0002", now=NOW + 303)
        assert second["ok"] and not second["duplicate"] and second["c4_left"] == 1
        passed.append("expiry-new-operation")
    finally:
        os.unlink(path)


async def _case_concurrency_and_isolation(passed):
    path = await _make_db()
    try:
        first, second = list(ne.BUILDING_AREAS)[:2]
        await _seed(path, first, uid=101, c4=5)
        same = await asyncio.gather(*[
            _arm(path, first, "c4-concurrent-same-0001") for _ in range(10)
        ])
        assert sum(not item["duplicate"] for item in same if item["ok"]) == 1
        assert sum(item["duplicate"] for item in same if item["ok"]) == 9
        assert (await _effects(path))["c4"] == 4
        assert (await _effects(path))["events"] == 1
        passed.append("concurrent-same-key-once")

        await _seed(path, second, uid=202, c4=2)
        player_loser = await _arm(
            path, first, "c4-player202-same-building", uid=202, now=NOW + 1)
        assert not player_loser["ok"] and player_loser["error"] == "armed"
        assert (await _effects(path, uid=202))["c4"] == 2
        passed.append("player-isolated-loser-untouched")

        independent = await _arm(
            path, second, "c4-player202-independent", uid=202, now=NOW + 1)
        assert independent["ok"] and independent["c4_left"] == 1
        assert await _scalar(
            path, "SELECT COUNT(*) n FROM npc_empire_building_closures") == 2
        passed.append("independent-player-building")

        request_conflict = await _arm(
            path, second, "c4-concurrent-same-0001", uid=101, now=NOW + 1)
        assert not request_conflict["ok"] and request_conflict["error"] == "request conflict"
        assert (await _effects(path))["c4"] == 4
        passed.append("request-key-target-isolation")
    finally:
        os.unlink(path)


async def _case_rollback_reload_and_legacy(passed):
    path = await _make_db()
    try:
        first, second = list(ne.BUILDING_AREAS)[:2]
        await _seed(path, first, c4=3, relation=15)
        before = await _effects(path)
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "CREATE TRIGGER abort_c4_receipt BEFORE INSERT ON "
                "npc_empire_building_sabotage_receipts BEGIN "
                "SELECT RAISE(ABORT,'forced receipt rollback'); END")
            await db.commit()
        try:
            await _arm(path, first, "c4-rollback-0001")
            raise AssertionError("forced rollback did not abort")
        except aiosqlite.IntegrityError:
            pass
        assert await _effects(path) == before
        assert await _scalar(
            path, "SELECT COUNT(*) n FROM npc_empire_building_closures") == 0
        async with aiosqlite.connect(path) as db:
            await db.execute("DROP TRIGGER abort_c4_receipt")
            await db.commit()
        retry = await _arm(path, first, "c4-rollback-0001")
        assert retry["ok"] and retry["c4_left"] == 2
        passed.append("transaction-rollback-retry")

        reloaded = importlib.reload(ne)
        armed = _holding(await reloaded.state_for(path, 101, now=NOW + 2), first)
        closed = _holding(await reloaded.state_for(path, 101, now=NOW + 3), first)
        replay = await reloaded.npc_building_action(
            path, 101, "leila", first, "sabotage", now=NOW + 3,
            request_key="c4-rollback-0001")
        assert armed["building_status"] == "armed"
        assert closed["building_status"] == "closed"
        assert replay["duplicate"] and replay["detonate_at"] == NOW + 3
        passed.append("module-db-reload-stable")

        await _seed(path, second, c4=1)
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_building_closures"
                "(holding_id,leader_id,saboteur_uid,closed_until,created_at) "
                "VALUES(?,?,?,?,?)", (second, "leila", 202, NOW + 300, NOW - 1))
            await db.commit()
        legacy = _holding(await reloaded.state_for(path, 101, now=NOW), second)
        denied = await reloaded.npc_building_action(
            path, 101, "leila", second, "sabotage", now=NOW,
            request_key="c4-legacy-denied-0001")
        assert legacy["building_status"] == "closed" and legacy["fuse_s"] == 0
        assert not denied["ok"] and denied["error"] == "closed"
        assert (await _effects(path))["c4"] == 1
        passed.append("legacy-immediate-closure")
    finally:
        os.unlink(path)


async def _case_validation_and_retention(passed):
    path = await _make_db()
    try:
        holding_id = list(ne.BUILDING_AREAS)[0]
        await _seed(path, holding_id, c4=70)
        bad = await ne.npc_building_action(
            path, 101, "leila", holding_id, "sabotage", now=NOW)
        assert not bad["ok"] and bad["error"] == "bad request key"
        async with aiosqlite.connect(path) as db:
            await db.execute("DELETE FROM inventory WHERE telegram_id=101 AND item_id='c4'")
            await db.commit()
        no_c4 = await _arm(path, holding_id, "c4-no-stock-0001")
        assert not no_c4["ok"] and no_c4["error"] == "no c4"
        assert await _scalar(
            path, "SELECT COUNT(*) n FROM npc_empire_building_sabotage_receipts") == 0
        passed.append("validation-no-write")

        async with aiosqlite.connect(path) as db:
            await db.execute(
                "INSERT INTO inventory(telegram_id,item_id,quantity) VALUES(101,'c4',70)")
            await db.commit()
        tick = NOW
        for index in range(65):
            result = await _arm(
                path, holding_id, f"c4-retained-{index:04d}", now=tick)
            assert result["ok"] and not result["duplicate"]
            tick += 304
        assert await _scalar(
            path, "SELECT COUNT(*) n FROM npc_empire_building_sabotage_receipts "
                  "WHERE telegram_id=101") == 64
        assert await _scalar(
            path, "SELECT COUNT(*) n FROM npc_empire_building_sabotage_receipts "
                  "WHERE telegram_id=202") == 0
        passed.append("bounded-receipt-retention")
    finally:
        os.unlink(path)


async def run():
    passed = []
    assert bot._requires_actor_binding('/npc-empires/101/building/action')
    assert bot._requires_actor_binding('/npc-empires/101/assault/hit')
    assert not bot._requires_actor_binding('/npc-empires/101/diplomacy')
    passed.append("production-route-actor-bound")
    await _case_boundaries_replay_and_expiry(passed)
    await _case_concurrency_and_isolation(passed)
    await _case_rollback_reload_and_legacy(passed)
    await _case_validation_and_retention(passed)
    assert len(passed) == 16, passed
    print("npc building C4 durable fuse: 16/16 gates OK — " + ", ".join(passed))


if __name__ == "__main__":
    asyncio.run(run())
