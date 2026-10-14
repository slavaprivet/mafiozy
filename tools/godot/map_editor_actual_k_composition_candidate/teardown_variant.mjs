import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {buildSource as buildClockAtomic} from '../map_editor_clock_atomic_candidate/build_candidate.mjs';

const own=path.dirname(fileURLToPath(import.meta.url));
function once(source, needle, replacement) {
  const at=source.indexOf(needle);
  if(at<0 || source.indexOf(needle,at+needle.length)>=0) throw Error('Missing/ambiguous teardown seam: '+needle.slice(0,70));
  return source.slice(0,at)+replacement+source.slice(at+needle.length);
}
function block(source, start, end, replacement) {
  const a=source.indexOf(start), b=source.indexOf(end,a+start.length);
  if(a<0 || b<0 || source.indexOf(start,a+start.length)>=0) throw Error('Missing/ambiguous teardown block: '+start);
  return source.slice(0,a)+replacement+source.slice(b);
}

export function deriveTeardownWorkspace(source) {
  let out=once(source,
    'const Router = preload("res://scripts/map_editor/editor_input_router_v2.gd")',
    'const Router = preload("res://scripts/map_editor/editor_input_router_v2.gd")\nconst TeardownGuard = preload("res://diagnostic/teardown_guard.gd")');
  out=once(out,'var _population_receipt: Dictionary = {}',
    'var _population_receipt: Dictionary = {}\nvar _teardown_guard: Node\nvar _teardown_verified := false\nvar _teardown_poisoned := false');
  out=once(out,'\t_pause_tree = _main.get_tree()\n\t_owns_tree_pause = true\n\t_pause_tree.set_meta(PAUSE_META, _receipt.token)',
    '\t_pause_tree = _main.get_tree()\n\t_teardown_guard = TeardownGuard.new()\n\t_pause_tree.root.add_child(_teardown_guard)\n\t_teardown_guard.configure(_pause_tree, _main, PAUSE_META, _receipt.token)\n\t_teardown_verified = false\n\t_teardown_poisoned = false\n\tif not _main.child_exiting_tree.is_connected(_on_child_exiting_tree):\n\t\t_main.child_exiting_tree.connect(_on_child_exiting_tree)\n\t_owns_tree_pause = true\n\t_pause_tree.set_meta(PAUSE_META, _receipt.token)');
  out=once(out,'func _terminal_hold(reason: String) -> void:\n\tstatus = "terminal_hold:" + reason',
    'func _terminal_hold(reason: String) -> void:\n\tstatus = "terminal_hold:" + reason\n\t_teardown_poisoned = true\n\tif is_instance_valid(_teardown_guard): _teardown_guard.disarm()');
  out=once(out,'\t_pause_tree.remove_meta(PAUSE_META)\n\t_owns_tree_pause = false',
    '\t_pause_tree.remove_meta(PAUSE_META)\n\tif is_instance_valid(_teardown_guard): _teardown_guard.disarm(); _teardown_guard.queue_free()\n\t_teardown_guard = null\n\t_teardown_verified = false\n\t_teardown_poisoned = false\n\t_owns_tree_pause = false');
  out=block(out,'func _notification(what: int) -> void:\n','func _emergency_cancel(reason: String) -> void:\n',
    `func _process(_delta: float) -> void:
	# A child removed earlier is not a lasting teardown approval.
	if _teardown_verified and is_instance_valid(_main) and _main.is_inside_tree():
		_teardown_verified = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _owns_tree_pause:
		_terminal_hold("focus_out")

func _exit_tree() -> void:
	if _owns_tree_pause:
		# Transfer only a current lease. The root guard releases the global
		# pause after the entire owner scene has been destroyed.
		if _teardown_verified and not _teardown_poisoned and _pause_tree.paused and _pause_tree.get_meta(PAUSE_META, "") == _receipt.get("token", "") and is_instance_valid(_teardown_guard):
			_teardown_guard.arm()
			status = "teardown_awaiting_owner_free"
		else:
			_terminal_hold("workspace_exit_owner_drift")

func _on_child_exiting_tree(_child: Node) -> void:
	if not _owns_tree_pause or _teardown_verified or _teardown_poisoned: return
	if _teardown_current():
		_teardown_verified = true
	else:
		_terminal_hold("owner_teardown_preflight")

func _teardown_current() -> bool:
	if _host == null or _host._fault or not active or not is_instance_valid(_main): return false
	if _pause_tree == null or not _pause_tree.paused or _pause_tree.get_meta(PAUSE_META, "") != _receipt.get("token", ""): return false
	if _main.get_tree() != _pause_tree or not _population_current(): return false
	if not is_instance_valid(_main.preview_melee) or not _main.preview_melee.gameplay_clock.receipt_live(_clock_receipt): return false
	if _source_block_bytes != var_to_bytes(_main._block) or _source_session_bytes != var_to_bytes(_main.preview_transport._session): return false
	return _without_focus_state(_capture()) == _critical_snapshot

`);
  return out;
}

export function buildTeardownSource() {
  const clocked=buildClockAtomic();
  return {workspace:Buffer.from(deriveTeardownWorkspace(clocked.workspace.toString('utf8'))),
    guard:fs.readFileSync(path.join(own,'teardown_guard.gd')),clock:clocked.clock};
}
