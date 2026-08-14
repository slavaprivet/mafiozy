"""Runtime regression for boss/empire shots reaching the player before damage."""

from pathlib import Path
import json
import subprocess


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


def extract_function(name: str) -> str:
    start = WORLD.index(f"function {name}(")
    brace = WORLD.index("{", start)
    depth = 0
    for pos in range(brace, len(WORLD)):
        if WORLD[pos] == "{":
            depth += 1
        elif WORLD[pos] == "}":
            depth -= 1
            if depth == 0:
                return WORLD[start:pos + 1]
    raise AssertionError(f"unterminated function {name}")


def run() -> None:
    queue = extract_function("_queueEmpirePlayerBallisticHit")
    think_start = WORLD.index("function _empirePlayerCombatThink")
    think_end = WORLD.index("function _empireActivityLabel", think_start)
    think = WORLD[think_start:think_end]
    assert "Math.max(11.5,Math.min(15.5" in think
    assert "targetActor:hit?player:null" in think
    assert "_queueEmpirePlayerBallisticHit" in think
    assert "if(hit)_applyEmpirePlayerWeaponHit" not in think

    script = f"""
let clock=1000, queued=null, hp=100, impacts=0;
const performance={{now:()=>clock}}, player={{r:0,c:10}}, document={{documentElement:{{dataset:{{}}}}}};
let myDead=false,_buildingInt=null,_bankInt=null;
const shooter={{_empirePlayerWar:true,dead:false,leader:'boss'}};
function _empireLeaderIdOf(n){{return n.leader;}}
function _empireCombatReady(n){{return !!n&&!n.dead;}}
function spawnImpact(){{impacts++;}}
function _applyEmpirePlayerWeaponHit(n,damage){{hp-=damage;}}
function setTimeout(fn,ms){{queued={{fn,ms}};return 1;}}
{queue}
const flight=_queueEmpirePlayerBallisticHit(shooter,17,{{}},'rifle',{{r:0,c:0}},15.5,clock);
const before={{hp,impacts,flight,delay:queued.ms}};
clock+=queued.ms;queued.fn();
console.log(JSON.stringify({{before,after:{{hp,impacts}}}}));
"""
    result = subprocess.run(
        ["node", "-e", script], cwd=ROOT, check=True,
        capture_output=True, text=True, encoding="utf-8"
    )
    data = json.loads(result.stdout)
    assert data["before"]["hp"] == 100
    assert data["before"]["impacts"] == 0
    assert data["before"]["delay"] == data["before"]["flight"]
    assert data["before"]["delay"] >= 80
    assert data["after"] == {"hp": 83, "impacts": 1}


if __name__ == "__main__":
    run()
    print("empire player ballistic arrival: OK")
