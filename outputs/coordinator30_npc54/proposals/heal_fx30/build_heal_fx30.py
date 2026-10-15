from pathlib import Path
import hashlib,json,difflib
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3];BASE=ROOT/'outputs/coordinator30_npc54/game'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
pins={}
edits={
 'scripts/npc_daily_life.gd':('\t_health.last_result = receipt.duplicate(true)\n\t_hospital_healed = true', '\t_health.last_result = receipt.duplicate(true)\n\tpreload("res://scripts/npc_visual/npc_heal_fx30.gd").confirmed30(_health,event_id)\n\t_hospital_healed = true'),
 'scripts/hospital/npc_hospital_treatment_port.gd':('\t_owner.get_ref().last_result=receipt.duplicate(true)\n\t_phase="COMPLETE"', '\t_owner.get_ref().last_result=receipt.duplicate(true)\n\tpreload("res://scripts/npc_visual/npc_heal_fx30.gd").confirmed30(_owner.get_ref(),event_id)\n\t_phase="COMPLETE"')
}
for rel,(before,after) in edits.items():
    old=(BASE/rel).read_text(encoding='utf-8');assert old.count(before)==1
    new=old.replace(before,after,1);dst=OUT/rel;dst.parent.mkdir(parents=True,exist_ok=True);dst.write_text(new,encoding='utf-8')
    pins[rel]={'base_sha256':sha(BASE/rel),'proposed_sha256':sha(dst)}
    (OUT/(dst.name+'.patch')).write_text(''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+rel,tofile='b/'+rel)),encoding='utf-8')
rel='scripts/npc_visual/npc_heal_fx30.gd';pins[rel]={'base_sha256':None,'proposed_sha256':sha(OUT/rel)}
(OUT/'BASE_HEAL_FX30.json').write_text(json.dumps(pins,indent=2)+'\n',encoding='utf-8')
print('heal_fx30',len(pins))
