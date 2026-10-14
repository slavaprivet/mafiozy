import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {buildSource as buildPopulation} from '../map_editor_resident_atomic_candidate/build_candidate.mjs';
import {buildAtomicSource as buildNavigation} from '../map_editor_nav_atomic_candidate/build_candidate.mjs';

const own = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(own, '../../..');
const checkpoint = path.join(root, 'outputs/coordinator22_residents_checkpoint/godot/mafiozi_walk');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const closurePin = 'cbd7182488cbaf56a72017c8be101b4bfdf4c9c45e9088e1d414324a7e435ba6';
const mainPin = 'faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53';
const scenePin = '52aa1629fe38251f27ab50e3c6c102e0d0073348d6f610319d6c6b0233618bde';
const projectPin = 'c500a17d372f149b4b751ed4ef90a5a27bcb55e1050ba9d510d33fb5bcf6ff28';

function once(source, needle, replacement) {
  const at = source.indexOf(needle);
  if (at < 0 || source.indexOf(needle, at + needle.length) >= 0) throw Error(`Missing/ambiguous workspace seam: ${needle.slice(0, 85)}`);
  return source.slice(0, at) + replacement + source.slice(at + needle.length);
}
function block(source, start, end, replacement) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  if (a < 0 || b < 0 || source.indexOf(start, a + start.length) >= 0) throw Error(`Missing/ambiguous workspace block: ${start}`);
  return source.slice(0, a) + replacement + source.slice(b);
}

const pauseGameplay = `func _pause_gameplay(request: Dictionary) -> Dictionary:
	_current_request = request.duplicate(true)
	var reason := _admission()
	if not reason.is_empty():
		status = reason
		return {"ok":false,"reason":reason}
	# Real three-resident, policy, queue and navigation owners are acquired while
	# the tree is still live. This is not a synthetic resident-off admission.
	_population_receipt = _main.preview_population.begin_editor_pause(_main)
	if _population_receipt.is_empty():
		status = "population_pause_refused"
		return {"ok":false,"reason":status}
	var melee: Variant = _main.preview_melee
	var clock: RefCounted = melee.gameplay_clock
	_clock_receipt = clock.pause(_main, melee)
	if not _clock_receipt.get("ok", false):
		if not _main.preview_population.cancel_editor_pause(_population_receipt):
			_terminal_hold("clock_pause_rollback_failed")
			return {"ok":false,"reason":status}
		_population_receipt.clear()
		status = "clock_pause_refused"
		return {"ok":false,"reason":status}
	_pause_start_usec = Time.get_ticks_usec()
	_source_block_bytes = var_to_bytes(_main._block)
	_source_session_bytes = var_to_bytes(_main.preview_transport._session)
	var block_digest := _sha256(_source_block_bytes)
	_document = {"schema_version":1,"map_id":"actual-preview-pause-only","metadata":{"block_sha256":block_digest},"objects":[]}
	_ground = {"pause_only":true,"block_sha256":block_digest,"water_id":_main._water_host.get_instance_id() if _main._water_host != null else 0}
	_snapshot = _capture()
	_critical_snapshot = _without_focus_state(_snapshot)
	_receipt = {"owner_id":_main.get_instance_id(),"request_id":request.get("request_id"),"token":"pause-only-atomic:" + str(_pause_start_usec),"player_id":_main._player.get_instance_id(),"transport_id":_main.preview_transport.get_instance_id(),"melee_id":melee.get_instance_id(),"population_id":_main.preview_population.get_instance_id()}
	active = true
	_escape_recovery_armed = false
	_pause_tree = _main.get_tree()
	_owns_tree_pause = true
	_pause_tree.set_meta(PAUSE_META, _receipt.token)
	_pause_tree.paused = true
	return {"ok":true,"receipt":_receipt.duplicate(true)}

func _population_current() -> bool:
	return not _population_receipt.is_empty() and _main.preview_population != null and _main.preview_population.get_instance_id() == int(_receipt.get("population_id", -1)) and _main.preview_population.verify_editor_pause(_population_receipt)

func _terminal_hold(reason: String) -> void:
	status = "terminal_hold:" + reason
	if _pause_tree == null and is_instance_valid(_main):
		_pause_tree = _main.get_tree()
		_owns_tree_pause = true
		_pause_tree.set_meta(PAUSE_META, "terminal-hold:" + reason)
	if _pause_tree != null and _owns_tree_pause: _pause_tree.paused = true
	if _host != null: _host._fault = true

`;

const resumeGameplay = `func _resume_gameplay(receipt: Dictionary, document: Dictionary, ground: Dictionary) -> Dictionary:
	if not _verify_pause(receipt) or _source_block_bytes != var_to_bytes(_main._block) or _source_session_bytes != var_to_bytes(_main.preview_transport._session) or document != _document or ground != _ground or not _k_released or _gameplay_input_held():
		return {"ok":false,"reason":"pause_only_receipt_or_input"}
	var population: RefCounted = _main.preview_population
	var clock: RefCounted = _main.preview_melee.gameplay_clock
	if not clock.receipt_live(_clock_receipt): return {"ok":false,"reason":"clock_receipt"}
	var ticket: Dictionary = population.prepare_editor_resume_atomic(_population_receipt)
	if ticket.is_empty(): return {"ok":false,"reason":"population_prepare"}
	if population.commit_editor_resume_atomic(ticket).is_empty():
		if not population.abort_editor_resume_atomic(ticket): _terminal_hold("population_commit_abort")
		return {"ok":false,"reason":"population_commit"}
	# No await, deferred call or event-loop turn from commit through finalization,
	# tree unpause and callback flush. Clock resumes while the tree is still held.
	if not clock.resume(_clock_receipt):
		if not population.abort_editor_resume_atomic(ticket): _terminal_hold("clock_resume_abort")
		return {"ok":false,"reason":"clock_resume"}
	if not population.finalize_editor_resume_atomic(ticket):
		_terminal_hold("population_finalize")
		return {"ok":false,"reason":status}
	_main.editor_water_pause_usec += maxi(0, Time.get_ticks_usec() - _pause_start_usec)
	_main._last_frame_usec = Time.get_ticks_usec()
	_pause_tree.paused = false
	if not population.flush_editor_resume_atomic(ticket):
		_terminal_hold("population_flush")
		return {"ok":false,"reason":status}
	_pause_tree.remove_meta(PAUSE_META)
	_owns_tree_pause = false
	active = false
	_escape_recovery_armed = false
	var result := {"ok":true,"owner_id":_main.get_instance_id(),"request_id":receipt.get("request_id")}
	_receipt.clear(); _clock_receipt.clear(); _population_receipt.clear(); _document.clear(); _ground.clear(); _snapshot.clear(); _critical_snapshot.clear(); _source_block_bytes.clear(); _source_session_bytes.clear(); _current_request.clear(); _pause_start_usec = 0
	return result

`;

const cancelGameplay = `func _cancel_pause(request: Dictionary) -> Dictionary:
	if request != _current_request or not is_instance_valid(_main) or request.get("owner_id") != _main.get_instance_id(): return {"ok":false,"reason":"stale_cancel_request"}
	# Host failure after tree pause cannot run a partial restore. It retains an
	# input barrier and an owner-visible terminal HOLD for diagnosis.
	if _owns_tree_pause:
		_terminal_hold("post_pause_cancel_refused")
		return {"ok":false,"reason":status}
	if not _population_receipt.is_empty():
		if _main.preview_population == null or not _main.preview_population.cancel_editor_pause(_population_receipt):
			_terminal_hold("pre_pause_cancel_refused")
			return {"ok":false,"reason":status}
	_population_receipt.clear(); _current_request.clear()
	return {"ok":true}

`;

const teardown = `func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _owns_tree_pause:
		_terminal_hold("focus_out")

func _exit_tree() -> void:
	if _owns_tree_pause:
		_terminal_hold("workspace_exit")

func _emergency_cancel(reason: String) -> void:
	# No implicit unpause or sequential resident/nav release is valid here.
	_terminal_hold("unsafe_recovery_refused:" + reason)
`;

export function deriveWorkspace(source) {
  let out = once(source, 'var _current_request: Dictionary = {}', 'var _current_request: Dictionary = {}\nvar _population_receipt: Dictionary = {}');
  out = once(out, `\t_main = get_parent() as Node3D
\tif not is_instance_valid(_main) or not _main.preview_ready:
\t\tstatus = "actual_main_not_ready"
\t\treturn`, `\t_main = get_parent() as Node3D
\tif not is_instance_valid(_main):
\t\tstatus = "actual_main_not_ready"
\t\treturn
\t# Main waits for resident physics admission inside its async _ready. A single
\t# call_deferred mount would otherwise race and permanently disable K.
\tvar deadline := Time.get_ticks_msec() + 20000
\twhile is_instance_valid(_main) and not _main.preview_ready and Time.get_ticks_msec() < deadline:
\t\tawait get_tree().process_frame
\tif not is_instance_valid(_main) or is_queued_for_deletion() or not _main.preview_ready:
\t\tstatus = "actual_main_not_ready"
\t\treturn`);
  out = once(out, 'if _main.preview_population != null or _main.preview_residents_enabled or OS.get_cmdline_user_args().has("--preview-residents"): return "nav_owner_missing"', 'if _main.preview_population == null or not _main.preview_residents_enabled or _main.population_status != "ready": return "population_owner_missing"\n\tfor method: String in ["begin_editor_pause", "verify_editor_pause", "cancel_editor_pause", "prepare_editor_resume_atomic", "commit_editor_resume_atomic", "abort_editor_resume_atomic", "finalize_editor_resume_atomic", "flush_editor_resume_atomic"]:\n\t\tif not _main.preview_population.has_method(method): return "population_atomic_api_missing"');
  out = block(out, 'func _pause_gameplay(request: Dictionary) -> Dictionary:\n', 'func _verify_pause(receipt: Dictionary) -> bool:\n', pauseGameplay);
  out = once(out, 'and _main.preview_population == null and not is_instance_valid(_main.preview_character_impacts)', 'and _population_current() and not is_instance_valid(_main.preview_character_impacts)');
  out = block(out, 'func _resume_gameplay(receipt: Dictionary, document: Dictionary, ground: Dictionary) -> Dictionary:\n', 'func _cancel_pause(request: Dictionary) -> Dictionary:\n', resumeGameplay);
  out = block(out, 'func _cancel_pause(request: Dictionary) -> Dictionary:\n', 'func _sha256(bytes: PackedByteArray) -> String:\n', cancelGameplay);
  const teardownAt = out.indexOf('func _notification(what: int) -> void:\n');
  if (teardownAt < 0 || out.indexOf('func _notification(what: int) -> void:\n', teardownAt + 1) >= 0 || !out.includes('func _emergency_cancel(reason: String) -> void:\n')) throw Error('Missing/ambiguous teardown seam');
  out = out.slice(0, teardownAt) + teardown;
  return out;
}

export function buildWorkspace() {
  return deriveWorkspace(fs.readFileSync(path.join(root, 'tools/godot/map_editor_main_pause_candidate/pause_workspace.gd'), 'utf8'));
}

export function buildCandidate() {
  const population = buildPopulation(), navigation = buildNavigation();
  return {population, navigation, workspace: Buffer.from(buildWorkspace())};
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const result = buildCandidate();
  console.log(JSON.stringify({workspaceSha256:sha(result.workspace), population:result.population.hashes, navigation:Object.fromEntries(Object.entries(result.navigation).map(([k,v])=>[k,sha(v)])), checkpoint:{closurePin,mainPin,scenePin,projectPin}}));
}
