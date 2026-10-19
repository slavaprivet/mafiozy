from pathlib import Path
import json,hashlib
O=Path(__file__).parent; p=O/'game/scripts/weapons/sword_prototype.gd'
s=p.read_text(encoding='utf-8')
def one(old,new):
    global s
    assert s.count(old)==1,(old,s.count(old))
    s=s.replace(old,new)
one('## A committed heavy blow to an unprotected head crosses the resident\'s full\n## head health in one real contact. A brush cannot earn this floor, and visible\n## head armour keeps its ordinary protection.\nfunc _npc_heavy_head_damage31(part: String, speed: float, prepared: float, kind: String, damage: float, region: String = "skin") -> float:\n\tif part != "head" or region == "plate": return damage\n\tvar proper_face := (_weapon_id == "sledge" and kind == "flat") \\\n\t\tor (_weapon_id == "axe" and kind == "slice")\n\tif not proper_face or speed * 0.6 < 2.65 or prepared < 0.8: return damage\n\treturn maxf(damage, float(PART_HP["head"]) + 1.0)\n','')
one('var wound := _npc_heavy_head_damage31(npc_part, speed, strength, kind, npc_cut * factor, str(protection.region))','var wound := npc_cut * factor')
one('var _npc_hp := 90.0','const NPC_MAX_HP57 := 270.0\nvar _npc_hp := NPC_MAX_HP57')
one('\t_npc_hp = 90.0','\t_npc_hp = NPC_MAX_HP57')
one('const PART_HP := {"head": 50.0, "chest": 96.0, "pelvis": 96.0,\n\t"upperarm": 34.0, "forearm": 30.0, "hand": 22.0,\n\t"thigh": 44.0, "shin": 34.0, "foot": 22.0}',
    'const PART_HP := {"head": 50.0, "chest": 96.0, "pelvis": 96.0,\n\t"upperarm": 34.0, "forearm": 30.0, "hand": 22.0,\n\t"thigh": 44.0, "shin": 34.0, "foot": 22.0}\n## The opponent lasts several landed blows; player body-part thresholds stay intact.\nconst NPC_PART_HP57 := {"head": 200.0, "chest": 288.0, "pelvis": 288.0,\n\t"upperarm": 102.0, "forearm": 90.0, "hand": 66.0,\n\t"thigh": 132.0, "shin": 102.0, "foot": 66.0}')
one('_npc_part_hp[full_key] = float(PART_HP.get(kind, 40.0))','_npc_part_hp[full_key] = float(NPC_PART_HP57.get(kind, 120.0))')
one('_npc_part_hp.get(full_key, PART_HP.get(base, 40.0))','_npc_part_hp.get(full_key, NPC_PART_HP57.get(base, 120.0))')
one('_npc_part_hp[full_key] = float(PART_HP.get(key, 40.0))','_npc_part_hp[full_key] = float(NPC_PART_HP57.get(key, 120.0))')
start=s.index('\tvar vital_penetration: bool = protection.region != "plate" or wound >= float(PART_HP.get(base_part, 96.0))')
end=s.index('\treturn SPEAR_STICK_DEPTH',start)
s=s[:start]+'''\tvar vital_penetration: bool = protection.region != "plate" or wound >= float(NPC_PART_HP57.get(base_part, 288.0))
\t# A penetrating spear can still travel through a vital zone; the ordinary
\t# wound/part-health owner decides whether that contact was fatal.
\tif base_part in ["head", "chest", "pelvis"] and speed >= SPEAR_LETHAL_SPEED \\
\t\tand incidence >= SPEAR_LETHAL_INCIDENCE and vital_penetration:
\t\treturn SPEAR_BODY_PIERCE_DEPTH
'''+s[end:]
p.write_text(s,encoding='utf-8',newline='\r\n')
print(json.dumps({'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'file':str(p)}))
