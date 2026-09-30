"""OUTPUTS ONLY. Build a guarded proposal; never modify candidate06 or shared files."""
from pathlib import Path
import hashlib, json, difflib

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
BASE=ROOT/'outputs/coordinator23_quality/candidate06/godot/mafiozi_walk'
AUDIT=ROOT/'outputs/coordinator23_combo_grid_review'
FROZEN=AUDIT/'frozen_grid045'
sha=lambda b:hashlib.sha256(b).hexdigest()
def write(p,b):p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
def text(p,s):write(p,s.encode('utf-8'))
owner='scripts/npc_visual/npc_local_preview_hit_owner.gd'
population='scripts/preview_population.gd'
assert sha((BASE/owner).read_bytes())=='e4ecf5b39a9d06244d51c01f9e1c4d2c8268ee90639600c690b09572d4096f04'
assert sha((BASE/population).read_bytes())=='f98702f302b1b275829e43c622a3e93e02310634860cd0f77431aa056de790a7'
files={owner:(AUDIT/'proposed'/owner).read_bytes()}
for name in ['npc_bullet_marks.gd','npc_hit_marks_adapter.gd','npc_blood_renderer.gd']:
    rel='scripts/npc_visual/'+name;files[rel]=(FROZEN/rel).read_bytes()
before=(BASE/population).read_text(encoding='utf-8')
anchor='\tif _staged_preview: residents.preview_walk_step(delta)\n'
assert before.count(anchor)==1
after=before.replace(anchor,anchor+'\tfor owner: RefCounted in hit_owners:\n\t\tif owner.marks!=null and owner.marks.renderer!=null and not owner.marks.renderer._marks.is_empty(): owner.marks.step()\n')
files[population]=after.encode('utf-8')
changes={}
for rel,data in files.items():
    before_bytes=(BASE/rel).read_bytes() if (BASE/rel).exists() else None
    changes[rel]={'before_sha256':sha(before_bytes) if before_bytes is not None else None,'after_sha256':sha(data),'origin':'corrected e4ec + marks hooks and paired terminal direction' if rel==owner else 'candidate06 + only marks step; contact wiring preserved' if rel==population else 'byte-identical frozen grid045 stage','tested':False if rel in [owner,population] else 'owner grid045 evidence; see audit limits'}
    write(OUT/'files'/rel,data)
    patch=''.join(difflib.unified_diff((before_bytes or b'').decode('utf-8').splitlines(True),data.decode('utf-8').splitlines(True),fromfile='a/'+rel,tofile='b/'+rel))
    text(OUT/'diffs'/(rel.replace('/','__')+'.patch'),patch)
# Assert the four accepted e4ec direction seams and mark's matching ray all survive.
new_owner=files[owner].decode('utf-8')
for needle in ['physical_direction: Vector3=Vector3.ZERO','damage,direction if physical_direction==Vector3.ZERO else physical_direction,','"physical_direction":receipt.direction','group.point,group.normal,group.physical_direction)','"incoming_direction":(direction if physical_direction==Vector3.ZERO else physical_direction).normalized()']:
    assert needle in new_owner,needle
assert after.replace('\tfor owner: RefCounted in hit_owners:\n\t\tif owner.marks!=null and owner.marks.renderer!=null and not owner.marks.renderer._marks.is_empty(): owner.marks.step()\n','')==before
dependencies={rel:sha((BASE/rel).read_bytes()) for rel in ['scripts/npc_visual/npc_hit_impulse.gd','scripts/npc_visual/npc_blood_adapter.gd','scripts/npc_visual/npc_ordinary_hit_lifecycle.gd','scripts/npc_visual/npc_ragdoll_host.gd','scripts/npc_visual/npc_body.gd','scripts/npc_visual/preview_resident_host.gd','scripts/weapons/weapon_projectiles.gd','scripts/weapons/weapon_fire.gd','scripts/weapons/weapon_hit_rules.gd','assets/npc_visual/session/prepared/manifest.json']}
receipt={'schema':'mafiozi.outputs-only.proposed-combo-merge/v1','base':'outputs/coordinator23_quality/candidate06/godot/mafiozi_walk','status':'PROPOSAL UNTESTED; do not treat grid045 743/23 as new SHA acceptance','grid045_pck_sha256':'20b208a3d5932268f3cf4f40a4985dee91327209179cb91a20413eccf99bbeba','changes':changes,'unchanged_dependency_guards':dependencies,'export_add_only':['res://scripts/npc_visual/npc_bullet_marks.gd','res://scripts/npc_visual/npc_hit_marks_adapter.gd'],'guard':'Before root overlay, require every before_sha256 and dependency guard to match. Null requires absent target. If population changed for corpse port since f987, rebase only its two-line marks loop, never overwrite newer contact wiring. Do not copy stage project/export/main/player. New export entries must preserve all existing resources/addons/raw source receipts.','headshot':'NOT INCLUDED; anatomical head04 656 owner evidence is a separate unfrozen combined closure','limits':['No engine, GPU, runtime compilation or performance tests performed on this proposal.','Blood renderer contains user-requested 1.65 radius/.95 opacity adjustment, not source-exact appearance.','First grouped pellet point/normal/direction are kept together; HP direction remains source camera base_direction.','No corpse-port code change. No additional HP/point commits, particle count, force/cap, ragdoll or medical policy changes.']}
text(OUT/'RECEIPT.json',json.dumps(receipt,indent=2,ensure_ascii=False)+'\n')
print(json.dumps(changes,indent=2))
