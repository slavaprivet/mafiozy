"""Runtime contract for honest player asset raid presentation and lifecycle."""

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
    target = extract_function("_playerBusinessRaidTargetName")
    presentation = extract_function("_playerRaidThreatPresentation")
    active = extract_function("_playerBusinessRaidActivityIsActive")
    compass = extract_function("_playerBusinessRaidCompass")
    render = extract_function("_renderPlayerBusinessRaidHud")
    script = f"""
const BUSINESS_POIS=[];
const _playerBuildingProperties=[];
const PLAYER_BUILDING_OPERATIONS={{}};
const ISO_Y=.55;
{target}
{presentation}
{active}
{compass}
const nodes={{b:{{}},span:{{}},small:{{}},em:{{}}}};
const classes=new Set(['show']);
const hud={{dataset:{{}},classList:{{add:x=>classes.add(x),remove:x=>classes.delete(x)}},querySelector:q=>nodes[q==='b'?'b':q==='span'?'span':q==='small'?'small':'em']}};
function _ensurePlayerBusinessRaidHud(){{return hud;}}
let _activePlayerBusinessRaidAlert=null;
{render}
const empire={{hq_key:'7,9'}};
const collision={{token:'b1',target_id:'7,9',target_kind:'building',business_label:'Печатный цех',objective:'first-close',expires_at:2000}};
const explicitHq={{...collision,token:'h1',target_kind:'hq',business_label:'',objective:'followup-capture'}};
const businessTarget=_playerBusinessRaidTargetName(empire,collision);
const hqTarget=_playerBusinessRaidTargetName(empire,explicitHq);
const business=_playerRaidThreatPresentation(collision,businessTarget);
const hq=_playerRaidThreatPresentation(explicitHq,hqTarget);
const compassAlert={{key:'b1',r:10,c:10,name:'Печатный цех',plan:{{breachPhase:'breach',objective:'followup-capture'}}}};
const compassDirections=[[10,9],[9,9],[9,10],[9,11],[10,11],[11,11],[11,10],[11,9]].map(([r,c])=>_playerBusinessRaidCompass(compassAlert,r,c).direction);
const compassCapture=_playerBusinessRaidCompass(compassAlert,10,9);
const compassApproach=_playerBusinessRaidCompass({{...compassAlert,plan:{{breachPhase:'approach',objective:'first-close'}}}},10,9);
const compassHere=_playerBusinessRaidCompass(compassAlert,10,10);
_activePlayerBusinessRaidAlert={{key:'h1',title:hq.title,name:hqTarget.name,boss:'Марко',family:'Семья',presentation:hq,plan:{{profileLabel:'Расчёт',objectiveLabel:'ЗАХВАТИТЬ',decision:{{summary:'короткий маршрут'}}}}}};
_renderPlayerBusinessRaidHud({{assigned_object_guards:3,assigned_free_squad:6}});
const shown={{title:nodes.b.textContent,counts:nodes.small.textContent,visible:classes.has('show')}};
_activePlayerBusinessRaidAlert=null;_renderPlayerBusinessRaidHud(null);
console.log(JSON.stringify({{businessTarget,hqTarget,business,hq,compassDirections,compassCapture,compassApproach,compassHere,shown,hidden:!classes.has('show'),active:_playerBusinessRaidActivityIsActive(collision,1500),resolved:_playerBusinessRaidActivityIsActive({{...collision,status:'resolved'}},1500),expired:_playerBusinessRaidActivityIsActive(collision,2000)}}));
"""
    result = subprocess.run(
        ["node", "-e", script], cwd=ROOT, check=False,
        capture_output=True, text=True, encoding="utf-8",
    )
    assert result.returncode == 0, f"node failed:\n{result.stderr}\n{result.stdout}"
    data = json.loads(result.stdout)
    assert data["businessTarget"] == {"hq": False, "name": "Печатный цех"}
    assert data["business"]["assetKind"] == "business"
    assert data["business"]["title"] == "Ваш бизнес атакуют"
    assert data["hqTarget"] == {"hq": True, "name": "Штаб"}
    assert data["hq"]["assetKind"] == "hq" and data["hq"]["capture"]
    assert data["hq"]["title"] == "Ваш штаб захватывают"
    assert data["hq"]["markerLabel"] == "ВАШ ШТАБ ЗАХВАТЫВАЮТ"
    assert data["compassDirections"] == ["↘", "↓", "↙", "←", "↖", "↑", "↗", "→"]
    assert data["compassCapture"]["state"] == "ЗАХВАТЫВАЮТ"
    assert "ПЕЧАТНЫЙ ЦЕХ" in data["compassCapture"]["text"]
    assert data["compassApproach"]["state"] == "ПРИБЛИЖАЮТСЯ"
    assert data["compassHere"]["directionName"] == "ВЫ НА МЕСТЕ"
    assert data["shown"] == {
        "title": "🚨 Ваш штаб захватывают · Штаб",
        "counts": "Атака 6 · защита 3 · цель: ЗАХВАТИТЬ · короткий маршрут",
        "visible": True,
    }
    assert data["hidden"] and data["active"]
    assert not data["resolved"] and not data["expired"]


if __name__ == "__main__":
    run()
    print("player asset threat runtime: honest business/HQ attack/capture lifecycle OK")
