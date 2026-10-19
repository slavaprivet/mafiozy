from pathlib import Path
import argparse, hashlib, json, os, subprocess, sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pins(game):return {p.relative_to(game).as_posix():sha(p) for p in game.rglob('*') if p.is_file() and '.godot' not in p.parts}
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('name');parser.add_argument('--graphical',action='store_true');parser.add_argument('--game',type=Path,default=ROOT/'outputs/coordinator30_npc54/game');args=parser.parse_args()
    game=args.game.resolve();out=HERE/'runs'/args.name;out.mkdir(parents=True,exist_ok=False)
    before=pins(game);(out/'SOURCE.json').write_text(json.dumps(before,indent=2),encoding='utf-8')
    harness={str(p.relative_to(HERE.parent)):sha(p) for p in [HERE/'entry_city30.gd',HERE/'observer_city30.gd',HERE/'run_city30.py',HERE.parent/'injury30/observer_injury30.gd',HERE.parent/'injury30/observer_death28.gd']}
    (out/'HARNESS_PINS.json').write_text(json.dumps(harness,indent=2),encoding='utf-8')
    flags=json.loads((ROOT/'outputs/coordinator29_npc53/death53_02/RUN_CHECK.json').read_text(encoding='utf-8'))['flags']
    flags=[f for f in flags if not f.startswith(('--qa-','--city-hp=','--city-energy-start=','--city-wallet-start=','--city-clear-cache='))]
    flags+=['--city-venue-sites29=1','--city-venue-staff29=1','--city-sandbox-seed=53','--city-hp=100','--city-threat30=1','--city-physical-dispatch30=1','--city-local-avoidance29=1','--city-multi-lifecycle30=1','--qa-out='+str(out)]
    exe=Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
    cmd=[sys.executable,'-B',str(ROOT/'tools/godot/test_scheduler.py'),'run','--mode','graphical' if args.graphical else 'headless','--project',str(game),'--wait-seconds','45','--timeout','300','--out',str(out/'engine'),'--',str(exe)]
    if not args.graphical:cmd+=['--headless']
    cmd+=['--path',str(game),'--script',str(HERE/'entry_city30.gd'),'--',*flags]
    run=subprocess.run(cmd,cwd=ROOT,capture_output=True)
    (out/'runner.stdout.log').write_bytes(run.stdout);(out/'runner.stderr.log').write_bytes(run.stderr)
    after=pins(game)
    result={'exit':run.returncode,'source_drift':[k for k in set(before)|set(after) if before.get(k)!=after.get(k)],'harness_drift':[k for k,v in harness.items() if sha(HERE.parent/k)!=v],'flags':flags,'graphical':args.graphical,'performance_accepted':False}
    (out/'RUN_CHECK.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result,ensure_ascii=True))
    sys.exit(run.returncode or bool(result['source_drift']) or bool(result['harness_drift']))
