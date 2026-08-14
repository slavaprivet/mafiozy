"""Runtime contract for bounded one-at-a-time interior raid admission."""

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
    raise AssertionError(name)


def run() -> None:
    admit = extract_function("_businessRaidAdmitOne")
    open_breach = extract_function("_businessRaidOpenBreach")
    update = extract_function("_updateBusinessInteriorRaid")
    seed_start = WORLD.index("function _seedBusinessInteriorRaid")
    seed_end = WORLD.index("function _spawnBusinessInteriorRaidNpc", seed_start)
    seed = WORLD[seed_start:seed_end]
    assert "phase:breached?'breach':'approach'" in seed
    assert "state.attackerReserve.push(...attackerRoster" in seed
    assert "front.forEach" in seed and "state.admission.defender.cap" in seed
    assert "_playerBusinessRaidBreachFor(state.activity)" in update
    assert "_businessRaidOpenBreach(state,breach)" in update
    assert "_businessRaidAdmitOne(bi,state,'attacker'" in update
    assert "_businessRaidAdmitOne(bi,state,'defender'" in update
    for forbidden in ("setTimeout", "setInterval", "createElement", "new Map", ".filter("):
        assert forbidden not in admit

    script = f"""
const document={{documentElement:{{dataset:{{}}}}}};let spawned=[];
function _playerBusinessRaidToken(activity){{return String(activity?.token||'');}}
function _spawnBusinessInteriorRaidNpc(bi,state,row,side,index){{const actor={{id:row.id,businessRaidSide:side,dead:false}};spawned.push({{id:row.id,side,index}});bi.npcs.push(actor);return actor;}}
{admit}
{open_breach}
const rows=(prefix,count)=>Array.from({{length:count}},(_,i)=>({{id:`${{prefix}}${{i}}`,casualty:false}}));
const bi={{H:12,W:16,npcs:[]}},state={{id:'raid',activity:{{token:'raid-token',target_id:'shop'}},breached:false,phase:'approach',playerDefends:true,attackerReserve:rows('a',8),defenderReserve:rows('d',6),attackerIds:new Set(),defenderIds:new Set(),admission:{{attacker:{{cap:4,nextAt:0,seq:0,chain:false}},defender:{{cap:6,nextAt:0,seq:0,chain:false}}}}}};
const calls=[];
function tick(side,live,now){{const before=spawned.length,actor=_businessRaidAdmitOne(bi,state,side,live,now);calls.push({{side,now,added:spawned.length-before,next:state.admission[side].nextAt,seq:state.admission[side].seq,reserve:(side==='attacker'?state.attackerReserve:state.defenderReserve).length,id:actor?.id||''}});return actor;}}
for(let i=0;i<100;i++)tick('attacker',0,i*10);
const approach={{spawned:spawned.length,next:state.admission.attacker.nextAt,seq:state.admission.attacker.seq}};
const wrongToken={{opened:_businessRaidOpenBreach(state,{{token:'other-raid'}}),breached:state.breached,phase:state.phase}};
const exactToken={{opened:_businessRaidOpenBreach(state,{{token:'raid-token'}}),breached:state.breached,phase:state.phase}};
tick('attacker',0,1000);tick('attacker',0,1649);tick('attacker',0,1650);tick('attacker',1,2069);tick('attacker',1,2070);tick('attacker',2,2490);tick('attacker',3,2910);
const firstWave={{ids:spawned.filter(x=>x.side==='attacker').map(x=>x.id),reserve:state.attackerReserve.length,next:state.admission.attacker.nextAt,seq:state.admission.attacker.seq}};
state.attackerReserve[0].casualty=true;tick('attacker',3,3000);tick('attacker',3,3899);tick('attacker',3,3900);
const refill={{ids:spawned.filter(x=>x.side==='attacker').map(x=>x.id),reserve:state.attackerReserve.length,seq:state.admission.attacker.seq}};
tick('defender',5,5000);tick('defender',5,6099);tick('defender',5,6100);tick('defender',6,7000);
const defenders={{ids:spawned.filter(x=>x.side==='defender').map(x=>x.id),reserve:state.defenderReserve.length,seq:state.admission.defender.seq,next:state.admission.defender.nextAt}};
console.log(JSON.stringify({{approach,wrongToken,exactToken,firstWave,refill,defenders,calls,maxPerCall:Math.max(...calls.map(x=>x.added))}}));
"""
    result = subprocess.run(
        ["node", "-e", script], cwd=ROOT, check=False,
        capture_output=True, text=True, encoding="utf-8",
    )
    assert result.returncode == 0, f"node runtime failed:\n{result.stderr}\n{result.stdout}"
    data = json.loads(result.stdout)
    assert data["approach"] == {"spawned": 0, "next": 0, "seq": 0}
    assert data["wrongToken"] == {"opened": False, "breached": False, "phase": "approach"}
    assert data["exactToken"] == {"opened": True, "breached": True, "phase": "breach"}
    assert data["firstWave"] == {
        "ids": ["a0", "a1", "a2", "a3"], "reserve": 4,
        "next": 0, "seq": 4,
    }
    assert data["refill"] == {
        "ids": ["a0", "a1", "a2", "a3", "a5"], "reserve": 2, "seq": 5,
    }
    assert data["defenders"] == {
        "ids": ["d0"], "reserve": 5, "seq": 1, "next": 0,
    }
    assert data["maxPerCall"] == 1
    assert all(call["added"] in (0, 1) for call in data["calls"])


if __name__ == "__main__":
    run()
    print("business interior reinforcement runtime: OK")
