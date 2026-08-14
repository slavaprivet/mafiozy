"""Production runtime sweep for time-based interior raid path recovery."""

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
    cover = extract_function("_convertedBusinessRaidCoverLayout")
    safe_point = extract_function("_businessRaidSafePoint")
    cash_point = extract_function("_businessRaidCashPoint")
    start = WORLD.index("const BUSINESS_RAID_RECOVERY_CELL")
    end = WORLD.index("function _damageBusinessRaidNpc", start)
    production = WORLD[start:end]
    assert "BUSINESS_RAID_RECOVERY_AFTER_MS=900" in production
    assert "bi._businessRaidRecoveryFlow?.key===key" in production
    assert "new Uint8Array(rows*cols)" in production
    assert "new Int16Array(rows*cols)" in production
    for forbidden in ("setTimeout", "setInterval", "document.querySelector", "bi.npcs"):
        assert forbidden not in production

    script = f"""
const operations=['beer_bar','pawnshop','bookmaker','strip_club','gun_shop','chop_shop','poker_club','print_shop'];
let operation='';const property={{get operation_type(){{return operation;}}}};
function _buildingPropertyAt(){{return property;}}
{cover}
function _businessInteriorMovementBlocked(bi,r,c,pad=.42){{if(r<pad||c<pad||r>bi.H-pad||c>bi.W-pad)return true;return _convertedBusinessRaidCoverLayout(bi,property).some(q=>Math.abs(r-q.r)<q.d/2+pad&&Math.abs(c-q.c)<q.w/2+pad);}}
function _majorInteriorLineClear(bi,r0,c0,r1,c1){{const distance=Math.hypot(r1-r0,c1-c0),steps=Math.max(1,Math.ceil(distance/.2));for(let i=1;i<steps;i++){{const t=i/steps,r=r0+(r1-r0)*t,c=c0+(c1-c0)*t;if(r<.25||c<.25||r>bi.H-.25||c>bi.W-.25||_businessInteriorMovementBlocked(bi,r,c,.12))return false;}}return true;}}
{safe_point}
{cash_point}
{production}
const results=[];let earlyRecoveries=0,maxStep=0,maxMs=0;
for(const op of operations){{operation=op;const bi={{r:1,c:1,H:12,W:16}},target=_businessRaidCashPoint(bi),actors=Array.from({{length:4}},(_,i)=>{{const spread=(i-(Math.min(6,i+1)-1)/2)*1.05,point=_businessRaidSafePoint(bi,9.95+(i%2)*.85,8+spread);return {{id:`${{op}}:${{i}}`,raidRosterId:`${{op}}:${{i}}`,r:point.r,c:point.c,speed:1.25,walkPhase:0}};}});let arrived=0,elapsed=0;
  for(let frame=0;frame<2400;frame++){{const now=frame*50;for(const actor of actors){{if(actor.arrived)continue;const before={{r:actor.r,c:actor.c}};_businessRaidMoveToward(bi,actor,target,.05,now);maxStep=Math.max(maxStep,Math.hypot(actor.r-before.r,actor.c-before.c));if(now<900&&actor._raidRecovering)earlyRecoveries++;if(Math.hypot(actor.r-target.r,actor.c-target.c)<=2.15){{actor.arrived=true;actor.arrivedAt=now;arrived++;}}}}elapsed=now;if(arrived===actors.length)break;}}
  maxMs=Math.max(maxMs,...actors.map(a=>a.arrivedAt||120000));results.push({{op,target,arrived,times:actors.map(a=>a.arrivedAt??null),positions:actors.map(a=>[a.r,a.c]),recoveries:actors.map(a=>a._raidRecoveries||0)}});
}}
console.log(JSON.stringify({{results,earlyRecoveries,maxStep,maxMs}}));
"""
    result = subprocess.run(
        ["node", "-e", script], cwd=ROOT, check=False,
        capture_output=True, text=True, encoding="utf-8",
    )
    assert result.returncode == 0, f"node runtime failed:\n{result.stderr}\n{result.stdout}"
    data = json.loads(result.stdout)
    assert [row["op"] for row in data["results"]] == [
        "beer_bar", "pawnshop", "bookmaker", "strip_club",
        "gun_shop", "chop_shop", "poker_club", "print_shop",
    ]
    assert all(row["arrived"] == 4 for row in data["results"]), data["results"]
    assert data["earlyRecoveries"] == 0
    assert data["maxStep"] <= 1.25 * .05 + 1e-9
    assert data["maxMs"] < 120_000


if __name__ == "__main__":
    run()
    print("business interior path recovery: 8 authored layouts OK")
