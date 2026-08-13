"""Regression contract for visible and persistent Bellini/Moretti recruitment."""

import asyncio
import os
import tempfile
from pathlib import Path

import aiosqlite
import npc_empire


WORLD = (Path(__file__).resolve().parent / "world.html").read_text(encoding="utf-8")
BOT = (Path(__file__).resolve().parent / "mafiozi_bot.py").read_text(encoding="utf-8")
PREVIEW = (Path(__file__).resolve().parent / "_preview_ws_server.py").read_text(encoding="utf-8")


async def run() -> None:
    assert "EMPIRE_STREET_RECRUIT_R=5.6" in WORLD
    assert "EMPIRE_POPIN_SAFE_R=40" in WORLD
    assert "dataset.empirePopinBlocked" in WORLD
    assert "function _empireHiddenCrewOrigin(point,leader,slot)" in WORLD
    assert "dataset.empireCrewStaged" in WORLD
    assert "function _findEmpireStreetRecruit(leader)" in WORLD
    assert "if(!zone?.is_city_gang)continue" in WORLD
    assert "raw==='yellow'||raw==='moretti'" in WORLD
    assert "raw==='purple'||raw==='bellini'" in WORLD
    assert "function _adoptEmpireStreetRecruit" in WORLD
    assert "zone.bots.splice(at,1);_empireRecruitedBotIds.add(sourceId)" in WORLD
    assert "_empireStreetRecruit:true" in WORLD
    assert "Я с вами, босс!" in WORLD
    assert "if(crew?._empireStreetRecruit)return" in WORLD
    assert "point=_empireHiddenCrewOrigin(origin,leader,slot)" in WORLD
    assert "dataset.empireStreetRecruits" in WORLD
    assert "${_empireLeaderIdOf(n)}>${_empireLeaderIdOf(target)}:tracked-${hit?1:0}" in WORLD
    assert WORLD.count("!_empireRecruitedBotIds.has(String(b.id))") == 2
    assert "ПЕРЕГОВОРЫ · босс предлагает вступить" in WORLD
    assert "Мне нужны надёжные люди. Пойдёшь со мной?" in WORLD
    assert "function _confirmEmpireStreetRecruit" in WORLD
    assert "/street-recruit`" in WORLD
    assert "joined:${leader._specialistId}" in WORLD
    assert "recruit_street_fighter" in BOT and "/street-recruit'" in BOT
    assert "npc_empire_street_recruit" in PREVIEW

    fd, path = tempfile.mkstemp(prefix="street_recruit_", suffix=".db"); os.close(fd)
    try:
        await npc_empire.ensure_schema(path)
        async with aiosqlite.connect(path) as db:
            old_members = (await (await db.execute(
                "SELECT members FROM npc_empires WHERE leader_id='marco'"
            )).fetchone())[0]
        first = await npc_empire.recruit_street_fighter(
            path, "marco", "city-yellow-77", "moretti", now=2_000_000_010)
        assert first["ok"] and first["members"] == old_members + 1
        duplicate = await npc_empire.recruit_street_fighter(
            path, "marco", "city-yellow-77", "moretti", now=2_000_000_020)
        assert duplicate["ok"] and duplicate["duplicate"] and duplicate["members"] == first["members"]
        second = await npc_empire.recruit_street_fighter(
            path, "marco", "city-purple-78", "bellini", now=2_000_000_021)
        assert second["ok"] and second["members"] == first["members"] + 1
        async with aiosqlite.connect(path) as db:
            event = await (await db.execute(
                "SELECT kind,summary FROM npc_empire_events WHERE leader_id='marco' ORDER BY id DESC LIMIT 1"
            )).fetchone()
        assert event[0] == "street_recruit" and "вступил" in event[1]
    finally:
        os.remove(path)
    print("npc_empire_city_recruitment: physical recruits and pop-in guard OK")


if __name__ == "__main__":
    asyncio.run(run())
