"""Node/client contract for event-only coalesced casualty acknowledgement."""

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
BOT = (ROOT / "mafiozi_bot.py").read_text(encoding="utf-8")


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
    payload = extract_function("_businessInteriorRaidCasualtyPayload")
    checkpoint = "async " + extract_function("_checkpointBusinessInteriorRaidCasualties")
    damage = extract_function("_damageBusinessRaidNpc")
    assert "_checkpointBusinessInteriorRaidCasualties(bi,state)" in damage
    assert "keepalive:true" in checkpoint
    assert "setInterval" not in checkpoint and "setTimeout" not in checkpoint
    assert "/interior-raid/casualties" in checkpoint
    assert "h_npc_empire_interior_raid_casualties" in BOT
    assert "player not in target interior" in BOT
    assert "'/npc-empires/{uid}/interior-raid/casualties'" in BOT

    script = f"""
const document={{documentElement:{{dataset:{{}}}}}},QP={{api:'https://qa.invalid',uid:'101'}};
function _apartmentOwnedKey(){{return 'business:coffee';}}
let sent=[];
async function fetch(url,options){{sent.push({{url,payload:JSON.parse(options.body),keepalive:options.keepalive}});await Promise.resolve();const version=sent.length;return {{ok:true,json:async()=>({{ok:true,version,duplicate:false}})}};}}
{payload}
{checkpoint}
const row=(id,slot,memberId=null,casualty=false)=>({{id,slot,memberId,casualty}});
const state={{activity:{{token:'raid:1',apt_key:'business:coffee'}},resolved:false,casualtyVersion:0,
 attackerRoster:[row('a0',0,null,true),row('a1',1)],defenderRoster:[row('d11',0,'11')],guardRoster:[row('g21',0,'21')]}};
const bi={{r:1,c:2}},_buildingInt=bi;
const first=_checkpointBusinessInteriorRaidCasualties(bi,state);
state.attackerRoster[1].casualty=true;state.defenderRoster[0].casualty=true;
const coalesced=_checkpointBusinessInteriorRaidCasualties(bi,state);
await Promise.all([first,coalesced]);
console.log(JSON.stringify({{sent,version:state.casualtyVersion,ack:document.documentElement.dataset.businessInteriorRaidCasualtyAck,busy:state.casualtyCheckpointBusy}}));
"""
    result = subprocess.run(
        ["node", "--input-type=module", "-e", script], cwd=ROOT,
        capture_output=True, text=True, encoding="utf-8", check=False,
    )
    assert result.returncode == 0, f"node failed:\n{result.stderr}\n{result.stdout}"
    data = json.loads(result.stdout)
    assert len(data["sent"]) == 2
    assert data["sent"][0]["payload"]["attacker_down_slots"] == [0]
    assert data["sent"][1]["payload"]["attacker_down_slots"] == [0, 1]
    assert data["sent"][1]["payload"]["defender_down_ids"] == ["11"]
    assert all(item["keepalive"] for item in data["sent"])
    assert data["version"] == 2 and data["ack"] == "ok:2:union"
    assert not data["busy"]


if __name__ == "__main__":
    run()
    print("business interior casualty checkpoint: event-only coalesced ACK OK")
