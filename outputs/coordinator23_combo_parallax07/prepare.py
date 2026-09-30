from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
BASE=ROOT/'outputs/coordinator23_quality/candidate07/godot/mafiozi_walk'
parent=ROOT/'outputs/artist23_hit_impulse/ready_base.gd'
source=parent.read_text(encoding='utf-8')
old='const HitOwner=preload("ready_impulse_only/npc_local_preview_hit_owner.gd")'
assert source.count(old)==1
(OUT/'base.gd').write_text(source.replace(old,'const HitOwner=preload("res://scripts/npc_visual/npc_local_preview_hit_owner.gd")'),encoding='utf-8',newline='\n')
source=(ROOT/'outputs/coordinator23_point_impulse_audit/test_parallax.gd').read_text(encoding='utf-8')
source=source.replace('extends "../artist23_hit_impulse/ready_base.gd"\nconst MergedOwner=preload("merged_owner.gd")\nconst CorrectedOwner=preload("corrected_owner.gd")','extends "base.gd"')
source=source.replace('owner_script=CorrectedOwner if corrected else MergedOwner','owner_script=HitOwner')
source=source.replace('for corrected:bool in [false,true]:','for corrected:bool in [true]:')
source=source.replace('actual candidate05 main','actual candidate07 main').replace('actual candidate05 main native','actual candidate07 main native')
needle='\tfor terminal:Dictionary in terminals:\n\t\tif terminal.shotId==shot.shotId:owner._on_projectile_resolved(terminal)'
extra='''\tcheck(owner.last_contact.get("incoming_direction",Vector3.ZERO).distance_to(accepted.direction.normalized())<.000001,"wound ray paired with the exact same accepted terminal")
\tcheck(owner.last_contact.point==accepted.point and owner.last_contact.normal==accepted.normal,"wound point normal direction remain one terminal tuple")
\tcheck(owner._serial==1 and owner._row.hp==0,"one completed source HP transaction per target")
\tcheck(owner.blood._last_revision==owner.last_result.revision and owner.blood.renderer.emitted==20,"one source-normal blood burst per completed transaction")
\tcheck(owner.marks._last_revision==owner.last_result.revision and owner.marks.renderer._marks.size()==1,"one genuine original-surface persistent mark")
\tvar mark_hash:String=JSON.stringify(owner.marks.renderer._marks).sha256_text()
\tvar blood_count:int=owner.blood.renderer.emitted
\tvar before_result:Dictionary=owner.last_result.duplicate(true)
'''
assert source.count(needle)==1;source=source.replace(needle,extra+needle)
needle='\tcheck(owner.last_impulse==impulse and owner._point_consumed.size()==1,"replay cannot duplicate point impulse")'
extra='''
\tcheck(owner._serial==1 and owner.last_result==before_result and owner._row.hp==0,"terminal replay cannot repeat HP")
\tcheck(owner.blood.renderer.emitted==blood_count and not owner.blood.receive(owner.last_contact.event_id,accepted.point,accepted.normal),"replay cannot duplicate admitted blood")
\tcheck(JSON.stringify(owner.marks.renderer._marks).sha256_text()==mark_hash and not owner.marks.receive(owner.last_contact.event_id,accepted.point,accepted.normal),"replay cannot duplicate or alter persistent wound")
'''
assert source.count(needle)==1;source=source.replace(needle,needle+extra)
source=source.replace('"corrected":corrected,','"corrected":corrected,"wound_direction":owner.last_contact.incoming_direction,"marks":owner.marks.renderer._marks.size(),"mark_hash":mark_hash,"blood_particles":blood_count,"hp_commits":owner._serial,')
source=source.replace('func run()->void:\n','func run()->void:\n\tcreate_timer(35).timeout.connect(func(): print("FAIL bounded timeout"); quit(2))\n')
source=source.replace('"rows":rows,"scope":','"rows":rows,"owner_sha256":FileAccess.get_sha256("res://scripts/npc_visual/npc_local_preview_hit_owner.gd"),"test_sha256":FileAccess.get_sha256(get_script().resource_path),"scope":')
(OUT/'test.gd').write_text(source,encoding='utf-8',newline='\n')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
pins={'parent_fixture_sha256':sha(parent),'original_parallax_sha256':sha(ROOT/'outputs/coordinator23_point_impulse_audit/test_parallax.gd'),'local_files':{p.name:sha(p) for p in OUT.glob('*.gd')},'project_inputs':{p.relative_to(BASE).as_posix():sha(p) for p in BASE.rglob('*') if p.is_file() and not set(p.relative_to(BASE).parts)&{'.godot','exports'}},'purpose':'single headless actual candidate07 res:// owner parallax/HP/blood/marks/point proof; not UI/GPU/performance'}
(OUT/'INPUTS.json').write_text(json.dumps(pins,indent=2),encoding='utf-8',newline='\n')
assert pins['project_inputs']['scripts/npc_visual/npc_local_preview_hit_owner.gd']=='fa1c551a8501f1f731126d374c25ab07ac209137862febd5ee40ec0b7102049e'
print('Prepared',pins['local_files'])
