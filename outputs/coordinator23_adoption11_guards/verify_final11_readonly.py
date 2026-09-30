"""Read final11 source/artifacts/PCK; writes only new final11 output reports."""
from pathlib import Path
import copy, datetime, hashlib, json, struct
ROOT=Path(__file__).resolve().parents[2]; OUT=Path(__file__).resolve().parent
SHARED=ROOT/'godot/mafiozi_walk'
stages={n:ROOT/f'outputs/coordinator23_quality/candidate{n}/godot/mafiozi_walk' for n in ['10','11']}
exports={n:p/'exports/win64/s01-20260930-quality23g' for n,p in stages.items()}
def digest(b):return hashlib.sha256(b).hexdigest()
def sha(p):return digest(p.read_bytes()) if p.is_file() else None
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
plan_path=OUT/'GUARDED_PROMOTION.json';plan=load(plan_path)
layout_path=ROOT/'outputs/coordinator23_trunk_layout11/RECEIPT.json';layout=load(layout_path)
receipts={n:load(p/'build_receipt.json') for n,p in exports.items()}
expected={'10':'3ba945307a9d71f800a687c3cb75fb62c5d7a39834eaa30be74f263b6f8adb0a','11':'ae82e44c46cf3d5f420897c7e91d8a631691dbf4180d27c45342ff428916209e'}
errors=[]; all_inputs=[]; delta=[]
before_inputs={x['path']:x for x in receipts['10']['inputs']}
after_inputs={x['path']:x for x in receipts['11']['inputs']}
assert len(before_inputs)==len(after_inputs)==204 and before_inputs.keys()==after_inputs.keys()
for rel,item in after_inputs.items():
    values={n:sha(p/rel) for n,p in stages.items()}
    for n,items in [('10',before_inputs),('11',after_inputs)]:
        if values[n]!=items[rel]['sha256'] or (stages[n]/rel).stat().st_size!=items[rel]['bytes']:errors.append('source receipt mismatch '+n+': '+rel)
    current=sha(SHARED/rel)
    all_inputs.append({'path':rel,'candidate10_sha256':values['10'],'candidate11_sha256':values['11'],'shared_current_sha256':current})
    if values['10']!=values['11']:delta.append(rel)
expected_delta=sorted(x['path'] for x in layout['files'])
if sorted(delta)!=expected_delta:errors.append('unexpected source delta: '+str(delta))
for item in layout['files']:
    rel=item['path']
    if sha(stages['10']/rel)!=item['before_sha256'] or sha(stages['11']/rel)!=item['after_sha256']:errors.append('layout guarded chain mismatch: '+rel)

def pack(path):
    data=path.read_bytes(); magic,fmt,major,minor,patch,flags,base,diroff=struct.unpack_from('<6I2Q',data)
    assert magic==0x43504447 and fmt==4 and (major,minor,patch)==(4,7,2) and flags in (0,2)
    pos=diroff;count=struct.unpack_from('<I',data,pos)[0];pos+=4;files={}
    for _ in range(count):
        length=struct.unpack_from('<I',data,pos)[0];pos+=4
        name=data[pos:pos+length].rstrip(b'\0').decode();pos+=length
        offset,size=struct.unpack_from('<2Q',data,pos);pos+=16
        md5=data[pos:pos+16];pos+=16;entryflags=struct.unpack_from('<I',data,pos)[0];pos+=4
        assert entryflags==0 and name not in files
        payload=data[base+offset:base+offset+size]
        assert len(payload)==size and hashlib.md5(payload).digest()==md5,name
        files[name]={'bytes':size,'sha256':digest(payload),'md5_verified':True}
    return {'pack_sha256':digest(data),'bytes':len(data),'entry_count':count,'entries':files}
packs={n:pack(p/'MafioziPreview.pck') for n,p in exports.items()}
artifacts=[]
for n in exports:
    if packs[n]['pack_sha256']!=expected[n]:errors.append('unexpected PCK SHA '+n)
    if set(packs[n]['entries'])!=set(receipts[n]['packInventory']['paths']):errors.append('PCK receipt directory mismatch '+n)
    for item in receipts[n]['artifacts']:
        p=exports[n]/item['filename'];ok=sha(p)==item['sha256'] and p.stat().st_size==item['bytes']
        artifacts.append(dict(item,candidate=n,verified=ok))
        if not ok:errors.append('artifact mismatch '+n+': '+item['filename'])
names=set(packs['10']['entries'])|set(packs['11']['entries'])
pack_delta={p:{n:packs[n]['entries'].get(p) for n in packs} for p in sorted(names) if packs['10']['entries'].get(p)!=packs['11']['entries'].get(p)}
gdc_delta=[p for p in pack_delta if p.endswith('.gdc')]
if sorted(gdc_delta)!=sorted(p.removesuffix('.gd')+'.gdc' for p in expected_delta):errors.append('unexpected compiled runtime delta: '+str(gdc_delta))
other_delta=[p for p in pack_delta if not p.endswith('.gdc')]
guards=copy.deepcopy(plan['guards'])
for row in guards:
    rel=row['relative_path'];current=sha(SHARED/rel);target=sha(stages['11']/rel)
    if current!=row['expected_current_sha256']:errors.append('shared scoped drift: '+rel)
    if sha(stages['10']/rel)!=row['target_current10_sha256']:errors.append('candidate10 guard drift: '+rel)
    row['target_final11_sha256']=target;row['target_source']=str((stages['11']/rel).relative_to(ROOT)).replace('\\','/')
    row['target_current10_source_sha256']=row.pop('target_current10_sha256')
    row['final11_sha256']=target;row['layout11_changed']=rel in expected_delta
    row['action']='KEEP_IDENTICAL' if current==target else ('CREATE_ONLY_IF_ABSENT' if current is None else 'GUARDED_REPLACE_EXACT_BYTES')
for row in plan['source_inputs']:
    if sha(SHARED/row['path'])!=row['current_sha256']:errors.append('shared204 drift: '+row['path'])
for row in plan['all_unscoped_differences_preserve']:
    if sha(SHARED/row['path'])!=row['current_sha256']:errors.append('preserve shared drift: '+row['path'])
for row in all_inputs:
    if sha(SHARED/row['path'])!=row['shared_current_sha256'] or sha(stages['11']/row['path'])!=row['candidate11_sha256']:errors.append('changed during final verification: '+row['path'])
report={'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'EXACT_FINAL11_GUARDS_READY_ROOT_GUI_ACCEPTANCE_SEPARATE' if not errors else 'BLOCKED','errors':errors,'engine_run':False,'git_run':False,'shared_mutations':False,'candidate_mutations':False,'promotion_performed':False,'source_inputs_verified':204,'source_delta10_11':sorted(delta),'layout_receipt_sha256':sha(layout_path),'candidate10_guard_plan_sha256':sha(plan_path),'artifacts_verified':artifacts,'pck_directories_match_receipts':True,'pck_all_payload_md5_verified':True,'pck_entry_count':{n:packs[n]['entry_count'] for n in packs},'pck_delta10_11':pack_delta,'compiled_runtime_delta':gdc_delta,'other_embedded_delta':other_delta,'guards':guards,'preserve_three_unscoped':plan['preserve_three_unscoped'],'all_unscoped_differences_preserve':plan['all_unscoped_differences_preserve'],'all204_source_inputs':all_inputs,'all21_shared_guards_rechecked':True,'limits':['Root GUI acceptance remains separate; this artifact does not claim a passed ongoing GPU run.','Same23g label is not identity; identify final PCK by ae82e44c SHA.','Preserving shared unscoped work makes the future shared export distinct from the measured candidate.','No whole-tree copying: apply exact21-row guard list only; KEEP_IDENTICAL requires no rewrite.']}
(OUT/'FINAL11_GUARDS.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
(OUT/'FINAL11_PCK_ENTRIES.json').write_text(json.dumps(packs['11'],ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({k:report[k] for k in ['status','errors','source_inputs_verified','source_delta10_11','pck_entry_count','compiled_runtime_delta','other_embedded_delta']},ensure_ascii=False))
