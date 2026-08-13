"""Three-pass behavioral verification for the street boss decision engine."""

import json
import re
import subprocess
from pathlib import Path

import npc_empire as ne


WORLD = (Path(__file__).resolve().parent / "world.html").read_text(encoding="utf-8")


def _extract(name: str) -> str:
    match = re.search(
        rf"function {re.escape(name)}\([^\n]*\)\{{.*?^\}}",
        WORLD,
        flags=re.MULTILINE | re.DOTALL,
    )
    assert match, f"missing JavaScript function {name}"
    return match.group(0)


def _node_json(source: str):
    result = subprocess.run(
        ["node", "-e", source], capture_output=True, text=True, check=True
    )
    return json.loads(result.stdout)


def run() -> None:
    chooser = _extract("_empireChoosePlayerOrder")
    scenarios = """
const doctrines={
 mobile:{id:'mobile',orders:['flank','press','withdraw'],retreat_hp:.22},
 fortress:{id:'fortress',orders:['hold','regroup','focus'],retreat_hp:.28},
 duelist:{id:'duelist',orders:['press','focus','hold'],retreat_hp:.12}
};
const base={bossAlive:true,bossHealth:.8,power:1.1,spread:2,playerHealth:.8,weaponBand:'medium',distance:6};
const out={
 sniper:_empireChoosePlayerOrder(doctrines.mobile,{...base,weaponBand:'long',distance:11}),
 broken:_empireChoosePlayerOrder(doctrines.fortress,{...base,spread:8,power:.9}),
 wounded:_empireChoosePlayerOrder(doctrines.mobile,{...base,bossHealth:.08,power:.5}),
 finisher:_empireChoosePlayerOrder(doctrines.duelist,{...base,playerHealth:.2,power:2.8})
 ,learned:_empireChoosePlayerOrder(doctrines.duelist,{...base,lesson:{incoming:80,shots:8,hits:2,casualties:2,failureStreak:3,lastFailedOrder:'press'}})
 ,patient:_empireChoosePlayerOrder({id:'neutral',orders:['hold','regroup','flank','focus','press','withdraw'],retreat_hp:.2},{...base,mindset:{patience:.98,adaptability:.2,courage:.15}})
 ,brave:_empireChoosePlayerOrder({id:'neutral',orders:['hold','regroup','flank','focus','press','withdraw'],retreat_hp:.2},{...base,mindset:{patience:.15,adaptability:.2,courage:.98}})
};
console.log(JSON.stringify(out));
"""
    decisions = _node_json(chooser + scenarios)
    assert decisions["sniper"]["type"] == "flank"
    assert decisions["broken"]["type"] == "regroup"
    assert decisions["wounded"]["type"] == "withdraw"
    assert decisions["finisher"]["type"] in {"focus", "press"}
    assert decisions["learned"]["type"] != "press"
    assert "change_failed_plan" in decisions["learned"]["reason"]
    assert decisions["patient"]["type"] == "hold"
    assert decisions["brave"]["type"] == "press"
    assert all(decisions[key]["reason"] != "doctrine"
               for key in ("sniper", "broken", "wounded", "finisher", "learned"))

    for marker in (
        "_empireChoosePlayerOrder", "weaponBand", "formation_broken",
        "counter_melee", "break_range", "avoid_heavy",
        "МОБИЛЬНЫЙ ОБХОД", "ПОДАВЛЕНИЕ", "ДУЭЛЬНЫЙ НАТИСК",
        "СВЯЗЬ СОРВАНА", "ВЫТЯНУТЬ ИЗ УКРЫТИЯ",
        "_empireCombatLessons", "_empireRecordIncoming",
        "_empireRecordAttack", "_empireEvaluatePreviousOrder",
        "under_fire", "poor_accuracy", "change_failed_plan",
        "NPC_EMPIRE_MINDSETS", "_empireMindsetOf",
        "empireAssaultMindset", "МЫШЛЕНИЕ ·",
    ):
        assert marker in WORLD

    print("boss intelligence pass 1: threat scoring and signature tactics OK")
    print("boss intelligence pass 2: bounded combat learning and plan switching OK")
    assert len(ne.BOSS_MINDSETS) == 19
    assert set(ne.BOSS_MINDSETS) == set(ne.PROFILE_BY_ID)
    fingerprints = {
        (mind["patience"], mind["adaptability"], mind["courage"])
        for mind in ne.BOSS_MINDSETS.values()
    }
    assert len(fingerprints) == 19
    assert all(plan["mindset"] == ne.BOSS_MINDSETS[leader]
               for leader, plan in ((leader, ne.boss_doctrine(leader))
                                    for leader in ne.BOSS_MINDSETS))
    print("boss intelligence pass 3: 19 unique cognitive profiles and HQ scaling OK")


if __name__ == "__main__":
    run()
