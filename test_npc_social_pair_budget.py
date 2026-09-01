from pathlib import Path
import math
import subprocess


WORLD = (Path(__file__).resolve().parent / "world.html").read_text(encoding="utf-8")


def test_social_pair_search_uses_local_spatial_cells():
    start = WORLD.index("function _findNpcSocialPair(now){")
    end = WORLD.index("function _npcSocialTick(now)", start)
    body = WORLD[start:end]
    assert "const cells=new Map(),eligible=[];" in body
    assert "Math.floor(n.r/NPC_SOCIAL_CELL_SIZE)" in body
    assert "for(let dx=-1;dx<=1;dx++)for(let dy=-1;dy<=1;dy++)" in body
    assert "if(d<.7||d>2.4)continue;" in body
    assert "if(Math.hypot(a.n.r-player.r,a.n.c-player.c)>18)continue;" in body
    assert "let best=null;" in body
    assert "if(!best||b.index<best.index)best=b;" in body
    assert "if(best)return [a.n,best.n];" in body


def test_social_tick_delegates_pair_selection_once():
    start = WORLD.index("function _npcSocialTick(now)")
    end = WORLD.index("// ── Реакция NPC", start)
    body = WORLD[start:end]
    assert "const pair=_findNpcSocialPair(now);" in body
    assert "for (let j = i + 1; j < NPCS.length; j++)" not in body


def test_adjacent_cells_cover_every_pair_in_the_original_radius():
    cell = 2.4
    # Sample both cell boundaries and interior offsets. Any two points no more
    # than one social radius apart must be in the same or adjacent grid cells.
    offsets = (0.0, 0.001, 0.6, 1.2, 1.8, 2.399)
    deltas = tuple(i * 0.1 for i in range(-24, 25))
    for row in offsets:
        for col in offsets:
            for dr in deltas:
                for dc in deltas:
                    if math.hypot(dr, dc) > cell:
                        continue
                    assert abs(math.floor((row + dr) / cell)) <= 1
                    assert abs(math.floor((col + dc) / cell)) <= 1


def test_neighbor_cell_order_keeps_original_lowest_partner_index():
    start = WORLD.index("const NPC_SOCIAL_CELL_SIZE=2.4;")
    end = WORLD.index("function _npcSocialTick(now)", start)
    helper = WORLD[start:end]
    # The high-index candidate sits in the first visited neighbour cell (-1, 0),
    # while the original nested i/j loop must still choose index 1 in (0, 1).
    # Execute the actual extracted helper against an independent reference loop.
    script = f"""
const vm=require('vm');
const context={{
  NPCS:[
    {{id:'a',r:.1,c:.1,ok:true}},
    {{id:'low',r:.1,c:2.499,ok:true}},
    {{id:'high',r:-1,c:.1,ok:true}},
  ],
  player:{{r:0,c:0}}, Math,
  _residentCanSocialize:(n)=>n.ok,
}};
vm.runInNewContext({helper!r}+"; globalThis.pick=()=>_findNpcSocialPair(0);",context);
const actual=context.pick().map(n=>n.id);
function reference(){{
  for(let i=0;i<context.NPCS.length;i++){{
    const a=context.NPCS[i];if(!a.ok)continue;
    for(let j=i+1;j<context.NPCS.length;j++){{
      const b=context.NPCS[j];if(!b.ok)continue;
      const d=Math.hypot(a.r-b.r,a.c-b.c);
      if(d<.7||d>2.4)continue;
      if(Math.hypot(a.r-context.player.r,a.c-context.player.c)>18)continue;
      return [a.id,b.id];
    }}
  }}
  return null;
}}
const expected=reference();
if(JSON.stringify(actual)!==JSON.stringify(expected))throw new Error(JSON.stringify({{actual,expected}}));
console.log(JSON.stringify({{actual,expected}}));
"""
    completed = subprocess.run(["node", "-e", script], check=True, text=True,
                               capture_output=True, encoding="utf-8")
    assert completed.stdout.strip() == '{"actual":["a","low"],"expected":["a","low"]}'


if __name__ == "__main__":
    test_social_pair_search_uses_local_spatial_cells()
    test_social_tick_delegates_pair_selection_once()
    test_adjacent_cells_cover_every_pair_in_the_original_radius()
    test_neighbor_cell_order_keeps_original_lowest_partner_index()
    print("npc social spatial search checks passed")
