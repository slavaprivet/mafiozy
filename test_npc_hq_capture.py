"""End-to-end regression for winning, converting, and owning an NPC HQ."""

import asyncio
import json
import os
import tempfile

import aiosqlite

import npc_empire as ne


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
                VALUES(101,'Слава','moretti',5000);
            """)
            await db.commit()
        await ne.ensure_schema(path)

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
            "3d389-hq-assault-ballistics",
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
