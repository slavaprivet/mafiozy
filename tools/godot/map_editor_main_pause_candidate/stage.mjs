import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const root=fs.realpathSync(process.cwd());
const source=path.join(root,'godot/mafiozi_walk');
const own=path.join(root,'tools/godot/map_editor_main_pause_candidate');
const outputRoot=path.join(root,'outputs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function safe(p){let q=p;while(q!==path.dirname(q)){if(fs.lstatSync(q).isSymbolicLink())throw Error('Symlink refused '+q);q=path.dirname(q);}return p;}
for(const p of [source,own,outputRoot])safe(p);
const sourceFiles=[];
function collect(dir){for(const d of fs.readdirSync(dir,{withFileTypes:true})){const p=safe(path.join(dir,d.name));if(d.isDirectory()){if(!['tests','.godot'].includes(d.name))collect(p);}else if(d.isFile()&&!d.name.endsWith('.uid')){sourceFiles.push([path.relative(source,p).split(path.sep).join('/'),fs.readFileSync(p)]);}}}
for(const d of ['scripts','scenes','data','assets','addons'])collect(path.join(source,d));
const main=sourceFiles.find(([p])=>p==='scripts/main.gd');
if(!main||sha(main[1])!=='653837bb2365c92f9e290e1f8c5126bf6fbb5357da8db3570cdb6f1bec9f6d50')throw Error('Actual main source pin changed');
const melee=sourceFiles.find(([p])=>p==='scripts/combat/preview_melee.gd');
if(!melee||sha(melee[1])!=='5098c2a1c98757446fa71bcb23117f3dfacc9b121d4c66d226ad572a6d64e5dc')throw Error('Melee source pin changed');
const originalProject=fs.readFileSync(path.join(source,'project.godot'));
if(sha(originalProject)!=='f7c9f0509cac7d8dc70ab81919cac2fcdc5444292d67a3df8e362eb40bb2e087')throw Error('Actual project settings pin changed');
const isolatedProject=originalProject.toString().replace('config/custom_user_dir_name="MafioziGodotPreview"','config/custom_user_dir_name="MafioziPause-'+crypto.randomUUID()+'"');
if(isolatedProject===originalProject.toString())throw Error('Expected isolated user dir seam missing');
const scene=sourceFiles.find(([p])=>p==='scenes/main.tscn');
if(!scene||!scene[1].toString().includes('path="res://scripts/main.gd"'))throw Error('Scene seam changed');
const candScene=scene[1].toString().replace('load_steps=2','load_steps=3').replace('path="res://scripts/main.gd"','path="res://diagnostic/main_pause.gd"')+'\n[node name="PauseOnlyWorkspace" type="Node" parent="."]\nscript = ExtResource("2")\n';
const derivedScene=candScene.replace('[node name="MafioziWalkMigration"', '[ext_resource type="Script" path="res://diagnostic/pause_workspace.gd" id="2"]\n\n[node name="MafioziWalkMigration"');
const overridden=new Set(['scenes/main.tscn','scripts/map_editor/editor_host_adapter.gd','scripts/map_editor/editor_host_adapter_v2.gd','scripts/map_editor/editor_host_adapter_v3.gd','scripts/map_editor/editor_input_router.gd','scripts/map_editor/editor_input_router_v2.gd','scripts/map_editor/map_document.gd']);
const files=sourceFiles.filter(([p])=>!overridden.has(p)).concat([
  ['scenes/main_original.tscn',scene[1]],['scenes/main.tscn',Buffer.from(derivedScene)],
  ...[
    ['diagnostic/main_pause.gd',path.join(own,'main_pause.gd')],
    ['diagnostic/pause_workspace.gd',path.join(own,'pause_workspace.gd')],
    ['diagnostic/clocked_main.gd',path.join(root,'tools/godot/map_editor_native_clock_candidate/clocked_main.gd')],
    ['diagnostic/clocked_melee.gd',path.join(root,'tools/godot/map_editor_native_clock_candidate/clocked_melee.gd')],
    ['diagnostic/gameplay_clock.gd',path.join(root,'tools/godot/map_editor_native_clock_candidate/gameplay_clock.gd')],
    ['scripts/map_editor/editor_host_adapter.gd',path.join(root,'tools/godot/map_editor_candidate/scripts/map_editor/editor_host_adapter.gd')],
    ['scripts/map_editor/editor_host_adapter_v2.gd',path.join(root,'tools/godot/map_editor_host_adapter_v2/host_adapter_v2.gd')],
    ['scripts/map_editor/editor_host_adapter_v3.gd',path.join(own,'host_adapter_v3.gd')],
    ['scripts/map_editor/editor_input_router.gd',path.join(root,'tools/godot/map_editor_candidate/scripts/map_editor/editor_input_router.gd')],
    ['scripts/map_editor/editor_input_router_v2.gd',path.join(root,'tools/godot/map_editor_input_router_pause_candidate/router_v2.gd')],
    ['scripts/map_editor/map_document.gd',path.join(root,'tools/godot/map_editor_candidate/scripts/map_editor/map_document.gd')],
    ['diagnostic/probe.gd',path.join(own,'probe.gd')]
  ].map(([rel,p])=>[rel,fs.readFileSync(p)]),
  ['project.godot',Buffer.from(isolatedProject)]
]);
const bytes=files.reduce((v,[,b])=>v+b.length,0);if(bytes>256*1024*1024)throw Error('Bounded stage exceeded');
const out=fs.mkdtempSync(path.join(outputRoot,'actual-main-pause-'));safe(out);
const manifest={schema:1,purpose:'isolated actual native pause candidate; original vs derived; no production/LIVE admission',mainSha256:sha(main[1]),meleeSha256:sha(melee[1]),originalSceneSha256:sha(scene[1]),originalProjectSha256:sha(originalProject),isolatedProjectSha256:sha(Buffer.from(isolatedProject)),projectDifference:'custom user directory name only',headless:true,gpu:false,files:[]};
for(const [rel,b] of files){const dest=path.join(out,rel);if(!dest.startsWith(out+path.sep))throw Error('Escape');fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,b,{flag:'wx'});if(sha(fs.readFileSync(dest))!==sha(b))throw Error('Copy mismatch '+rel);manifest.files.push({path:rel,sha256:sha(b),bytes:b.length,origin:rel.startsWith('diagnostic/')||rel.startsWith('scripts/map_editor/')?'candidate':rel==='project.godot'||rel==='scenes/main.tscn'?'derived':'source'});}
for(const [rel,b] of sourceFiles){if(sha(fs.readFileSync(safe(path.join(source,rel))))!==sha(b))throw Error('Concurrent source drift '+rel);}
fs.writeFileSync(path.join(out,'source_snapshot.json'),JSON.stringify(manifest,null,2),{flag:'wx'});
console.log(JSON.stringify({stage:out,files:files.length,bytes,mainSha256:manifest.mainSha256,originalSceneSha256:manifest.originalSceneSha256,headless:true,gpu:false}));
