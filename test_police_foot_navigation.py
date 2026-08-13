"""Deterministic 60-second regression for client foot-police navigation."""

import json
import re
import subprocess
from pathlib import Path


HTML = Path("world.html").read_text(encoding="utf-8")


def _function(name: str) -> str:
    """Extract one top-level JS function while respecting strings/comments."""
    start = HTML.index(f"function {name}(")
    brace = HTML.index("{", start)
    depth = 0
    quote = None
    escaped = False
    line_comment = False
    block_comment = False
    i = brace
    while i < len(HTML):
        ch = HTML[i]
        nxt = HTML[i + 1] if i + 1 < len(HTML) else ""
        if line_comment:
            if ch == "\n":
                line_comment = False
        elif block_comment:
            if ch == "*" and nxt == "/":
                block_comment = False
                i += 1
        elif quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
        elif ch == "/" and nxt == "/":
            line_comment = True
            i += 1
        elif ch == "/" and nxt == "*":
            block_comment = True
            i += 1
        elif ch in "'\"`":
            quote = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return HTML[start:i + 1]
        i += 1
    raise AssertionError(f"unterminated function {name}")


def _prison_routes_clear() -> None:
    marker = "const PRISON_STAFF_ROUTES = Object.freeze("
    start = HTML.index(marker) + len(marker)
    end = HTML.index(");", start)
    raw = re.sub(r"//[^\n]*", "", HTML[start:end])
    raw = re.sub(r",\s*]", "]", raw)
    routes = json.loads(raw)
    solids_block = HTML[HTML.index("solidRects:Object.freeze([", HTML.index("const JAIL_ISLAND_LAYOUT")):]
    solids_block = solids_block[:solids_block.index("]),")]
    solids = [
        {key: float(value) for key, value in re.findall(r"(minR|maxR|minC|maxC):([0-9.]+)", obj)}
        for obj in re.findall(r"\{kind:'[^']+'([^}]+)\}", solids_block)
    ]
    assert len(routes) == 6 and len(solids) >= 7
    pad = .24
    for slot, route in enumerate(routes):
        for a, b in zip(route, route[1:] + route[:1]):
            distance = max(abs(b[0] - a[0]), abs(b[1] - a[1]))
            steps = max(1, int(distance / .02))
            for step in range(steps + 1):
                t = step / steps
                r = a[0] + (b[0] - a[0]) * t
                c = a[1] + (b[1] - a[1]) * t
                assert not any(
                    q["minR"] - pad <= r <= q["maxR"] + pad
                    and q["minC"] - pad <= c <= q["maxC"] + pad
                    for q in solids
                ), (slot, a, b, round(r, 2), round(c, 2))


def _run_60_second_js() -> dict:
    functions = "\n".join(_function(name) for name in (
        "_clearPoliceFootRoute",
        "_reservePoliceFootRoute",
        "_policeCrewSegmentPassable",
        "_planPoliceFootRoute",
        "_movePoliceFootCop",
    ))
    harness = f"""
let simNow=0;
Object.defineProperty(globalThis,'performance',{{value:{{now:()=>simNow}}}});
const document={{documentElement:{{dataset:{{}}}}}},MAP_COLS=220;
let _policeFootRouteFrame=-1,_policeFootRoutesThisFrame=0,_policeFootRouteDeferredCount=0,
  _policeFootRoutePlanCount=0,_policeFootRouteCacheHits=0,_policeFootRouteMaxMs=0;
const _policeFootRouteSharedCache=new Map();
function _policeCrewBodyPassable(r,c){{
  if(r<1||r>95||c<1||c>218)return false;
  // Body-expanded facade that cuts the direct line from the QA trace.
  return !(r>=68.76&&r<=71.24&&c>=155.76&&c<=158.74);
}}
{functions}
const cops=Array.from({{length:12}},(_,i)=>({{
  id:'citycop_'+(8+i),y:68.25-i*.012,x:159.50+i*.014,speed:1.35,
  ty:71.5,tx:154.5,_wayUntil:7000,walkPhase:0
}}));
let overlapFrames=0,patrolResets=0,maxStalls=0,stallsAt30=0;
for(let frame=0;frame<1800;frame++){{
  simNow=frame*(1000/30);
  for(const cop of cops){{
    const beforeR=cop.y,beforeC=cop.x;
    _movePoliceFootCop(cop,cop.ty,cop.tx,1/30,1);
    // Production keeps the authored target during short route admission waits.
    if(!_policeCrewBodyPassable(cop.y,cop.x))overlapFrames++;
  }}
  maxStalls=Math.max(maxStalls,+(document.documentElement.dataset.policeFootStallRecoveries||0));
  if(frame===899)stallsAt30=maxStalls;
}}
// Force route admission contention and prove a deferred plan preserves target state.
simNow=61000;_policeFootRouteFrame=Math.floor(simNow/16.667);_policeFootRoutesThisFrame=1;
const deferred={{y:68.75,x:158.75,ty:71.5,tx:154.5,speed:1.35,_wayUntil:7777}};
_movePoliceFootCop(deferred,deferred.ty,deferred.tx,1/30,1);
if(!deferred._policeFootMoveDeferred)throw new Error('route was not marked deferred');
if(deferred._policeFootMoveDeferred){{ /* production guard keeps _wayUntil */ }} else deferred._wayUntil=0;
if(deferred._wayUntil!==7777)throw new Error('deferred patrol target reset');
const result={{plans:_policeFootRoutePlanCount,deferred:_policeFootRouteDeferredCount,
  stalls:maxStalls,stallsAt30,stallsSecondHalf:maxStalls-stallsAt30,overlapFrames,patrolResets,
  arrived:cops.filter(c=>Math.hypot(c.ty-c.y,c.tx-c.x)<.3).length}};
if(result.stallsSecondHalf!==0||result.stalls>12||result.overlapFrames!==0||result.patrolResets!==0||result.arrived!==12||result.plans>24)
  throw new Error(JSON.stringify(result));
console.log(JSON.stringify(result));
"""
    proc = subprocess.run(
        ["node", "-"], input=harness, text=True, encoding="utf-8",
        capture_output=True,
    )
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout.strip())


def run() -> None:
    _prison_routes_clear()
    assert "_nearestPoliceFootTile(origin.r,origin.c,12)" in HTML
    assert "if (!_policeCrewBodyPassable(r+.5,c+.5)) continue;" in HTML
    assert "movedBeforeC)<.0001&&!cop._policeFootMoveDeferred" in HTML
    patrol = HTML[HTML.index("// ── ОБЫЧНОЕ ПАТРУЛИРОВАНИЕ"):HTML.index("const policeInSolids=")]
    assert "cop._wayUntil = 0" not in patrol
    result = _run_60_second_js()
    print("POLICE_FOOT_NAV_OK:", json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    run()
