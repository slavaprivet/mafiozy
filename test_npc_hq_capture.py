"""End-to-end regression for winning, converting, and owning an NPC HQ."""

import asyncio
import json
import os
import sqlite3
import tempfile

import aiosqlite

import npc_empire as ne


async def _scalar(path: str, sql: str, args=()):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql, args)).fetchone()
        return row[0] if row else None


async def run() -> None:
    fd, path = tempfile.mkstemp(prefix="npc_hq_capture_", suffix=".db")
    os.close(fd)
    now = 2_100_000_000
    try:
        async with aiosqlite.connect(path) as db:
            await db.executescript("""
                CREATE TABLE characters (
                    telegram_id INTEGER PRIMARY KEY, name TEXT DEFAULT '',
                    mafia_family TEXT DEFAULT '', cash INTEGER NOT NULL DEFAULT 0
                );
                CREATE TABLE business_property_owners (
                    biz_id TEXT PRIMARY KEY, owner_uid INTEGER, owner_name TEXT,
                    acquired_at INTEGER, protected_until INTEGER
                );
                CREATE TABLE player_businesses (
                    telegram_id INTEGER, biz_id TEXT PRIMARY KEY, bought_at INTEGER,
                    last_collect INTEGER, status TEXT, blocked_until INTEGER,
                    last_event_at INTEGER, level INTEGER, guards INTEGER,
                    pending_notice TEXT
                );
                CREATE TABLE apartments_owned (
                    telegram_id INTEGER, apt_key TEXT, price INTEGER DEFAULT 0,
                    bought_at INTEGER DEFAULT 0, safe_level INTEGER DEFAULT 0,
                    weapon_rack_level INTEGER DEFAULT 0, garage_level INTEGER DEFAULT 0,
                    cameras_level INTEGER DEFAULT 0, repair_level INTEGER DEFAULT 0,
                    stolen_bags INTEGER DEFAULT 0, property_kind TEXT DEFAULT 'hq',
                    operation_type TEXT DEFAULT '', area INTEGER DEFAULT 4,
                    income_per_minute INTEGER DEFAULT 0, last_income_at INTEGER DEFAULT 0,
                    PRIMARY KEY (telegram_id, apt_key)
                );
                INSERT INTO characters(telegram_id,name,mafia_family,cash)
                VALUES(101,'Слава','moretti',5000),
                      (202,'Другой игрок','bellini',5000);
            """)
            await db.commit()
        await ne.ensure_schema(path)

        vassal = next(item for item in ne.PROFILES if item.leader_id == "sofia")
        rollback_family = next(item for item in ne.PROFILES
                               if item.leader_id == "marco")
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET status='vassal' WHERE leader_id='sofia'"
            )
            await db.executemany(
                "INSERT OR REPLACE INTO npc_empire_relations VALUES(?,?,?,?,?)",
                [("sofia", 101, 80, "vassal", now),
                 ("sofia", 202, 0, "none", now)],
            )
            await db.commit()
        vassal_guards = await _scalar(
            path,
            "SELECT COALESCE(SUM(living),0) FROM npc_empire_guard_assignments "
            "WHERE owner_kind='npc' AND owner_id='sofia'",
        )
        vassal_events = await _scalar(
            path,
            "SELECT COUNT(*) FROM npc_empire_events WHERE leader_id='sofia'",
        )
        vassal_r, vassal_c = ne._hq_coords(vassal.hq_key)
        rejected = await asyncio.gather(
            ne.prepare_assault(path, 101, "sofia", vassal_r, vassal_c,
                               now=now + 1),
            ne.prepare_assault(path, 101, "sofia", vassal_r, vassal_c,
                               now=now + 1),
        )
        assert rejected == [
            {"ok": False, "error": "leader vassal"},
            {"ok": False, "error": "leader vassal"},
        ]
        assert await _scalar(
            path,
            "SELECT COUNT(*) FROM npc_empire_assaults "
            "WHERE leader_id='sofia'",
        ) == 0
        assert await _scalar(
            path,
            "SELECT COUNT(*) FROM npc_empire_player_wars "
            "WHERE leader_id='sofia'",
        ) == 0
        assert await _scalar(
            path,
            "SELECT score||':'||pact FROM npc_empire_relations "
            "WHERE leader_id='sofia' AND telegram_id=101",
        ) == "80:vassal"
        assert await _scalar(
            path,
            "SELECT score||':'||pact FROM npc_empire_relations "
            "WHERE leader_id='sofia' AND telegram_id=202",
        ) == "0:none"
        assert await _scalar(
            path,
            "SELECT COALESCE(SUM(living),0) FROM npc_empire_guard_assignments "
            "WHERE owner_kind='npc' AND owner_id='sofia'",
        ) == vassal_guards
        assert await _scalar(
            path,
            "SELECT COUNT(*) FROM npc_empire_events WHERE leader_id='sofia'",
        ) == vassal_events
        state = await ne.state_for(path, 101, now=now + 2)
        sofia_state = next(item for item in state["empires"]
                           if item["leader_id"] == "sofia")
        assert sofia_state["status"] == "vassal"
        assert sofia_state["pact"] == "vassal"
        assert sofia_state["war_pressure"] is None
        other_state = await ne.state_for(path, 202, now=now + 2)
        other_sofia = next(item for item in other_state["empires"]
                           if item["leader_id"] == "sofia")
        assert other_sofia["pact"] == "none"
        assert other_sofia["war_pressure"] is None

        # A final event failure must roll back the active-family token, war
        # authority, relation change and guard reconciliation together.
        rollback_guards = await _scalar(
            path,
            "SELECT COALESCE(SUM(living),0) FROM npc_empire_guard_assignments "
            "WHERE owner_kind='npc' AND owner_id='marco'",
        )
        async with aiosqlite.connect(path) as db:
            await db.execute("""
                CREATE TRIGGER reject_marco_assault_event
                BEFORE INSERT ON npc_empire_events
                WHEN NEW.leader_id='marco' AND NEW.kind='assault_started'
                BEGIN SELECT RAISE(ABORT, 'forced assault prepare rollback'); END
            """)
            await db.commit()
        rollback_r, rollback_c = ne._hq_coords(rollback_family.hq_key)
        try:
            await ne.prepare_assault(
                path, 101, "marco", rollback_r, rollback_c, now=now + 3
            )
            raise AssertionError("forced assault prepare failure did not abort")
        except sqlite3.IntegrityError as error:
            assert "forced assault prepare rollback" in str(error)
        finally:
            async with aiosqlite.connect(path) as db:
                await db.execute("DROP TRIGGER reject_marco_assault_event")
                await db.commit()
        assert await _scalar(
            path,
            "SELECT COUNT(*) FROM npc_empire_assaults "
            "WHERE leader_id='marco' AND telegram_id=101",
        ) == 0
        assert await _scalar(
            path,
            "SELECT COUNT(*) FROM npc_empire_relations "
            "WHERE leader_id='marco' AND telegram_id=101",
        ) == 0
        assert await _scalar(
            path,
            "SELECT COUNT(*) FROM npc_empire_player_wars "
            "WHERE leader_id='marco' AND telegram_id=101",
        ) == 0
        assert await _scalar(
            path,
            "SELECT COALESCE(SUM(living),0) FROM npc_empire_guard_assignments "
            "WHERE owner_kind='npc' AND owner_id='marco'",
        ) == rollback_guards
        assert await _scalar(
            path,
            "SELECT COUNT(*) FROM npc_empire_events "
            "WHERE leader_id='marco' AND kind='assault_started'",
        ) == 0

        profile = ne.PROFILES[0]
        hq_r, hq_c = ne._hq_coords(profile.hq_key)
        assault = await ne.prepare_assault(
            path, 101, profile.leader_id, hq_r, hq_c, now=now
        )
        assert assault["ok"] and len(assault["guards"]) >= 4

        # The browser reaches this state only after every defender and boss is dead.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empire_assaults SET guard_hp_json=?,boss_hp=0 WHERE token=?",
                (json.dumps([0] * len(assault["guards"])), assault["token"]),
            )
            await db.commit()

        result = await ne.resolve_assault(
            path, 101, assault["token"], "annex",
            operation_map={profile.hq_key: "gun_shop"}, now=now + 30,
        )
        assert result["ok"]
        captured = result["captured_headquarters"]
        assert captured and captured["source_kind"] == "hq"
        assert captured["building_key"] == profile.hq_key
        assert captured["operation_type"] == "gun_shop"
        assert captured["area"] == ne.CAPTURED_HQ_AREA == 27
        assert captured["income_per_minute"] == ne.building_operation_income("gun_shop", 27)
        assert result["operation_map"][profile.hq_key] == "gun_shop"

        block_r, block_c = map(int, profile.hq_key.split(","))
        expected_key = f"tile:{block_r * 10 + 6},{block_c * 10 + 6}"
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            row = await (await db.execute(
                "SELECT * FROM apartments_owned WHERE apt_key=?", (expected_key,)
            )).fetchone()
        assert row is not None
        assert row["telegram_id"] == 101 and row["price"] == 0
        assert row["property_kind"] == "business"
        assert row["operation_type"] == "gun_shop" and row["area"] == 27
        assert row["income_per_minute"] == captured["income_per_minute"]

        root = os.path.dirname(os.path.abspath(__file__))
        with open(os.path.join(root, "world.html"), encoding="utf-8") as source:
            world = source.read()
        with open(os.path.join(root, "three_preview.js"), encoding="utf-8") as source:
            three = source.read()
        for marker in (
            "npc_hq:[42,30]", "const visualSpeed=", "bulletScale:projectileKind?1.15:1.35",
            "trailScale:projectileKind ? .35 : 1.65", "hitAt:+n._hurtAt||0",
            "previewEnterNpcHqAssault", "captured_headquarters",
            "allowAssault&&!['defeated','vassal'].includes(empire.status)",
            "'leader vassal':'Эта семья уже подчинена'",
        ):
            assert marker in world, marker
        assert "const assaultHq=data.kind==='building'&&data.type==='npc_hq'&&kind==='hq'" in three
        assert "command-compound-42x30-v1" in three
        assert len(ne.BUILDING_OPERATIONS) == 8
    finally:
        try:
            os.remove(path)
        except FileNotFoundError:
            pass


if __name__ == "__main__":
    asyncio.run(run())
    print("npc hq capture regression: OK")
