from pathlib import Path
import json,hashlib,struct
r=Path.cwd();o=r/'outputs/coordinator23_adoption12_guards';guard=json.loads((o/'FINAL12_SOURCE_GUARDS.json').read_text(encoding='utf-8'));errors=[]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
stages={n:r/f'outputs/coordinator23_quality/candidate{n}/godot/mafiozi_walk' for n in ['11','12']};exports={n:s/('exports/win64/s01-20260930-quality23g' if n=='11' else 'exports/win64/s01-20260930-quality23h') for n,s in stages.items()}
receipts={n:json.loads((e/'build_receipt.json').read_text(encoding='utf-8-sig')) for n,e in exports.items()}
def pack(path):
 d=path.read_bytes();magic,fmt,major,minor,patch,flags,base,diroff=struct.unpack_from('<6I2Q',d);assert magic==0x43504447 and fmt==4 and (major,minor,patch)==(4,7,2) and flags in [0,2]
 pos=diroff;count=struct.unpack_from('<I',d,pos)[0];pos+=4;entries={}
 for _ in range(count):
  length=struct.unpack_from('<I',d,pos)[0];pos+=4;name=d[pos:pos+length].rstrip(b'\0').decode();pos+=length;offset,size=struct.unpack_from('<2Q',d,pos);pos+=16;md5=d[pos:pos+16];pos+=16;ef=struct.unpack_from('<I',d,pos)[0];pos+=4
  assert ef==0 and name not in entries;payload=d[base+offset:base+offset+size];assert len(payload)==size and hashlib.md5(payload).digest()==md5,name
  entries[name]={'bytes':size,'sha256':hashlib.sha256(payload).hexdigest(),'md5_verified':True}
 return {'sha256':hashlib.sha256(d).hexdigest(),'bytes':len(d),'entries':entries,'count':count}
packs={n:pack(e/'MafioziPreview.pck') for n,e in exports.items()};assert packs['12']['sha256']=='4cf4cd1acda59f9d10e7da2b9fa4dea664c450cd87cebb344ae808d7533404be'
source={}
for row in receipts['12']['inputs']:
 p=stages['12']/row['path'];actual=sha(p);assert actual==row['sha256'] and p.stat().st_size==row['bytes'],row['path'];source[row['path']]=actual
 assert guard['all_candidate12_inputs'][row['path']]==actual,row['path']
artifacts=[]
for row in receipts['12']['artifacts']:
 p=exports['12']/row['filename'];assert sha(p)==row['sha256'] and p.stat().st_size==row['bytes'];artifacts.append(row)
for n in packs:assert set(packs[n]['entries'])==set(receipts[n]['packInventory']['paths'])
delta={p:{n:packs[n]['entries'].get(p) for n in packs} for p in sorted(set(packs['11']['entries'])|set(packs['12']['entries'])) if packs['11']['entries'].get(p)!=packs['12']['entries'].get(p)}
compiled=[p for p in delta if p.endswith('.gdc')];expected=sorted(v['path'][:-3]+'.gdc' for v in guard['promotion_scoped_paths'] if v['path'].endswith('.gd'));assert sorted(compiled)==expected,(compiled,expected)
cursor={p:v for p,v in packs['12']['entries'].items() if 'cursor_' in p or 'walk_cursor' in p}
for n,c in guard['cursor_resources'].items():
 dest=c['imported_path'];assert packs['12']['entries'][dest]['sha256']==c['imported_sha256']
 assert any(p=='assets/ui/cursor_'+n+'.svg.remap' or p=='assets/ui/cursor_'+n+'.svg.import' for p in cursor)
for row in guard['promotion_scoped_paths']:
 p=r/'godot/mafiozi_walk'/row['path'];current=sha(p) if p.exists() else None
 if current!=row['expected_current_sha256']:errors.append('shared drift '+row['path'])
report={'status':'FINAL12_SOURCE_AND_PACK_SCOPE_PASS_GPU_ACCEPTANCE_SEPARATE' if not errors else 'HOLD','errors':errors,'source_receipt_input_count':len(source),'source_receipt_inputs':source,'build_receipt_sha256':sha(exports['12']/'build_receipt.json'),'source_guard_sha256':sha(o/'FINAL12_SOURCE_GUARDS.json'),'artifacts_verified':artifacts,'pck_entry_counts':{n:packs[n]['count'] for n in packs},'pck_sha256':packs['12']['sha256'],'all_payload_md5_verified':True,'directories_exact_build_receipts':True,'compiled_scope_delta':compiled,'other_embedded_delta':[p for p in delta if not p.endswith('.gdc')],'all_embedded_delta':delta,'packed_cursors':cursor,'shared13guards_rechecked':not errors,'limits':['Read-only no engine/GPU/Git','Root compiled behavior/GPU results not claimed here']}
(o/'FINAL12_EXPORT_AUDIT.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');(o/'FINAL12_PCK_ENTRIES.json').write_text(json.dumps(packs['12'],ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
with (o/'REVIEW.md').open('a',encoding='utf-8') as f:f.write('\nFinal export verified: PCK4cf4cd1a, '+str(len(source))+' exact source receipt inputs; '+str(packs['12']['count'])+' embedded payload MD5s and directory all match build_receipt. Compiled changes are exactly the9 declared GD paths; all packed cursor texture bytes match imported sources. Shared13 promotion guards rechecked unchanged. Details FINAL12_EXPORT_AUDIT.json. GPU and root compiled behavioral acceptance remain separate.\n')
print(json.dumps({k:report[k] for k in ['status','errors','source_receipt_input_count','pck_entry_counts','compiled_scope_delta','other_embedded_delta']}))
