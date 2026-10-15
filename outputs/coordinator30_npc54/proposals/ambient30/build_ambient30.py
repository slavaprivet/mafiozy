"""Scoped ambient successor. Generates only package scripts and exact base diffs."""
from pathlib import Path
import difflib,hashlib,importlib.util,json
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3];BASE=ROOT/'outputs/coordinator29_release53a/game';SLOTS=ROOT/'outputs/coordinator29_npc53/proposals/ambient29_slots'
spec=importlib.util.spec_from_file_location('staff_adapter',OUT.parent/'staff30/apply_staff30.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def read(p):return p.read_text(encoding='utf-8').replace('\r\n','\n')
def replace(s,a,b):
    assert s.count(a)==1,a[:100]
    return s.replace(a,b,1)
def save(relative,s):
    p=OUT/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s,encoding='utf-8')
def main():
    manifest=json.loads((SLOTS/'SOURCE_MANIFEST.json').read_text(encoding='utf-8'))
    assert all(hashlib.sha256((SLOTS/k).read_bytes()).hexdigest()==v for k,v in manifest['files'].items())
    rel='scripts/npc_ambient/ambient_controller28.gd';s=m.apply_hunks(read(BASE/rel),read(SLOTS/'AMBIENT_CONTROLLER.patch'))
    s=replace(s,'"Осмотреть карман"]','"Осмотреть карман", "Посмотреть телефон"]')
    s=replace(s,').length() > .18:',').length() > .42:')
    save(rel,s)
    for name in ['ambient_benches28.gd','ambient_bench_registry29.gd']:
        rel='scripts/npc_ambient/'+name;s=read(SLOTS/rel)
        if name=='ambient_bench_registry29.gd':s=replace(s,'scene.get_meta(META,null)','scene.get_meta(META) if scene.has_meta(META) else null')
        save(rel,s)
    rel='scripts/npc_ambient/ambient_pose28.gd';s=read(BASE/rel)
    s=replace(s,'"camera", "pocket"]','"camera", "pocket", "phone"]')
    s=replace(s,'var _legs_ready := false','var _legs_ready := false\nvar _hand_rest30: Dictionary = {}\nvar _bench_feet30: Dictionary = {}\nvar _bench_start30: Dictionary = {}')
    s=replace(s,'\t_legs_ready = true','\tfor side30: String in ["l","r"]:\n\t\tif not _indices.has("socket_hand_"+side30): return false\n\t\t_hand_rest30[side30] = _global[_indices["hand_"+side30]].basis.get_rotation_quaternion()\n\t_legs_ready = true')
    a=s.index('func _seat(value: Dictionary) -> bool:');b=s.index('\nfunc compose(',a)
    s=s[:a]+'''func _hand_rotation30(side: String, rotation: Quaternion) -> void:
	var index: int = _indices["hand_"+side]
	var parent: int = _parents[index]
	if parent >= 0: rotation = _global[parent].basis.get_rotation_quaternion().inverse()*rotation
	var base: Transform3D = _working[index]
	_working[index] = Transform3D(Basis(rotation.normalized())*Basis.from_scale(base.basis.get_scale()),base.origin)
	_compose_globals()

func _palm30(side: String, target: Vector3, fingers: Vector3) -> void:
	# The actual canonical palm socket converts a surface target to its wrist.
	var socket: Vector3 = _working[_indices["socket_hand_"+side]].origin
	var rest: Quaternion = _hand_rest30[side]
	var direction: Vector3 = rest*socket
	if direction.length_squared() < .00001 or fingers.length_squared() < .00001: return
	var rotation: Quaternion = Quaternion(direction.normalized(),fingers.normalized())*rest
	_arm(side,target-rotation*socket)
	_hand_rotation30(side,rotation)

func _seat(value: Dictionary) -> bool:
	if not _legs_ready or not value.get("seat") is Vector3 or not is_instance_valid(_ambient_rig.get_ref()): return false
	var rig: Skeleton3D = _ambient_rig.get_ref()
	_bench_feet30.clear(); _bench_start30.clear()
	for side30: String in ["l","r"]: _bench_start30[side30] = _global[_indices["foot_"+side30]]
	# On this canonical rig `pelvis` is the low root anchor. Anatomical hip
	# position is the thigh-joint midpoint, not that misleading bone origin.
	var hips: Vector3 = (_point("thigh_l")+_point("thigh_r"))*.5
	var target: Vector3 = rig.to_local(Vector3(value.seat)+Vector3.UP*.10)
	var pelvis: int = _indices["pelvis"]; var parent: int = _parents[pelvis]
	var desired: Vector3 = _point("pelvis")+target-hips
	var local: Vector3 = _global[parent].affine_inverse()*desired if parent >= 0 else desired
	_working[pelvis] = Transform3D(_working[pelvis].basis,local)
	_compose_globals()
	for side30: String in ["l","r"]:
		var hip: Vector3 = _point("thigh_"+side30)
		var upper: float = hip.distance_to(_point("shin_"+side30))
		var lower: float = _point("shin_"+side30).distance_to(_point("foot_"+side30))
		# A high real bench and short legs require naturally hanging feet. Their
		# reachable anchors are explicit; the actor's capsule remains supported.
		var foot: Vector3 = hip+_forward*(upper*.94+lower*.04)-_up*(upper*.34+lower*.98)
		_bench_feet30[side30] = foot
		_leg(side30,foot)
	_turn_global("chest",_right,-.07)
	_arm("l",_point("shin_l")+_up*_reach*.08)
	_arm("r",_point("shin_r")+_up*_reach*.08)
	return true

func _bench_blend_contacts30(poses: Array[Transform3D], weight: float) -> void:
	_working = poses.duplicate(); _compose_globals()
	for side30: String in ["l","r"]:
		var start: Transform3D = _bench_start30[side30]
		var target: Vector3 = start.origin.lerp(_bench_feet30[side30],weight)
		_leg(side30,target)
		var index: int = _indices["foot_"+side30]; var parent: int = _parents[index]
		var rotation: Quaternion = start.basis.get_rotation_quaternion()
		if parent >= 0: rotation = _global[parent].basis.get_rotation_quaternion().inverse()*rotation
		var base: Transform3D = _working[index]
		_working[index] = Transform3D(Basis(rotation.normalized())*Basis.from_scale(base.basis.get_scale()),base.origin)
		_compose_globals()
	for side30: String in ["l","r"]:
		for part30: String in ["thigh_","shin_","foot_"]:
			var index: int = _indices[part30+side30]; poses[index] = _working[index]
''' + s[b:]
    s=replace(s,'\t\t\t_arm("l", _p(shoulders,-.17,.03,.13)); _arm("r", _p(shoulders,.17,.03+.02*pulse,.13))','\t\t\t_palm30("l",_p(shoulders,-.24,-.10,.42),_up); _palm30("r",_p(shoulders,.24,-.10+.015*pulse,.42),_up)')
    s=replace(s,'\t\t\t_arm("r", pelvis+(_right*.27+_up*.02+_forward*.17)*_reach)\n\t\t\t_arm("l", _p(shoulders,-.32,-.55,.04)); _turn_global("head", _right, .26); _turn_global("head", _up, .17)','\t\t\tvar hips30: Vector3 = (_point("thigh_l")+_point("thigh_r"))*.5\n\t\t\t_palm30("r",_p(hips30,.35,.26+.012*pulse,.36),-_up)\n\t\t\t_turn_global("head",_right,.26); _turn_global("head",_up,.17)\n\t\t"phone":\n\t\t\tvar phone30: Vector3 = _p(shoulders,-.24,-.32,.72)\n\t\t\t_palm30("l",phone30-_up*_reach*.10-_right*_reach*.06,_up)\n\t\t\t_palm30("r",phone30+_right*_reach*.16+_up*_reach*.03-_forward*_reach*(.07+.04*pulse),-_right*.8+_forward*.2)\n\t\t\t_turn_global("head",_right,.28); _turn_global("head",_up,-.10)')
    s=replace(s,'\tvalue["pose_weight"] = weight','\tif kind == "bench": _bench_blend_contacts30(poses,weight)\n\tvalue["pose_weight"] = weight')
    save(rel,s)
    rel='scripts/npc_ambient/ambient_props28.gd';s=read(BASE/rel)
    s=replace(s,'kind not in ["book", "newspaper", "camera"]','kind not in ["book", "newspaper", "camera", "phone"]')
    anchor='\t\t"camera":\n'
    s=replace(s,anchor,'\t\t"phone":\n\t\t\t_box(_root,Vector3(.075,.145,.012),Vector3.ZERO,Color("202326"))\n\t\t\t_box(_root,Vector3(.065,.125,.002),Vector3(0,0,-.0075),Color("718fa2"))\n\t\t\t_box(_root,Vector3(.047,.007,.002),Vector3(0,.037,-.009),Color("d5e4e8"))\n\t\t\t_box(_root,Vector3(.047,.005,.002),Vector3(0,.018,-.009),Color("bed0dc"))\n'+anchor)
    anchor='\tvar a: Vector3 = rig.to_global(rig.get_bone_global_pose(left).origin)'
    s=replace(s,anchor,'''\tif kind == "phone":
		var palm: int = rig.find_bone("socket_hand_l")
		var upper_l: int = rig.find_bone("upperarm_l"); var upper_r: int = rig.find_bone("upperarm_r")
		if palm < 0 or upper_l < 0 or upper_r < 0: hide(); return
		var side30: Vector3 = (rig.get_bone_global_pose(upper_r).origin-rig.get_bone_global_pose(upper_l).origin).normalized()
		var up30: Vector3 = Vector3.UP
		var forward30: Vector3 = side30.cross(up30).normalized()
		var reach30: float = 0.0
		for suffix30: String in ["l","r"]:
			var shoulder30: Vector3 = rig.get_bone_global_pose(rig.find_bone("upperarm_"+suffix30)).origin
			var elbow30: Vector3 = rig.get_bone_global_pose(rig.find_bone("forearm_"+suffix30)).origin
			var wrist30: Vector3 = rig.get_bone_global_pose(rig.find_bone("hand_"+suffix30)).origin
			reach30 += shoulder30.distance_to(elbow30)+elbow30.distance_to(wrist30)
		reach30 *= .5
		var center30: Vector3 = rig.get_bone_global_pose(palm).origin+(up30*.10+side30*.06)*reach30
		var frame30: Basis = rig.global_basis*Basis(side30,up30,forward30)
		_root.global_transform = Transform3D(frame30.orthonormalized()*Basis(Vector3.RIGHT,-.22),rig.to_global(center30))
		_attachment.visible = true
		return
'''+anchor)
    save(rel,s)
    # QA entry/observer files are independently adapted in this package, including
    # bounded startup registration and child-first removal event verification.
    pins={}
    for p in (OUT/'scripts').rglob('*.gd'):
        relative=p.relative_to(OUT).as_posix();old=read(BASE/relative) if (BASE/relative).exists() else '';new=read(p)
        (OUT/(p.stem+'.patch')).write_text(''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+relative,tofile='b/'+relative)),encoding='utf-8')
        pins[relative]={'base_sha256':hashlib.sha256((BASE/relative).read_bytes()).hexdigest() if (BASE/relative).exists() else None,'proposed_sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
    save('BASE_AMBIENT30.json',json.dumps(pins,indent=2)+'\n')
    print('ambient30 scripts',len(pins))
if __name__=='__main__':main()
