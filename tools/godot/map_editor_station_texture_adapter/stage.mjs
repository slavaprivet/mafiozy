/** Isolated CPU texture candidate. --check default; --stage only into outputs. */
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const sha=b=>createHash('sha256').update(b).digest('hex');
const sourceSha='69ecbd14108fd151b504a41dc3d00ab5dbeca98b8c5ccd6251553fb60189546b';
let stage=false,target=path.join(root,'outputs/map_editor_station_texture_adapter');
for(let i=2;i<process.argv.length;i++){
 const arg=process.argv[i];if(arg==='--check')stage=false;else if(arg==='--stage')stage=true;
 else if(arg==='--target')target=path.resolve(process.argv[++i]);else throw Error(`Unknown argument ${arg}`);
}
assert(target.startsWith(path.join(root,'outputs')+path.sep),'Output-only staging required');
function noLinks(p){while(p!==root){if(fs.existsSync(p))assert(!fs.lstatSync(p).isSymbolicLink(),'Symlink refused');p=path.dirname(p);}}
noLinks(target);
const manifestRaw=fs.readFileSync(path.join(root,'outputs/map_editor_transport_decor_source/manifest.json'));assert.equal(sha(manifestRaw),sourceSha);
const manifest=JSON.parse(manifestRaw),captureDir=path.join(root,'outputs/map_editor_station_canvas_capture');
const raw=fs.readFileSync(path.join(captureDir,'receipt.json')),capture=JSON.parse(raw);
assert.equal(sha(raw),'8324eabf33a71a9133137491a3bab766e04d3bb10cc4fee7ca58e9602a994fcf','Exact approved Chrome capture receipt changed');
assert.equal(capture.source_manifest_sha256,sourceSha);assert.equal(capture.captures.length,2);
assert.equal(capture.gpuFeatureStatus['2d_canvas'],'disabled_software');assert.equal(capture.userProfileUsed,false);
assert.equal(capture.sourceGenerator.sha256,sha(fs.readFileSync(path.join(root,capture.sourceGenerator.path))));
const files=[['manifest.json',manifestRaw],['captures/receipt.json',raw]];
for(const row of capture.captures){
 assert(/^texture-[01]$/.test(row.texture_id));assert.equal(row.rgba_file,row.texture_id+'.rgba');assert.equal(row.png_file,row.texture_id+'.png');
 assert.deepEqual(row.sourceTexture,manifest.textures.find(t=>t.id===row.texture_id));
 for(const [file,expected] of [[row.rgba_file,row.rgba_sha256],[row.png_file,row.png_sha256]]){
  const p=path.join(captureDir,file);noLinks(p);const bytes=fs.readFileSync(p);assert.equal(sha(bytes),expected);files.push(['captures/'+file,bytes]);
 }
}
const expectedCode={
 'station_texture_adapter.gd':'7adb5ce878ab7ead5f78bfff79d50218e5812063ce734218010b54aaf76ead19',
 'test_station_texture_adapter.gd':'15ccc3c326503e2f557eecd27c36cd7ef37f20985a53398c7f790a0be179c822',
 'project.godot':'636f51a6e99246614c8f37844f3002b20c5f9446bd74b6fe44a0eb7239e0dee7'
};
for(const [file,expected] of Object.entries(expectedCode)){const p=path.join(here,file);noLinks(p);const bytes=fs.readFileSync(p);assert.equal(sha(bytes),expected,'Frozen adapter candidate changed');files.push([file,bytes]);}
for(const file of ['HANDOFF.md','receipt.json'])files.push([file,fs.readFileSync(path.join(here,file))]);
for(const [file,bytes] of files){const p=path.join(target,file);noLinks(p);if(fs.existsSync(p))assert.equal(sha(fs.readFileSync(p)),sha(bytes),`Refuse changed target overwrite ${file}`);}
if(stage)for(const [file,bytes] of files){const p=path.join(target,file);fs.mkdirSync(path.dirname(p),{recursive:true});if(!fs.existsSync(p))fs.writeFileSync(p,bytes,{flag:'wx'});}
console.log(JSON.stringify({mode:stage?'staged':'checked-read-only',sourceSha,captureReceiptSha256:sha(raw),target,files:files.length,gpuChecked:false,gates:['original GPU mipmap bytes/minification/sRGB sampler parity','real gameplay owner and production integration']}));
