import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {patchResident, patchPopulation, patchPolicy} from '../map_editor_resident_pause_candidate/build_candidate.mjs';
import {patchAtomicSource} from '../map_editor_resident_atomic_candidate/build_candidate.mjs';
import {buildWaterCandidate} from '../map_editor_water_owner_candidate/build_candidate.mjs';

const own = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(own, '../../..');
const project = path.join(root, 'godot/mafiozi_walk');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

function once(source, needle, replacement) {
  const at = source.indexOf(needle);
  if (at < 0 || source.indexOf(needle, at + needle.length) >= 0) throw Error(`Missing or ambiguous current-main seam: ${needle.slice(0, 90)}`);
  return source.slice(0, at) + replacement + source.slice(at + needle.length);
}

function block(source, start, end, replacement) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  if (a < 0 || b < 0 || source.indexOf(start, a + start.length) >= 0) throw Error(`Missing or ambiguous current-main block: ${start}`);
  return source.slice(0, a) + replacement + source.slice(b);
}

// The old pause candidate predates the weapon/HP/activity work on current main.
// Keep those actual sources and extend their receipts instead of copying the
// Coordinator22 population file over Artist23's production changes.
export function patchCurrentResident(source) {
  let out = patchResident(source);
  out = once(out, '\tvar rows: Array = []\n\tvar ids: Array = _records.keys()\n\tids.sort()', `\tvar rows: Array = []
\tvar ids: Array = _records.keys()
\tids.sort()
\tvar physical_rows := {}
\tfor id: String in ids:
\t\tif not _ragdolls.has(id): return {}
\t\tvar physical: RefCounted = _ragdolls[id]
\t\tif not is_instance_valid(physical): return {}
\t\tvar physical_status: Dictionary = physical.status()
\t\t# Editing an active/recovering body would require a separate physical lease.
\t\tif physical_status.get("mode") != "IDLE": return {}
\t\tphysical_rows[id] = {"id":physical.get_instance_id(),"status":physical_status.duplicate(true)}`);
  out = once(out, '\t\tvar gait: Gait = record.gait\n', `\t\tvar gait: Gait = record.gait
\t\tvar activity: RefCounted = record.activity
\t\tif record.get("physical_failed", false) or not is_instance_valid(activity): return {}
\t\tvar activity_rig: WeakRef = activity.get("_rig")
\t\tif activity_rig == null or not is_instance_valid(activity_rig.get_ref()): return {}
`);
  out = once(out, '\t\trows[rows.size() - 1]["gait_id"] = gait.get_instance_id()', `\t\trows[rows.size() - 1]["activity"] = {"id":activity.get_instance_id(),"rig_id":activity_rig.get_ref().get_instance_id(),"head":activity.get("_head"),"chest":activity.get("_chest"),"clock":activity.get("_clock"),"phase":activity.get("_phase"),"weight":activity.get("_weight")}
\t\trows[rows.size() - 1]["gait_id"] = gait.get_instance_id()`);
  out = once(out, '"rows":rows,"walk_enabled":_walk_preview_enabled', '"rows":rows,"physical_rows":physical_rows,"walk_enabled":_walk_preview_enabled');
  return out;
}

export function patchCurrentPopulation(source) {
  let out = patchPopulation(source);
  out = block(out, 'func _editor_owner_state() -> Dictionary:\n', 'func begin_editor_pause(owner: Node) -> Dictionary:\n', `func _editor_owner_state() -> Dictionary:
\tif _disposed or status != "ready" or residents == null or navigation == null or policy == null or owners.size() != 3 or hit_owners.size() != 3: return {}
\tvar state := {"policy_version":policy.access_version(),"owners":{},"hit_owners":[],"combat_status":combat_status}
\tfor id: String in owners:
\t\tvar owner: Queue.Owner = owners[id]
\t\tif not is_instance_valid(owner) or owner.dead or owner.source_id != id or owner.life_generation != 1: return {}
\t\tstate.owners[id] = {"instance_id":owner.get_instance_id(),"source_id":owner.source_id,"generation":owner.life_generation,"dead":owner.dead}
\tfor hit: RefCounted in hit_owners:
\t\tif not is_instance_valid(hit) or not hit.get("_ready") or not hit.get("_admitting") is Dictionary or not hit.get("_admitting").is_empty(): return {}
\t\tvar row: Dictionary = hit.get("_row")
\t\tif row.is_empty() or row.get("dead", false) or row.get("_medicalDowned", false): return {}
\t\tstate.hit_owners.append({"id":hit.get_instance_id(),"binding":hit.get("_binding").duplicate(true),"row":row.duplicate(true),"shots":hit.get("_shots").duplicate(true),"events":hit.get("_events").duplicate(true),"pending_effects":hit.get("pending_effects").duplicate(true),"last_result":hit.get("last_result").duplicate(true),"last_physical":hit.get("last_physical").duplicate(true),"serial":hit.get("_serial"),"clock_id":hit.get("_gameplay_clock").get_instance_id() if is_instance_valid(hit.get("_gameplay_clock")) else -1})
\treturn state

`);
  return out;
}

export function patchCurrentHitOwner(source) {
  let out = once(source, 'var _start_us:=0', 'var _start_ms:=0.0\nvar _gameplay_clock: RefCounted');
  out = once(out, '\t_host=host; _token=token.duplicate(); _weapons=weapons; _marksman=source_player_stats.marksman', `\tvar main: Node3D = weapons.get_parent() as Node3D
\tif not is_instance_valid(main) or not is_instance_valid(main.get("preview_melee")): return {"ok":false,"reason":"gameplay_clock_owner"}
\tvar clock: RefCounted = main.preview_melee.gameplay_clock
\tif not is_instance_valid(clock) or not is_finite(clock.now_ms()): return {"ok":false,"reason":"gameplay_clock_unavailable"}
\t_host=host; _token=token.duplicate(); _weapons=weapons; _marksman=source_player_stats.marksman`);
  out = once(out, '"start_us":Time.get_ticks_usec(),"rng":_rng', '"start_ms":clock.now_ms(),"clock":clock,"rng":_rng');
  out = once(out, 'if registry.marksman!=_marksman or registry.session_id!=token.session_id:', 'if registry.marksman!=_marksman or registry.session_id!=token.session_id or registry.clock!=clock:');
  out = once(out, '\t_start_us=registry.start_us; _rng=registry.rng; _ready=true', '\t_start_ms=float(registry.start_ms); _gameplay_clock=clock; _rng=registry.rng; _ready=true');
  out = once(out, '\treturn float(Time.get_ticks_usec()-_start_us)/1000.0+1.0', '\treturn _gameplay_clock.now_ms()-_start_ms+1.0 if is_instance_valid(_gameplay_clock) else NAN');
  out = once(out, '\t_adapter=null; _host=null; _weapons=null', '\t_adapter=null; _host=null; _weapons=null; _gameplay_clock=null');
  return out;
}

export function buildCurrentWorkspace() {
  let out = buildWaterCandidate().workspace.toString('utf8');
  out = once(out,
    '\tif _gameplay_input_held(): return "held_gameplay_input"',
    `\tif _gameplay_input_held(): return "held_gameplay_input"
\t# Current main also owns real weapon input and projectile effects. K must
\t# refuse while a shot, reload or effect is still crossing an owner boundary.
\tvar weapons: Node = _main.preview_weapons
\tif not is_instance_valid(weapons) or not weapons.ready_for_play or weapons.menu_open or not weapons._pending_plan.is_empty() or not weapons._pending_shots.is_empty(): return "weapons_owner_unavailable"
\tvar fire: Dictionary = weapons.fire_state
\tif fire.get("triggerHeld", false) or float(fire.get("cooldown", 0.0)) > 0.0 or float(fire.get("reloadRemaining", 0.0)) > 0.0 or float(fire.get("recoil", 0.0)) > 0.0: return "weapons_action_in_flight"
\tif not is_instance_valid(weapons.effects) or not is_instance_valid(weapons.rpg_effects) or not is_instance_valid(weapons.surface_effects): return "weapons_effect_owner_missing"
\tvar effects: Dictionary = weapons.effects.stats()
\tvar rpg: Dictionary = weapons.rpg_effects.stats()
\tvar surface: Dictionary = weapons.surface_effects.stats()
\tif int(effects.get("active", -1)) != 0 or int(effects.get("pendingCasings", -1)) != 0 or int(rpg.get("active_rockets", -1)) != 0 or int(rpg.get("active_explosions", -1)) != 0 or int(surface.get("impacts", -1)) != 0: return "weapons_effect_in_flight"`);
  out = once(out,
    '"melee_state":_main.preview_melee.snapshot(),"transport_phase":transport.phase',
    '"melee_state":_main.preview_melee.snapshot(),"weapons_id":_main.preview_weapons.get_instance_id(),"weapons_state":_main.preview_weapons.snapshot(),"weapon_pending":_main.preview_weapons._pending_plan.duplicate(true),"weapon_shots":_main.preview_weapons._pending_shots.duplicate(true),"weapon_surface":_main.preview_weapons.surface_effects.stats(),"transport_phase":transport.phase');
  return out;
}

export function buildCurrentSource(read = relative => fs.readFileSync(path.join(project, relative), 'utf8')) {
  const originals = {
    resident: read('scripts/npc_visual/preview_resident_host.gd'),
    population: read('scripts/preview_population.gd'),
    policy: read('scripts/npc_visual/preview_resident_world_policy.gd'),
    hit: read('scripts/npc_visual/npc_local_preview_hit_owner.gd')
  };
  const base = {
    resident: patchCurrentResident(originals.resident),
    population: patchCurrentPopulation(originals.population),
    policy: patchPolicy(originals.policy),
    sourcePins: Object.fromEntries(Object.entries(originals).map(([key, value]) => [key, sha(Buffer.from(value))]))
  };
  const atomic = patchAtomicSource(base);
  return {...atomic, hit: patchCurrentHitOwner(originals.hit), workspace: buildCurrentWorkspace(), sourcePins: {...base.sourcePins, hit: sha(Buffer.from(originals.hit))}};
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const output = buildCurrentSource();
  console.log(JSON.stringify({sourcePins: output.sourcePins, outputHashes: Object.fromEntries(['resident', 'population', 'policy', 'hit', 'workspace'].map(key => [key, sha(Buffer.from(output[key]))])), production: false, nativeRun: false}));
}
