from pathlib import Path
import subprocess


HUB = (Path(__file__).resolve().parent / "hub.html").read_text(encoding="utf-8")


def _body_discovery_source():
    start = HUB.index("function tacCheckBodyDiscovery(dt){")
    end = HUB.index("\nfunction ", start + 1)
    return HUB[start:end]


def test_body_discovery_uses_the_existing_clamped_simulation_delta():
    update_start = HUB.index("function tacUpdate(dt){")
    update_end = HUB.index("\nfunction ", update_start + 1)
    update = HUB[update_start:update_end]
    helper = _body_discovery_source()

    assert "tacCheckBodyDiscovery(dt);" in update
    assert "tacCheckBodyDiscovery();" not in update
    assert "e._foundBodyCD=Math.max(0,e._foundBodyCD-dt*1000);" in helper
    assert "if(e._foundBodyCD>0)return;" in helper
    assert "e._foundBodyCD-=16" not in helper
    assert "e._foundBodyCD=9000" in helper
    assert "ally._foundBodyCD=7000" in helper
    assert "setTimeout" not in helper and "setInterval" not in helper


def test_actual_helper_is_cadence_independent_and_never_discovers_early():
    helper = _body_discovery_source()
    script = f"""
const vm=require('vm');
const context={{Math,quotes:0,tac:null,tacEnemyQuote:()=>{{context.quotes++;}}}};
vm.runInNewContext({helper!r}+"; globalThis.check=tacCheckBodyDiscovery;",context);
for(const fps of [30,60,120]){{
  const dt=1/fps;
  const corpse={{hp:0,deathTimer:20000,stealthKill:false,r:0,c:0}};
  const watcher={{hp:100,alerted:false,_searchMode:false,_foundBodyCD:9000,
                  viewDist:8,fovAngle:Math.PI,r:0,c:0,angle:0}};
  context.tac={{enemies:[corpse,watcher],_bodyFound:0}};
  context.quotes=0;
  let elapsed=0;
  while(!watcher.alerted&&elapsed<10){{
    context.check(dt);
    elapsed+=dt;
    if(watcher._foundBodyCD<0)throw new Error(`negative cooldown at ${{fps}}fps`);
    if(watcher.alerted&&elapsed<9-1e-9)throw new Error(`early discovery at ${{fps}}fps: ${{elapsed}}`);
  }}
  if(!watcher.alerted)throw new Error(`no discovery at ${{fps}}fps`);
  if(elapsed<9-1e-9||elapsed>9+dt+1e-9)
    throw new Error(`cadence drift at ${{fps}}fps: ${{elapsed}}`);
  if(context.quotes!==1)throw new Error(`unexpected discovery count at ${{fps}}fps: ${{context.quotes}}`);
}}
console.log('tactical body discovery timing contract passed');
"""
    completed = subprocess.run(
        ["node", "-e", script], check=False, text=True, capture_output=True,
        encoding="utf-8",
    )
    assert completed.returncode == 0, completed.stderr
    assert completed.stdout.strip() == "tactical body discovery timing contract passed"


def test_visibility_cone_range_and_traversal_contract_stays_owned_by_helper():
    helper = _body_discovery_source()
    ordered_fragments = (
        "const corpses=tac.enemies.filter(e=>e.hp<=0&&e.deathTimer>0);",
        "tac.enemies.forEach(e=>{",
        "if(e.hp<=0)return;",
        "if(e.alerted&&!e._searchMode)return;",
        "const visRange=c.stealthKill?(e.viewDist*.5):(e.viewDist*1.5);",
        "if(dist>visRange)return;",
        "if(ang>e.fovAngle*0.85)return;",
        "tac.enemies.forEach(ally=>{",
    )
    positions = [helper.index(fragment) for fragment in ordered_fragments]
    assert positions == sorted(positions)


if __name__ == "__main__":
    test_body_discovery_uses_the_existing_clamped_simulation_delta()
    test_actual_helper_is_cadence_independent_and_never_discovers_early()
    test_visibility_cone_range_and_traversal_contract_stays_owned_by_helper()
    print("tactical body discovery timing checks passed")
