import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {buildTeardownSource} from '../map_editor_actual_k_composition_candidate/teardown_variant.mjs';
import {deriveVehicleWorkspace} from '../map_editor_vehicle_pause_candidate/compose_k_vehicle.mjs';

const own = path.dirname(fileURLToPath(import.meta.url));
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const BASE_PIN = '7aa4ec78e89da3edd4ccfc8f09881e63197b5e1450d3a6507b4d1d0cfae36eb0';
function once(source, needle, replacement) {
  const at = source.indexOf(needle);
  if (at < 0 || source.indexOf(needle, at + needle.length) >= 0) throw Error(`Missing/ambiguous water seam: ${needle.slice(0, 80)}`);
  return source.slice(0, at) + replacement + source.slice(at + needle.length);
}
export function deriveWaterWorkspace(source) {
  let out = once(source,
    'const Router = preload("res://scripts/map_editor/editor_input_router_v2.gd")',
    'const Router = preload("res://scripts/map_editor/editor_input_router_v2.gd")\nconst WaterOwnerGuard = preload("res://diagnostic/water_owner_guard.gd")');
  out = once(out,
    'if not is_instance_valid(_main) or not _main.preview_ready or _main.preview_dead or _main.preview_physics_fault: return "main_or_life"',
    'if not is_instance_valid(_main) or not _main.preview_ready or _main.preview_dead or _main.preview_physics_fault: return "main_or_life"\n\tif not WaterOwnerGuard.snapshot(_main).get("ok", false): return "water_owner_lifetime"');
  out = once(out,
    'var water_id: int = _main._water_host.get_instance_id() if _main._water_host != null else 0\n\tvar water_factory_id: int = _main._water_host._factory.get_instance_id() if _main._water_host != null and _main._water_host._factory != null else 0',
    'var water_receipt: Dictionary = WaterOwnerGuard.snapshot(_main)');
  out = once(out,
    '"water_host_id":water_id,"water_factory_id":water_factory_id,"water_time":float(_main._water_host._factory._time) if _main._water_host != null and _main._water_host._factory != null else -1.0',
    '"water_owner":water_receipt');
  out = once(out,
    '"water_id":_main._water_host.get_instance_id() if _main._water_host != null else 0',
    '"water_owner":WaterOwnerGuard.snapshot(_main)');
  out = once(out, 'and _capture() == _snapshot', 'and WaterOwnerGuard.snapshot(_main).get("ok", false) and _capture() == _snapshot');
  out = once(out,
    'return _without_focus_state(_capture()) == _critical_snapshot and is_instance_valid(_vehicle_lease)',
    'return WaterOwnerGuard.snapshot(_main).get("ok", false) and _without_focus_state(_capture()) == _critical_snapshot and is_instance_valid(_vehicle_lease)');
  return out;
}
export function buildWaterCandidate() {
  const base = deriveVehicleWorkspace(buildTeardownSource().workspace.toString('utf8'));
  if (sha(base) !== BASE_PIN) throw Error(`Composed actual-K base drift: ${sha(base)}`);
  return {workspace:Buffer.from(deriveWaterWorkspace(base)), guard:fs.readFileSync(path.join(own,'water_owner_guard.gd')),
    baseSha256:BASE_PIN};
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const result = buildWaterCandidate();
  console.log(JSON.stringify({baseSha256:result.baseSha256,workspaceSha256:sha(result.workspace),guardSha256:sha(result.guard),production:false,gpu:false}));
}
