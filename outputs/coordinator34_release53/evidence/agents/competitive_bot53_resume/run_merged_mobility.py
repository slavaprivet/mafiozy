from pathlib import Path
import subprocess,sys,json,hashlib
O=Path('D:/MafioziCombat31/competitive_bot53_resume/merged_mobility');G=Path('D:/MafioziCombat31/coordinator34_merged53/game');Q=Path('D:/MafioziCombat31/competitive_bot53_resume/qa/mobility_lane.gd');R=Path('C:/Users/Слава/Desktop/Мафиози');E='C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'
M=G.parent/'CANDIDATE.json';pins=json.loads(M.read_text(encoding='utf-8-sig'))['source_pins'];O.mkdir(exist_ok=False)
def snapshot():return {r:hashlib.sha256((G/r).read_bytes()).hexdigest() for r in pins}
before=snapshot();drift_before=[r for r,h in pins.items() if before[r]!=h]
(O/'PINS_BEFORE.json').write_text(json.dumps(before,indent=2))
assert not drift_before,drift_before
cmd=[sys.executable,str(R/'tools/godot/test_scheduler.py'),'run','--mode','headless','--project',str(G),'--timeout','110','--out',str(O/'native'),'--',E,'--headless','--path',str(G),'--script',str(Q),'--','--qa-out='+str(O)]
p=subprocess.run(cmd,capture_output=True);(O/'runner.log').write_bytes(p.stdout+p.stderr)
after=snapshot();(O/'PINS_AFTER.json').write_text(json.dumps(after,indent=2));raw=json.loads((O/'result.json').read_text(encoding='utf-8-sig')) if (O/'result.json').exists() else {};scheduler=json.loads((O/'native/SCHEDULER_RUN.json').read_text(encoding='utf-8-sig'))
report={'passed':raw.get('passed') and scheduler.get('passed') and before==after,'scheduler':scheduler.get('passed'),'functional':raw.get('passed'),'pin_count':len(pins),'drift_before':drift_before,'drift_after':[r for r,h in pins.items() if after[r]!=h],'harness_sha256':hashlib.sha256(Q.read_bytes()).hexdigest(),'manifest_sha256':hashlib.sha256(M.read_bytes()).hexdigest(),'rows':[{k:v for k,v in row.items() if k!='samples'} for row in raw.get('rows',[])]}
(O/'AUDIT.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
