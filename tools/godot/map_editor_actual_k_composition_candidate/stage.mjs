import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {buildCandidate} from './build_candidate.mjs';
import {buildSource as buildClockAtomic} from '../map_editor_clock_atomic_candidate/build_candidate.mjs';
import {buildVehicleWorkspace,deriveVehicleWorkspace} from '../map_editor_vehicle_pause_candidate/compose_k_vehicle.mjs';
import {buildTeardownSource} from './teardown_variant.mjs';
import {buildWaterCandidate} from '../map_editor_water_owner_candidate/build_candidate.mjs';

const own = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(own, '../../..');
const source = path.join(root, 'outputs/coordinator22_residents_checkpoint/godot/mafiozi_walk');
const outputRoot = path.join(root, 'outputs');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const pins = {
  closure:'cbd7182488cbaf56a72017c8be101b4bfdf4c9c45e9088e1d414324a7e435ba6',
  main:'faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53',
  scene:'52aa1629fe38251f27ab50e3c6c102e0d0073348d6f610319d6c6b0233618bde',
  project:'c500a17d372f149b4b751ed4ef90a5a27bcb55e1050ba9d510d33fb5bcf6ff28'
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
  for (const directory of ['scripts','scenes','data','assets','addons']) collect(path.join(source, directory));
  files.sort(([a],[b]) => a.localeCompare(b));
  return files;
}
function exactReplace(text, needle, replacement) {
  const at=text.indexOf(needle);
  if(at<0 || text.indexOf(needle,at+needle.length)>=0) throw Error(`Missing/ambiguous scene or project seam: ${needle}`);
  return text.slice(0,at)+replacement+text.slice(at+needle.length);
}
const files=closure();
const byPath=new Map(files);
const projectOriginal=fs.readFileSync(path.join(source,'project.godot'));
for (const [relative, expected] of [['scripts/main.gd',pins.main],['scenes/main.tscn',pins.scene]]) {
  if (!byPath.has(relative) || sha(byPath.get(relative)) !== expected) throw Error(`Pinned source drift: ${relative}`);
}
if (sha(projectOriginal) !== pins.project) throw Error('Pinned project drift');
const digest=sha(Buffer.from(JSON.stringify(files.map(([relative,bytes])=>[relative,sha(bytes)]))));
if (digest !== pins.closure) throw Error(`Pinned closure drift: ${digest}`);
const total=files.reduce((sum,[,bytes])=>sum+bytes.length,0);
if (total>180*1024*1024) throw Error(`Source closure too large: ${total}`);
const candidate=buildCandidate();
const clockAtomic=process.argv.includes('--clock-atomic')?buildClockAtomic():null;
const vehicleLease=process.argv.includes('--vehicle-lease');
const teardownGuard=process.argv.includes('--teardown-guard');
const waterGuard=process.argv.includes('--water-guard');
if(vehicleLease && !clockAtomic) throw Error('--vehicle-lease requires --clock-atomic');
if(teardownGuard && !clockAtomic) throw Error('--teardown-guard requires --clock-atomic');
if(waterGuard && !(clockAtomic && vehicleLease && teardownGuard)) throw Error('--water-guard requires --clock-atomic --vehicle-lease --teardown-guard');
const teardown=teardownGuard?buildTeardownSource():null;
const water=waterGuard?buildWaterCandidate():null;
const stagedWorkspace=water?.workspace??(vehicleLease?(teardown?Buffer.from(deriveVehicleWorkspace(teardown.workspace.toString('utf8'))):buildVehicleWorkspace()):teardown?.workspace??clockAtomic?.workspace??candidate.workspace);
const checkpointTransport=byPath.get('scripts/preview_transport.gd');
if(sha(checkpointTransport)!=='9d80b1f88a0d1e7196c525b8f09ab2154dc1180091449897d4016ed473e8ab45') throw Error('Pinned checkpoint transport drift');
let scene=byPath.get('scenes/main.tscn').toString('utf8');
scene=exactReplace(scene,'load_steps=2','load_steps=3');
scene=exactReplace(scene,'path="res://scripts/main.gd"','path="res://diagnostic/main_pause.gd"');
scene=exactReplace(scene,'[node name="MafioziWalkMigration"','[ext_resource type="Script" path="res://diagnostic/pause_workspace.gd" id="2"]\n\n[node name="MafioziWalkMigration"');
scene += '\n[node name="PauseOnlyAtomicWorkspace" type="Node" parent="."]\nscript = ExtResource("2")\n';
const project=exactReplace(projectOriginal.toString('utf8'),'config/custom_user_dir_name="MafioziGodotPreview"',`config/custom_user_dir_name="MafioziAtomicPause-${crypto.randomUUID()}"`);
const fromTool=(relative)=>fs.readFileSync(path.join(root,relative));
const overrides=new Map([
  ['scenes/main_original.tscn',byPath.get('scenes/main.tscn')],
  ['scenes/main.tscn',Buffer.from(scene)],
  ['project.godot',Buffer.from(project)],
  ['scripts/preview_population.gd',Buffer.from(candidate.population.population)],
  ['scripts/preview_transport.gd',Buffer.concat([checkpointTransport,fromTool('tools/godot/map_editor_vehicle_pause_candidate/transport_owner_append.gdinc')])],
  ['scripts/npc_visual/preview_resident_host.gd',Buffer.from(candidate.population.resident)],
  ['scripts/npc_visual/preview_resident_world_policy.gd',Buffer.from(candidate.population.policy)],
  ['scripts/navigation/preview_navigation_host.gd',candidate.navigation.host],
  ['scripts/navigation/path_job_queue.gd',candidate.navigation.queue],
  ['scripts/navigation/pause_backend.gd',candidate.navigation.pauseBackend],
  ['scripts/navigation/atomic_backend.gd',candidate.navigation.backend],
  ['scripts/map_editor/editor_host_adapter.gd',fromTool('tools/godot/map_editor_candidate/scripts/map_editor/editor_host_adapter.gd')],
  ['scripts/map_editor/editor_host_adapter_v2.gd',fromTool('tools/godot/map_editor_host_adapter_v2/host_adapter_v2.gd')],
  ['scripts/map_editor/editor_host_adapter_v3.gd',fromTool('tools/godot/map_editor_main_pause_candidate/host_adapter_v3.gd')],
  ['scripts/map_editor/editor_input_router.gd',fromTool('tools/godot/map_editor_candidate/scripts/map_editor/editor_input_router.gd')],
  ['scripts/map_editor/editor_input_router_v2.gd',fromTool('tools/godot/map_editor_input_router_pause_candidate/router_v2.gd')],
  ['scripts/map_editor/map_document.gd',fromTool('tools/godot/map_editor_candidate/scripts/map_editor/map_document.gd')],
  ['diagnostic/main_pause.gd',fromTool('tools/godot/map_editor_main_pause_candidate/main_pause.gd')],
  ['diagnostic/pause_workspace.gd',stagedWorkspace],
  ['diagnostic/clocked_main.gd',fromTool('tools/godot/map_editor_native_clock_candidate/clocked_main.gd')],
  ['diagnostic/clocked_melee.gd',fromTool('tools/godot/map_editor_native_clock_candidate/clocked_melee.gd')],
  ['diagnostic/gameplay_clock.gd',clockAtomic?.clock??fromTool('tools/godot/map_editor_native_clock_candidate/gameplay_clock.gd')],
  ['test_k_clock_native.gd',fromTool('tools/godot/map_editor_actual_k_composition_candidate/test_k_clock_native.gd')],
  ['diagnostic/vehicle_pause_lease.gd',fromTool('tools/godot/map_editor_vehicle_pause_candidate/vehicle_pause_lease.gd')],
  ...(teardownGuard?[['diagnostic/teardown_guard.gd',teardown.guard]]:[]),
  ...(waterGuard?[['diagnostic/water_owner_guard.gd',water.guard]]:[]),
  ['test_vehicle_actual_body_native.gd',fromTool('tools/godot/map_editor_vehicle_pause_candidate/test_actual_body_native.gd')]
]);
const staged=[...files.filter(([relative])=>!overrides.has(relative)),...overrides];
const relativePaths=staged.map(([relative])=>relative);
if (new Set(relativePaths).size!==relativePaths.length) throw Error('Duplicate staged paths');
const stagedBytes=staged.reduce((sum,[,bytes])=>sum+bytes.length,0);
if (stagedBytes>256*1024*1024) throw Error('Staged byte ceiling exceeded');
function verifySource() {
  const now=closure();
  if(now.length!==files.length) throw Error('Concurrent checkpoint path-set drift');
  for(let i=0;i<files.length;i++) if(now[i][0]!==files[i][0] || sha(now[i][1])!==sha(files[i][1])) throw Error(`Concurrent checkpoint byte drift: ${files[i][0]}`);
  if(sha(fs.readFileSync(path.join(source,'project.godot')))!==pins.project) throw Error('Concurrent project drift');
}
verifySource();
const summary={source:'immutable Coordinator22 residents checkpoint',sourceFiles:files.length,sourceBytes:total,sourceClosureSha256:digest,stagedFiles:staged.length,stagedBytes,workspaceSha256:sha(stagedWorkspace),clockSha256:clockAtomic?sha(clockAtomic.clock):null,clockAtomic:clockAtomic!=null,vehicleLease,teardownGuard,waterGuard,navHostSha256:sha(candidate.navigation.host),populationSha256:sha(Buffer.from(candidate.population.population)),defaultResidents:true,pauseOnly:true,production:false,godotRun:false,gpu:false};
if (process.argv.includes('--dry-run')) { console.log(JSON.stringify({...summary,stageCreated:false})); process.exit(0); }
if (!process.argv.includes('--stage')) throw Error('Specify --dry-run or coordinator-approved --stage; no implicit staging');
const stage=safe(fs.mkdtempSync(path.join(outputRoot,'map-editor-actual-k-atomic-')));
const manifest={schema:1,purpose:'diagnostic actual-main K pause-only atomic-owner composition; native unverified',...summary,files:[]};
for(const [relative,bytes] of staged){
  const destination=path.join(stage,relative);
  if(!destination.startsWith(stage+path.sep)) throw Error(`Stage escape: ${relative}`);
  fs.mkdirSync(path.dirname(destination),{recursive:true});
  fs.writeFileSync(destination,bytes,{flag:'wx'});
  if(sha(fs.readFileSync(destination))!==sha(bytes)) throw Error(`Stage byte mismatch: ${relative}`);
  manifest.files.push({path:relative,sha256:sha(bytes),bytes:bytes.length,origin:overrides.has(relative)?'candidate':'checkpoint'});
}
verifySource();
fs.writeFileSync(path.join(stage,'source_snapshot.json'),JSON.stringify(manifest,null,2),{flag:'wx'});
console.log(JSON.stringify({...summary,stage,stageCreated:true}));
