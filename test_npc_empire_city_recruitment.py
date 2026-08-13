"""Regression contract for visible Bellini/Moretti street recruitment."""

from pathlib import Path


WORLD = (Path(__file__).resolve().parent / "world.html").read_text(encoding="utf-8")


def run() -> None:
    assert "EMPIRE_STREET_RECRUIT_R=5.6" in WORLD
    assert "EMPIRE_POPIN_SAFE_R=40" in WORLD
    assert "dataset.empirePopinBlocked" in WORLD
    assert "function _findEmpireStreetRecruit(leader)" in WORLD
    assert "if(!zone?.is_city_gang)continue" in WORLD
    assert "raw==='yellow'||raw==='moretti'" in WORLD
    assert "raw==='purple'||raw==='bellini'" in WORLD
    assert "function _adoptEmpireStreetRecruit" in WORLD
    assert "zone.bots.splice(at,1);_empireRecruitedBotIds.add(sourceId)" in WORLD
    assert "_empireStreetRecruit:true" in WORLD
    assert "теперь я с вами!" in WORLD
    assert "if(crew?._empireStreetRecruit)return" in WORLD
    assert "const popinSafe=Math.hypot(leader.r-player.r,leader.c-player.c)>=EMPIRE_POPIN_SAFE_R" in WORLD
    assert "popinSafe&&slot<want" in WORLD
    assert "dataset.empireStreetRecruits" in WORLD
    assert WORLD.count("!_empireRecruitedBotIds.has(String(b.id))") == 2
    print("npc_empire_city_recruitment: physical recruits and pop-in guard OK")


if __name__ == "__main__":
    run()
