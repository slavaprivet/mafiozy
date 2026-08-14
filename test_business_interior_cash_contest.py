"""Runtime contract for contesting the business-raid cashier objective."""

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def extract_function(name: str) -> str:
    start = WORLD.index(f"function {name}(")
    brace = WORLD.index("{", start)
    depth = 0
    quote = None
    escaped = False
    for pos in range(brace, len(WORLD)):
        char = WORLD[pos]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            continue
        if char in "'\"`":
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return WORLD[start:pos + 1]
    raise AssertionError(f"unterminated {name}")


def run() -> None:
    cash_phase = extract_function("_businessRaidCashPhase")
    contest_combat = extract_function("_businessRaidContestCombat")
    update = extract_function("_updateBusinessInteriorRaid")
    assert "_businessRaidCashPhase(state,liveAttackers,cash,now)" in update
    assert "_businessRaidContestCombat(bi,state,n,now,dt)" in update

    script = f"""
let myDead=false,player={{r:8,c:8}},moves=0,shots=0;
const document={{documentElement:{{dataset:{{}}}}}};
function _majorInteriorLineClear(){{return false;}}
function _businessRaidMoveToward(){{moves++;}}
function _interiorGuardWeaponAi(){{return {{range:8}};}}
function _fireBusinessRaidRound(){{shots++;}}
function showEventBanner(){{}}
{cash_phase}
{contest_combat}
const cash={{r:2.8,c:8}},attackers=[{{id:'a',raidRosterId:'a',r:2.8,c:8,weapon:'rifle',_nextShotAt:0}}];
const fresh=()=>({{playerDefends:true,phase:'advance',holdStartedAt:0,holdRoster:'',holdMs:20000,outcome:''}});
const state=fresh();
_businessRaidCashPhase(state,attackers,cash,0);
_businessRaidCashPhase(state,attackers,cash,10000);
player.r=2.8;_businessRaidCashPhase(state,attackers,cash,10000);
const contested={{phase:state.phase,start:state.holdStartedAt,roster:state.holdRoster,outcome:state.outcome}};
_businessRaidContestCombat({{}},state,attackers[0],10000,.05);
const blocked={{moves,shots}};
player.r=8;_businessRaidCashPhase(state,attackers,cash,11000);
_businessRaidCashPhase(state,attackers,cash,30999);
const before={{phase:state.phase,outcome:state.outcome,start:state.holdStartedAt}};
_businessRaidCashPhase(state,attackers,cash,31000);
const after={{phase:state.phase,outcome:state.outcome}};
const dead=fresh();player.r=2.8;myDead=true;
_businessRaidCashPhase(dead,attackers,cash,0);
_businessRaidCashPhase(dead,attackers,cash,20000);
console.log(JSON.stringify({{contested,blocked,before,after,dead:{{phase:dead.phase,outcome:dead.outcome}}}}));
"""
    result = subprocess.run(
        ["node", "-e", script], cwd=ROOT, check=False,
        capture_output=True, text=True, encoding="utf-8",
    )
    assert result.returncode == 0, f"node runtime failed:\n{result.stderr}\n{result.stdout}"
    data = json.loads(result.stdout)
    assert data["contested"] == {
        "phase": "contested", "start": 0, "roster": "", "outcome": "",
    }
    assert data["blocked"] == {"moves": 1, "shots": 0}
    assert data["before"] == {"phase": "hold", "outcome": "", "start": 11000}
    assert data["after"] == {"phase": "captured", "outcome": "captured"}
    assert data["dead"] == {"phase": "captured", "outcome": "captured"}


if __name__ == "__main__":
    run()
    print("business interior cash contest: OK")
