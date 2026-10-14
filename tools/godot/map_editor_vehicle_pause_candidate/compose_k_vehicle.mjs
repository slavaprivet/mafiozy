import {buildSource as buildClockAtomic} from '../map_editor_clock_atomic_candidate/build_candidate.mjs';

function once(source, needle, replacement) {
  const at = source.indexOf(needle);
  if (at < 0 || source.indexOf(needle, at + needle.length) >= 0) throw Error(`Missing/ambiguous vehicle K seam: ${needle.slice(0, 80)}`);
  return source.slice(0, at) + replacement + source.slice(at + needle.length);
}

// Deliberately composes only the isolated clock-atomic diagnostic workspace.
// No production script, map object, or visible game is modified.
export function deriveVehicleWorkspace(source) {
  let out = once(source, 'var _population_receipt: Dictionary = {}', 'var _population_receipt: Dictionary = {}\nvar _vehicle_lease: Node\nvar _vehicle_receipt: Dictionary = {}');
  out = once(out, '\t_router = Router.new()', '\t_vehicle_lease = preload("res://diagnostic/vehicle_pause_lease.gd").new()\n\t_main.preview_transport.add_child(_vehicle_lease)\n\t_router = Router.new()');
  out = once(out,
    'if not transport._parked_brake or body.linear_velocity.length_squared() > 0.0001 or body.angular_velocity.length_squared() > 0.0001 or body._contact_buffer.size() != 0 or body._contact_buffer.has_gap(): return "rolling_or_contact_vehicle"',
    'if not transport._parked_brake or body._contact_buffer.size() != 0 or body._contact_buffer.has_gap(): return "rolling_or_contact_vehicle"\n\tif not is_instance_valid(_vehicle_lease): return "vehicle_lease_missing"');
  out = once(out,
    '\t# Real three-resident, policy, queue and navigation owners are acquired while',
    '\t_vehicle_receipt = _vehicle_lease.acquire()\n\tif _vehicle_receipt.is_empty():\n\t\tstatus = "vehicle_stability_lease_refused"\n\t\treturn {"ok":false,"reason":status}\n\t# Real three-resident, policy, queue and navigation owners are acquired while');
  out = once(out,
    '\tif _population_receipt.is_empty():\n\t\tstatus = "population_pause_refused"',
    '\tif _population_receipt.is_empty():\n\t\tif not _vehicle_lease.release(_vehicle_receipt):\n\t\t\t_terminal_hold("vehicle_population_rollback")\n\t\t\treturn {"ok":false,"reason":status}\n\t\t_vehicle_receipt.clear()\n\t\tstatus = "population_pause_refused"');
  out = once(out,
    '\t\t_population_receipt.clear()\n\t\tstatus = "clock_pause_refused"',
    '\t\t_population_receipt.clear()\n\t\tif not _vehicle_lease.release(_vehicle_receipt):\n\t\t\t_terminal_hold("vehicle_clock_rollback")\n\t\t\treturn {"ok":false,"reason":status}\n\t\t_vehicle_receipt.clear()\n\t\tstatus = "clock_pause_refused"');
  out = once(out,
    'and _population_current() and not is_instance_valid(_main.preview_character_impacts)',
    'and _population_current() and is_instance_valid(_vehicle_lease) and _vehicle_lease.verify(_vehicle_receipt) and not is_instance_valid(_main.preview_character_impacts)');
  out = once(out,
    '\tif not clock.commit_resume(clock_ticket):',
    '\t# Vehicle is the last fallible native body owner, released while tree and\n\t# gameplay clock remain paused. A failure keeps the scene in terminal HOLD.\n\tif not _vehicle_lease.release(_vehicle_receipt):\n\t\t_terminal_hold("vehicle_release")\n\t\treturn {"ok":false,"reason":status}\n\t_vehicle_receipt.clear()\n\tif not clock.commit_resume(clock_ticket):');
  if (out.includes('func _teardown_current() -> bool:')) {
    out = once(out,
      'return _without_focus_state(_capture()) == _critical_snapshot',
      'return _without_focus_state(_capture()) == _critical_snapshot and is_instance_valid(_vehicle_lease) and _vehicle_lease.verify(_vehicle_receipt)');
  }
  return out;
}

export function buildVehicleWorkspace() {
  return Buffer.from(deriveVehicleWorkspace(buildClockAtomic().workspace.toString('utf8')));
}
