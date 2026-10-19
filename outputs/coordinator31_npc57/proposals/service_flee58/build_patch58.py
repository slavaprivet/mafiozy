from pathlib import Path
import hashlib, json, difflib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
GAME=ROOT/'outputs/coordinator31_npc57/game'
BASE={
    'scripts/city/runtime/npc_threat_route30.gd':'b2aebb500dd5d69028f3f5cf4257503ae476b43b391c0554d3fff3bc27cc5574',
    'scripts/city/runtime/npc_threat_life30.gd':'afb84c3df8f670c9deea44cb03c15fcc5e7e35e6ded0036615613e54629e6999',
}
def sha(data):return hashlib.sha256(data).hexdigest()
manifest={};diff=[]
for rel,expected in BASE.items():
    raw=(GAME/rel).read_bytes();assert sha(raw)==expected,rel
    old=raw.decode('utf-8-sig').replace('\r\n','\n');new=old
    if rel.endswith('npc_threat_route30.gd'):
        new=new.replace('var reason := ""','''var reason := ""
# A hint for the existing physical planner, never movement permission. Probe one
# bounded candidate per physics frame; charge these queries to the SAME work cap.
const ESCAPE_ANGLES58 := [0.0, .75, -.75, PI * .5, -PI * .5]
const ESCAPE_LENGTHS58 := [8.0, 4.0]
var _selecting58 := false
var _selection_cursor58 := 0
var _selection_us58 := 0
var _selection_max_us58 := 0
var _selection_origin58 := Vector3.ZERO
var _known_from58 := Vector3.ZERO
var _away58 := Vector3.ZERO
var _fallback58 := Vector3.ZERO
var _tried58: Array[Vector3] = []
var _selection58: Array[Dictionary] = []''')
        new=new.replace('func _publish(before: Vector3, delta: float) -> void:', '''func begin_escape58(known_from: Vector3, attempt: int) -> bool:
	if _route==null or not _route._actor_live() or not known_from.is_finite() or attempt<0 or attempt>=3:return false
	if attempt==0:_tried58.clear()
	_route.cancel();_selection_origin58=_body.global_position;_known_from58=known_from
	_away58=_selection_origin58-known_from;_away58.y=0.0
	if _away58.length_squared()<.01:_away58=-_body.global_basis.z;_away58.y=0.0
	_away58=_away58.normalized()
	_fallback58=_selection_origin58+_away58.rotated(Vector3.UP,[0.0,.75,-.75][attempt])*8.0
	_selection_cursor58=0;_selection58.clear();_selecting58=true
	_age=0.0;_way=0;status="selecting";reason=""
	return true

func _work_us58() -> int:
	return int(_route.service_us29)+_selection_us58

func _tried_goal58(goal: Vector3) -> bool:
	for previous: Vector3 in _tried58:
		if _flat(previous,goal)<.5:return true
	return false

func _choose_escape58() -> void:
	var index: int=_selection_cursor58
	_selection_cursor58+=1
	var angle: float=ESCAPE_ANGLES58[index%ESCAPE_ANGLES58.size()]
	var length: float=ESCAPE_LENGTHS58[index/ESCAPE_ANGLES58.size()]
	var target: Vector3=_selection_origin58+_away58.rotated(Vector3.UP,angle)*length
	var why := "already_tried"
	var accepted := false
	# Orthogonal retreat increases distance without initially approaching the
	# last OBSERVED threat. Do not inspect the hidden player's current location.
	if not _tried_goal58(target):
		why="not_farther"
		if _flat(target,_known_from58)>_flat(_selection_origin58,_known_from58)+.1:
			var floor: Variant=_route.floor_at(target,_selection_origin58.y)
			why="no_floor"
			if floor is Vector3:
				why="capsule_blocked"
				if _route.standing(floor) and _route.sweep(_selection_origin58,floor):
					target=floor;accepted=true;why="direct_corridor_hint"
	_selection58.append({"index":index,"goal":target,"reason":why,"accepted":accepted})
	if accepted:
		_selecting58=false;_tried58.append(target);begin(target)
	elif _selection_cursor58>=ESCAPE_ANGLES58.size()*ESCAPE_LENGTHS58.size():
		_selecting58=false
		# A blocked straight sweep does not prove no path. Retain the old bounded
		# planner's opportunity to find a detour, with the remaining incident cap.
		if _tried_goal58(_fallback58):status="blocked";reason="escape_candidates_exhausted"
		else:_tried58.append(_fallback58);begin(_fallback58)

func _publish(before: Vector3, delta: float) -> void:''')
        new=new.replace('if _age>LEG_SECONDS or int(_route.service_us29)>PLAN_SERVICE_CAP_US:', 'if _age>LEG_SECONDS or _work_us58()>PLAN_SERVICE_CAP_US:')
        marker='\tif _route.status=="searching":_route.tick()'
        new=new.replace(marker, '''	if _selecting58:
		var since: int=Time.get_ticks_usec()
		_choose_escape58()
		var used: int=Time.get_ticks_usec()-since
		_selection_us58+=used;_selection_max_us58=maxi(_selection_max_us58,used)
		if _work_us58()>PLAN_SERVICE_CAP_US:
			status="blocked";reason="bounded_route_deadline";_selecting58=false;_route.cancel()
		_route.hold(delta);_publish(before,delta);return status
'''+marker)
        new=new.replace('func cancel() -> void:\n\tif _route!=null:', 'func cancel() -> void:\n\t_selecting58=false\n\tif _route!=null:')
        new=new.replace('"service_us":_route.service_us29 if _route!=null else 0}', '"service_us":_route.service_us29 if _route!=null else 0,"selection_us58":_selection_us58,"selection_max_us58":_selection_max_us58,"total_work_us58":_work_us58() if _route!=null else 0,"selection58":_selection58.duplicate(true)}')
    else:
        start=new.index('func _start_leg(');end=new.index('\nfunc _recover31()',start)
        new=new[:start]+'''func _start_leg(life: RefCounted) -> bool:
	if _attempts>=3:return false
	var attempt: int=_attempts
	_attempts+=1
	return _driver.begin_escape58(Vector3(_event.escape_from),attempt)
'''+new[end:]
    assert new!=old
    destination=HERE/'patch'/rel
    destination.parent.mkdir(parents=True,exist_ok=True)
    assert not destination.exists(),'Preserve previously generated proposal'
    destination.write_text(new,encoding='utf-8',newline='\n')
    manifest[rel]={'base_sha256':expected,'candidate_sha256':sha(destination.read_bytes())}
    diff.extend(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+rel,tofile='b/'+rel))
(HERE/'PATCH.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
(HERE/'SERVICE_FLEE58.patch').write_text(''.join(diff),encoding='utf-8')
print(json.dumps(manifest))
