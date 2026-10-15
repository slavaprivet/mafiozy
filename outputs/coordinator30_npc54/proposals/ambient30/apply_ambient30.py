"""Apply only the five verified ambient files. No host, player or scene edits."""
from pathlib import Path
import argparse,hashlib,json,sys
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def apply(game,report):
    game=Path(game).resolve();assert game.is_relative_to(ROOT/'outputs/coordinator30_npc54')
    rows=json.loads((OUT/'BASE_AMBIENT30.json').read_text(encoding='utf-8'));actions=[]
    for rel,pin in rows.items():
        src=OUT/rel;dst=game/rel;current=sha(dst) if dst.exists() else None
        assert sha(src)==pin['proposed_sha256'],rel+' package drift'
        assert current in [pin['base_sha256'],pin['proposed_sha256']],rel+' destination conflict'
        actions.append({'path':rel,'before':current,'after':pin['proposed_sha256'],'changed':current!=pin['proposed_sha256']})
    for row in actions:
        if row['changed']:
            target=game/row['path'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((OUT/row['path']).read_bytes())
        assert sha(game/row['path'])==row['after']
    result={'game':str(game),'changes':actions,'host_changed':False,'physics_capsule_changed':False,'user_game_closed':False}
    Path(report).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');return result
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('game',type=Path);parser.add_argument('--report',type=Path,required=True);args=parser.parse_args()
    with Lease(mode='headless',project=args.game.resolve(),access='write',wait_seconds=180):apply(args.game,args.report)
