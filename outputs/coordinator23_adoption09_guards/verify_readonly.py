"""Read source/export/PCK only; writes reports under this output directory."""
from pathlib import Path
import json, hashlib, struct, difflib, subprocess, datetime, re
ROOT=Path(__file__).resolve().parents[2]; OUT=Path(__file__).resolve().parent
def digest(b): return hashlib.sha256(b).hexdigest() if b is not None else None
def read(p): return p.read_bytes() if p.exists() else None
def jread(p): return json.loads(p.read_text(encoding='utf-8-sig'))
stages={n:ROOT/f'outputs/coordinator23_quality/candidate{n}/godot/mafiozi_walk' for n in ['08','09']}
exports={n:p/'exports/win64/s01-20260930-quality23f' for n,p in stages.items()}
receipts={n:jread(p/'build_receipt.json') for n,p in exports.items()}
integration=jread(stages['09'].parents[1]/'INTEGRATION.json')
old=jread(ROOT/'outputs/coordinator23_adoption08_guards/HASH_INVENTORY.json')
def pack(path):
    data=path.read_bytes(); magic,fmt,major,minor,patch,flags,base,diroff=struct.unpack_from('<6I2Q',data)
    assert magic==0x43504447 and fmt==4 and (major,minor,patch)==(4,7,2) and flags in (0,2)
    pos=diroff; count=struct.unpack_from('<I',data,pos)[0]; pos+=4; files={}
    for i in range(count):
        length=struct.unpack_from('<I',data,pos)[0]; pos+=4
        name=data[pos:pos+length].rstrip(b'\0').decode(); pos+=length
        offset,size=struct.unpack_from('<2Q',data,pos); pos+=16
        md5=data[pos:pos+16]; pos+=16
        entryflags=struct.unpack_from('<I',data,pos)[0]; pos+=4; assert entryflags==0
        payload=data[base+offset:base+offset+size]
        assert len(payload)==size and hashlib.md5(payload).digest()==md5, name
        files[name]={'bytes':size,'sha256':digest(payload)}
    return {'sha256':digest(data),'bytes':len(data),'format':fmt,'entries':files}
packs={n:pack(p/'MafioziPreview.pck') for n,p in exports.items()}
rows=[]; delta=[]
for item in receipts['09']['inputs']:
    rel=item['path']; candidate=read(stages['09']/rel); parent=read(stages['08']/rel)
    assert digest(candidate)==item['sha256'] and len(candidate)==item['bytes'],rel
    if candidate!=parent: delta.append(rel)
    current=read(ROOT/'godot/mafiozi_walk'/rel)
    rows.append({'path':rel,'candidate_sha256':digest(candidate),'parent08_sha256':digest(parent),'current_sha256':digest(current)})
assert len(rows)==203 and delta==['scripts/npc_visual/npc_bullet_marks.gd'],delta
artifacts=[]
for item in receipts['09']['artifacts']:
    raw=read(exports['09']/item['filename'])
    assert digest(raw)==item['sha256'] and len(raw)==item['bytes']
    artifacts.append(item)
assert packs['09']['sha256']=='51892e6818d85edf4903362de225e4c71eaf262134df859c3c2a012751d5d83e'
assert set(packs['09']['entries'])==set(receipts['09']['packInventory']['paths'])
pack_delta=[p for p in sorted(set(packs['08']['entries'])|set(packs['09']['entries'])) if packs['08']['entries'].get(p)!=packs['09']['entries'].get(p)]
guards=[]; drift=[]; patches=[]
for previous in old['rows']:
    p=previous['path']; rel=p.removeprefix('godot/mafiozi_walk/')
    current=read(ROOT/p); cand=read(stages['09']/rel)
    head=subprocess.run(['git','show','HEAD:'+p],cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL).stdout
    headsha=digest(head) if head else None
    row={'path':p,'candidate09_sha256':digest(cand),'current_sha256':digest(current),'HEAD_sha256':headsha,'accepted05_sha256':previous['accepted05_sha256'],'prior_current_sha256':previous['current_sha256'],'drift_since08_review':digest(current)!=previous['current_sha256']}
    if row['drift_since08_review']: drift.append(p)
    row['action']='EXCLUDE_UNSCOPED'
    if rel in integration['changes']:
        assert digest(cand)==integration['changes'][rel]['after'],rel
        row['action']='KEEP_IDENTICAL' if current==cand else ('CREATE_ONLY_IF_ABSENT' if current is None else 'GUARDED_EXACT_CANDIDATE_PROMOTION')
        if current!=cand:
            patches.extend(difflib.unified_diff((current or b'').decode('utf-8-sig').replace('\r\n','\n').splitlines(True),cand.decode('utf-8-sig').replace('\r\n','\n').splitlines(True),fromfile='a/'+p if current else '/dev/null',tofile='b/'+p))
    guards.append(row)
unscoped=[]
for row in rows:
    rel=row['path']
    if rel in integration['changes'] or row['candidate_sha256']==row['current_sha256']: continue
    shared=(ROOT/'godot/mafiozi_walk'/rel).read_text(encoding='utf-8-sig')
    candidate=(stages['09']/rel).read_text(encoding='utf-8-sig')
    entry=dict(row,action='EXCLUDE_KEEP_SHARED',newline_only=shared==candidate)
    unscoped.append(entry)
    if shared!=candidate:
        (OUT/(rel.replace('/','__')+'.EXCLUDED.diff')).write_text(''.join(difflib.unified_diff(shared.splitlines(True),candidate.splitlines(True),fromfile='shared/'+rel,tofile='candidate09/'+rel)),encoding='utf-8')
def txt(root,rel):return (root/rel).read_text(encoding='utf-8-sig')
def code(t):return '\n'.join(x for x in t.splitlines() if x.strip() and not x.lstrip().startswith('#'))
owner='scripts/npc_visual/npc_local_preview_hit_owner.gd'
a=txt(ROOT/'godot/mafiozi_walk',owner); b=txt(stages['09'],owner)
def func(t,name):return re.search(r'^func '+re.escape(name)+r'\(.*?(?=^func |\Z)',t,re.M|re.S).group(0).strip()
assert func(a,'_publish_physical')==func(b,'_publish_physical')
for literal in ['const MEDICAL_IMPULSE_MAX_NS:=75.0','const POINT_SHARE:=0.10','const POINT_MAX_NS:=2.5']: assert literal in a and literal in b
lc='scripts/npc_visual/npc_ordinary_hit_lifecycle.gd'
assert code(txt(ROOT/'godot/mafiozi_walk',lc))==code(txt(stages['09'],lc))
# Finish by repeating every shared203 hash, so no old guard is silently reused.
end_drift=[r['path'] for r in rows if digest(read(ROOT/'godot/mafiozi_walk'/r['path']))!=r['current_sha256']]
assert not end_drift,end_drift
report={'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'HEAD':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'engine_run':False,'production_edits':False,'source_inputs_verified':203,'source_delta08_09':delta,'pack_entry_count':len(packs['09']['entries']),'pack_all_payload_md5_verified':True,'pack_delta08_09':pack_delta,'artifacts_verified':artifacts,'shared_drift_since08_review':drift,'all203_current_rechecked_at_end':True,'unscoped_shared_differences':unscoped,'guards':guards,'all203source_inputs':rows,'pack_changed_payloads':{p:{n:packs[n]['entries'].get(p) for n in packs} for p in pack_delta},'limits':['PCK hashes/inventory and embedded payload checksums verified without engine. Compiled bytecode-to-source semantics follow export receipt; no decompiler proof claimed.','EXACT_PROMOTION.patch is readable logical diff only; exact candidate bytes require guarded file bytes replacement after owner/root review.','Preserve unscoped palette and transport WIP; do not sync full candidate tree.']}
(OUT/'VERIFY_AND_GUARDS.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(OUT/'EXACT_PROMOTION.patch').write_text(''.join(patches),encoding='utf-8',newline='\n')
print(json.dumps({k:report[k] for k in ['HEAD','source_inputs_verified','source_delta08_09','pack_entry_count','pack_delta08_09','shared_drift_since08_review']},ensure_ascii=False))
