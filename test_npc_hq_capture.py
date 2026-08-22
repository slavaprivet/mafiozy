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


async def _ruin_terminalizes_sibling_hq(
        path: str, leader_id: str, choice: str, now: int,
        other_family_token: str, inject_rollback: bool = False) -> None:
    profile = ne.PROFILE_BY_ID[leader_id]
    hq_r, hq_c = ne._hq_coords(profile.hq_key)
    winner = await ne.prepare_assault(
        path, 101, leader_id, hq_r, hq_c, now=now
    )
    sibling = await ne.prepare_assault(
        path, 202, leader_id, hq_r, hq_c, now=now
    )
    field = await ne.prepare_field_encounter(
        path, 303, leader_id, hq_r, hq_c, now=now,
        server_activity={"target_r": hq_r, "target_c": hq_c,
                         "target_id": f"{leader_id}-field-proof",
                         "created_at": now},
    )
    assert winner["ok"] and sibling["ok"]
    assert field["ok"] and field["encounter_kind"] == "field"
    async with aiosqlite.connect(path) as db:
        await db.execute(
            "UPDATE npc_empire_assaults SET guard_hp_json=?,boss_hp=0 "
            "WHERE token=?",
            (json.dumps([0] * len(winner["guards"])), winner["token"]),
        )
        await db.commit()

    if inject_rollback:
        rollback_cash = await _scalar(
            path, "SELECT cash FROM characters WHERE telegram_id=101"
        )
        rollback_holdings = await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_holdings WHERE leader_id=?",
            (leader_id,),
        )
        rollback_events = await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events WHERE leader_id=?",
            (leader_id,),
        )
        async with aiosqlite.connect(path) as db:
            await db.execute("""
                CREATE TRIGGER reject_ruin_assault_event
                BEFORE INSERT ON npc_empire_events
                WHEN NEW.leader_id='rustam' AND NEW.kind='assault_won'
                BEGIN SELECT RAISE(ABORT, 'forced ruin sibling rollback'); END
            """)
            await db.commit()
        try:
            await ne.resolve_assault(
                path, 101, winner["token"], choice, now=now + 1
            )
            raise AssertionError("forced ruin sibling failure did not abort")
        except sqlite3.IntegrityError as error:
            assert "forced ruin sibling rollback" in str(error)
        finally:
            async with aiosqlite.connect(path) as db:
                await db.execute("DROP TRIGGER reject_ruin_assault_event")
                await db.commit()
        assert await _scalar(
            path, "SELECT status FROM npc_empires WHERE leader_id=?",
            (leader_id,),
        ) == "active"
        for token in (winner["token"], sibling["token"], field["token"],
                      other_family_token):
            assert await _scalar(
                path, "SELECT status FROM npc_empire_assaults WHERE token=?",
                (token,),
            ) == "active"
        assert await _scalar(
            path, "SELECT cash FROM characters WHERE telegram_id=101"
        ) == rollback_cash
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_holdings WHERE leader_id=?",
            (leader_id,),
        ) == rollback_holdings
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events WHERE leader_id=?",
            (leader_id,),
        ) == rollback_events

    resolved = await ne.resolve_assault(
        path, 101, winner["token"], choice, now=now + 2
    )
    assert resolved["ok"] and resolved["choice"] == choice
    assert await _scalar(
        path,
        "SELECT status||':'||resolution FROM npc_empire_assaults WHERE token=?",
        (winner["token"],),
    ) == f"resolved:{choice}"
    assert await _scalar(
        path,
        "SELECT status||':'||resolution FROM npc_empire_assaults WHERE token=?",
        (sibling["token"],),
    ) == "resolved:leader_ruined"
    assert await _scalar(
        path, "SELECT status FROM npc_empire_assaults WHERE token=?",
        (field["token"],),
    ) == "active"
    assert await _scalar(
        path, "SELECT status FROM npc_empire_field_encounters WHERE encounter_id=?",
        (field["encounter_id"],),
    ) == "active"
    assert await _scalar(
        path, "SELECT status FROM npc_empire_assaults WHERE token=?",
        (other_family_token,),
    ) == "active"

    sibling_hp = await _scalar(
        path, "SELECT guard_hp_json||':'||boss_hp FROM npc_empire_assaults "
              "WHERE token=?", (sibling["token"],),
    )
    cash_101 = await _scalar(
        path, "SELECT cash FROM characters WHERE telegram_id=101"
    )
    cash_202 = await _scalar(
        path, "SELECT cash FROM characters WHERE telegram_id=202"
    )
    holdings = await _scalar(
        path, "SELECT COUNT(*) FROM npc_empire_holdings WHERE leader_id=?",
        (leader_id,),
    )
    events = await _scalar(
        path, "SELECT COUNT(*) FROM npc_empire_events WHERE leader_id=?",
        (leader_id,),
    )
    ruined_state = await _scalar(
        path, "SELECT status||':'||defeated_by||':'||comeback_at "
              "FROM npc_empires WHERE leader_id=?", (leader_id,),
    )
    terminal = {"ok": True, "duplicate": True, "terminal": True,
                "resolution": "leader_ruined"}
    stale_results = await asyncio.gather(
        ne.assault_hit(path, 202, sibling["token"], "guard", 0, 35,
                       now=now + 3.0),
        ne.resolve_assault(path, 202, sibling["token"],
                           "annex" if choice == "loot" else "vassalize",
                           now=now + 3),
    )
    assert stale_results == [terminal, terminal]
    assert await ne.assault_hit(
        path, 202, sibling["token"], "guard", 0, 35, now=now + 4.0
    ) == terminal
    assert await ne.resolve_assault(
        path, 202, sibling["token"], "loot", now=now + 4
    ) == terminal
    assert await _scalar(
        path, "SELECT guard_hp_json||':'||boss_hp FROM npc_empire_assaults "
              "WHERE token=?", (sibling["token"],),
    ) == sibling_hp
    assert await _scalar(
        path, "SELECT cash FROM characters WHERE telegram_id=101"
    ) == cash_101
    assert await _scalar(
        path, "SELECT cash FROM characters WHERE telegram_id=202"
    ) == cash_202
    assert await _scalar(
        path, "SELECT COUNT(*) FROM npc_empire_holdings WHERE leader_id=?",
        (leader_id,),
    ) == holdings
    assert await _scalar(
        path, "SELECT COUNT(*) FROM npc_empire_events WHERE leader_id=?",
        (leader_id,),
    ) == events
    assert await _scalar(
        path, "SELECT status||':'||defeated_by||':'||comeback_at "
              "FROM npc_empires WHERE leader_id=?", (leader_id,),
    ) == ruined_state
    assert await _scalar(
        path, "SELECT status FROM npc_empire_assaults WHERE token=?",
        (field["token"],),
    ) == "active"
    assert await _scalar(
        path, "SELECT status FROM npc_empire_assaults WHERE token=?",
        (other_family_token,),
    ) == "active"


async def _peace_terminalizes_exact_pair_hq(
        path: str, leader_id: str, action: str, now: int,
        other_family_token: str, inject_rollback: bool = False) -> None:
    profile = ne.PROFILE_BY_ID[leader_id]
    hq_r, hq_c = ne._hq_coords(profile.hq_key)
    own = await ne.prepare_assault(
        path, 101, leader_id, hq_r, hq_c, now=now
    )
    other_player = await ne.prepare_assault(
        path, 202, leader_id, hq_r, hq_c, now=now
    )
    field = await ne.prepare_field_encounter(
        path, 303, leader_id, hq_r, hq_c, now=now,
        server_activity={"target_r": hq_r, "target_c": hq_c,
                         "target_id": f"{leader_id}-peace-field",
                         "created_at": now},
    )
    assert own["ok"] and other_player["ok"] and field["ok"]
    if action == "compensation":
        first = await ne.diplomacy_action(
            path, 101, leader_id, action, now=now + 1
        )
        assert first["ok"] and first["pact"] == "war"
    else:
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empire_relations SET score=-50 "
                "WHERE leader_id=? AND telegram_id=101", (leader_id,)
            )
            await db.commit()
        cash_before = await _scalar(
            path, "SELECT cash FROM characters WHERE telegram_id=101")
        offer = await ne.conditional_truce_action(
            path, 101, leader_id, "offer",
            f"hq-pair:{leader_id}:{now}:offer", now=now + 1)
        assert offer["ok"] and not offer["duplicate"]
        agreement = offer["agreement"]
        assert agreement["state"] == "offered"
        assert agreement["terms"] == [{
            "kind": "compensation", "label": "Компенсация $300",
            "state": "pending"}]
        async with aiosqlite.connect(path) as db:
            db.row_factory = aiosqlite.Row
            generation = int((await (await db.execute(
                "SELECT comebacks FROM npc_empires WHERE leader_id=?",
                (leader_id,))).fetchone())[0])
            agreement_row = await (await db.execute(
                "SELECT leader_id,leader_generation,telegram_id,term_amount,"
                "created_at,expires_at,status FROM npc_empire_player_agreements "
                "WHERE agreement_id=?", (agreement["agreement_id"],))).fetchone()
        assert dict(agreement_row) == {
            "leader_id": leader_id, "leader_generation": generation,
            "telegram_id": 101, "term_amount": 300,
            "created_at": now + 1, "expires_at": now + 1801,
            "status": "offered"}
        assert await _scalar(
            path, "SELECT status FROM npc_empire_assaults WHERE token=?",
            (own["token"],)) == "active"
        assert await _scalar(
            path, "SELECT pact FROM npc_empire_relations "
                  "WHERE leader_id=? AND telegram_id=101", (leader_id,)) == "war"
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_player_wars "
                  "WHERE leader_id=? AND telegram_id=101", (leader_id,)) == 1
        assert await _scalar(
            path, "SELECT cash FROM characters WHERE telegram_id=101") == cash_before

    if inject_rollback:
        async with aiosqlite.connect(path) as db:
            await db.execute("""
                CREATE TRIGGER reject_pair_peace_event
                BEFORE INSERT ON npc_empire_events
                WHEN NEW.leader_id='vera' AND NEW.kind='diplomacy'
                BEGIN SELECT RAISE(ABORT, 'forced pair peace rollback'); END
            """)
            await db.commit()
        try:
            await ne.diplomacy_action(
                path, 101, leader_id, action, now=now + 2
            )
            raise AssertionError("forced pair peace failure did not abort")
        except sqlite3.IntegrityError as error:
            assert "forced pair peace rollback" in str(error)
        finally:
            async with aiosqlite.connect(path) as db:
                await db.execute("DROP TRIGGER reject_pair_peace_event")
                await db.commit()
        assert await _scalar(
            path, "SELECT status FROM npc_empire_assaults WHERE token=?",
            (own["token"],),
        ) == "active"
        assert await _scalar(
            path, "SELECT pact FROM npc_empire_relations "
                  "WHERE leader_id=? AND telegram_id=101", (leader_id,),
        ) == "war"

    if action == "truce":
        peace = await ne.conditional_truce_action(
            path, 101, leader_id, "fulfill",
            f"hq-pair:{leader_id}:{now}:fulfill",
            agreement["agreement_id"], now + 3)
        assert peace["ok"] and not peace["duplicate"]
        assert peace["pact"] == "truce" and peace["relation"] == -20
        assert peace["cost"] == 300 and peace["cash"] == cash_before - 300
        assert peace["agreement"]["state"] == "fulfilled"
    else:
        peace = await ne.diplomacy_action(
            path, 101, leader_id, action, now=now + 3
        )
    assert peace["ok"] and peace["pact"] in {"truce", "none"}
    assert await _scalar(
        path, "SELECT status||':'||resolution FROM npc_empire_assaults "
              "WHERE token=?", (own["token"],),
    ) == "resolved:diplomacy_changed"
    for token in (other_player["token"], field["token"], other_family_token):
        assert await _scalar(
            path, "SELECT status FROM npc_empire_assaults WHERE token=?",
            (token,),
        ) == "active"
    assert await _scalar(
        path, "SELECT COUNT(*) FROM npc_empire_player_wars "
              "WHERE leader_id=? AND telegram_id=101", (leader_id,),
    ) == 0
    assert await _scalar(
        path, "SELECT COUNT(*) FROM npc_empire_player_wars "
              "WHERE leader_id=? AND telegram_id=202", (leader_id,),
    ) == 1

    hp = await _scalar(
        path, "SELECT guard_hp_json||':'||boss_hp FROM npc_empire_assaults "
              "WHERE token=?", (own["token"],),
    )
    cash = await _scalar(path, "SELECT cash FROM characters WHERE telegram_id=101")
    events = await _scalar(
        path, "SELECT COUNT(*) FROM npc_empire_events WHERE leader_id=?",
        (leader_id,),
    )
    status = await _scalar(
        path, "SELECT status||':'||COALESCE(defeated_by,0) FROM npc_empires "
              "WHERE leader_id=?", (leader_id,),
    )
    terminal = {"ok": True, "duplicate": True, "terminal": True,
                "resolution": "diplomacy_changed"}
    stale = await asyncio.gather(
        ne.assault_hit(path, 101, own["token"], "guard", 0, 35,
                       now=now + 4.0),
        ne.resolve_assault(path, 101, own["token"], "loot", now=now + 4),
    )
    assert stale == [terminal, terminal]
    assert await ne.resolve_assault(
        path, 101, own["token"], "annex", now=now + 5
    ) == terminal
    assert await _scalar(
        path, "SELECT guard_hp_json||':'||boss_hp FROM npc_empire_assaults "
              "WHERE token=?", (own["token"],),
    ) == hp
    assert await _scalar(
        path, "SELECT cash FROM characters WHERE telegram_id=101"
    ) == cash
    assert await _scalar(
        path, "SELECT COUNT(*) FROM npc_empire_events WHERE leader_id=?",
        (leader_id,),
    ) == events
    assert await _scalar(
        path, "SELECT status||':'||COALESCE(defeated_by,0) FROM npc_empires "
              "WHERE leader_id=?", (leader_id,),
    ) == status


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

        isolated = next(item for item in ne.PROFILES
                        if item.leader_id == "viktor")
        isolated_r, isolated_c = ne._hq_coords(isolated.hq_key)
        other_family = await ne.prepare_assault(
            path, 303, "viktor", isolated_r, isolated_c, now=now
        )
        assert other_family["ok"]
        await _peace_terminalizes_exact_pair_hq(
            path, "vera", "compensation", now + 1,
            other_family["token"], inject_rollback=True,
        )
        await _peace_terminalizes_exact_pair_hq(
            path, "alisa", "truce", now + 6, other_family["token"],
        )
        await _ruin_terminalizes_sibling_hq(
            path, "rustam", "loot", now + 10, other_family["token"],
            inject_rollback=True,
        )
        await _ruin_terminalizes_sibling_hq(
            path, "marat", "annex", now + 20, other_family["token"],
        )

        # Two players can hold real HQ tokens concurrently. The first global
        # vassalization must terminalize the sibling before any later hit or
        # irreversible resolve can use its stale authority.
        contested = next(item for item in ne.PROFILES
                         if item.leader_id == "niko")
        contested_r, contested_c = ne._hq_coords(contested.hq_key)
        winner = await ne.prepare_assault(
            path, 101, "niko", contested_r, contested_c, now=now
        )
        sibling = await ne.prepare_assault(
            path, 202, "niko", contested_r, contested_c, now=now
        )
        assert winner["ok"] and sibling["ok"]
        field = await ne.prepare_field_encounter(
            path, 303, "niko", contested_r, contested_c, now=now,
            server_activity={"target_r": contested_r, "target_c": contested_c,
                             "target_id": "niko-field-proof",
                             "created_at": now},
        )
        assert field["ok"] and field["encounter_kind"] == "field"
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empire_assaults SET guard_hp_json=?,boss_hp=0 "
                "WHERE token=?",
                (json.dumps([0] * len(winner["guards"])), winner["token"]),
            )
            await db.commit()

        rollback_cash = await _scalar(
            path, "SELECT cash FROM characters WHERE telegram_id=101"
        )
        async with aiosqlite.connect(path) as db:
            await db.execute("""
                CREATE TRIGGER reject_niko_vassal_event
                BEFORE INSERT ON npc_empire_events
                WHEN NEW.leader_id='niko' AND NEW.kind='assault_won'
                BEGIN SELECT RAISE(ABORT, 'forced vassal sibling rollback'); END
            """)
            await db.commit()
        try:
            await ne.resolve_assault(
                path, 101, winner["token"], "vassalize", now=now + 1
            )
            raise AssertionError("forced vassal sibling failure did not abort")
        except sqlite3.IntegrityError as error:
            assert "forced vassal sibling rollback" in str(error)
        finally:
            async with aiosqlite.connect(path) as db:
                await db.execute("DROP TRIGGER reject_niko_vassal_event")
                await db.commit()
        assert await _scalar(
            path, "SELECT status FROM npc_empires WHERE leader_id='niko'"
        ) == "active"
        for token in (winner["token"], sibling["token"], field["token"]):
            assert await _scalar(
                path, "SELECT status FROM npc_empire_assaults WHERE token=?",
                (token,),
            ) == "active"
        assert await _scalar(
            path, "SELECT cash FROM characters WHERE telegram_id=101"
        ) == rollback_cash

        vassalized = await ne.resolve_assault(
            path, 101, winner["token"], "vassalize", now=now + 2
        )
        assert vassalized["ok"] and vassalized["choice"] == "vassalize"
        assert await _scalar(
            path,
            "SELECT status||':'||resolution FROM npc_empire_assaults "
            "WHERE token=?", (winner["token"],),
        ) == "resolved:vassalize"
        assert await _scalar(
            path,
            "SELECT status||':'||resolution FROM npc_empire_assaults "
            "WHERE token=?", (sibling["token"],),
        ) == "resolved:vassalized"
        assert await _scalar(
            path,
            "SELECT status FROM npc_empire_assaults WHERE token=?",
            (field["token"],),
        ) == "active"
        assert await _scalar(
            path,
            "SELECT status FROM npc_empire_field_encounters WHERE encounter_id=?",
            (field["encounter_id"],),
        ) == "active"

        sibling_hp = await _scalar(
            path, "SELECT guard_hp_json FROM npc_empire_assaults WHERE token=?",
            (sibling["token"],),
        )
        cash_101 = await _scalar(
            path, "SELECT cash FROM characters WHERE telegram_id=101"
        )
        cash_202 = await _scalar(
            path, "SELECT cash FROM characters WHERE telegram_id=202"
        )
        holdings = await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_holdings WHERE leader_id='niko'"
        )
        events = await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events WHERE leader_id='niko'"
        )
        terminal = {"ok": True, "duplicate": True, "terminal": True,
                    "resolution": "vassalized"}
        stale_results = await asyncio.gather(
            ne.assault_hit(path, 202, sibling["token"], "guard", 0, 35,
                           now=now + 3.0),
            ne.resolve_assault(path, 202, sibling["token"], "loot",
                               now=now + 3),
        )
        assert stale_results == [terminal, terminal]
        assert await ne.assault_hit(
            path, 202, sibling["token"], "guard", 0, 35, now=now + 4.0
        ) == terminal
        assert await ne.resolve_assault(
            path, 202, sibling["token"], "annex", now=now + 4
        ) == terminal
        assert await _scalar(
            path, "SELECT guard_hp_json FROM npc_empire_assaults WHERE token=?",
            (sibling["token"],),
        ) == sibling_hp
        assert await _scalar(
            path, "SELECT status||':'||defeated_by FROM npc_empires "
                  "WHERE leader_id='niko'"
        ) == "vassal:101"
        assert await _scalar(
            path, "SELECT cash FROM characters WHERE telegram_id=101"
        ) == cash_101
        assert await _scalar(
            path, "SELECT cash FROM characters WHERE telegram_id=202"
        ) == cash_202
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_holdings WHERE leader_id='niko'"
        ) == holdings
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_events WHERE leader_id='niko'"
        ) == events
        assert await _scalar(
            path, "SELECT status FROM npc_empires WHERE leader_id='leila'"
        ) == "active"
        assert await _scalar(
            path, "SELECT status FROM npc_empire_assaults WHERE token=?",
            (field["token"],),
        ) == "active"

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
