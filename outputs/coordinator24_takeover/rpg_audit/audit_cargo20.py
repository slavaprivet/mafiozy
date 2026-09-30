"""Read-only candidate20 source/PCK audit. Never starts Godot or modifies a candidate."""
from pathlib import Path
import hashlib,json,re,struct

root=Path(__file__).resolve().parents[3]
out=Path(__file__).parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
stage=root/'outputs/coordinator24_quality/candidate20'
game=stage/'godot/mafiozi_walk'
export=game/'exports/win64/s01-20260930-quality24a'
base=root/'outputs/coordinator23_quality/candidate16/godot/mafiozi_walk'
base_export=base/'exports/win64/s01-20260930-quality23h'
manifest=load(stage/'INTEGRATION.json')
receipt16=load(base_export/'build_receipt.json')
expected_changes={'scripts/main.gd','data/preview_updates.json','scripts/weapons/preview_weapon_cargo.gd','scripts/weapons/preview_weapons.gd'}
errors=[]
source_rows=[]
for row in receipt16['inputs']:
    path=row['path'];before=sha(base/path);after=sha(game/path)
    if before!=row['sha256']:errors.append('accepted16_input_changed:'+path)
    if before!=after:source_rows.append({'path':path,'before':before,'after':after})
if {r['path'] for r in source_rows}!=expected_changes:errors.append('unexpected_source_delta')
for path,row in manifest['changes'].items():
    if sha(base/path)!=row['before'] or sha(game/path)!=row['after']:errors.append('integration_pin:'+path)
if set(manifest['changes'])!=expected_changes:errors.append('integration_scope')
main=(game/'scripts/main.gd').read_text(encoding='utf8')
baseline_main=(base/'scripts/main.gd').read_text(encoding='utf8')
expected_revision='s01-20260930-quality24a'
main_revision=re.search(r'const PREVIEW_RUNTIME_REVISION := "([^"]+)"',main).group(1)
notes=load(game/'data/preview_updates.json')
if main_revision!=expected_revision or notes['runtime_revision']!=expected_revision:errors.append('revision_mismatch')
if len(notes['items'])!=5 or not any('РПГ пока без урона взрывом' in t for t in notes['items']):errors.append('notes_scope')
if main.replace(expected_revision,'s01-20260930-quality23h')!=baseline_main:errors.append('main_more_than_revision')
weapon=(game/'scripts/weapons/preview_weapons.gd').read_text(encoding='utf8')
baseline_weapon=(base/'scripts/weapons/preview_weapons.gd').read_text(encoding='utf8')
if weapon.replace('func cancel_inputs(reset_camera: bool = true) -> void:\n\tif reset_camera and aim_camera!=null: aim_camera.reset()','func cancel_inputs() -> void:\n\tif aim_camera!=null: aim_camera.reset()')!=baseline_weapon:errors.append('weapons_more_than_optional_reset')

def pack(path):
    data=path.read_bytes()
    magic,version,major,minor,patch,flags,base_offset,directory=struct.unpack_from('<6I2Q',data)
    if (magic,version,major,minor,patch,flags)!=(0x43504447,4,4,7,2,2):raise ValueError('pack_header')
    pos=directory;count,=struct.unpack_from('<I',data,pos);pos+=4
    files={};bad=[]
    for _ in range(count):
        length,=struct.unpack_from('<I',data,pos);pos+=4
        name=data[pos:pos+length].rstrip(b'\0').decode('utf8');pos+=length
        offset,size,digest,entry_flags=struct.unpack_from('<QQ16sI',data,pos);pos+=36
        payload=data[base_offset+offset:base_offset+offset+size]
        if entry_flags or len(payload)!=size or hashlib.md5(payload).digest()!=digest:bad.append(name)
        files[name]={'sha256':hashlib.sha256(payload).hexdigest(),'bytes':size}
    return files,bad

result={'scope':'Independent read-only source/export hash audit; no Godot or tests executed','candidate':'candidate20','base':'accepted16','expected_base_pack_sha256':'8051926d109704cb4f85eb46cd2af8dd5b9a84d9cc4e71480db22b699dce7741','source_count':len(receipt16['inputs']),'source_changes':source_rows,'source_error_list':errors.copy(),'main_revision':main_revision,'notes_revision':notes['runtime_revision'],'notes_count':len(notes['items']),'notes_rpg_remains_without_blast_damage':True,'base16_quarantine_correction':'_process clears take-release maps whenever not _allowed; prior stale-after-focus hypothesis withdrawn.'}
receipt_path=export/'build_receipt.json'
if not receipt_path.exists():
    result['export_status']='PENDING_EXPORT_RECEIPT'
else:
    receipt=load(receipt_path)
    files20,bad20=pack(export/'MafioziPreview.pck')
    files16,bad16=pack(base_export/'MafioziPreview.pck')
    mismatches=[r['path'] for r in receipt['inputs'] if not (game/r['path']).exists() or sha(game/r['path'])!=r['sha256']]
    artifact_bad=[r['filename'] for r in receipt['artifacts'] if sha(export/r['filename'])!=r['sha256']]
    changed_payloads=sorted(n for n in set(files16)|set(files20) if files16.get(n)!=files20.get(n))
    allowed_payloads={'scripts/main.gdc','data/preview_updates.json','scripts/weapons/preview_weapon_cargo.gdc','scripts/weapons/preview_weapons.gdc','.godot/uid_cache.bin'}
    unexpected_payloads=sorted(set(changed_payloads)-allowed_payloads)
    if {r['path'] for r in receipt['inputs']}!={r['path'] for r in receipt16['inputs']}:errors.append('input_set_drift')
    errors.extend('input:'+n for n in mismatches)
    errors.extend('artifact:'+n for n in artifact_bad)
    errors.extend('pack_md5:'+n for n in bad20+bad16)
    errors.extend('unexpected_payload:'+n for n in unexpected_payloads)
    if sha(base_export/'MafioziPreview.pck')!=result['expected_base_pack_sha256']:errors.append('base_pack_hash')
    result.update(export_status='VERIFIED' if not errors else 'FAIL',export_receipt_sha256=sha(receipt_path),integration_sha256=sha(stage/'INTEGRATION.json'),pack_sha256=sha(export/'MafioziPreview.pck'),export_source_count=len(receipt['inputs']),input_hash_errors=mismatches,artifact_hash_errors=artifact_bad,baseline_payload_count=len(files16),candidate_payload_count=len(files20),baseline_payload_md5_errors=bad16,candidate_payload_md5_errors=bad20,changed_payloads=changed_payloads,unexpected_payloads=unexpected_payloads,unchanged_payload_count=sum(files16.get(n)==v for n,v in files20.items()),errors=errors)
(out/'CARGO20_CLOSURE.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps(result,ensure_ascii=False,indent=2))
