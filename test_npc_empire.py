"""Focused integrity tests for the autonomous NPC empire system."""

import asyncio
import json
import os
import sqlite3
import tempfile

import aiosqlite

import npc_empire as ne


async def _base_db(path: str) -> None:
    async with aiosqlite.connect(path) as db:
        await db.executescript("""
        CREATE TABLE characters (telegram_id INTEGER PRIMARY KEY, cash INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE business_property_owners (
          biz_id TEXT PRIMARY KEY, owner_uid INTEGER, owner_name TEXT,
          acquired_at INTEGER, protected_until INTEGER
        );
        CREATE TABLE player_businesses (
          telegram_id INTEGER, biz_id TEXT PRIMARY KEY, bought_at INTEGER,
          last_collect INTEGER, status TEXT, blocked_until INTEGER,
          last_event_at INTEGER, level INTEGER, guards INTEGER, pending_notice TEXT
        );
        INSERT INTO characters(telegram_id,cash) VALUES(101,10000),(202,100);
        """)
        await db.commit()
    await ne.ensure_schema(path)


async def _scalar(path: str, sql: str, args=()):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql, args)).fetchone()
        return row[0]


async def run() -> None:
    fd, path = tempfile.mkstemp(prefix="npc_empire_", suffix=".db")
    os.close(fd)
    try:
        await _base_db(path)
        assert await _scalar(path, "SELECT COUNT(*) FROM npc_empires") == 19
        assert await _scalar(path, "SELECT COUNT(DISTINCT hq_key) FROM npc_empires") == 19
        assert await _scalar(path, "SELECT COUNT(*) FROM npc_empire_diplomacy") == 171
        assert await _scalar(path, "SELECT COUNT(*) FROM npc_empire_diplomacy WHERE leader_a>=leader_b") == 0

        state = await ne.state_for(path, 101)
        assert len(state["empires"]) == 19
        assert all(e["activity"]["kind"] in {
            "recruit", "business_capture", "business_bought", "expand", "hq_expand",
            "patrol", "war_won", "war_lost", "gang_destroyed", "comeback",
        } for e in state["empires"])
        assert all(e["activity"]["complete_at"] >= state["server_time"] for e in state["empires"])
        assert len(ne.WEAPON_PROFILES) == 19
        assert {p.weapon_id for p in ne.PROFILES} == set(ne.WEAPON_PROFILES)
        assert len({p.weapon_name for p in ne.PROFILES}) == 19
        assert all(e["weapon_profile"] == ne.WEAPON_PROFILES[e["weapon_id"]] for e in state["empires"])
        assert ne.WEAPON_PROFILES["timur_express"]["effect"] == "arrow"
        assert ne.WEAPON_PROFILES["rustam_wrench"]["effect"] == "nailed_bat"
        assert ne.WEAPON_PROFILES["rustam_wrench"]["kind"] == "melee"
        assert ne.WEAPON_PROFILES["marco_road"]["effect"] == "explosive"
        assert {x["leader_name"] for x in state["empires"]} == set(ne.MAFIA_BOSS_NAMES.values())
        assert next(x for x in state["empires"] if x["leader_id"] == "rustam")["leader_name"] == "Билли Капоне"
        assert len(state["leaderboard"]) == 19 and len(state["districts"]) == len(ne.DISTRICTS)
        assert all(x["relation"] == 0 and x["relation_band"] == "neutral" for x in state["empires"])

        gift = await ne.diplomacy_action(path, 101, "leila", "gift", now=2_000_000_000)
        assert gift["ok"] and gift["cost"] == 500 and gift["cash"] == 9500 and gift["relation"] == 12
        assert await _scalar(path, "SELECT cash FROM characters WHERE telegram_id=101") == 9500
        failed = await ne.diplomacy_action(path, 202, "leila", "gift", now=2_000_000_001)
        assert not failed["ok"] and failed["error"] == "no cash"
        assert await _scalar(path, "SELECT cash FROM characters WHERE telegram_id=202") == 100
        first = await ne.diplomacy_action(path, 101, "rustam", "respect", now=2_000_000_010)
        second = await ne.diplomacy_action(path, 101, "rustam", "respect", now=2_000_000_011)
        assert first["ok"] and not second["ok"] and second["error"] == "cooldown"

        too_far = await ne.prepare_assault(path, 101, "leila", 0, 0, now=2_000_001_000)
        assert not too_far["ok"] and too_far["error"] == "too far"
        assault = await ne.prepare_assault(path, 101, "leila", 26, 16, now=2_000_001_001)
        assert assault["ok"] and 4 <= len(assault["guards"]) <= 14
        assert all(g["weapon_id"] == "leila_mercy" and g["weapon_profile"] for g in assault["guards"])
        assert assault["boss"]["weapon_profile"] == ne.WEAPON_PROFILES["leila_mercy"]
        token = assault["token"]
        blocked = await ne.assault_hit(path, 101, token, "boss", None, 35, now=2_000_001_001.2)
        assert not blocked["ok"] and blocked["error"] == "guards alive"

        hit_time = 2_000_001_002.0
        for guard in assault["guards"]:
            hp = guard["hp"]
            while hp > 0:
                reply = await ne.assault_hit(path, 101, token, "guard", guard["id"], 35, now=hit_time)
                assert reply["ok"]
                hp = reply["guards"][guard["id"]]
                hit_time += 0.12
        boss_hp = assault["boss"]["hp"]
        while boss_hp > 0:
            reply = await ne.assault_hit(path, 101, token, "boss", None, 35, now=hit_time)
            assert reply["ok"]
            boss_hp = reply["boss_hp"]
            hit_time += 0.12
        assert reply["victory"]

        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empire_diplomacy SET score=-100,pact='war',tension=80 "
                "WHERE leader_a='leila' OR leader_b='leila'"
            )
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_holdings(kind,holding_id,leader_id,income,defense,acquired_at) VALUES('business','coffee','leila',175,80,?)",
                (2_000_001_000,),
            )
            await db.execute(
                "INSERT OR REPLACE INTO business_property_owners VALUES(?,?,?,?,?)",
                ("coffee", ne.npc_owner_uid("leila"), "Красный полумесяц", 2_000_001_000, 0),
            )
            await db.commit()
        before_cash = await _scalar(path, "SELECT cash FROM characters WHERE telegram_id=101")
        won = await ne.resolve_assault(path, 101, token, "annex", now=2_000_002_000)
        assert won["ok"] and won["captured_businesses"] == ["coffee"]
        assert won["comeback_at"] > 2_000_002_000
        assert await _scalar(path, "SELECT status FROM npc_empires WHERE leader_id='leila'") == "ruined"
        assert await _scalar(path, "SELECT score FROM npc_empire_relations WHERE telegram_id=101 AND leader_id='leila'") == 0
        assert await _scalar(path, "SELECT pact FROM npc_empire_relations WHERE telegram_id=101 AND leader_id='leila'") == "none"
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_diplomacy "
                  "WHERE (leader_a='leila' OR leader_b='leila') AND (score<>0 OR pact<>'none' OR tension<>0)"
        ) == 0
        assert await _scalar(path, "SELECT owner_uid FROM business_property_owners WHERE biz_id='coffee'") == 101
        assert await _scalar(path, "SELECT COUNT(*) FROM player_businesses WHERE telegram_id=101 AND biz_id='coffee'") == 1
        assert await _scalar(path, "SELECT cash FROM characters WHERE telegram_id=101") == before_cash + won["reward"]
        duplicate = await ne.resolve_assault(path, 101, token, "annex", now=2_000_002_001)
        assert not duplicate["ok"] and duplicate["error"] == "not won"
        assert await _scalar(path, "SELECT cash FROM characters WHERE telegram_id=101") == before_cash + won["reward"]

        # The two other irreversible outcomes retain their distinct ownership rules.
        async with aiosqlite.connect(path) as db:
            for extra_token, leader in (("won-loot", "rustam"), ("won-vassal", "niko")):
                await db.execute(
                    "INSERT INTO npc_empire_assaults(token,telegram_id,leader_id,guard_hp_json,boss_hp,boss_max_hp,status,started_at,expires_at,last_hit_at) VALUES(?,?,?,'[0]',0,300,'active',?,?,?)",
                    (extra_token, 101, leader, 2_000_002_000, 2_000_010_000, 2_000_002_000.0),
                )
            await db.execute("INSERT OR REPLACE INTO npc_empire_holdings VALUES('business','bar','rustam',1200,90,?)", (2_000_002_000,))
            await db.execute("INSERT OR REPLACE INTO business_property_owners VALUES(?,?,?,?,?)", ("bar", ne.npc_owner_uid("rustam"), "Железные волки", 2_000_002_000, 0))
            await db.commit()
        looted = await ne.resolve_assault(path, 101, "won-loot", "loot", now=2_000_002_100)
        assert looted["ok"] and await _scalar(path, "SELECT COUNT(*) FROM business_property_owners WHERE biz_id='bar'") == 0
        assert await _scalar(path, "SELECT status FROM npc_empires WHERE leader_id='rustam'") == "ruined"
        vassal = await ne.resolve_assault(path, 101, "won-vassal", "vassalize", now=2_000_002_200)
        assert vassal["ok"] and await _scalar(path, "SELECT status FROM npc_empires WHERE leader_id='niko'") == "vassal"
        assert await _scalar(path, "SELECT pact FROM npc_empire_relations WHERE telegram_id=101 AND leader_id='niko'") == "vassal"

        # A ruined leader returns with a new HQ, two fighters, small capital and
        # a clean neutral reputation instead of disappearing permanently.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empires SET comeback_at=? WHERE leader_id='leila'", (2_000_002_300,)
            )
            await db.commit()
        await ne.advance(path, now=2_000_002_301)
        comeback = (await ne.state_for(path, 101, now=2_000_002_301))
        leila = next(e for e in comeback["empires"] if e["leader_id"] == "leila")
        assert leila["status"] == "rebuilding" and leila["members"] == 2
        assert leila["hq_key"] and leila["comebacks"] == 1 and leila["relation"] == 0
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events WHERE kind='comeback' AND leader_id='leila'"
        ) == 1
        assert len(comeback["leaderboard"]) == 19 and len(comeback["districts"]) == len(ne.DISTRICTS)
        print("npc_empire: endless sandbox, neutral reset, comeback, districts and rewards OK")
    finally:
        try:
            os.remove(path)
        except PermissionError:
            pass


if __name__ == "__main__":
    asyncio.run(run())
