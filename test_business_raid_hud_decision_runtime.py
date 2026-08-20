"""Runtime contract for honest exterior/interior boss-raid HUD decisions."""

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
SERVER = (ROOT / "npc_empire.py").read_text(encoding="utf-8")


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
    decision = extract_function("_playerBusinessRaidDecision")
    plan = extract_function("_playerBusinessRaidPlan")
    phase = extract_function("_businessRaidPhaseLabel")
    script = f"""
function _playerBusinessRaidBreachFor(activity){{return activity.breached?{{token:'t'}}:null;}}
{decision}
{plan}
{phase}
const empire={{leader_name:'Марко',doctrine:{{id:'mobile',label:'Мобильный обход'}}}};
const activity={{objective:'followup-capture',hold_seconds:5,target_reason:'profit-over-risk',raid_policy:{{id:'mobile',value_weight:1.2}},raid_metrics:{{value:438,distance_cost:96,defense_cost:145,risk_tolerance:1.18}}}};
const good=_playerBusinessRaidPlan(empire,activity);
const bad=_playerBusinessRaidDecision(empire,{{target_reason:'<raw>',raid_policy:{{id:'<script>'}},raid_metrics:{{value:'oops',distance_cost:-5,defense_cost:20000,risk_tolerance:99}}}});
const phases={{}};for(const name of ['approach','breach','fight','advance','hold','contested'])phases[name]=_businessRaidPhaseLabel({{phase:name,outcome:''}},12300);phases.defended=_businessRaidPhaseLabel({{phase:'fight',outcome:'defended'}},0);phases.captured=_businessRaidPhaseLabel({{phase:'hold',outcome:'captured'}},0);
console.log(JSON.stringify({{good,bad,phases}}));
"""
    result = subprocess.run(
        ["node", "-e", script], cwd=ROOT, check=False,
        capture_output=True, text=True, encoding="utf-8",
    )
    assert result.returncode == 0, f"node failed:\n{result.stderr}\n{result.stdout}"
    data = json.loads(result.stdout)
    good = data["good"]
    assert good["hold"] == 20 and good["objectiveLabel"] == "ЗАХВАТИТЬ"
    assert good["decision"]["policyId"] == "mobile"
    assert not good["decision"]["policyMismatch"]
    assert good["decision"]["profileLabel"] == "Мобильный обход"
    assert good["decision"]["reasonId"] == "profit-over-risk"
    assert good["decision"]["summary"] == (
        "доход окупает риск · доход +438 · путь −96 · защита −145 · риск ×1.18"
    )
    bad = data["bad"]
    assert bad["policyId"] == "script" and bad["policyMismatch"]
    assert bad["profileLabel"] == "Серверный расчёт"
    assert bad["reasonId"] == "server-evaluation"
    assert bad["value"] is None and bad["distance"] == 0
    assert bad["defense"] == 9999 and bad["risk"] == 1.5
    assert "<" not in bad["summary"] and "NaN" not in bad["summary"]
    assert data["phases"] == {
        "approach": "ВРАГ ЕЩЁ В ПУТИ",
        "breach": "ПРОРЫВ · ПЕРВЫЙ ВХОД",
        "fight": "БОЙ ЗА БИЗНЕС",
        "advance": "ПРОРЫВ К КАССЕ",
        "hold": "УДЕРЖАНИЕ КАССЫ · 12.3 С",
        "contested": "КАССА ОСПАРИВАЕТСЯ",
        "defended": "БИЗНЕС ЗАЩИЩЁН",
        "captured": "КАССА ЗАХВАЧЕНА",
    }

    # Both surfaces consume the same plan/decision; interior never advertises
    # doctrine-specific combat that its generic nearest-target AI does not run.
    assert "alert.plan.decision.summary" in WORLD
    assert "function _playerBusinessRaidCompass(alert,r,c)" in WORLD
    assert "signature:`${alert.key}:${atTarget?'here':index}:${distance}:${state}:${alert.name||''}`" in WORLD
    assert "plan.decision.summary" in WORLD
    assert "orders=`ЦЕЛЬ: ${plan.objectiveLabel}" in WORLD
    assert "orders=`${plan.doctrineLabel}" not in WORLD
    assert "state.raidPlan||_playerBusinessRaidPlan(state.empire,state.activity)" in WORLD
    assert "Math.max(20,+activity?.hold_seconds||20)" in WORLD
    assert "policy-mismatch-${plan.decision.policyMismatch?1:0}" in WORLD

    # Existing nodes remain bounded and only the interior surface is visible
    # while inside, preventing two raid cards from overlapping.
    assert "width:min(430px,calc(100vw - 16px))" in WORLD
    assert "max-height:132px" in WORLD and "max-height:120px" in WORLD
    assert "-webkit-line-clamp:2;white-space:normal" in WORLD
    assert "if(exteriorHud)exteriorHud.style.visibility='hidden'" in WORLD
    assert "if(exteriorRaidHud)exteriorRaidHud.style.visibility=''" in WORLD

    # Authoritative snapshots expose the fields consumed above.
    snapshot = SERVER[SERVER.index("interior_raids = []"):SERVER.index("return {'empires':", SERVER.index("interior_raids = []"))]
    for marker in ("'target_reason':", "'raid_metrics':", "'raid_policy':"):
        assert marker in snapshot


if __name__ == "__main__":
    run()
    print("business raid HUD decision: honest policy metrics, phases and bounded layout OK")
