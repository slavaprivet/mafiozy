from pathlib import Path
import hashlib,json,difflib
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3];BASE=ROOT/'outputs/coordinator30_npc54/game'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def replace(s,a,b):assert s.count(a)==1,a;return s.replace(a,b,1)
pins={}
for name in ['npc_venue_staff_actor29.gd','npc_venue_staff_host29.gd']:
    rel='scripts/venues/'+name;old=(BASE/rel).read_text(encoding='utf-8');s=old
    if 'actor' in name:
        s=replace(s,'\t_skeleton = appearance.skeleton','\t_skeleton = appearance.skeleton\n\tif role29 == "medic":\n\t\tvar style30: Dictionary = preload("npc_medic_style30.gd").dress30(_skeleton)\n\t\tif not style30.get("ok",false): push_error("MEDIC30 "+str(style30)); return false\n\t\tset_meta("medic_style30",style30)')
    else:
        s=replace(s,'\t_box29(counter, Vector3(.44,.18,.30), Transform3D(basis,device_at), Color("e8ede8") if kind == "hospital" else Color("263a3f"))\n\tif kind == "hospital":\n\t\t_box29(counter, Vector3(.25,.015,.065), Transform3D(basis,device_at + Vector3.UP * .10), Color("bc3636"))\n\t\t_box29(counter, Vector3(.065,.015,.22), Transform3D(basis,device_at + Vector3.UP * .101), Color("bc3636"))\n\telse:', '\tif kind == "hospital":\n\t\tpreload("npc_medic_style30.gd").case30(counter,Transform3D(basis,device_at))\n\telse:\n\t\t_box29(counter, Vector3(.44,.18,.30), Transform3D(basis,device_at), Color("263a3f"))')
    target=OUT/rel;target.write_text(s,encoding='utf-8');pins[rel]={'base_sha256':sha(BASE/rel),'proposed_sha256':sha(target)}
    (OUT/(name+'.patch')).write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='a/'+rel,tofile='b/'+rel)),encoding='utf-8')
helper='scripts/venues/npc_medic_style30.gd';pins[helper]={'base_sha256':None,'proposed_sha256':sha(OUT/helper)}
(OUT/'BASE_MEDIC30.json').write_text(json.dumps(pins,indent=2),encoding='utf-8')
print('medic30 prepared',len(pins))
