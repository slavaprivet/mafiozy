"""Create a one-hunk proposal and compact fixture, without touching any game."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
BASE=ROOT/'outputs/coordinator30_release55/game'
REL='scripts/npc_visual/npc_resident_diag.gd'
before='\tif not body.is_inside_tree() or body.is_queued_for_deletion() or not Focus29.focused(body):\n\t\t_hp_fast30.hidden+=1;_release_focus30(body);return\n'
after='''\tif not body.is_inside_tree() or body.is_queued_for_deletion():
\t\t_hp_fast30.hidden+=1;_release_focus30(body);return
\tif not Focus29.focused(body):
\t\t_hp_fast30.hidden+=1
\t\t# HP-only mode owns one focused card. Diagnostic update() also has a legacy writer.
\t\tif diag_on() or (_focused_body30!=null and _focused_body30.get_ref()==body):
\t\t\t_release_focus30(body)
\t\treturn
'''
source=(BASE/REL).read_text(encoding='utf-8-sig')
assert source.count(before)==1
spec={'base':'frozen55','base_sha256':hashlib.sha256((BASE/REL).read_bytes()).hexdigest(),'changes':[{'file':REL,'before':before,'after':after}],'helpers':{}}
(HERE/'PATCH56.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2),encoding='utf-8')
dest=HERE/'patch'/REL;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(source.replace(before,after,1),encoding='utf-8')
fixture=(HERE.parent/'diag_perf30/qa/diag_perf30_native.gd').read_text(encoding='utf-8-sig')
fixture=fixture.replace('\tawait actual_city()\n','').replace('create_timer(200.0)','create_timer(25.0)')
start=fixture.index('func actual_city() -> void:');end=fixture.index('func finish() -> void:',start)
fixture=fixture[:start]+fixture[end:]
fixture=fixture.replace('DIAG_PERF30','HP_RELEASE56')
fixture=fixture.replace('"performance_accepted":false','"performance_accepted":false,"scope":"native focus/label lifecycle; HP rows controlled by fixture, no combat/city claim"')
anchor='\tvar successor:=FixtureLife.new();'
extra='''\t# Look-away must release the tracked ordinary card in the same call.
\tawait aim(scene,camera,bodies[286]);Diag.repaint_focus30(bodies[286])
\tawait aim(scene,camera,bodies[2]);Diag.repaint_focus30(bodies[286])
\tcheck(not label.visible and Diag._focused_body30==null,"ordinary look-away releases tracked card immediately")
\t# Diagnostic update is a separate legacy writer and does not own _focused_body30.
\tDiag._diag_flag=1
\tDiag.update("fixture_2",bodies[2],lives[2].row,{}, {},"Resident")
\tvar legacy: Label3D=Diag._cached_label30(bodies[2])
\tcheck(legacy!=null and legacy.visible and Diag._focused_body30==null,"legacy diagnostic update creates an untracked visible card")
\tawait aim(scene,camera,bodies[3]);Diag.repaint_focus30(bodies[2])
\tcheck(legacy!=null and not legacy.visible,"diagnostic look-away still releases untracked card")
\tDiag._diag_flag=0
\t# Retirement cleanup must not depend on the ordinary focus pointer.
\tawait aim(scene,camera,bodies[4]);Diag._diag_flag=1
\tDiag.update("fixture_4",bodies[4],lives[4].row,{}, {},"Resident")
\tvar queued_label: Label3D=Diag._cached_label30(bodies[4]);Diag._diag_flag=0
\tbodies[4].queue_free();Diag.repaint_focus30(bodies[4])
\tcheck(queued_label!=null and not queued_label.visible,"queued untracked body releases its label before deletion")
\tDiag.unregister_life30("fixture_4",lives[4])
\tcheck(not Diag._labels.has(str(bodies[4].get_instance_id())),"unregister removes retired unfocused cache")
\tawait aim(scene,camera,bodies[5]);Diag._diag_flag=1
\tDiag.update("fixture_5",bodies[5],lives[5].row,{}, {},"Resident")
\tvar detached_label: Label3D=Diag._cached_label30(bodies[5]);Diag._diag_flag=0
\tscene.remove_child(bodies[5]);Diag.repaint_focus30(bodies[5])
\tcheck(detached_label!=null and not detached_label.visible,"detached untracked body releases its label")
\tscene.add_child(bodies[5])
'''
assert fixture.count(anchor)==1
fixture=fixture.replace(anchor,extra+anchor,1)
(HERE/'fixture56.gd').write_text(fixture,encoding='utf-8')
print(json.dumps({'hunks':1,'patch_sha256':hashlib.sha256((HERE/'PATCH56.json').read_bytes()).hexdigest()}))
