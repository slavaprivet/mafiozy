from pathlib import Path
import re
import subprocess


WORLD = (Path(__file__).resolve().parent / "world.html").read_text(encoding="utf-8")


def _traffic_helper_source():
    start = WORLD.index("const _TRAFFIC_PATH_CACHE_MAX=1024;")
    end = WORLD.index("function _trafficGoalScore", start)
    return WORLD[start:end]


def test_actual_cached_helper_matches_reference_and_lru_contract():
    helper = _traffic_helper_source()
    script = f"""
const vm=require('vm');
const context={{Map,Math}};
vm.runInNewContext({helper!r}+"; globalThis.testApi={{find:_trafficFindNodePath,cache:_trafficPathCache,max:_TRAFFIC_PATH_CACHE_MAX}};",context);
const {{find,cache,max}}=context.testApi;
const a={{key:'a',next:[]}},b={{key:'b',next:[]}},c={{key:'c',next:[]}},isolated={{key:'isolated',next:[]}};
a.next=[b];b.next=[c];
function reference(start,goal){{
  if(!start||!goal)return null;
  if(start===goal)return [start];
  const queue=[start],came=new Map([[start.key,null]]);
  for(let head=0;head<queue.length;head++){{
    const n=queue[head];
    for(const next of n.next){{
      if(came.has(next.key))continue;
      came.set(next.key,n);
      if(next===goal){{const path=[goal];let cur=n;while(cur){{path.push(cur);cur=came.get(cur.key);}}path.reverse();return path;}}
      queue.push(next);
    }}
  }}
  return null;
}}
const first=find(a,c),expected=reference(a,c);
if(JSON.stringify(first.map(n=>n.key))!==JSON.stringify(expected.map(n=>n.key)))throw new Error('reachable mismatch');
if(find(a,c)!==first)throw new Error('reachable cache did not retain completed path identity');
if(find(c,a)!==null||!cache.has('c>a')||find(c,a)!==null)throw new Error('unreachable null cache contract failed');
if(find(a,a).length!==1||cache.has('a>a'))throw new Error('start-equals-goal early return changed');
if(find(null,a)!==null)throw new Error('missing start early return changed');
cache.clear();
const starts=[],goals=[];
for(let i=0;i<=max;i++){{starts.push({{key:'s'+i,next:[]}});goals.push({{key:'g'+i,next:[]}});}}
for(let i=0;i<max;i++)find(starts[i],goals[i]);
find(starts[0],goals[0]);
find(starts[max],goals[max]);
if(cache.size!==max||!cache.has('s0>g0')||cache.has('s1>g1')||!cache.has('s'+max+'>g'+max))throw new Error('LRU promotion or oldest eviction failed');
console.log('traffic cache runtime contract passed');
"""
    completed = subprocess.run(["node", "-e", script], check=True, text=True,
                               capture_output=True, encoding="utf-8")
    assert completed.stdout.strip() == "traffic cache runtime contract passed"


def test_init_cars_clears_cache_with_graph_and_planner_is_sole_reader():
    start = WORLD.index("function initCars() {")
    end = WORLD.index("\nfunction ", start + 1)
    init_body = WORLD[start:end]
    assert "_trafficRoadGraph = null;" in init_body
    assert "_trafficPathCache.clear();" in init_body
    assert init_body.index("_trafficRoadGraph = null;") < init_body.index("_trafficPathCache.clear();")
    calls = [m.start() for m in re.finditer(r"_trafficFindNodePath\(", WORLD)]
    assert len(calls) == 2  # declaration plus the planner's only call site
    planner_start = WORLD.index("function _planCarRoute(car, forceNewGoal = false) {")
    planner_end = WORLD.index("function _updateCarRouteDirection", planner_start)
    planner = WORLD[planner_start:planner_end]
    assert "_trafficFindNodePath(start, destination)" in planner
    assert "path.push(" not in planner and "path.pop(" not in planner
    assert "path.shift(" not in planner and "path.splice(" not in planner
    assert not re.search(r"path\s*\[[^\]]+\]\s*=", planner)


if __name__ == "__main__":
    test_actual_cached_helper_matches_reference_and_lru_contract()
    test_init_cars_clears_cache_with_graph_and_planner_is_sole_reader()
    print("traffic path cache checks passed")
