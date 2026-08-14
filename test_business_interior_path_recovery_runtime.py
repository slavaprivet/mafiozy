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
    cover_identity = extract_function("_convertedBusinessRaidCoverIdentity")
    cover_blocked = extract_function("_convertedBusinessRaidCoverBlocked")
    cover = extract_function("_convertedBusinessRaidCoverLayout")
    safe_point = extract_function("_businessRaidSafePoint")
    cash_point = extract_function("_businessRaidCashPoint")
    start = WORLD.index("const BUSINESS_RAID_RECOVERY_CELL")
    end = WORLD.index("function _damageBusinessRaidNpc", start)
    production = WORLD[start:end]
    assert "BUSINESS_RAID_RECOVERY_AFTER_MS=900" in production
    assert "BUSINESS_RAID_RECOVERY_BUILD_GATE_MS=160" in production
    assert "bi._businessRaidRecoveryFlows||(bi._businessRaidRecoveryFlows=[])" in production
    assert "if(cache.length>2)cache.length=2" in production
    assert "new Uint8Array(rows*cols)" in production
    assert "new Int16Array(rows*cols)" in production
    assert "if(!flow)return null" in production
    assert "dr=recovery?.r??target.r-n.r" in production
    for forbidden in ("setTimeout", "setInterval", "document.querySelector", "bi.npcs"):
        assert forbidden not in production

    script = f"""
const NativeU8=Uint8Array,NativeI16=Int16Array;let u8Allocs=0,i16Allocs=0;
globalThis.Uint8Array=class extends NativeU8{{constructor(...args){{super(...args);u8Allocs++;}}}};
globalThis.Int16Array=class extends NativeI16{{constructor(...args){{super(...args);i16Allocs++;}}}};
const operations=['beer_bar','pawnshop','bookmaker','strip_club','gun_shop','chop_shop','poker_club','print_shop'];
let operation='';const property={{get operation_type(){{return operation;}}}};
function _buildingPropertyAt(){{return property;}}
{cover_identity}
{cover_blocked}
{cover}
function _businessInteriorMovementBlocked(bi,r,c,pad=.42){{if(r<pad||c<pad||r>bi.H-pad||c>bi.W-pad)return true;return _convertedBusinessRaidCoverLayout(bi,property).some(q=>Math.abs(r-q.r)<q.d/2+pad&&Math.abs(c-q.c)<q.w/2+pad);}}
function _majorInteriorLineClear(bi,r0,c0,r1,c1){{const distance=Math.hypot(r1-r0,c1-c0),steps=Math.max(1,Math.ceil(distance/.2));for(let i=1;i<steps;i++){{const t=i/steps,r=r0+(r1-r0)*t,c=c0+(c1-c0)*t;if(r<.25||c<.25||r>bi.H-.25||c>bi.W-.25||_businessInteriorMovementBlocked(bi,r,c,.12))return false;}}return true;}}
{safe_point}
{cash_point}
{production}
operation='beer_bar';const cacheBi={{r:1,c:1,H:12,W:16}},left={{r:5,c:8.09}},right={{r:5,c:8.11}};
const leftA=_businessRaidRecoveryFlow(cacheBi,left,0),leftB=_businessRaidRecoveryFlow(cacheBi,left,0),rightA=_businessRaidRecoveryFlow(cacheBi,right,160),leftC=_businessRaidRecoveryFlow(cacheBi,left,160),rightB=_businessRaidRecoveryFlow(cacheBi,right,160);
const boundary={{builds:cacheBi._businessRaidRecoveryFlowBuilds,hits:cacheBi._businessRaidRecoveryFlowHits,coverBuilds:cacheBi._businessRaidCoverBuilds,u8Allocs,i16Allocs,size:cacheBi._businessRaidRecoveryFlows.length,same:leftA===leftB&&leftA===leftC&&rightA===rightB}};
const beerKey=leftA.key,beerBlocked=leftA.blocked.reduce((sum,value)=>sum+value,0);operation='print_shop';const changed=_businessRaidRecoveryFlow(cacheBi,left,320),operationSwap={{builds:cacheBi._businessRaidRecoveryFlowBuilds,coverBuilds:cacheBi._businessRaidCoverBuilds,u8Allocs,i16Allocs,keyChanged:changed.key!==beerKey,blockedChanged:changed.blocked.reduce((sum,value)=>sum+value,0)!==beerBlocked}};
const otherBi={{r:2,c:2,H:12,W:16}};_businessRaidRecoveryFlow(otherBi,left,0);const separate={{builds:otherBi._businessRaidRecoveryFlowBuilds,coverBuilds:otherBi._businessRaidCoverBuilds,u8Allocs,i16Allocs}};
operation='beer_bar';const fallbackBi={{r:4,c:4,H:12,W:16}},fallbackSeed={{r:5,c:8.05}},fallbackTarget={{r:5,c:8.65}};_businessRaidRecoveryFlow(fallbackBi,fallbackSeed,0);const fallbackActor={{id:'fallback',raidRosterId:'fallback',r:9,c:8,speed:1.25,walkPhase:0,_raidGoalKey:'10:17',_raidGoalBest:5,_raidGoalProgressAt:-1000,_raidRecovering:true,_raidRecoveryStageAt:0}},fallbackBefore={{r:fallbackActor.r,c:fallbackActor.c}};_businessRaidMoveToward(fallbackBi,fallbackActor,fallbackTarget,.05,50);const fallback={{builds:fallbackBi._businessRaidRecoveryFlowBuilds,gated:fallbackBi._businessRaidRecoveryFlowGated||0,cacheSize:fallbackBi._businessRaidRecoveryFlows.length,moved:Math.hypot(fallbackActor.r-fallbackBefore.r,fallbackActor.c-fallbackBefore.c)}};
operation='beer_bar';const thrashBi={{r:3,c:3,H:12,W:16}},thrashTargets=[8.05,8.35,8.65].map(c=>({{r:5,c}}));for(let frame=0;frame<40;frame++)_businessRaidRecoveryFlow(thrashBi,thrashTargets[frame%3],frame*50);const thrash={{builds:thrashBi._businessRaidRecoveryFlowBuilds,hits:thrashBi._businessRaidRecoveryFlowHits||0,gated:thrashBi._businessRaidRecoveryFlowGated||0,lastMs:thrashBi._businessRaidRecoveryBuildLastMs,maxMs:thrashBi._businessRaidRecoveryBuildMaxMs}};
const results=[];let earlyRecoveries=0,maxStep=0,maxMs=0;
for(const op of operations){{operation=op;const bi={{r:1,c:1,H:12,W:16}},target=_businessRaidCashPoint(bi),actors=Array.from({{length:4}},(_,i)=>{{const spread=(i-(Math.min(6,i+1)-1)/2)*1.05,point=_businessRaidSafePoint(bi,9.95+(i%2)*.85,8+spread);return {{id:`${{op}}:${{i}}`,raidRosterId:`${{op}}:${{i}}`,r:point.r,c:point.c,speed:1.25,walkPhase:0}};}});let arrived=0,elapsed=0;
  for(let frame=0;frame<2400;frame++){{const now=frame*50;for(const actor of actors){{if(actor.arrived)continue;const before={{r:actor.r,c:actor.c}};_businessRaidMoveToward(bi,actor,target,.05,now);maxStep=Math.max(maxStep,Math.hypot(actor.r-before.r,actor.c-before.c));if(now<900&&actor._raidRecovering)earlyRecoveries++;if(Math.hypot(actor.r-target.r,actor.c-target.c)<=2.15){{actor.arrived=true;actor.arrivedAt=now;arrived++;}}}}elapsed=now;if(arrived===actors.length)break;}}
  maxMs=Math.max(maxMs,...actors.map(a=>a.arrivedAt||120000));results.push({{op,target,arrived,times:actors.map(a=>a.arrivedAt??null),positions:actors.map(a=>[a.r,a.c]),recoveries:actors.map(a=>a._raidRecoveries||0)}});
}}
console.log(JSON.stringify({{boundary,operationSwap,separate,fallback,thrash,results,earlyRecoveries,maxStep,maxMs}}));
"""
    result = subprocess.run(
        ["node", "-e", script], cwd=ROOT, check=False,
        capture_output=True, text=True, encoding="utf-8",
    )
    assert result.returncode == 0, f"node runtime failed:\n{result.stderr}\n{result.stdout}"
    data = json.loads(result.stdout)
    assert data["boundary"] == {
        "builds": 2, "hits": 3, "coverBuilds": 1,
        "u8Allocs": 2, "i16Allocs": 4, "size": 2, "same": True,
    }
    assert data["operationSwap"] == {
        "builds": 3, "coverBuilds": 2, "u8Allocs": 3,
        "i16Allocs": 6, "keyChanged": True, "blockedChanged": True,
    }
    assert data["separate"] == {
        "builds": 1, "coverBuilds": 1, "u8Allocs": 4, "i16Allocs": 8,
    }
    assert data["fallback"]["builds"] == 1
    assert data["fallback"]["gated"] == 1
    assert data["fallback"]["cacheSize"] == 1
    assert 0 < data["fallback"]["moved"] <= 1.25 * .05 + 1e-9
    assert data["thrash"]["builds"] <= 12, data["thrash"]
    assert data["thrash"]["gated"] > 0, data["thrash"]
    assert 0 <= data["thrash"]["lastMs"] <= data["thrash"]["maxMs"]
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
    print("business interior path recovery: rate gate + 8 authored layouts OK")
