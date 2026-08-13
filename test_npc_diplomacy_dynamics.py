"""Deterministic integration tests for autonomous boss-to-boss diplomacy."""

import asyncio
import os
import sqlite3
import tempfile

import aiosqlite

import npc_empire as ne


async def _base_db(path: str, now: int) -> None:
    async with aiosqlite.connect(path) as db:
        await db.executescript("""
            CREATE TABLE characters(
                telegram_id INTEGER PRIMARY KEY, cash INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE business_property_owners(
                biz_id TEXT PRIMARY KEY,owner_uid INTEGER,owner_name TEXT,
                acquired_at INTEGER,protected_until INTEGER);
            CREATE TABLE player_businesses(
                telegram_id INTEGER,biz_id TEXT PRIMARY KEY,bought_at INTEGER,
                last_collect INTEGER,status TEXT,blocked_until INTEGER,
                last_event_at INTEGER,level INTEGER,guards INTEGER,
                pending_notice TEXT);
        """)
        await db.commit()
    await ne.ensure_schema(path)
    async with aiosqlite.connect(path) as db:
        await db.execute("UPDATE npc_empires SET last_tick=?", (now,))
        await db.commit()


async def _load_diplomacy(db) -> dict:
    rows = await (await db.execute(
        "SELECT leader_a,leader_b,score,pact,tension,last_event_at "
        "FROM npc_empire_diplomacy"
    )).fetchall()
    return {
        (str(row['leader_a']), str(row['leader_b'])): {
            'score': int(row['score']), 'pact': str(row['pact']),
            'tension': int(row['tension']),
            'last_event_at': int(row['last_event_at']),
        }
        for row in rows
    }


async def run() -> None:
    handle, path = tempfile.mkstemp(prefix="npc_diplomacy_", suffix=".db")
    os.close(handle)
    now = 2_000_200_000
    try:
        await _base_db(path, now)
        target = "4,4"
        target_district = ne._holding_district("building", target)
        claim_keys = [
            key for key in ne.GENERIC_BUILDINGS
            if key != target and ne._holding_district("building", key) == target_district
        ][:2]
        assert len(claim_keys) == 2

        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            await db.execute("BEGIN IMMEDIATE")
            # Leila already hates Rustam, so Viktor earns her respect by taking
            # Rustam's building. Roman controls two nearby properties and sees
            # the same capture as an incursion into his sphere of influence.
            a, b = ne._diplomacy_pair("leila", "rustam")
            await db.execute(
                "UPDATE npc_empire_diplomacy SET score=-70,pact='war',tension=70 "
                "WHERE leader_a=? AND leader_b=?", (a, b),
            )
            for left, right in (("leila", "viktor"), ("roman", "viktor")):
                a, b = ne._diplomacy_pair(left, right)
                await db.execute(
                    "UPDATE npc_empire_diplomacy SET score=0,pact='none',tension=0 "
                    "WHERE leader_a=? AND leader_b=?", (a, b),
                )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                "VALUES('building',?,'rustam',100,10,?,'beer_bar',16)",
                (target, now),
            )
            for key in claim_keys:
                await db.execute(
                    "INSERT OR REPLACE INTO npc_empire_holdings"
                    "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                    "VALUES('building',?,'roman',100,10,?,'pawnshop',16)",
                    (key, now),
                )
            state = await _load_diplomacy(db)
            events: list[dict] = []
            await ne._react_to_npc_attack(
                db, state, "viktor", "rustam", now, events,
                captured_kind="building", captured_id=target,
            )
            await db.commit()

        with sqlite3.connect(path) as db:
            def relation(left: str, right: str):
                a, b = ne._diplomacy_pair(left, right)
                return db.execute(
                    "SELECT score,pact,tension FROM npc_empire_diplomacy "
                    "WHERE leader_a=? AND leader_b=?", (a, b),
                ).fetchone()

            assert relation("viktor", "rustam")[0:2] == (-100, "war")
            common_enemy = relation("leila", "viktor")
            territorial = relation("roman", "viktor")
            assert 8 <= common_enemy[0] <= 15 and common_enemy[2] == 0
            assert -7 <= territorial[0] <= -3 and territorial[2] >= 3
        assert any(event['kind'] == 'common_enemy_respect' for event in events)
        assert any(event['kind'] == 'territorial_dispute' for event in events)
        print("diplomacy pass 1: war, common-enemy respect and territory reaction OK")

        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            await db.execute("BEGIN IMMEDIATE")
            await db.execute("UPDATE npc_empires SET status='active',strength=100,dominance_score=0")
            await db.execute(
                "UPDATE npc_empires SET strength=2000,dominance_score=100 "
                "WHERE leader_id='viktor'"
            )
            for left, right, score, pact, tension in (
                ("vera", "yana", 72, "none", 0),
                ("vera", "viktor", -100, "war", 80),
                ("yana", "viktor", 0, "none", 0),
                ("damir", "roman", 75, "alliance", 0),
                ("damir", "viktor", 0, "none", 0),
            ):
                a, b = ne._diplomacy_pair(left, right)
                await db.execute(
                    "UPDATE npc_empire_diplomacy SET score=?,pact=?,tension=? "
                    "WHERE leader_a=? AND leader_b=?", (score, pact, tension, a, b),
                )
            state = await _load_diplomacy(db)
            empire_rows = {
                str(row['leader_id']): row for row in await (await db.execute(
                    "SELECT * FROM npc_empires"
                )).fetchall()
            }
            alliance_events: list[dict] = []
            await ne._advance_npc_alliances(
                db, state, empire_rows, now + 1, alliance_events,
            )
            assert state[ne._diplomacy_pair("vera", "yana")]['pact'] == 'alliance'
            assert state[ne._diplomacy_pair("yana", "viktor")]['pact'] == 'war'
            support = ne._coalition_support_power(
                state, empire_rows, "vera", "viktor")
            assert 4 <= support <= 45

            defense_events: list[dict] = []
            await ne._react_to_npc_attack(
                db, state, "viktor", "roman", now + 2, defense_events,
            )
            assert state[ne._diplomacy_pair("damir", "viktor")]['pact'] == 'war'
            await db.commit()
        assert any(event['kind'] == 'alliance_formed' for event in alliance_events)
        assert any(event['kind'] == 'coalition_joined' for event in alliance_events)
        assert any(event['kind'] == 'ally_defended' for event in defense_events)
        print("diplomacy pass 2: alliance, ally defense and coalition support OK")

        peace_now = now + 2 * ne.NPC_DIPLOMACY_PEACE_STEP_SECONDS
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            await db.execute("BEGIN IMMEDIATE")
            old_at = now
            for left, right, score, pact, tension in (
                ("vera", "sofia", -50, "none", 30),
                ("viktor", "emil", -50, "none", 30),
                ("alisa", "yana", 40, "none", 24),
                ("rustam", "musa", -5, "truce", 5),
            ):
                a, b = ne._diplomacy_pair(left, right)
                await db.execute(
                    "UPDATE npc_empire_diplomacy SET score=?,pact=?,tension=?,last_event_at=? "
                    "WHERE leader_a=? AND leader_b=?",
                    (score, pact, tension, old_at, a, b),
                )
            state = await _load_diplomacy(db)
            peace_events: list[dict] = []
            await ne._advance_npc_peace(db, state, peace_now, peace_events)
            high_diplomacy = state[ne._diplomacy_pair("vera", "sofia")]
            low_diplomacy = state[ne._diplomacy_pair("viktor", "emil")]
            goodwill = state[ne._diplomacy_pair("alisa", "yana")]
            truce = state[ne._diplomacy_pair("rustam", "musa")]
            assert high_diplomacy['score'] > low_diplomacy['score'] > -50
            assert high_diplomacy['tension'] < 30 and low_diplomacy['tension'] < 30
            assert 0 < goodwill['score'] < 40 and goodwill['tension'] < 24
            assert truce['pact'] == 'none' and truce['score'] == 0
            await db.execute("UPDATE npc_empires SET last_tick=?", (peace_now,))
            await db.commit()
        assert any(event['kind'] == 'peace_normalized' for event in peace_events)

        api_state = await ne.state_for(path, 999, now=peace_now)
        assert all(row['pact_label'] == ne.NPC_PACT_LABELS[row['pact']]
                   and row['relation_band'] == ne.relation_band(row['score'])
                   for row in api_state['diplomacy'])
        world = open(os.path.join(os.path.dirname(__file__), "world.html"),
                     encoding="utf-8").read()
        assert 'data-ne-dynamic-diplomacy' in world
        assert "d.pact_label||d.pact||'none'" in world
        assert 'напряжение ${heat}' in world
        print("diplomacy pass 3: personality-based peace decay and dossier UI OK")
    finally:
        try:
            os.remove(path)
        except PermissionError:
            pass


if __name__ == "__main__":
    asyncio.run(run())
