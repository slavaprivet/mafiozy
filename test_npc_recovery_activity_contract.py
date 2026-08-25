"""A recovery deadline must suppress the physical player-raid order."""

import asyncio
import importlib
import os
import tempfile

import aiosqlite

import npc_empire as ne
from test_npc_empire import _base_db
from test_npc_raid_target_memory import _create, _row, _targets


async def run():
    fd, path = tempfile.mkstemp(prefix="npc_recovery_activity_", suffix=".db")
    os.close(fd)
    now = 2_720_000_000
    passed = []
    try:
        await _base_db(path)
        async with aiosqlite.connect(path) as db:
            await db.executescript("""
                CREATE TABLE gang_members(
                    id INTEGER PRIMARY KEY,telegram_id INTEGER,current_hp INTEGER);
                CREATE TABLE apartments_owned(
                    telegram_id INTEGER,apt_key TEXT PRIMARY KEY,price INTEGER,bought_at INTEGER,
                    property_kind TEXT,operation_type TEXT,area INTEGER,income_per_minute INTEGER,
                    last_income_at INTEGER DEFAULT 0);
            """)
            await db.executemany(
                "INSERT INTO apartments_owned"
                "(telegram_id,apt_key,price,bought_at,property_kind,operation_type,area,income_per_minute) "
                "VALUES(101,?,?,?,'business','pawnshop',24,120)",
                [("tile:6,36", 20000, now - 100),
                 ("tile:6,46", 18000, now - 100)])
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_relations"
                "(leader_id,telegram_id,score,pact,last_action_at) "
                "VALUES('leila',101,-100,'war',?)", (now - 100,))
            await db.execute(
                "UPDATE npc_empires SET members=20,strength=420,treasury=80000 "
                "WHERE leader_id='leila'")
            await db.execute(
                "INSERT OR REPLACE INTO npc_empire_player_wars"
                "(leader_id,telegram_id,next_attack_at,attacks,last_business_id,last_attack_at) "
                "VALUES('leila',101,?,0,'',0)", (now + 99999,))
            await db.commit()

        targets = await _targets(path)
        first = next(item for item in targets if item["ref"] == "building:0,3")
        raid = await _create(path, 101, "leila", first, 0, now)
        resolved_at = now + ne.PLAYER_INTERIOR_RAID_MIN_SECONDS
        defended = await ne.resolve_interior_raid(
            path, 101, raid["token"], raid["apt_key"], "defended",
            attacker_casualties=list(range(raid["force"])),
            defender_casualties=[], guard_casualties=[], now=resolved_at)
        assert defended["ok"] and not defended.get("duplicate")
        passed.append("real-defended-raid")

        recovery_state = await ne.state_for(path, 101, now=resolved_at + 1)
        leila = next(item for item in recovery_state["empires"]
                     if item["leader_id"] == "leila")
        assert leila["war_pressure"]["recovery"]["state"] == "regrouping"
        assert leila["activity"]["kind"] == "recover"
        assert leila["activity"]["phase"] == "regroup"
        assert leila["activity"]["created_at"] == resolved_at
        assert "target_id" not in leila["activity"]
        assert not recovery_state["interior_raids"]
        passed.append("no-immediate-reattack")

        deadline_before = int(leila["war_pressure"]["next_attack_at"])
        second_poll = await ne.state_for(path, 101, now=resolved_at + 2)
        second_leila = next(item for item in second_poll["empires"]
                            if item["leader_id"] == "leila")
        assert second_leila["activity"]["created_at"] == resolved_at
        assert int(second_leila["war_pressure"]["next_attack_at"]) == deadline_before
        passed.append("sequential-generation-stable")

        reloaded = importlib.reload(ne)
        reconnect = await reloaded.state_for(path, 101, now=resolved_at + 3)
        reconnect_leila = next(item for item in reconnect["empires"]
                               if item["leader_id"] == "leila")
        assert reconnect_leila["activity"]["kind"] == "recover"
        assert reconnect_leila["activity"]["created_at"] == resolved_at
        assert reconnect_leila["war_pressure"]["recovery"]["state"] == "regrouping"
        passed.append("reload-stable")

        concurrent = await asyncio.gather(*(
            reloaded.state_for(path, 101, now=resolved_at + offset)
            for offset in (4, 5, 6)))
        concurrent_leila = [next(item for item in state["empires"]
                                 if item["leader_id"] == "leila")
                            for state in concurrent]
        assert {item["activity"]["created_at"] for item in concurrent_leila} == {resolved_at}
        assert {int(item["war_pressure"]["next_attack_at"])
                for item in concurrent_leila} == {deadline_before}
        passed.append("concurrent-generation-stable")

        deadline = int((await _row(
            path, "SELECT next_attack_at FROM npc_empire_player_wars "
                  "WHERE leader_id='leila' AND telegram_id=101"))["next_attack_at"])
        resumed = await reloaded.state_for(path, 101, now=deadline)
        resumed_leila = next(item for item in resumed["empires"]
                             if item["leader_id"] == "leila")
        assert "recovery" not in resumed_leila["war_pressure"]
        assert resumed_leila["activity"]["kind"] == "player_business_raid"
        assert resumed_leila["activity"]["target_reason"] == "remembered-defeat"
        assert resumed_leila["activity"]["target_id"] == "0,4"
        assert len(resumed["interior_raids"]) == 1
        world = open("world.html", encoding="utf-8").read()
        assert "${_npcEmpireEsc(recovery.label||'Семья перегруппировывается" in world
        assert "${escapeHtml(recovery.label" not in world
        assert "kind==='recover'?(+empire?.war_pressure?.next_attack_at||+value.created_at||0)" in world
        passed.append("deadline-resumes-remembered-target")

        assert len(passed) == 6, passed
        print("recovery activity contract: 6/6 gates OK — " + ", ".join(passed))
    finally:
        os.unlink(path)


if __name__ == "__main__":
    asyncio.run(run())
