import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const root=fs.realpathSync(process.cwd());
const source=path.join(root,'godot/mafiozi_walk');
const own=path.join(root,'tools/godot/map_editor_native_clock_candidate');
const outputRoot=path.join(root,'outputs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function safe(p){let q=p;while(q!==path.dirname(q)){if(fs.lstatSync(q).isSymbolicLink())throw Error('Symlink refused '+q);q=path.dirname(q);}return p;}
for(const p of [source,own,outputRoot])safe(p);
const sourceFiles=[];
function collect(dir){for(const d of fs.readdirSync(dir,{withFileTypes:true})){const p=safe(path.join(dir,d.name));if(d.isDirectory()){if(!['tests','.godot'].includes(d.name))collect(p);}else if(d.isFile()&&!d.name.endsWith('.uid')){sourceFiles.push([path.relative(source,p).split(path.sep).join('/'),fs.readFileSync(p)]);}}}
for(const d of ['scripts','scenes','data','assets'])collect(path.join(source,d));
const main=sourceFiles.find(([p])=>p==='scripts/main.gd');
if(!main||sha(main[1])!=='653837bb2365c92f9e290e1f8c5126bf6fbb5357da8db3570cdb6f1bec9f6d50')throw Error('Actual main source pin changed');
const meleeHost=sourceFiles.find(([p])=>p==='scripts/combat/preview_melee.gd');
if(!meleeHost||sha(meleeHost[1])!=='5098c2a1c98757446fa71bcb23117f3dfacc9b121d4c66d226ad572a6d64e5dc')throw Error('Inherited melee host seam changed');
const originalProject=fs.readFileSync(path.join(source,'project.godot'));
const scene=sourceFiles.find(([p])=>p==='scenes/main.tscn');
if(!scene||!scene[1].toString().includes('path="res://scripts/main.gd"'))throw Error('Scene seam changed');
const diagnostic=[
  ['scenes/main.tscn',Buffer.from(scene[1].toString().replace('path="res://scripts/main.gd"','path="res://diagnostic/clocked_main.gd"'))],
  ...['gameplay_clock.gd','clocked_melee.gd','clocked_main.gd','probe.gd'].map(n=>['diagnostic/'+n,fs.readFileSync(path.join(own,n))]),
  ['project.godot',Buffer.from('config_version=5\n[application]\nconfig/name="Actual Native Clock CPU Diagnostic"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="MafioziNativeClock-'+crypto.randomUUID()+'"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')]
];
const copies=sourceFiles.filter(([p])=>p!=='scenes/main.tscn').concat(diagnostic);
const bytes=copies.reduce((v,[,b])=>v+b.length,0);
if(bytes>256*1024*1024)throw Error('Bounded stage exceeded');
const out=fs.mkdtempSync(path.join(outputRoot,'actual-native-clock-'));safe(out);
const manifest={schema:1,purpose:'isolated actual-main diagnostic, no production admission',mainSha256:sha(main[1]),meleeHostSha256:sha(meleeHost[1]),originalProjectSha256:sha(originalProject),originalSceneSha256:sha(scene[1]),headless:true,gpu:false,files:[]};
for(const [rel,b] of copies){const dest=path.join(out,rel);if(!dest.startsWith(out+path.sep))throw Error('Escape');fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,b,{flag:'wx'});if(sha(fs.readFileSync(dest))!==sha(b))throw Error('Copy mismatch '+rel);manifest.files.push({path:rel,sha256:sha(b),bytes:b.length,origin:rel.startsWith('diagnostic/')?'candidate':rel==='project.godot'||rel==='scenes/main.tscn'?'derived':'source'});}
for(const [rel,b] of sourceFiles){if(sha(fs.readFileSync(safe(path.join(source,rel))))!==sha(b))throw Error('Concurrent source drift '+rel);}
fs.writeFileSync(path.join(out,'source_snapshot.json'),JSON.stringify(manifest,null,2),{flag:'wx'});
console.log(JSON.stringify({stage:out,files:copies.length,bytes,mainSha256:manifest.mainSha256,originalSceneSha256:manifest.originalSceneSha256,importRequired:true,gpu:false}));
