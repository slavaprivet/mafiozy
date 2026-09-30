"""Synthetic comparator guards only. Does not run Godot or constitute performance results."""
import copy,json,pathlib,subprocess,sys,tempfile
here=pathlib.Path(__file__).resolve().parent
raw=json.loads((here.parent/'coordinator23_quality_perf/loaded_pck03ready/candidate.json').read_text(encoding='utf8'))
r=json.loads((here/'BASELINE_RECEIPT.json').read_text(encoding='utf-8-sig'))
pin=json.loads((here/'BASELINE_PIN.json').read_text())
canonical={'res://'+x['path']:x['sha256'] for x in r['inputs']}
prov={'canonical_inputs':canonical,'mode':r['mode'],'engine':r['engineVersion'],'architecture':r['architecture'],'compiled_scripts':True}
manifest={'baseline_sha256':pin['pck_sha256'],'baseline_source_provenance':prov,'candidate_source_provenance':copy.deepcopy(prov),'candidate_form':'compiled_pck'}
for phase in raw['phases']:
 for edge in ['before','after']:
  phase[edge]['collision_shape_count']=377
  phase[edge]['static_memory_bytes']=phase['static_memory_bytes']['p50']
checks=[]
for case in ['equal','wrong_baseline','missing_collision','cargo_short','unknown_npc_hash','raw_form','camera_mismatch','approved_npc_merge','altered_new_npc_asset']:
 with tempfile.TemporaryDirectory(prefix='synthetic_',dir=here) as folder:
  f=pathlib.Path(folder);m=copy.deepcopy(manifest);b=copy.deepcopy(raw);c=copy.deepcopy(raw)
  if case in ['approved_npc_merge','altered_new_npc_asset']:
   plan=json.loads((here/'MERGE_PLAN_PINNED.json').read_text(encoding='utf8'))
   for path,row in plan['files'].items():
    if path.startswith(('scripts/npc_visual/','assets/npc_visual/')) or path in ['scripts/preview_population.gd','scripts/weapons/weapon_projectiles.gd']:m['candidate_source_provenance']['canonical_inputs']['res://'+path]=row['after']
   if case=='altered_new_npc_asset':m['candidate_source_provenance']['canonical_inputs']['res://assets/npc_visual/death_eyes/npc_resident_72_skin_closed.res']='0'*64
  if case=='wrong_baseline':m['baseline_sha256']='0'*64
  if case=='missing_collision':c['phases'][0]['after']['collision_shape_count']=376
  if case=='cargo_short':c['cargo_summary']['used_units']=99
  if case=='unknown_npc_hash':m['candidate_source_provenance']['canonical_inputs']['res://scripts/npc_visual/preview_resident_host.gd']='0'*64
  if case=='raw_form':m['candidate_form']='raw_project'
  if case=='camera_mismatch':c['phases'][0]['before']['camera_fov']=45
  for name,data in [('MANIFEST',m),('baseline',b),('candidate',c)]:f.joinpath(name+'.json').write_text(json.dumps(data),encoding='utf8')
  for label in ['baseline','candidate']:f.joinpath(label+'.log').write_text('Synthetic validation fixture only',encoding='utf8')
  result=subprocess.run([sys.executable,str(here/'run_pair.py'),'--compare-only','--candidate-pck','unused.pck','--tag',str(f)],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True)
  report=json.loads(f.joinpath('COMPARISON.json').read_text(encoding='utf8')) if f.joinpath('COMPARISON.json').exists() else {'issues':[result.stderr]}
  passed=(result.returncode==0) if case in ['equal','approved_npc_merge'] else result.returncode==2
  checks.append({'case':case,'passed':passed,'issues':report['issues']})
out={'synthetic_only':True,'gpu_launched':False,'passed':all(x['passed'] for x in checks),'checks':checks}
here.joinpath('COMPARATOR_SELFTEST.json').write_text(json.dumps(out,indent=2),encoding='utf8')
print(json.dumps(out,indent=2));sys.exit(0 if out['passed'] else 1)
