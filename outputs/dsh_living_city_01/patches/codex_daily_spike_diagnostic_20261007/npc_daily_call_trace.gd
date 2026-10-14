extends RefCounted
## Opt-in, bounded timing for ONE current life.step invocation.
## No ownership/physics queries, state callbacks, body writes or retained owners.
const MAX_REPORTS := 16
const MAX_EVENTS := 4096
const MAX_LABELS := 24
const MAX_DEPTH := 12
static var _flag := -1
static var _threshold := 50000
static var _pick := ""
static var _active := false
static var _reports := 0
static var _events := 0
static var _dropped := 0
static var _began := 0
static var _meta: Dictionary = {}
static var _stack: Array[Dictionary] = []
static var _stats: Dictionary = {}

static func enabled() -> bool:
	if _flag < 0:
		_flag=0
		for arg: String in OS.get_cmdline_user_args():
			if arg == "--city-daily-spike-trace=1": _flag=1
			elif arg.begins_with("--city-daily-spike-us="): _threshold=maxi(1000,int(arg.trim_prefix("--city-daily-spike-us=")))
			elif arg.begins_with("--city-daily-spike-id="): _pick=arg.trim_prefix("--city-daily-spike-id=")
	return _flag == 1 and _reports < MAX_REPORTS

static func active() -> bool: return _active

static func begin_poll(meta: Dictionary) -> bool:
	if not enabled() or _active or (not _pick.is_empty() and meta.get("source_id","") != _pick): return false
	_meta=meta.duplicate()
	_stack.clear(); _stats.clear(); _events=0; _dropped=0
	_began=Time.get_ticks_usec(); _active=true
	return true

static func enter(label: String, attributes: Dictionary={}) -> int:
	if not _active: return -1
	if _events>=MAX_EVENTS or _stack.size()>=MAX_DEPTH or (not _stats.has(label) and _stats.size()>=MAX_LABELS):
		_dropped+=1; return -1
	_events+=1
	if not _stats.has(label):
		_stats[label]={"calls":0,"inclusive_us":0,"exclusive_us":0,"max_single_us":0,"first":attributes.duplicate(),"last":{}}
	var marker:=_stack.size()
	_stack.append({"label":label,"started":Time.get_ticks_usec(),"child_us":0})
	return marker

static func leave(marker: int, attributes: Dictionary={}) -> void:
	if marker < 0 or not _active: return
	if marker != _stack.size()-1:
		_dropped+=1; return
	var span: Dictionary=_stack.pop_back()
	var elapsed: int=Time.get_ticks_usec()-int(span.started)
	var row: Dictionary=_stats[span.label]
	row.calls=int(row.calls)+1
	row.inclusive_us=int(row.inclusive_us)+elapsed
	row.exclusive_us=int(row.exclusive_us)+maxi(0,elapsed-int(span.child_us))
	row.max_single_us=maxi(int(row.max_single_us),elapsed)
	row.last=attributes.duplicate()
	if not _stack.is_empty():
		_stack[-1].child_us=int(_stack[-1].child_us)+elapsed

static func finish_poll(observed_life_us: int, phase_after: String) -> void:
	if not _active: return
	var trace_wall: int=Time.get_ticks_usec()-_began
	_active=false
	if observed_life_us>=_threshold and _reports<MAX_REPORTS:
		_reports+=1
		_meta["phase_after"]=phase_after
		_meta["life_us"]=observed_life_us
		_meta["trace_wall_us"]=trace_wall
		_meta["events"]=_events
		_meta["dropped"]=_dropped
		_meta["truncated"]=_dropped>0 or not _stack.is_empty()
		_meta["report"]=_reports
		_meta["scope"]="same_life_poll_wall_time; nested inclusive timings overlap"
		_meta["spans"]=_stats
		# Formatting/printing is after observed_life_us. It adds daily overhead;
		# this diagnostic run is not a performance acceptance comparison.
		print("DSH_DAILY_SPIKE "+JSON.stringify(_meta))
	_stack.clear(); _stats.clear(); _meta={}
