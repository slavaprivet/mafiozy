from pathlib import Path
import json,hashlib,subprocess,time
base=Path(__file__).resolve().parent;repo=base.parents[2];stage=repo/'outputs/coordinator23_quality/candidate18';project=stage/'godot/mafiozi_walk';pack=project/'exports/win64/s01-20260930-quality23i/MafioziPreview.pck';receipt=pack.parent/'build_receipt.json';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();pack_sha=sha(pack)
export=json.loads(receipt.read_text(encoding='utf-8-sig'));integration=json.loads((stage/'INTEGRATION.json').read_text(encoding='utf-8-sig'));inputs={x['path']:x['sha256'] for x in export['inputs']}
assert next(x['sha256'] for x in export['artifacts'] if x['filename']==pack.name)==pack_sha
assert export['sourceInputsUnchangedDuringExport'] is True
for path,value in integration['changes'].items():
 assert sha(project/path)==value['after']
 assert inputs[path]==value['after']
engine=Path.home()/'AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe';runs=[]
for label,case,harness in [('floor','floor','actual_main.gd'),('wall','wall','actual_main.gd'),('spread','spread','actual_main.gd'),('range_end','range_end','actual_main.gd'),('cancel','cancel','actual_main.gd'),('context_dispose','context_dispose','actual_main.gd'),('blood_floor','floor','actual_blood.gd'),('blood_disposal','context_dispose','actual_blood.gd')]:
 out=base/(label+'01');assert not out.exists();out.mkdir()
 cmd=[str(engine),'--headless','--main-pack',str(pack),'--script',str(base/harness),'--','--case='+case,'--qa-out='+str(out)];start=time.monotonic()
 with (out/'engine.log').open('w',encoding='utf-8') as log:
  try:run={'exit_code':subprocess.run(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=30).returncode}
  except subprocess.TimeoutExpired:run={'timeout_seconds':30}
 text=(out/'engine.log').read_text(encoding='utf-8-sig');result=json.loads((out/'RESULT.json').read_text(encoding='utf-8-sig')) if (out/'RESULT.json').exists() else {}
 run.update(label=label,case=case,seconds=time.monotonic()-start,pack_sha256=pack_sha,pack_unchanged=sha(pack)==pack_sha,export_receipt_sha256=sha(receipt),integration_sha256=sha(stage/'INTEGRATION.json'),harness_sha256=sha(base/harness),command=cmd,cwd=str(out),checks=result.get('checks',0),compiled_resources=result.get('compiled_resources',{}),result_valid=result.get('valid',False),errors=result.get('errors',[]),engine_clean=not any(x in text for x in ['SCRIPT ERROR:','ERROR:','WARNING:']))
 run['accepted']=run.get('exit_code')==0 and run['pack_unchanged'] and run['result_valid'] and run['engine_clean'] and len(run['compiled_resources'])==11 and all(run['compiled_resources'].values())
 (out/'RUN.json').write_text(json.dumps(run,indent=2,ensure_ascii=False)+'\n',encoding='utf-8');runs.append(run)
 (base/'PROGRESS.json').write_text(json.dumps({'pack_sha256':pack_sha,'runs':runs},indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
 print(json.dumps({'case':label,'accepted':run['accepted'],'checks':run['checks'],'seconds':run['seconds'],'errors':run['errors']},ensure_ascii=True),flush=True)
 if not run['accepted']:
  print(text[-4000:],flush=True);raise SystemExit(2)
print('COMPILED18_ALL_PASS '+str(sum(x['checks'] for x in runs)),flush=True)
