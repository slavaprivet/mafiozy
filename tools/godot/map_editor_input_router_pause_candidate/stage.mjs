import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
function read(p){if(fs.lstatSync(p).isSymbolicLink()||fs.realpathSync(p)!==p)throw Error('Linked source refused');return fs.readFileSync(p);}
const original=read(path.join(root,'tools/godot/map_editor_candidate/scripts/map_editor/editor_input_router.gd'));
const files=new Map([
 ['scripts/map_editor/editor_input_router.gd',original],
 ['router_v2.gd',read(path.join(own,'router_v2.gd'))],
 ['test_router_pause.gd',read(path.join(own,'test_router_pause.gd'))],
 ['test_original_pause_negative.gd',read(path.join(own,'test_original_pause_negative.gd'))],
 ['project.godot',Buffer.from('config_version=5\n[application]\nconfig/name="Editor K pause route boundary"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')]
]);
const outroot=path.join(root,'outputs');
if(fs.lstatSync(outroot).isSymbolicLink()||fs.realpathSync(outroot)!==outroot)throw Error('Linked output root');
const out=fs.mkdtempSync(path.join(outroot,'editor-router-pause-'));
const receipts=[];
for(const[name,bytes]of files){const p=path.join(out,...name.split('/'));fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,bytes,{flag:'wx'});if(hash(fs.readFileSync(p))!==hash(bytes))throw Error('Copy mismatch');receipts.push({name,bytes:bytes.length,sha256:hash(bytes)});}
fs.writeFileSync(path.join(out,'source_receipt.json'),JSON.stringify({schema:1,files:receipts,fixtureOnly:true,actualMainLease:false,productionInstalled:false,gpu:false},null,2),{flag:'wx'});
console.log(JSON.stringify({output:out,files:files.size,originalSha256:hash(original),fixtureOnly:true}));
