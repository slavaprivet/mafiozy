extends RefCounted
## Local velocity suggestion only. The caller MUST retain live floor/water and
## full-capsule native movement. This object never moves or owns a physics body.
const MAX_ACTORS := 384
const CELL_M := 2.0
const HEIGHT_CELL_M := 3.0
const SCAN_LIMIT := 64
const NEIGHBOR_LIMIT := 8
const DECISIONS_PER_FRAME := 16
const MIN_CADENCE := 6
const RANGE_M := 3.2
const HORIZON_S := 1.0
const GAP_M := .12
const SIDE_DWELL_MS := 1200
const YIELD_DWELL_MS := 600
const STUCK_REPLAN_MS := 3500
const OFFSETS := [Vector2i.ZERO,Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1),Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2),Vector2i(2,1),Vector2i(2,-1),Vector2i(-2,1),Vector2i(-2,-1),Vector2i(1,2),Vector2i(-1,2),Vector2i(1,-2),Vector2i(-1,-2),Vector2i(2,2),Vector2i(-2,2),Vector2i(2,-2),Vector2i(-2,-2)]
class FrameInput extends RefCounted:
	var key:String
	var position:Vector3
	var velocity:Vector3
	var radius:=.36
	var height:=1.9
	var priority:=0
	var waiting:=false
class Agent extends RefCounted:
	var key:String
	var position:Vector3
	var flat:Vector2
	var planar_velocity:Vector2
	var radius:float
	var height:float
	var priority:int
	var waiting:bool
	var bucket_seed:int
	var state:State
class State extends RefCounted:
	var frame:=-10000
	var seen_frame:=-1
	var direction:=Vector2.ZERO
	var turn_cos:=1.0
	var turn_sin:=0.0
	var ratio:=0.0
	var reason:="first_admission"
	var side:=1.0
	var side_until:=0
	var yield_until:=0
	var blocked_until:=0
	var blocked_direction:=Vector2.ZERO
	var goal_direction:=Vector2.ZERO
	var progress_ms:=0
	var next_replan:=0
	var decisions:=0
	var output:Dictionary={"direction":Vector3.ZERO,"ratio":0.0,"waiting":true,"reason":"first_admission","replan":false}
var _rows: Dictionary = {}
var _cells: Dictionary = {}
var _layers:Dictionary={}
var _cadence:=MIN_CADENCE
var _frame := -1
var _now := 0
var _decisions := 0
var _scans := 0
var _pairs := 0
var _snapshot_us := 0
var _solve_us := 0
var _max_scan := 0
var _max_neighbors := 0
var _rejected := 0

static func _flat(v: Vector3) -> Vector2:return Vector2(v.x,v.z)
static func _world(v: Vector2) -> Vector3:return Vector3(v.x,0.0,v.y)
static func _cell(p: Vector3) -> Vector3i:return Vector3i(floori(p.x/CELL_M),floori(p.y/HEIGHT_CELL_M),floori(p.z/CELL_M))

## One stable frame snapshot, O(N), hard bounded by MAX_ACTORS. Keys identify a
## life/body, not just a reused resident name. No references or callbacks retained.
func snapshot(rows: Array, frame: int, now_ms: int) -> bool:
	if frame==_frame:return true
	if frame<_frame or now_ms<_now or rows.size()>MAX_ACTORS:
		_rejected+=1;return false
	var started:int=Time.get_ticks_usec()
	var previous:Dictionary=_rows
	_rows={};_cells.clear();_layers.clear();_frame=frame;_now=now_ms
	_decisions=0;_scans=0;_pairs=0;_solve_us=0;_cadence=maxi(MIN_CADENCE,ceili(float(rows.size())/DECISIONS_PER_FRAME))
	for row:FrameInput in rows:
		var key:String=row.key
		if key.is_empty() or _rows.has(key) or not row.position.is_finite() or not row.velocity.is_finite() or row.radius<.1 or row.radius>.75 or row.height<.5 or row.height>2.9:
			_rejected+=1;continue
		var agent:Agent=previous.get(key)
		if agent==null:
			agent=Agent.new();agent.key=key;agent.bucket_seed=hash(key)&0x7fffffff;agent.state=State.new();agent.state.progress_ms=now_ms
		var at:Vector3=row.position;var moving:Vector3=row.velocity;var flat:Vector2=Vector2(at.x,at.z)
		var state:State=agent.state
		# Measured frame displacement provides feedback in the existing O(N)
		# snapshot, avoiding another per-body call/dictionary pass after movement.
		if state.seen_frame==frame-1:
			if (flat-agent.flat).dot(state.goal_direction)>.002:state.progress_ms=now_ms
			elif state.ratio>.05:state.blocked_direction=state.direction;state.blocked_until=now_ms+700
		agent.position=at;agent.flat=flat;agent.planar_velocity=Vector2(moving.x,moving.z)
		agent.radius=row.radius;agent.height=row.height;agent.priority=row.priority;agent.waiting=row.waiting
		_rows[key]=agent
		var cell:Vector3i=_cell(at)
		_layers[cell.y]=true
		if not _cells.has(cell):_cells[cell]=[]
		_cells[cell].append(agent)
	_snapshot_us=Time.get_ticks_usec()-started
	return true

func _neighbors(own:Agent)->Array[Agent]:
	var result:Array[Agent]=[];var inspected:=0;var center:Vector3i=_cell(own.position)

	# Own cell first. Rotating within a crowded bucket avoids permanent omission;
	# the live capsule guard is still mandatory when SCAN_LIMIT truncates a crowd.

	for vertical:int in [0,-1,1]:
		if not _layers.has(center.y+vertical):continue
		for offset:Vector2i in OFFSETS:
			var cell:Vector3i=center+Vector3i(offset.x,vertical,offset.y)
			var bucket:Array=_cells.get(cell,[])
			if bucket.is_empty():continue
			var start:int=(own.bucket_seed+own.state.decisions)%bucket.size()
			for index:int in bucket.size():
				if inspected>=SCAN_LIMIT:break
				var other:Agent=bucket[(start+index)%bucket.size()];inspected+=1
				if other==own:continue
				if other.position.y>=own.position.y+own.height or own.position.y>=other.position.y+other.height:continue
				var squared:float=(other.flat-own.flat).length_squared()
				if squared>RANGE_M*RANGE_M:continue
				result.append(other)
				if result.size()>=NEIGHBOR_LIMIT:break
			if inspected>=SCAN_LIMIT or result.size()>=NEIGHBOR_LIMIT:break
		if inspected>=SCAN_LIMIT or result.size()>=NEIGHBOR_LIMIT:break
	_scans+=inspected;_max_scan=maxi(_max_scan,inspected);_max_neighbors=maxi(_max_neighbors,result.size())
	return result

static func _wins(a:Agent,b:Agent)->bool:
	if a.priority!=b.priority:return a.priority>b.priority
	return a.key<b.key

func _conflict(own:Agent,other:Agent,velocity:Vector2)->float:
	_pairs+=1
	var relative:Vector2=other.flat-own.flat
	var speed:Vector2=other.planar_velocity-velocity
	var t:float=clampf(-relative.dot(speed)/maxf(.00001,speed.length_squared()),0.0,HORIZON_S)
	var separation:float=(relative+speed*t).length()
	var required:float=own.radius+other.radius+GAP_M
	return maxf(0.0,required-separation)

## direction is the caller's normalized planar waypoint direction.
func steer(key:String,direction:Vector3,speed:float)->Dictionary:
	var own:Agent=_rows.get(key)
	if own==null or not direction.is_finite() or not is_finite(speed) or speed<0.0:
		return {"direction":Vector3.ZERO,"ratio":0.0,"waiting":true,"reason":"no_current_snapshot","replan":false}
	var state:State=own.state
	if state.seen_frame<_frame-1:state.progress_ms=_now;state.frame=-10000
	state.seen_frame=_frame
	if own.waiting:
		state.ratio=0.0;state.direction=Vector2.ZERO;state.progress_ms=_now
		state.output={"direction":Vector3.ZERO,"ratio":0.0,"waiting":true,"reason":"portal_fifo_wait","replan":false}
		state.frame=-10000
		return state.output
	# Cache a turn relative to the current waypoint, never an obsolete world
	# heading. Waypoint changes and attention resume retain next-frame steering.
	state.goal_direction=Vector2(direction.x,direction.z)
	if _rows.size()==1:
		state.direction=state.goal_direction;state.ratio=1.0;state.progress_ms=_now
		state.output.direction=Vector3(direction.x,0.0,direction.z);state.output.ratio=1.0
		state.output.waiting=false;state.output.reason="alone";state.output.replan=false
		return state.output
	if _frame-state.frame<_cadence or _decisions>=DECISIONS_PER_FRAME:
		state.direction=Vector2(direction.x*state.turn_cos-direction.z*state.turn_sin,direction.x*state.turn_sin+direction.z*state.turn_cos)
		state.output.direction=Vector3(state.direction.x,0.0,state.direction.y)
		state.output.replan=false
		return state.output
	var desired:Vector2=Vector2(direction.x,direction.z).normalized()
	state.goal_direction=desired
	if true:
		var started:int=Time.get_ticks_usec();_decisions+=1
		var nearby:Array[Agent]=_neighbors(own)
		var must_yield:=false;var danger:=0.0
		for other:Agent in nearby:
			var collision:float=_conflict(own,other,desired*speed)
			danger=maxf(danger,collision)
			if not _wins(own,other) and collision>.04:must_yield=true
		if must_yield:state.yield_until=_now+YIELD_DWELL_MS
		var yielding:bool=_now<state.yield_until
		var best:Vector2=desired;var best_ratio:float=.55 if yielding else 1.0
		if danger>.025:
			# One deterministic passing side, not a costly velocity lattice.
			var angle:float=clampf(.35+danger*1.4,.35,1.1)*state.side
			best=desired.rotated(angle)
			if state.side_until==0:state.side_until=_now+SIDE_DWELL_MS
		if _now<state.blocked_until and best.dot(state.blocked_direction)>.92:
			if _now>=state.side_until:state.side=-state.side;state.side_until=_now+SIDE_DWELL_MS
			best=desired.rotated(1.15*state.side)
		var residual:=0.0
		for other:Agent in nearby:residual=maxf(residual,_conflict(own,other,best*speed*best_ratio))
		if residual>.12:
			var sidestep:Vector2=desired.rotated(1.57*state.side);var side_collision:=0.0
			for other:Agent in nearby:side_collision=maxf(side_collision,_conflict(own,other,sidestep*speed*.55))
			if side_collision<residual:best=sidestep;best_ratio=.55;residual=side_collision
			if residual>.22 and yielding:best=Vector2.ZERO;best_ratio=0.0
		state.direction=best;state.turn_cos=desired.dot(best);state.turn_sin=desired.cross(best)
		state.ratio=best_ratio;state.frame=_frame;state.decisions+=1
		state.reason="peer_yield" if best_ratio==0.0 else ("right_pass" if not nearby.is_empty() else "clear")
		state.output.direction=Vector3(best.x,0.0,best.y);state.output.ratio=best_ratio
		state.output.waiting=best_ratio==0.0;state.output.reason=state.reason
		_solve_us+=Time.get_ticks_usec()-started
	var replan:bool=_now-state.progress_ms>=STUCK_REPLAN_MS and _now>=state.next_replan
	if replan:state.next_replan=_now+STUCK_REPLAN_MS
	state.output.replan=replan
	return state.output

func diagnostics()->Dictionary:
	return {"actors":_rows.size(),"states":_rows.size(),"cells":_cells.size(),"frame":_frame,"decisions":_decisions,"scans":_scans,"pair_evaluations":_pairs,"snapshot_us":_snapshot_us,"solve_us":_solve_us,"max_scan":_max_scan,"max_neighbors":_max_neighbors,"max_decisions":DECISIONS_PER_FRAME,"max_actors":MAX_ACTORS,"rejected":_rejected}
