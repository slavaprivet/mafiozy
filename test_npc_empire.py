"""Focused integrity tests for the autonomous NPC empire system."""

import asyncio
import math
import json
import os
import re
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
    async with aiosqlite.connect(path) as db:
        await db.execute(
            "UPDATE npc_empires SET last_tick=?,next_action_at=?",
            (2_000_000_000, 2_000_000_000 + ne.TICK_SECONDS),
        )
        await db.commit()


async def _scalar(path: str, sql: str, args=()):
    async with aiosqlite.connect(path) as db:
        row = await (await db.execute(sql, args)).fetchone()
        return row[0]


async def run() -> None:
    assert ne.NPC_EMPIRE_MAX_FIGHTERS == 20
    assert len(ne.BUILDING_OPERATIONS) == 8
    assert len(ne.BUILDING_AREAS) == 101
    assert not set(ne.BUILDING_AREAS).intersection(p.hq_key for p in ne.PROFILES)
    assert ne.building_operation_income("print_shop", 27) == 200
    assert ne.building_operation_income("print_shop", 4) == 175
    assert ne.building_operation_income("beer_bar", 27) > ne.building_operation_income("beer_bar", 4)
    assert {ne.choose_building_operation(p, key, 2_000_000_000)
            for p, key in zip(ne.PROFILES, ne.BUILDING_AREAS)} <= set(ne.BUILDING_OPERATIONS)
    root = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(root, "world.html"), encoding="utf-8") as source:
        world_source = source.read()
    with open(os.path.join(root, "three_preview.js"), encoding="utf-8") as source:
        three_source = source.read()
    assert "empireFlags" in world_source and ".slice(0,64)" in world_source
    hq_keys_source = re.search(
        r"const NPC_EMPIRE_HQ_BLOCK_KEYS = new Set\(\[(.*?)\]\);",
        world_source, re.S,
    )
    assert hq_keys_source
    client_hq_keys = set(re.findall(r"'(\d+,\d+)'", hq_keys_source.group(1)))
    assert client_hq_keys == {profile.hq_key for profile in ne.PROFILES}
    assert not client_hq_keys.intersection(old for old, _ in ne.HQ_KEY_MIGRATIONS.values())
    assert "if(moved==='blocked'||moved===false)" not in world_source
    assert world_source.count("else if(moved===false)n.walking=false") >= 3
    assert "if(distance>.8&&now>=(n._empireRouteRetryAt||0)&&" in world_source
    assert ")-target.r,(n._routeGoalC??n.c)-target.c)>5.2" in world_source
    assert "Math.hypot(live.r-target.r,live.c-target.c)>8" in world_source
    assert "const _empireRoutePlanQueue=[]" in world_source
    assert "_processEmpireRoutePlanQueue(now)" in world_source
    assert "return 'deferred'" in world_source
    assert "empireRouteAdmission" in world_source
    assert "_planNpcRouteTo(n,target.r,target.c,_empireBossPassable" not in world_source
    assert "3d368-visible-empire-flags" in world_source
    assert "const EMPIRE_FLAG_CAP=64" in three_source
    assert "src.operationName" in three_source and "incomePerMinute" in three_source
    assert "empireHqRoofBox.setFromObject(object)" in three_source
    assert "depthTest:false,depthWrite:false" in three_source
    assert set(ne.BUILDING_OPERATIONS) <= {
        operation_id for operation_id in ne.BUILDING_OPERATIONS if operation_id in world_source
    }
    fd, path = tempfile.mkstemp(prefix="npc_empire_", suffix=".db")
    os.close(fd)
    try:
        await _base_db(path)
        assert await _scalar(path, "SELECT COUNT(*) FROM npc_empires") == 19
        assert await _scalar(path, "SELECT COUNT(DISTINCT hq_key) FROM npc_empires") == 19
        assert await _scalar(path, "SELECT COUNT(*) FROM npc_empire_diplomacy") == 171
        assert await _scalar(path, "SELECT COUNT(*) FROM npc_empire_diplomacy WHERE leader_a>=leader_b") == 0

        # Upgrading a live database moves both sides of HQ ownership.  Leaving
        # the legacy holding behind would make the client count two HQs while
        # still failing to resolve the old prison/lair footprint.
        old_hq, new_hq = ne.HQ_KEY_MIGRATIONS["rustam"]
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "DELETE FROM npc_empire_holdings WHERE kind='hq' AND leader_id='rustam'"
            )
            await db.execute(
                "UPDATE npc_empires SET hq_key=? WHERE leader_id='rustam'", (old_hq,)
            )
            await db.execute(
                "INSERT INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at) "
                "VALUES('hq',?,'rustam',0,100,1)", (old_hq,)
            )
            await db.commit()
        await ne.ensure_schema(path)
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empires WHERE leader_id='rustam' AND hq_key=?",
            (new_hq,),
        ) == 1
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_holdings "
                  "WHERE kind='hq' AND leader_id='rustam' AND holding_id=?",
            (new_hq,),
        ) == 1
        assert await _scalar(
            path, "SELECT COUNT(*) FROM npc_empire_holdings "
                  "WHERE kind='hq' AND leader_id='rustam' AND holding_id=?",
            (old_hq,),
        ) == 0

        state_now = 2_000_000_000
        state = await ne.state_for(path, 101, now=state_now)
        assert len(state["empires"]) == 19
        assert {x["leader_name"] for x in state["empires"]} == set(ne.MAFIA_BOSS_NAMES.values())
        assert next(x for x in state["empires"] if x["leader_id"] == "rustam")["leader_name"] == "Билли Капоне"
        assert all(x["brain"]["strategy"] in {
            "recover", "recruit", "fortify", "retaliate", "acquire", "expand", "consolidate"
        } for x in state["empires"])
        assert all(52 <= x["brain"]["confidence"] <= 96 and x["brain"]["reason"]
                   for x in state["empires"])
        assert all(isinstance(x["memory"], list) for x in state["empires"])

        weak_plan = ne._boss_brain(
            ne.PROFILE_BY_ID["leila"],
            {"treasury": 5000, "members": 2, "strength": 38,
             "status": "active", "hospital_until": 0},
            [], [], state_now, neutral_buildings=0, affordable_businesses=0,
        )
        assert weak_plan["strategy"] == "recruit"
        trader_plan = ne._boss_brain(
            ne.PROFILE_BY_ID["zara"],
            {"treasury": 100000, "members": 20, "strength": 280,
             "status": "active", "hospital_until": 0},
            [{"kind": "building", "holding_id": "1,1"}], [], state_now,
            neutral_buildings=0, affordable_businesses=4,
        )
        assert trader_plan["strategy"] == "acquire"
        revenge_plan = ne._boss_brain(
            ne.PROFILE_BY_ID["viktor"],
            {"treasury": 9000, "members": 20, "strength": 250,
             "status": "active", "hospital_until": 0},
            [], [{"kind": "player_attack", "summary": "Игрок открыл огонь",
                  "created_at": state_now, "target_id": "101"}], state_now,
            active_wars=1, neutral_buildings=0, affordable_businesses=0,
        )
        assert revenge_plan["strategy"] == "retaliate"
        learned_plan = ne._boss_brain(
            ne.PROFILE_BY_ID["viktor"],
            {"treasury": 9000, "members": 12, "strength": 170,
             "status": "active", "hospital_until": 0},
            [{"kind": "building", "holding_id": "2,2"}],
            [{"kind": "war_lost", "summary": "loss 2", "created_at": state_now},
             {"kind": "war_lost", "summary": "loss 1", "created_at": state_now - 60}],
            state_now, active_wars=1, neutral_buildings=4, affordable_businesses=0,
        )
        assert learned_plan["adaptation"]["mode"] == "cautious"
        assert learned_plan["adaptation"]["loss_streak"] == 2
        assert learned_plan["strategy"] in {"fortify", "recruit", "recover"}
        bold_lesson = ne._boss_adaptation([
            {"kind": "war_won", "created_at": state_now},
            {"kind": "gang_destroyed", "created_at": state_now - 60},
        ], state_now)
        assert bold_lesson["mode"] == "bold" and bold_lesson["win_streak"] == 2
        forgotten_lesson = ne._boss_adaptation([
            {"kind": "war_lost", "created_at": state_now - 25 * 3600},
            {"kind": "war_lost", "created_at": state_now - 26 * 3600},
        ], state_now)
        assert forgotten_lesson["mode"] == "balanced"
        assert len(state["leaderboard"]) == 19 and len(state["districts"]) == len(ne.DISTRICTS)
        assert all(x["relation"] == 0 and x["relation_band"] == "neutral" for x in state["empires"])
        assert all(x["activity"]["phase"] == "travel" for x in state["empires"])
        leila_activity = next(x for x in state["empires"] if x["leader_id"] == "leila")["activity"]
        assert "target_r" in leila_activity and "target_c" in leila_activity
        later_state = await ne.state_for(
            path, 101, now=state_now + ne.VISIBLE_ACTIVITY_SECONDS)
        later_activity = next(x for x in later_state["empires"] if x["leader_id"] == "leila")["activity"]
        assert later_activity["created_at"] != leila_activity["created_at"]

        # A captured apartment is converted into one of eight criminal
        # operations.  The API exposes its skin/name and per-minute economy.
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "INSERT INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at,operation_type,area) "
                "VALUES('building','0,3','leila',200,60,?,'print_shop',27)",
                (state_now,),
            )
            await db.commit()
        converted_state = await ne.state_for(path, 101, now=state_now)
        converted = next(h for h in next(
            e for e in converted_state["empires"] if e["leader_id"] == "leila"
        )["holdings"] if h["kind"] == "building")
        assert converted["operation_name"] == "Фальшивая типография"
        assert converted["operation_icon"] == "🖨️"
        assert converted["income"] == 200 and converted["income_unit"] == "minute"
        assert converted["size_class"] == "large"

        hospitalized = await ne.hospitalize_boss(path, "leila", "hospital_east", now=state_now)
        assert hospitalized["ok"] and hospitalized["hospital_until"] == state_now + 60
        duplicate_hospital = await ne.hospitalize_boss(path, "leila", "hospital", now=state_now + 10)
        assert duplicate_hospital["hospital_until"] == state_now + 60
        treatment_state = await ne.state_for(path, 101, now=state_now + 59)
        treatment = next(x for x in treatment_state["empires"] if x["leader_id"] == "leila")
        assert treatment["hospital_until"] == state_now + 60 and treatment["hospital_id"] == "hospital_east"
        released_state = await ne.state_for(path, 101, now=state_now + 61)
        released = next(x for x in released_state["empires"] if x["leader_id"] == "leila")
        assert released["hospital_until"] == 0 and released["hospital_id"] == ""

        # Peace-time orders are city-wide too: over a short deterministic
        # window families visit the east city and the southern coast/port,
        # instead of orbiting only eight tiles around their headquarters.
        roam = [ne._visible_activity(profile, {'hq_key': profile.hq_key}, [],
                                     slot * ne.VISIBLE_ACTIVITY_SECONDS)
                for slot in range(24) for profile in ne.PROFILES]
        assert any(float(a["target_c"]) >= 100 for a in roam)
        assert any(float(a["target_r"]) >= 150 for a in roam)
        assert any(math.hypot(float(a["target_r"])-ne._hq_coords(profile.hq_key)[0],
                              float(a["target_c"])-ne._hq_coords(profile.hq_key)[1]) >= 40
                   for slot in range(24) for profile in ne.PROFILES
                   for a in [ne._visible_activity(profile, {'hq_key': profile.hq_key}, [],
                                                  slot * ne.VISIBLE_ACTIVITY_SECONDS)])
        for slot in range(6):
            simultaneous = [ne._visible_activity(
                profile, {'hq_key': profile.hq_key}, [],
                slot * ne.VISIBLE_ACTIVITY_SECONDS) for profile in ne.PROFILES]
            assert sum(float(a["target_c"]) >= 100 for a in simultaneous) >= 3
            assert sum(float(a["target_r"]) >= 150 for a in simultaneous) >= 3

        # A shared strategic need is staggered into execution windows.  At a
        # fresh-city start all 19 brains want recruits, but only one wave may
        # travel to the Lair while the others keep doctrine-specific field jobs.
        recruit_brain = {'strategy': 'recruit'}
        for slot in range(10):
            simultaneous = [ne._visible_activity(
                profile, {'hq_key': profile.hq_key}, [],
                slot * ne.VISIBLE_ACTIVITY_SECONDS, recruit_brain)
                for profile in ne.PROFILES]
            lair_orders = [a for a in simultaneous if a['kind'] == 'recruit']
            assert 3 <= len(lair_orders) <= 4
            assert len({(a['target_r'], a['target_c']) for a in lair_orders}) == len(lair_orders)
            target_load = {}
            for activity in simultaneous:
                point = (activity['target_r'], activity['target_c'])
                target_load[point] = target_load.get(point, 0) + 1
            assert max(target_load.values()) <= 2
            assert len({a['ui_label'] for a in simultaneous}) >= 11
            assert all(a.get('intent') == 'recruit' for a in simultaneous)
        assert len(ne.BOSS_FIELD_JOBS) == len(ne.PROFILES) == 19
        assert len(set(ne.BOSS_FIELD_JOBS.values())) == 19

        # A server NPC war becomes a shared physical order: both leaders choose
        # the opposing boss, carry a stance/force, and converge in the city.
        async with aiosqlite.connect(path) as db:
            left, right = sorted(("leila", "rustam"))
            await db.execute(
                "UPDATE npc_empire_diplomacy SET score=-100,pact='war',tension=80 "
                "WHERE leader_a=? AND leader_b=?", (left, right),
            )
            await db.commit()
        war_state = await ne.state_for(path, 101, now=2_000_000_080)
        leila_war = next(x for x in war_state["empires"] if x["leader_id"] == "leila")["activity"]
        rustam_war = next(x for x in war_state["empires"] if x["leader_id"] == "rustam")["activity"]
        assert leila_war["kind"] == rustam_war["kind"] == "gang_war"
        assert leila_war["target_id"] == "rustam" and rustam_war["target_id"] == "leila"
        assert leila_war["stance"] in {"assault", "harass"} and 2 <= leila_war["force"] <= 20
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "UPDATE npc_empire_diplomacy SET score=0,pact='none',tension=0 "
                "WHERE leader_a=? AND leader_b=?", (left, right),
            )
            await db.commit()

        gift = await ne.diplomacy_action(path, 101, "leila", "gift", now=2_000_000_000)
        assert gift["ok"] and gift["cost"] == 500 and gift["cash"] == 9500 and gift["relation"] == 12
        assert await _scalar(path, "SELECT cash FROM characters WHERE telegram_id=101") == 9500
        failed = await ne.diplomacy_action(path, 202, "leila", "gift", now=2_000_000_001)
        assert not failed["ok"] and failed["error"] == "no cash"
        assert await _scalar(path, "SELECT cash FROM characters WHERE telegram_id=202") == 100
        first = await ne.diplomacy_action(path, 101, "rustam", "respect", now=2_000_000_010)
        second = await ne.diplomacy_action(path, 101, "rustam", "respect", now=2_000_000_011)
        assert first["ok"] and not second["ok"] and second["error"] == "cooldown"

        # War is an explicit decision available only after relations turn negative.
        neutral_war = await ne.diplomacy_action(path, 101, "marco", "declare_war", now=2_000_000_020)
        assert not neutral_war["ok"] and neutral_war["error"] == "war requires negative relation"
        insult = await ne.diplomacy_action(path, 101, "marco", "insult", now=2_000_000_021)
        assert insult["ok"] and insult["relation"] < 0 and insult["pact"] == "none"
        war = await ne.diplomacy_action(path, 101, "marco", "declare_war", now=2_000_000_922)
        assert war["ok"] and war["pact"] == "war" and war["relation"] == -100
        async with aiosqlite.connect(path) as db:
            await db.execute(
                "INSERT INTO player_businesses VALUES(101,'pizza',0,0,'ok',0,0,1,0,NULL)"
            )
            await db.execute(
                "INSERT INTO business_property_owners VALUES(?,?,?,?,?)",
                ("pizza", 101, "Test player", 2_000_000_922, 0),
            )
            await db.execute(
                "UPDATE npc_empire_player_wars SET next_attack_at=? WHERE leader_id='marco' AND telegram_id=101",
                (2_000_000_923,),
            )
            await db.commit()
        pressured = await ne.state_for(path, 101, now=2_000_000_923)
        assert pressured["player_war_events"] and pressured["player_war_events"][0]["business_id"] == "pizza"
        assert await _scalar(path, "SELECT blocked_until FROM player_businesses WHERE biz_id='pizza'") == 2_000_001_523
        assert next(e for e in pressured["empires"] if e["leader_id"] == "marco")["war_pressure"]["attacks"] == 1
        compensation = await ne.diplomacy_action(path, 101, "marco", "compensation", now=2_000_000_924)
        assert compensation["ok"] and compensation["relation"] == -70 and compensation["pact"] == "war"
        compensation = await ne.diplomacy_action(path, 101, "marco", "compensation", now=2_000_000_925)
        assert compensation["ok"] and compensation["relation"] == -40 and compensation["pact"] == "truce"
        assert await _scalar(path, "SELECT COUNT(*) FROM npc_empire_player_wars WHERE leader_id='marco' AND telegram_id=101") == 0

        too_far = await ne.prepare_assault(path, 101, "leila", 0, 0, now=2_000_001_000)
        assert not too_far["ok"] and too_far["error"] == "too far"
        assault = await ne.prepare_assault(path, 101, "leila", 26, 16, now=2_000_001_001)
        assert assault["ok"] and 4 <= len(assault["guards"]) <= 14
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
        assert won["ok"] and "coffee" in won["captured_businesses"]
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
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_holdings"
                "(kind,holding_id,leader_id,income,defense,acquired_at) "
                "VALUES('business','bar','rustam',1200,90,?)", (2_000_002_000,))
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
        print("npc_empire: hospital, endless sandbox, neutral reset, comeback, districts and rewards OK")
    finally:
        try:
            os.remove(path)
        except PermissionError:
            pass


if __name__ == "__main__":
    asyncio.run(run())
