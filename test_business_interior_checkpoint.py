"""Node runtime contract for the same-page business-raid checkpoint."""

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
    names = [
        "_businessInteriorRaidCheckpointIdentity",
        "_businessInteriorRaidCheckpointRoster",
        "_saveBusinessInteriorRaidCheckpoint",
        "_restoreBusinessInteriorRaidCheckpoint",
        "_clearBusinessInteriorRaidCheckpoint",
        "_reconcileBusinessInteriorRaidCheckpoint",
    ]
    helpers = "\n".join(extract_function(name) for name in names)

    exit_body = extract_function("exitBuildingInterior")
    seed_body = extract_function("_seedBusinessInteriorRaid")
    resolve_body = extract_function("_resolveBusinessInteriorRaid")
    assert exit_body.index("_saveBusinessInteriorRaidCheckpoint(bi)") < exit_body.index("_buildingInt = null")
    assert seed_body.index("_restoreBusinessInteriorRaidCheckpoint") < seed_body.index("bi.businessInteriorRaid=state")
    assert seed_body.index("bi.businessInteriorRaid=state") < seed_body.index("if(!state.outcome)")
    assert "if(breached&&!restoredCheckpoint)" in seed_body
    assert "_clearBusinessInteriorRaidCheckpoint(state.activity.token)" in resolve_body
    assert "j.duplicate?'duplicate':'ok'" in resolve_body

    stage_at = WORLD.index("_stagePreviewPlayerBusinessRaid();", WORLD.index("async function loadNpcEmpireState"))
    reconcile_at = WORLD.index("_reconcileBusinessInteriorRaidCheckpoint();", stage_at)
    assert reconcile_at > stage_at
    checkpoint_block = WORLD[WORLD.index("let _businessInteriorRaidCheckpoint=null"):WORLD.index("const _BUSINESS_RAID_TIER_AI")]
    assert "localStorage" not in checkpoint_block and "setInterval" not in checkpoint_block

    script = f"""
const PLAYER_BUSINESS_INTERIOR_MAX_ATTACKERS=8,PLAYER_BUSINESS_INTERIOR_MAX_DEFENDERS=12;
const document={{documentElement:{{dataset:{{}}}}}};
let _businessInteriorRaidCheckpoint=null,_npcEmpireInteriorRaids=[];
function _apartmentOwnedKey(){{return 'apt:one';}}
{helpers}
const row=(id,hp=100)=>({{id,slot:Number(id.slice(1))||0,hp,maxHp:100,casualty:false}});
const activity={{token:'raid:one',apt_key:'apt:one',target_id:'biz:7',expires_at:Date.now()/1000+600}};
const original={{activity,phase:'hold',outcome:'',holdStartedAt:3000,holdMs:20000,holdRoster:'a0',shots:9,hits:4,
  attackerRoster:[row('a0'),row('a1')],defenderRoster:[row('d0')],guardRoster:[row('g0')]}};
const bi={{r:1,c:2,businessInteriorRaid:original,npcs:[
  {{businessRaidSide:'attacker',raidRosterId:'a0',hp:61,dead:false}},
  {{businessRaidSide:'attacker',raidRosterId:'a1',hp:0,dead:true}},
  {{businessRaidSide:'defender',raidRosterId:'d0',hp:55,dead:false}},
  {{businessRaidSide:'defender',raidRosterId:'g0',hp:40,dead:false}}
]}};
const saved=_saveBusinessInteriorRaidCheckpoint(bi,10000);
const fresh={{activity:{{...activity}},phase:'breach',outcome:'',holdStartedAt:0,holdMs:20000,holdRoster:'',shots:0,hits:0,
  attackerRoster:[row('a0'),row('a1')],defenderRoster:[row('d0')],guardRoster:[row('g0')]}};
const restored=_restoreBusinessInteriorRaidCheckpoint({{r:1,c:2}},fresh,40000);
const survival={{a0:fresh.attackerRoster[0],a1:fresh.attackerRoster[1],d0:fresh.defenderRoster[0],g0:fresh.guardRoster[0]}};
const hold={{phase:fresh.phase,elapsed:40000-fresh.holdStartedAt,roster:fresh.holdRoster,shots:fresh.shots,hits:fresh.hits}};
const stable=_restoreBusinessInteriorRaidCheckpoint({{r:1,c:2}},fresh,41000);
const stableElapsed=41000-fresh.holdStartedAt;
const mismatchState={{...fresh,activity:{{...activity,token:'raid:other'}},attackerRoster:[row('a0')],defenderRoster:[],guardRoster:[]}};
const mismatch=_restoreBusinessInteriorRaidCheckpoint({{r:1,c:2}},mismatchState,42000),mismatchCleared=_businessInteriorRaidCheckpoint===null;

const terminal={{...original,phase:'captured',outcome:'captured',holdStartedAt:0,attackerRoster:[row('a0')],defenderRoster:[],guardRoster:[]}};
bi.businessInteriorRaid=terminal;bi.npcs=[];_saveBusinessInteriorRaidCheckpoint(bi,50000);
const terminalFresh={{...terminal,phase:'breach',outcome:'',attackerRoster:[row('a0')],defenderRoster:[],guardRoster:[]}};
const terminalRestored=_restoreBusinessInteriorRaidCheckpoint({{r:1,c:2}},terminalFresh,51000);
_npcEmpireInteriorRaids=[{{token:'raid:one',status:'active'}}];const activeKept=_reconcileBusinessInteriorRaidCheckpoint();
_npcEmpireInteriorRaids=[];const staleKept=_reconcileBusinessInteriorRaidCheckpoint(),staleCleared=_businessInteriorRaidCheckpoint===null;
bi.businessInteriorRaid=terminal;_saveBusinessInteriorRaidCheckpoint(bi,52000);const explicitClear=_clearBusinessInteriorRaidCheckpoint('raid:one');
console.log(JSON.stringify({{saved,restored,survival,hold,stable,stableElapsed,mismatch,mismatchCleared,
  terminalRestored,terminal:{{phase:terminalFresh.phase,outcome:terminalFresh.outcome}},activeKept,staleKept,staleCleared,explicitClear}}));
"""
    result = subprocess.run(
        ["node", "-e", script], cwd=ROOT, check=False,
        capture_output=True, text=True, encoding="utf-8",
    )
    assert result.returncode == 0, f"node runtime failed:\n{result.stderr}\n{result.stdout}"
    data = json.loads(result.stdout)
    assert data["saved"] and data["restored"]
    assert data["survival"]["a0"]["hp"] == 61 and not data["survival"]["a0"]["casualty"]
    assert data["survival"]["a1"]["hp"] == 0 and data["survival"]["a1"]["casualty"]
    assert data["survival"]["d0"]["hp"] == 55 and data["survival"]["g0"]["hp"] == 40
    assert data["hold"] == {"phase": "hold", "elapsed": 7000, "roster": "a0", "shots": 9, "hits": 4}
    assert data["stable"] and data["stableElapsed"] == 7000
    assert not data["mismatch"] and data["mismatchCleared"]
    assert data["terminalRestored"] and data["terminal"] == {"phase": "captured", "outcome": "captured"}
    assert data["activeKept"] and not data["staleKept"] and data["staleCleared"]
    assert data["explicitClear"]


if __name__ == "__main__":
    run()
    print("business interior checkpoint: OK")
