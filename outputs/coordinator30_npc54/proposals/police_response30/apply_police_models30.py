from pathlib import Path
import argparse,hashlib,json,sys
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def apply(game,report):
    game=Path(game).resolve();assert game.is_relative_to(ROOT/'outputs/coordinator30_npc54')
    pins=json.loads((OUT/'BASE_POLICE_MODELS30.json').read_text(encoding='utf-8'));rows=[]
    for rel,pin in pins.items():
        source=OUT/rel;target=game/rel;before=sha(target) if target.exists() else None
        assert sha(source)==pin['proposed_sha256'],rel+' package drift'
        assert before in [pin['base_sha256'],pin['proposed_sha256']],rel+' destination conflict'
        rows.append({'path':rel,'before':before,'after':pin['proposed_sha256'],'changed':before!=pin['proposed_sha256']})
    for row in rows:
        if row['changed']:
            target=game/row['path'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((OUT/row['path']).read_bytes())
        assert sha(game/row['path'])==row['after']
    result={'game':str(game),'files':rows,'world_hook_added':False,'police_behaviour_enabled':False,'models_only':True}
    Path(report).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');return result
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('game',type=Path);parser.add_argument('--report',type=Path,required=True);args=parser.parse_args()
    with Lease(mode='headless',project=args.game.resolve(),access='write',wait_seconds=180):apply(args.game,args.report)
