"""Root-only guarded 24c promotion. Default checks only; --apply copies scoped files. No Git/engine/launch."""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, shutil

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT/'outputs/coordinator24_quality/candidate25/godot/mafiozi_walk'
SHARED = ROOT/'godot/mafiozi_walk'
EXPORT = GAME/'exports/win64/s01-20260930-quality24c'
OUT = ROOT/'outputs/coordinator24_delivery24c'
DEST = SHARED/'exports/win64/s01-20260930-quality24c-play'
HERE = Path(__file__).resolve().parent
PACK = 'fa1504583eefd212211a87ced7c2fc7805885213aa71d9211c63447f4ac74863'
ASSEMBLY = 'f506b940a4a3adb48263f67c9115d4843ce5429ea7944b0af96ce8c831b71770'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
save = lambda p,v: p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
args = argparse.ArgumentParser(); args.add_argument('--apply',action='store_true'); a=args.parse_args()
proof_pins = {
 'outputs/coordinator24_delivery24b/build_receipt.json':'7864b23dcb9218b77864489d8505c1eeed9ecdd4652368e36bb117d971c814cb',
 'outputs/coordinator24_quality/candidate25/godot/mafiozi_walk/exports/win64/s01-20260930-quality24c/build_receipt.json':'801ed28b63db8dedc3ecfe935d56256b35a3f5c326dd8d49c0489702c1888d65',
 'outputs/coordinator24_npc_delivery/combined25/ASSEMBLY25.json':ASSEMBLY,
 'outputs/coordinator24_npc_delivery/combined25/observer01/RUN.json':'bf26c00d9bbe78219b1481373b9cc7a91c540aaca567e7ea3107f313be5f1b1f',
 'outputs/coordinator24_npc_delivery/combined25/observer01/observer/RESULT.json':'36d6b01e9230c4433fdcf782d64bcc0e90a004a74163ec4996b43850c4020e3c',
 'outputs/coordinator24_npc_combat/compiled25_gpu02/RUN.json':'6c6c3cf4f6b19aa4b76d8f7166f25aa4e6ddd7e50f64ac0117fa5e6053b59dbb',
 'outputs/coordinator24_npc_combat/compiled25_gpu02/RESULT.json':'0b8111e551de7674a13da4a94dda05842cf7b110bd42da1aa8d13f9080e114b3',
}
for rel, expected in proof_pins.items(): assert sha(ROOT/rel)==expected, 'Proof drift: '+rel
base=load(ROOT/'outputs/coordinator24_delivery24b/build_receipt.json')
receipt=load(EXPORT/'build_receipt.json'); asm=load(HERE/'combined25/ASSEMBLY25.json')
bp={r['path']:r['sha256'] for r in base['inputs']}; ap={r['path']:r['sha256'] for r in receipt['inputs']}
assert len(bp)==209 and len(ap)==224 and set(bp)<=set(ap)
assert ap==asm['source_pins']=={r['path']:r['sha256'] for r in asm['inputs']}
assert receipt['sourceInputsUnchangedDuringExport'] and sha(EXPORT/'MafioziPreview.pck')==PACK
for rel,expected in ap.items():
 assert (GAME/rel).resolve().is_relative_to(GAME.resolve()) and (SHARED/rel).resolve().is_relative_to(SHARED.resolve()), rel
 assert sha(GAME/rel)==expected, 'Frozen25 drift: '+rel
for item in receipt['artifacts']: assert sha(EXPORT/item['filename'])==item['sha256'], item['filename']
observer=load(HERE/'combined25/observer01/RUN.json'); result=load(HERE/'combined25/observer01/observer/RESULT.json')
assert observer['valid'] and observer['input_count']==224 and observer['pins_sha256']==ASSEMBLY
assert all(c['ok'] and c['own_child_stopped'] and not c['native_errors'] and not c['pins_changed'] for c in observer['children'])
assert result['valid'] and result['checks']==51780 and not result['errors'] and result['freeze_files_checked']==224
assert result['visit']['phase']=='COMPLETE' and result['post_completion_frames']==180 and result['post_completion_travel_m']>0.1
gpu=load(ROOT/'outputs/coordinator24_npc_combat/compiled25_gpu02/RUN.json')
gr=load(ROOT/'outputs/coordinator24_npc_combat/compiled25_gpu02/RESULT.json')
assert gpu['passed'] and gpu['behavior_pass'] and gpu['exit_code']==0 and not gpu['native_errors'] and not gpu['errors'] and not gpu['changed']
assert gpu['checks']==60 and gr['passed'] and gr['checks']==60 and not gr['errors']
assert gpu['assembly_sha256']==gpu['assembly_after_sha256']==ASSEMBLY and gpu['pack_sha256']==gpu['pack_after_sha256']==PACK
generated={'scripts/weapons/scope_optic.svg.import':'0081075e89bfbdcb69ea6dea5a1e021a38fa40a734c0a732cbdab2eac00fb006'}
assert gpu['source_count']==224 and gpu['non_runtime_extra_pins']==generated
assert gpu['all_source_before']==gpu['all_source_after']==(ap|generated)
for rel,expected in generated.items(): assert sha(GAME/rel)==expected, 'Generated import drift: '+rel
scope={rel for rel,s in ap.items() if bp.get(rel)!=s}
assert len(scope)==22
plan=load(HERE/'promotion24c/SCOPED_PLAN.json')
assert scope==set(plan['changes']) and plan['assembly_sha256']==ASSEMBLY and plan['pack_sha256']==PACK
changes={}
for rel in sorted(scope):
 current=sha(SHARED/rel); expected=plan['changes'][rel]
 assert bp.get(rel)==expected['base_sha256'] and ap[rel]==expected['after_sha256']
 assert current==expected['shared_before_sha256'], 'Concurrent scoped change: '+rel
 if rel=='scenes/main.tscn':
  old=ROOT/'outputs/coordinator24_quality/candidate22/godot/mafiozi_walk'/rel
  assert sha(old)==bp[rel] and old.read_bytes().replace(b'\r\n',b'\n')==(SHARED/rel).read_bytes(), 'Scene is not the allowed base LF normalization'
  assert b'\r' not in (GAME/rel).read_bytes(), 'Keep merged scene LF'
 else: assert current in (bp.get(rel),ap[rel]), 'Unexpected owner conflict: '+rel
 changes[rel]={'before_sha256':current,'after_sha256':ap[rel],'base_sha256':bp.get(rel),'write':current!=ap[rel]}
assert not OUT.exists() and not DEST.exists(), 'Delivery destination already exists; inspect instead of overwrite'
def unscoped():
 return {p.relative_to(SHARED).as_posix():sha(p) for p in SHARED.rglob('*') if p.is_file() and not any(x in ('.godot','exports') for x in p.relative_to(SHARED).parts) and p.relative_to(SHARED).as_posix() not in scope}
preserved=unscoped()
owner_wip={rel:preserved.get(rel) for rel in ap if rel not in scope and preserved.get(rel)!=ap[rel]}
record={'status':'CHECKED_NOT_APPLIED','revision':'s01-20260930-quality24c','candidate':'candidate25','assembly_sha256':ASSEMBLY,'pack_sha256':PACK,'source_count':224,'scoped_count':22,'changes':changes,'preserved_unscoped':preserved,'preserved_owner_wip':owner_wip,'proof_pins':proof_pins,'compiled_export_destination':DEST.relative_to(ROOT).as_posix(),'scene_note':'Base scene differs only CRLF to LF; frozen25 adds the authorized scene_hook and is already LF. Exact after bytes are preserved.','limits':'Local three-resident preview only. Hit-location fixpoint observation remains pending a separate candidate. Physical corpse blocking/nudge and building destruction remain pending. No whole-city FPS acceptance. Shared owner WIP is preserved, so shared source is not claimed byte-identical to the frozen compiled candidate. No engine, Git or game launch performed.'}
if a.apply:
 OUT.mkdir()
 record['status']='IN_PROGRESS'; save(OUT/'PROMOTION.json',record)
 try:
  # Back up every existing scoped file before the first shared mutation.
  for rel,change in changes.items():
   assert sha(SHARED/rel)==change['before_sha256'], 'Concurrent scoped change before backup: '+rel
   if change['before_sha256'] is not None:
    backup=OUT/'before'/rel; backup.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(SHARED/rel,backup)
    assert sha(backup)==change['before_sha256'], 'Backup mismatch: '+rel
  save(OUT/'BEFORE.json',{'changes':changes,'preserved_unscoped':preserved,'owner_wip':owner_wip})
  assert unscoped()==preserved, 'Unscoped bytes changed before promotion'
  for rel,change in changes.items():
   assert sha(SHARED/rel)==change['before_sha256'] and sha(GAME/rel)==change['after_sha256'], 'Concurrent delta drift: '+rel
   if change['write']:
    target=SHARED/rel; target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(GAME/rel,target)
   assert sha(SHARED/rel)==change['after_sha256'], 'Promotion mismatch: '+rel
  assert unscoped()==preserved, 'Unscoped bytes changed during promotion'
  DEST.mkdir(parents=True)
  for name in ('MafioziPreview.exe','MafioziPreview.pck','build_receipt.json'):
   shutil.copyfile(EXPORT/name,DEST/name); assert sha(DEST/name)==sha(EXPORT/name), name
  assert sha(DEST/'MafioziPreview.pck')==PACK
  for rel,expected in ap.items(): assert sha(GAME/rel)==expected, 'Frozen25 drift after promotion: '+rel
  assert unscoped()==preserved, 'Unscoped bytes changed during export copy'
  for rel,expected in proof_pins.items(): assert sha(ROOT/rel)==expected, 'Proof changed during promotion: '+rel
  shutil.copyfile(EXPORT/'build_receipt.json',OUT/'build_receipt.json')
  for name in ('SCOPED_PLAN.json','GIT_FILELIST.txt','CHECKLIST.md','ACCEPTANCE.md'):
   shutil.copyfile(HERE/'promotion24c'/name,OUT/name)
  record['status']='ACCEPTED_SCOPED_PROMOTION'; record['finished_utc']=datetime.now(timezone.utc).isoformat()
 except Exception as error:
  record['status']='FAILED_INSPECT_BEFORE_BACKUPS'; record['error']=str(error); save(OUT/'PROMOTION.json',record); raise
 save(OUT/'PROMOTION.json',record)
print(json.dumps({'status':record['status'],'scoped':len(changes),'will_write':sum(c['write'] for c in changes.values()),'preserved_unscoped':len(preserved),'owner_wip':owner_wip,'pack_sha256':PACK},ensure_ascii=False))
