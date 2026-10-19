import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {buildCurrentSource} from './build_candidate.mjs';
import {buildAtomicSource as buildNavigation} from '../map_editor_nav_atomic_candidate/build_candidate.mjs';
import {buildSource as buildClock} from '../map_editor_clock_atomic_candidate/build_candidate.mjs';
import {buildWaterCandidate} from '../map_editor_water_owner_candidate/build_candidate.mjs';
import {buildTeardownSource} from '../map_editor_actual_k_composition_candidate/teardown_variant.mjs';

const own = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(own, '../../..');
const source = path.join(root, 'godot/mafiozi_walk');
const outputRoot = path.join(root, 'outputs');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const navPins = {
  'scripts/navigation/preview_engine_navigation.gd':'aca4ff31b689a5b652ca85ddd0999d45696debb912bb8e1495f056d02db69aab',
  'scripts/navigation/preview_navigation_host.gd':'0b6fd34bc1d77e1f27c2005b699477453f089f4f65bf7d21942e73adbad631d4',
  'scripts/navigation/path_job_queue.gd':'dc19de386ccef8e23dcf1c2f0b62f6a46f7f816cf8fd5c3c26c8a6409b7be473',
  'scripts/preview_printshop_interior.gd':'300b48c8efa0d0b953514b36e0c0319febfd6d9a2ff61450601a45e1109e37f4',
  'scripts/preview_interior_finish.gd':'f2137740ac1b31669454f18c258db3560bf3c9eb9ff35b0a00875db0ee6bb497'
};
function safe(target) {
  let cursor = target;
  while (cursor !== path.dirname(cursor)) {
    if (fs.existsSync(cursor) && fs.lstatSync(cursor).isSymbolicLink()) throw Error(`Symlink refused: ${cursor}`);
    cursor = path.dirname(cursor);
  }
  return target;
}
for (const p of [source, outputRoot, own]) safe(p);
function closure() {
  const files = [];
  function collect(dir) {
    for (const entry of fs.readdirSync(dir, {withFileTypes:true})) {
      const absolute = safe(path.join(dir, entry.name));
      if (entry.isSymbolicLink()) throw Error(`Symlink refused: ${absolute}`);
      if (entry.isDirectory()) {
        if (entry.name !== '.godot' && entry.name !== 'tests') collect(absolute);
      } else if (entry.isFile()) files.push([path.relative(source, absolute).split(path.sep).join('/'), fs.readFileSync(absolute)]);
    }
  }
  for (const directory of ['scripts', 'scenes', 'data', 'assets', 'addons']) collect(path.join(source, directory));
  files.sort(([a], [b]) => a.localeCompare(b));
  return files;
}
function one(text, needle, replacement) {
  const at = text.indexOf(needle);
  if (at < 0 || text.indexOf(needle, at + needle.length) >= 0) throw Error(`Missing/ambiguous scene seam: ${needle}`);
  return text.slice(0, at) + replacement + text.slice(at + needle.length);
}
const files = closure();
const byPath = new Map(files);
const projectOriginal = fs.readFileSync(path.join(source, 'project.godot'));
const sourceDigest = sha(Buffer.from(JSON.stringify(files.map(([relative, bytes]) => [relative, sha(bytes)]))));
const sourceBytes = files.reduce((sum, [, bytes]) => sum + bytes.length, 0);
if (sourceBytes > 320 * 1024 * 1024) throw Error(`Source closure too large: ${sourceBytes}`);
for (const [relative, expected] of Object.entries(navPins)) {
  if (sha(byPath.get(relative) ?? Buffer.alloc(0)) !== expected) throw Error(`Navigation owner drift: ${relative}`);
}
const current = buildCurrentSource(relative => {
  const bytes = byPath.get(relative);
  if (bytes == null) throw Error(`Current source absent: ${relative}`);
  return bytes.toString('utf8');
});
for (const [key, relative] of Object.entries({resident:'scripts/npc_visual/preview_resident_host.gd', population:'scripts/preview_population.gd', policy:'scripts/npc_visual/preview_resident_world_policy.gd', hit:'scripts/npc_visual/npc_local_preview_hit_owner.gd'})) {
  if (sha(byPath.get(relative)) !== current.sourcePins[key]) throw Error(`Current source drift: ${relative}`);
}
const nav = buildNavigation(), clock = buildClock(), water = buildWaterCandidate(), teardown = buildTeardownSource();
let scene = byPath.get('scenes/main.tscn').toString('utf8');
scene = one(scene, 'load_steps=2', 'load_steps=3');
scene = one(scene, 'path="res://scripts/main.gd"', 'path="res://diagnostic/main_pause.gd"');
scene = one(scene, '[node name="MafioziWalkMigration"', '[ext_resource type="Script" path="res://diagnostic/pause_workspace.gd" id="2"]\n\n[node name="MafioziWalkMigration"');
scene += '\n[node name="PauseOnlyAtomicWorkspace" type="Node" parent="."]\nscript = ExtResource("2")\n';
const projectText = one(projectOriginal.toString('utf8'), 'config/custom_user_dir_name="MafioziGodotPreview"', `config/custom_user_dir_name="MafioziCurrentK-${crypto.randomUUID()}"`);
const fromTool = relative => fs.readFileSync(path.join(root, relative));
const overrides = new Map([
  ['scenes/main_original.tscn', byPath.get('scenes/main.tscn')],
  ['scenes/main.tscn', Buffer.from(scene)],
  ['project.godot', Buffer.from(projectText)],
  ['scripts/preview_population.gd', Buffer.from(current.population)],
  ['scripts/npc_visual/preview_resident_host.gd', Buffer.from(current.resident)],
  ['scripts/npc_visual/preview_resident_world_policy.gd', Buffer.from(current.policy)],
  ['scripts/npc_visual/npc_local_preview_hit_owner.gd', Buffer.from(current.hit)],
  ['scripts/preview_transport.gd', Buffer.concat([byPath.get('scripts/preview_transport.gd'), fromTool('tools/godot/map_editor_vehicle_pause_candidate/transport_owner_append.gdinc')])],
  ['scripts/navigation/preview_navigation_host.gd', nav.host],
  ['scripts/navigation/path_job_queue.gd', nav.queue],
  ['scripts/navigation/pause_backend.gd', nav.pauseBackend],
  ['scripts/navigation/atomic_backend.gd', nav.backend],
  ['scripts/map_editor/editor_host_adapter.gd', fromTool('tools/godot/map_editor_candidate/scripts/map_editor/editor_host_adapter.gd')],
  ['scripts/map_editor/editor_host_adapter_v2.gd', fromTool('tools/godot/map_editor_host_adapter_v2/host_adapter_v2.gd')],
  ['scripts/map_editor/editor_host_adapter_v3.gd', fromTool('tools/godot/map_editor_main_pause_candidate/host_adapter_v3.gd')],
  ['scripts/map_editor/editor_input_router.gd', fromTool('tools/godot/map_editor_candidate/scripts/map_editor/editor_input_router.gd')],
  ['scripts/map_editor/editor_input_router_v2.gd', fromTool('tools/godot/map_editor_input_router_pause_candidate/router_v2.gd')],
  ['scripts/map_editor/map_document.gd', fromTool('tools/godot/map_editor_candidate/scripts/map_editor/map_document.gd')],
  ['diagnostic/main_pause.gd', fromTool('tools/godot/map_editor_main_pause_candidate/main_pause.gd')],
  ['diagnostic/pause_workspace.gd', Buffer.from(current.workspace)],
  ['diagnostic/clocked_main.gd', fromTool('tools/godot/map_editor_native_clock_candidate/clocked_main.gd')],
  ['diagnostic/clocked_melee.gd', fromTool('tools/godot/map_editor_native_clock_candidate/clocked_melee.gd')],
  ['diagnostic/gameplay_clock.gd', clock.clock],
  ['diagnostic/vehicle_pause_lease.gd', fromTool('tools/godot/map_editor_vehicle_pause_candidate/vehicle_pause_lease.gd')],
  ['diagnostic/teardown_guard.gd', teardown.guard],
  ['diagnostic/water_owner_guard.gd', water.guard],
  ['test_k_clock_native.gd', fromTool('tools/godot/map_editor_actual_k_composition_candidate/test_k_clock_native.gd')]
]);
const staged = [...files.filter(([relative]) => !overrides.has(relative)), ...overrides];
if (new Set(staged.map(([relative]) => relative)).size !== staged.length) throw Error('Duplicate staged path');
function verifySource() {
  const now = closure();
  if (now.length !== files.length) throw Error('Concurrent source path-set drift');
  for (let i = 0; i < files.length; i++) {
    if (now[i][0] !== files[i][0] || sha(now[i][1]) !== sha(files[i][1])) throw Error(`Concurrent source drift: ${files[i][0]}`);
  }
  if (sha(fs.readFileSync(path.join(source, 'project.godot'))) !== sha(projectOriginal)) throw Error('Concurrent project drift');
}
verifySource();
const summary = {source:'current production byte snapshot', sourceFiles:files.length, sourceBytes, sourceDigest, currentMainSha256:sha(byPath.get('scripts/main.gd')), currentSceneSha256:sha(byPath.get('scenes/main.tscn')), currentProjectSha256:sha(projectOriginal), currentSourcePins:current.sourcePins, workspaceSha256:sha(Buffer.from(current.workspace)), stagedFiles:staged.length, production:false, visibleGame:false, nativeRun:false};
if (process.argv.includes('--dry-run')) { console.log(JSON.stringify({...summary,stageCreated:false})); process.exit(0); }
if (!process.argv.includes('--stage')) throw Error('Specify --dry-run or --stage; no implicit staging');
const stage = safe(fs.mkdtempSync(path.join(outputRoot, 'map-editor-current-k-rebase-')));
const manifest = {schema:1, purpose:'current-main K pause candidate with weapons and Artist23 NPC owner preservation', ...summary, files:[]};
for (const [relative, bytes] of staged) {
  const destination = path.join(stage, relative);
  if (!destination.startsWith(stage + path.sep)) throw Error(`Stage escape: ${relative}`);
  fs.mkdirSync(path.dirname(destination), {recursive:true});
  fs.writeFileSync(destination, bytes, {flag:'wx'});
  if (sha(fs.readFileSync(destination)) !== sha(bytes)) throw Error(`Stage write drift: ${relative}`);
  manifest.files.push({path:relative, sha256:sha(bytes), bytes:bytes.length, origin:overrides.has(relative)?'candidate':'current-production-snapshot'});
}
verifySource();
fs.writeFileSync(path.join(stage, 'source_snapshot.json'), JSON.stringify(manifest, null, 2), {flag:'wx'});
console.log(JSON.stringify({...summary,stage,stageCreated:true}));
