from pathlib import Path
import json,hashlib,difflib,statistics,math
O=Path('D:/MafioziCombat31/bow_motion53');G=O/'game';B=Path('D:/MafioziCombat31/coordinator33/game');base=json.loads((O/'BASE.json').read_text(encoding="utf-8-sig"));changed=[]
for r,h in base['source_pins'].items():
 got=hashlib.sha256((G/r).read_bytes()).hexdigest()
 if got!=h:changed.append(dict(path=r,base_sha256=h,candidate_sha256=got))
assert {x['path'] for x in changed}=={'scripts/preview_player.gd','scripts/weapons/bow_prototype.gd'}
for x in changed:
 r=x['path'];(O/(Path(r).name+'.patch')).write_text(''.join(difflib.unified_diff((B/r).read_text(encoding="utf-8-sig").splitlines(True),(G/r).read_text(encoding="utf-8-sig").splitlines(True),fromfile='a/'+r,tofile='b/'+r)),encoding="utf-8")
metrics={}
for run in ['before02','after','graphical']:
 raw=json.loads((O/run/'result.json').read_text(encoding="utf-8-sig"));metrics[run]={}
 for phase in ['back_held','back_aimed','back_released']:
  rows=[x for x in raw['rows'] if x['phase']==phase][40:]
  hands=[[x['hand'][i]-x['position'][i] for i in range(3)] for x in rows]
  steps=[math.dist(a,b) for a,b in zip(hands,hands[1:])]
  metrics[run][phase]={'samples_after_warmup':len(rows),'max_physics_render_correction_degrees':max(x['frame_correction_degrees'] for x in rows),'max_render_step_degrees':max(x['render_step_degrees'] for x in rows),'mean_camera_error_degrees':statistics.mean(x['camera_error_degrees'] for x in rows),'backward_metres':rows[-1]['position'][2]-rows[0]['position'][2],'max_relative_bow_step_m':max(steps)}
assert all(m['max_render_step_degrees']<0.01 and m['max_physics_render_correction_degrees']<0.01 and m['backward_metres']>4 for run in ['after','graphical'] for m in metrics[run].values())
result=dict(passed=True,base_revision=base['revision'],game=str(G),changes=changed,metrics=metrics,evidence=['before02/result.json','after/result.json','graphical/result.json','graphical/back_held0.png through back_released3.png'],before_graphical='D:/MafioziCombat31/bow_aim53/baseline/back_0.png through back_3.png',limits=['Native synthetic S and RMB events at actual 1280x720; no mouse movement needed for this regression.','Full performance not accepted; user game preserved.','Integration must merge the narrow bow patch with bow_aim53 and rerun combined ownership/contact tests.','Failed initial harness dereferenced pre-equip null bow; raw before logs preserved, corrected before02 used.','Import completed resources then remained open; owned import process stopped; raw import receipt retained.'])
(O/'READY.json').write_text(json.dumps(result,indent=2));print(json.dumps({'changes':changed,'metrics':metrics}))

