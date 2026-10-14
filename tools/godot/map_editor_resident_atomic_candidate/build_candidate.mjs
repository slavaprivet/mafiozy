import {buildSource as buildPauseSource} from '../map_editor_resident_pause_candidate/build_candidate.mjs';
import crypto from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const sha = value => crypto.createHash('sha256').update(value).digest('hex');
function before(source, marker, insertion) {
  const first = source.indexOf(marker);
  if (first < 0 || source.indexOf(marker, first + marker.length) >= 0) throw Error(`Missing or ambiguous seam: ${marker}`);
  return source.slice(0, first) + insertion + source.slice(first);
}

// Residents and policy have no deferred callback queue. Their tickets only
// stage the owner-held lease; no gameplay write is admitted by prepare/commit.
const leafAtomic = `var _editor_resume_serial := 0
var _editor_resume_ticket: Dictionary = {}
var _editor_resume_phase := ""

func prepare_editor_resume_atomic(receipt: Dictionary) -> Dictionary:
\tif _editor_resume_phase != "" or not _editor_pause_current(receipt): return {}
\tvar owner: Node = _editor_pause_owner.get_ref()
\tif owner.get_tree().paused != true: return {}
\t_editor_resume_serial += 1
\t_editor_resume_ticket = {"serial":_editor_resume_serial,"lease":receipt.duplicate(true),"object_id":get_instance_id()}
\t_editor_resume_phase = "prepared"
\treturn _editor_resume_ticket.duplicate(true)

func commit_editor_resume_atomic(ticket: Dictionary) -> Dictionary:
\tif _editor_resume_phase != "prepared" or ticket != _editor_resume_ticket or not _editor_pause_current(ticket.lease): return {}
\tif _editor_pause_owner.get_ref().get_tree().paused != true: return {}
\t_editor_resume_phase = "committed"
\treturn ticket.duplicate(true)

func abort_editor_resume_atomic(ticket: Dictionary) -> bool:
\tif _editor_resume_phase != "prepared" and _editor_resume_phase != "committed": return false
\tif ticket != _editor_resume_ticket or not _editor_pause_current(ticket.lease): return false
\tif _editor_pause_owner.get_ref().get_tree().paused != true: return false
\t_editor_resume_phase = ""
\t_editor_resume_ticket.clear()
\treturn true

func finalize_editor_resume_atomic(ticket: Dictionary) -> bool:
\tif _editor_resume_phase != "committed" or ticket != _editor_resume_ticket or not _editor_pause_current(ticket.lease): return false
\tif _editor_pause_owner.get_ref().get_tree().paused != true: return false
\t_editor_pause_active = false
\t_editor_pause_receipt.clear(); _editor_pause_snapshot.clear(); _editor_pause_owner = null
\t_editor_resume_phase = ""
\t_editor_resume_ticket.clear()
\treturn true

`;

const populationAtomic = `var _editor_resume_serial := 0
var _editor_resume_ticket: Dictionary = {}
var _editor_resume_phase := ""

func _editor_resume_owner(ticket: Dictionary) -> Node:
\tif ticket != _editor_resume_ticket or _editor_pause_owner == null: return null
\tvar owner: Node = _editor_pause_owner.get_ref()
\tif not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree(): return null
\treturn owner

# Acquisition rollback is legal only while the tree is still live. Release in
# reverse acquisition order: navigation, policy, residents. Any late refusal
# re-pauses the tree and retains terminal HOLD rather than exposing a half lease.
func cancel_editor_pause(receipt: Dictionary) -> bool:
\tif _editor_resume_phase != "" or not _editor_pause_current(receipt): return false
\tvar owner: Node = _editor_pause_owner.get_ref()
\tif owner.get_tree().paused: return false
\tif not navigation.has_method("cancel_editor_pause") or not navigation.can_end_editor_pause(receipt.navigation) or not policy.can_end_editor_pause(receipt.policy) or not residents.can_end_editor_pause(receipt.residents):
\t\t_editor_terminal_hold(owner)
\t\treturn false
\tif not navigation.cancel_editor_pause(receipt.navigation):
\t\t_editor_terminal_hold(owner)
\t\treturn false
\tif not policy.end_editor_pause(receipt.policy):
\t\t_editor_terminal_hold(owner)
\t\treturn false
\tif not residents.end_editor_pause(receipt.residents):
\t\t_editor_terminal_hold(owner)
\t\treturn false
\t_editor_pause_active = false
\t_editor_pause_receipt.clear(); _editor_pause_owner = null
\t_editor_pause_residents = null; _editor_pause_navigation = null; _editor_pause_policy = null; _editor_pause_owners.clear()
\treturn true

func prepare_editor_resume_atomic(receipt: Dictionary) -> Dictionary:
\tif _editor_resume_phase != "" or not _editor_pause_current(receipt): return {}
\tvar owner: Node = _editor_pause_owner.get_ref()
\tif not owner.get_tree().paused or not verify_editor_pause(receipt): return {}
\tfor dependency: RefCounted in [residents, policy, navigation]:
\t\tif not dependency.has_method("prepare_editor_resume_atomic") or not dependency.has_method("commit_editor_resume_atomic") or not dependency.has_method("abort_editor_resume_atomic") or not dependency.has_method("finalize_editor_resume_atomic"): return {}
\tvar resident_ticket: Dictionary = residents.prepare_editor_resume_atomic(receipt.residents)
\tif resident_ticket.is_empty(): return {}
\tvar policy_ticket: Dictionary = policy.prepare_editor_resume_atomic(receipt.policy)
\tif policy_ticket.is_empty():
\t\tif not residents.abort_editor_resume_atomic(resident_ticket): _editor_terminal_hold(owner)
\t\treturn {}
\tvar nav_ticket: Dictionary = navigation.prepare_editor_resume_atomic(receipt.navigation)
\tif nav_ticket.is_empty():
\t\tvar policy_ok: bool = policy.abort_editor_resume_atomic(policy_ticket)
\t\tvar resident_ok: bool = residents.abort_editor_resume_atomic(resident_ticket)
\t\tif not policy_ok or not resident_ok: _editor_terminal_hold(owner)
\t\treturn {}
\t_editor_resume_serial += 1
\t_editor_resume_ticket = {"serial":_editor_resume_serial,"lease":receipt.duplicate(true),"population_id":get_instance_id(),"residents":resident_ticket,"policy":policy_ticket,"navigation":nav_ticket}
\t_editor_resume_phase = "prepared"
\treturn _editor_resume_ticket.duplicate(true)

func commit_editor_resume_atomic(ticket: Dictionary) -> Dictionary:
\tif _editor_resume_phase != "prepared" or ticket != _editor_resume_ticket or not _editor_pause_current(ticket.lease): return {}
\tvar owner: Node = _editor_resume_owner(ticket)
\tif owner == null or not owner.get_tree().paused: return {}
\tif navigation.commit_editor_resume_atomic(ticket.navigation).is_empty():
\t\tabort_editor_resume_atomic(ticket)
\t\treturn {}
\tif policy.commit_editor_resume_atomic(ticket.policy).is_empty():
\t\tabort_editor_resume_atomic(ticket)
\t\treturn {}
\tif residents.commit_editor_resume_atomic(ticket.residents).is_empty():
\t\tabort_editor_resume_atomic(ticket)
\t\treturn {}
\t_editor_resume_phase = "committed"
\treturn ticket.duplicate(true)

func abort_editor_resume_atomic(ticket: Dictionary) -> bool:
\tif _editor_resume_phase != "prepared" and _editor_resume_phase != "committed": return false
\tvar owner: Node = _editor_resume_owner(ticket)
\tif owner == null or not owner.get_tree().paused: return false
\t# Evaluate every abort even if an earlier owner refuses.
\tvar resident_ok: bool = residents.abort_editor_resume_atomic(ticket.residents)
\tvar policy_ok: bool = policy.abort_editor_resume_atomic(ticket.policy)
\tvar nav_ok: bool = navigation.abort_editor_resume_atomic(ticket.navigation)
\tif not resident_ok or not policy_ok or not nav_ok:
\t\t_editor_terminal_hold(owner)
\t\treturn false
\t_editor_resume_phase = ""
\t_editor_resume_ticket.clear()
\treturn true

# The navigation release must retain callbacks. All owners finalize under
# paused tree, without yielding. Root unpauses only after this succeeds.
func finalize_editor_resume_atomic(ticket: Dictionary) -> bool:
\tif _editor_resume_phase != "committed" or ticket != _editor_resume_ticket or not _editor_pause_current(ticket.lease): return false
\tvar owner: Node = _editor_resume_owner(ticket)
\tif owner == null or not owner.get_tree().paused or not navigation.has_method("flush_editor_resume_atomic"): return false
\t# These finalizers are specified as no-fail after commit in the same stack.
\t# An unexpected refusal is terminal HOLD, not success.
\tif not residents.finalize_editor_resume_atomic(ticket.residents) or not policy.finalize_editor_resume_atomic(ticket.policy) or not navigation.finalize_editor_resume_atomic(ticket.navigation):
\t\t_editor_terminal_hold(owner)
\t\treturn false
\t_editor_pause_active = false
\t_editor_pause_receipt.clear()
\t_editor_pause_residents = null; _editor_pause_policy = null; _editor_pause_owners.clear()
\t_editor_resume_phase = "finalized"
\treturn true

func flush_editor_resume_atomic(ticket: Dictionary) -> bool:
\tif _editor_resume_phase != "finalized" or ticket != _editor_resume_ticket or _editor_pause_navigation == null: return false
\tvar owner: Node = _editor_resume_owner(ticket)
\tif owner == null or owner.get_tree().paused: return false
\tif not _editor_pause_navigation.flush_editor_resume_atomic(ticket.navigation):
\t\t_editor_terminal_hold(owner)
\t\treturn false
\t_editor_pause_navigation = null
\t_editor_pause_owner = null
\t_editor_resume_phase = ""
\t_editor_resume_ticket.clear()
\treturn true

`;

export function patchAtomicSource(base) {
  const addEndGuard = source => {
    const signature = 'func end_editor_pause(receipt: Dictionary) -> bool:\n';
    return before(source, signature, '').replace(signature, signature + '\tif _editor_resume_phase != "": return false\n');
  };
  const resident = addEndGuard(before(base.resident, 'func configure(scene: Node3D, navigation: RefCounted, packet: PackedByteArray, trust: Dictionary, prepared_manifest: PackedByteArray, prepared_directory: String, owners: Dictionary, source_admit: Callable, support_height: Callable) -> Dictionary:', leafAtomic));
  const policy = addEndGuard(before(base.policy, 'func configure(scene: Node3D, packet_rows: Array, owners: Dictionary, trust: Dictionary, access: Dictionary) -> Dictionary:', leafAtomic));
  const populationSource = before(base.population, 'func setup(scene: Node3D, staged_preview: bool = false, walking_preview: bool = true) -> bool:', populationAtomic);
  const population = populationSource.replace('func end_editor_pause(receipt: Dictionary) -> bool:\n', 'func end_editor_pause(receipt: Dictionary) -> bool:\n\treturn false # Legacy sequential release is forbidden in the atomic candidate.\n');
  return {resident, policy, population, sourcePins: base.sourcePins, hashes: {resident: sha(resident), policy: sha(policy), population: sha(population)}};
}

export function buildSource() {
  return patchAtomicSource(buildPauseSource());
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) console.log(JSON.stringify(buildSource().hashes));
