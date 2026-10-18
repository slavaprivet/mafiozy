from pathlib import Path
import sys,hashlib,json
O=Path(__file__).parent;R=Path('C:/Users/Слава/Desktop/Мафиози');G=O/'game'
sys.path.insert(0,str(R/'tools/godot'));from test_scheduler import Lease
p=G/'scripts/weapons/sword_prototype.gd'
from contextlib import nullcontext
with nullcontext():
    s=p.read_text(encoding='utf-8')
    def change(old,new):
        global s
        assert s.count(old)==1,(old,s.count(old));s=s.replace(old,new)
    change('"length": 0.92, "mass": 2.7','"length": 1.12, "mass": 2.7')
    change('_add_haft(sledge, -0.34, 0.86,','_add_haft(sledge, -0.34, 1.06,')
    change('head.position = Vector3(0.82, 0.0, 0.0)','head.position = Vector3(1.02, 0.0, 0.0)')
    change('face.position = Vector3(0.82, side, 0.0)','face.position = Vector3(1.02, side, 0.0)')
    change('for at: float in [0.72, 0.88]:','for at: float in [0.92, 1.08]:')
    change('var speed_limit := 4.8 if heavy','var speed_limit := 7.6 if heavy')
    change('var acceleration := 12.0 if heavy','var acceleration := 28.0 if heavy')
    start=s.index('\t\tif heavy and _hold_left:\n',s.index('func _steer('));end=s.index('\t\t# The stopping distance',start)
    s=s[:start]+'\t\t# Sledge uses the same steering in every direction; lower acceleration\n\t\t# and speed preserve its weight without a separate overhead constraint.\n'+s[end:]
    change('angle * (10.0 if heavy else 14.0)','angle * 14.0')
    start=s.index('\t\tif heavy:\n',s.index('func _steer('));end=s.index('\t\t_omega = (_omega + torque',start)
    s=s[:start]+s[end:]
    change('_weapon_id in ["sledge", "axe", "spear"] and _hold_left else 0.0','_weapon_id in ["axe", "spear"] and _hold_left else 0.0')
    change('(lerpf(0.44, 0.40, clampf(local_want.y, 0.0, 1.0)) if _weapon_id == "sledge" else lerpf(0.38, 0.25, clampf(local_want.y, 0.0, 1.0)))','lerpf(0.38, 0.25, clampf(local_want.y, 0.0, 1.0))')
    start=s.index('\tif _weapon_id == "sledge" and _hold_left:\n',s.index('func _pose_shared_grip('));end=s.index('\tvar grip: Vector3 = world_to_rig',start)
    s=s[:start]+s[end:]
    change('\t\tif _weapon_id == "sledge":\n\t\t\tchest_yaw -= clampf(_hand.x, -1.0, 1.0) * (0.48 if absf(_hand.y)<0.35 else 0.30)\n\t\telse:\n\t\t\tchest_yaw += clampf(_hand.x, -1.0, 1.0) * 0.30','\t\tchest_yaw += clampf(_hand.x, -1.0, 1.0) * 0.30')
    change('(7.5 if _weapon_id == "sledge" else','(7.6 if _weapon_id == "sledge" else')
    p.write_text(s,encoding='utf-8',newline='\r\n')
print(json.dumps({'changed':'scripts/weapons/sword_prototype.gd','sha256':hashlib.sha256(p.read_bytes()).hexdigest()}))
