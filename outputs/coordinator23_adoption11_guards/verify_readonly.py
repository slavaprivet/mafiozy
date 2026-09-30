"""Snapshot exact promotion guards; writes only this report directory. No Git/engine."""
from pathlib import Path
import datetime, difflib, hashlib, json, re

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
SHARED = ROOT / 'godot/mafiozi_walk'
CANDIDATE = ROOT / 'outputs/coordinator23_quality/candidate10/godot/mafiozi_walk'
PREFIX = 'godot/mafiozi_walk/'
def read(p): return p.read_bytes() if p.is_file() else None
def sha(p):
    data=read(p)
    return hashlib.sha256(data).hexdigest() if data is not None else None
def load(p): return json.loads(p.read_text(encoding='utf-8-sig'))

old_path=ROOT/'outputs/coordinator23_adoption09_guards/VERIFY_AND_GUARDS.json'
trunk_path=ROOT/'outputs/coordinator23_trunk_window/RECEIPT.json'
integration_path=CANDIDATE.parents[1]/'INTEGRATION.json'
receipt_path=CANDIDATE/'exports/win64/s01-20260930-quality23g/build_receipt.json'
old=load(old_path); trunk=load(trunk_path); integration=load(integration_path); receipt=load(receipt_path)
prior_scoped={r['path'].removeprefix(PREFIX):r for r in old['guards'] if r['action']!='EXCLUDE_UNSCOPED'}
scope=list(prior_scoped)+[p for p in trunk['changes'] if p not in prior_scoped]
assert len(prior_scoped)==15 and len(scope)==21
assert set(scope)==set(integration['changes'])
errors=[]; guards=[]; patch=[]
future={'scripts/weapons/walk_trunk_window.gd','scripts/weapons/preview_weapons.gd','scripts/weapons/preview_weapon_cargo.gd'}
for rel in scope:
    current=sha(SHARED/rel); target=sha(CANDIDATE/rel)
    previous=prior_scoped.get(rel,{}).get('current_sha256')
    expected=previous if rel in prior_scoped else trunk['changes'][rel]['before']
    if current!=expected: errors.append('shared drift: '+rel)
    if target!=integration['changes'][rel]['after']: errors.append('candidate integration receipt mismatch: '+rel)
    if rel in trunk['changes']:
        if target!=trunk['changes'][rel]['after']: errors.append('trunk target mismatch: '+rel)
        if rel not in prior_scoped and current!=trunk['changes'][rel]['before']:errors.append('extra trunk before mismatch: '+rel)
        if rel in prior_scoped and prior_scoped[rel]['candidate09_sha256']!=trunk['changes'][rel]['before']:errors.append('trunk parent chain mismatch: '+rel)
    action='KEEP_IDENTICAL' if current==target else ('CREATE_ONLY_IF_ABSENT' if current is None else 'GUARDED_REPLACE_EXACT_BYTES')
    guards.append({'path':PREFIX+rel,'relative_path':rel,'expected_current_sha256':current,'prior_expected_current_sha256':expected,'target_current10_sha256':target,'target_source':str((CANDIDATE/rel).relative_to(ROOT)).replace('\\','/'),'action':action,'origin':'prior15_root_npc' if rel in prior_scoped else 'extra6_trunk','future_layout11_overlay_possible':rel in future,'final11_sha256':None,'trunk_receipt_before_sha256':trunk['changes'].get(rel,{}).get('before')})
    if action!='KEEP_IDENTICAL':
        a=(read(SHARED/rel) or b'').decode('utf-8-sig').replace('\r\n','\n')
        b=(read(CANDIDATE/rel) or b'').decode('utf-8-sig').replace('\r\n','\n')
        patch.extend(difflib.unified_diff(a.splitlines(True),b.splitlines(True),fromfile='a/'+PREFIX+rel if current else '/dev/null',tofile='b/'+PREFIX+rel))

inputs=[]; shared_drift=[]; outside=[]
prior_inputs={r['path']:r for r in old['all203source_inputs']}
for item in receipt['inputs']:
    rel=item['path']; target=sha(CANDIDATE/rel); current=sha(SHARED/rel)
    if target!=item['sha256'] or (CANDIDATE/rel).stat().st_size!=item['bytes']:errors.append('export source receipt mismatch: '+rel)
    prior=prior_inputs.get(rel,{})
    if rel in prior_inputs and current!=prior['current_sha256']:shared_drift.append(rel)
    row={'path':rel,'current_sha256':current,'target_current10_sha256':target,'receipt_sha256':item['sha256']}
    inputs.append(row)
    if rel not in scope and current!=target:
        a=read(SHARED/rel);b=read(CANDIDATE/rel)
        newline_only=a is not None and a.replace(b'\r\n',b'\n')==b.replace(b'\r\n',b'\n')
        outside.append(dict(row,action='PRESERVE_SHARED_DO_NOT_COPY',newline_only=newline_only))
errors.extend('shared exported input drift: '+p for p in shared_drift)
must_preserve=['scripts/preview_update_panel.gd','scripts/transport/transport_access_provider.gd','scripts/transport/transport_descriptor_catalog.gd']
preserve=[]
for rel in must_preserve:
    row=next(r for r in outside if r['path']==rel)
    assert not row['newline_only']
    preserve.append(row)

cfg=(CANDIDATE/'export_presets.cfg').read_text(encoding='utf-8')
old_cfg=(SHARED/'export_presets.cfg').read_text(encoding='utf-8')
def export_files(text):return set(re.findall(r'"res://([^\"]+)"',next(x for x in text.splitlines() if x.startswith('export_files='))))
lost_export_entries=sorted(export_files(old_cfg)-export_files(cfg))
if lost_export_entries:errors.append('candidate deletes existing shared export entries')
new_export_entries=sorted(export_files(cfg)-export_files(old_cfg))
assert 'scripts/weapons/walk_trunk_window.gd' in export_files(cfg)
dependencies=[]
for rel in scope:
    if not rel.endswith('.gd'):continue
    text=(CANDIDATE/rel).read_text(encoding='utf-8')
    for dep in sorted(set(re.findall(r'(?:preload|load)\("([^\"]+)"\)',text))):
        resolved=dep[6:] if dep.startswith('res://') else (Path(rel).parent/dep).as_posix()
        exists_candidate=(CANDIDATE/resolved).is_file()
        exists_after=(CANDIDATE/resolved).is_file() if resolved in scope else (SHARED/resolved).is_file()
        dependencies.append({'consumer':rel,'dependency':resolved,'exists_candidate':exists_candidate,'exists_after_scoped_promotion':exists_after})
        if not exists_candidate or not exists_after:errors.append('missing literal dependency: '+rel+' -> '+resolved)
artifacts=[]
for item in receipt['artifacts']:
    path=receipt_path.parent/item['filename'];actual=sha(path)
    valid=actual==item['sha256'] and path.stat().st_size==item['bytes']
    artifacts.append(dict(item,verified=valid))
    if not valid:errors.append('artifact hash mismatch: '+item['filename'])
if any(sha(SHARED/r['path'])!=r['current_sha256'] for r in inputs):errors.append('shared changed during verification')
if any(sha(CANDIDATE/r['path'])!=r['target_current10_sha256'] for r in inputs):errors.append('candidate changed during verification')
report={'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'GUARDS_READY_AWAIT_LAYOUT11_ACCEPTANCE' if not errors else 'BLOCKED_DRIFT_OR_DEPENDENCY','errors':errors,'engine_run':False,'git_run':False,'shared_mutations':False,'candidate_mutations':False,'promotion_performed':False,'prior15_count':15,'extra_trunk_count':6,'scope_count':21,'inputs_verified':len(inputs),'guards':guards,'preserve_three_unscoped':preserve,'all_unscoped_differences_preserve':outside,'shared_drift_since09':shared_drift,'export_entries_added':new_export_entries,'export_entries_removed':lost_export_entries,'literal_dependencies':dependencies,'source_inputs':inputs,'candidate10_artifacts_verified':artifacts,'source_receipts':{str(p.relative_to(ROOT)).replace('\\','/'):sha(p) for p in [old_path,trunk_path,integration_path,receipt_path]},'future11':{'status':'UNACCEPTED_NOT_A_PROMOTION_TARGET','expected_parent':'candidate10 exact SHA in each guard','anticipated_paths':sorted(future),'rule':'Freeze accepted11 receipt and replace targets only for its explicit guarded overlay; compare every other source input against candidate10. Runtime revision/notes changes require paired explicit guards. Abort new shared drift. Never whole-tree copy.'},'limits':['This plan pins candidate10, not unfinished candidate11.','Preserved shared transport/palette differs from measured candidate10; final shared export requires its own exact receipt and acceptance.','Literal dependency scan does not prove dynamically constructed paths; export receipt/artifact hashes verified, engine not launched.']}
(OUT/'GUARDED_PROMOTION.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
(OUT/'EXACT_CURRENT10_PROMOTION.patch').write_text(''.join(patch),encoding='utf-8',newline='\n')
(OUT/'SCOPED_PATHS.txt').write_text('\n'.join(PREFIX+p for p in scope)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({k:report[k] for k in ['status','errors','scope_count','inputs_verified','shared_drift_since09','export_entries_added']},ensure_ascii=False))
