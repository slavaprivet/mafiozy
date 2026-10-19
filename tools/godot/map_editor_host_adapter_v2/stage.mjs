import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
function read(p){if(fs.lstatSync(p).isSymbolicLink()||fs.realpathSync(p)!==p)throw Error('Linked source refused');return fs.readFileSync(p);}
const source=path.join(root,'tools/godot/map_editor_candidate');
const original=read(path.join(source,'scripts/map_editor/editor_host_adapter.gd'));
if(hash(original)!=='1147d035070488da5b01e558faeee41fde40fc18b0ef86ab1d4a3f5385a3f360')throw Error('Original adapter pin changed');
const files=new Map([
 ['scripts/map_editor/editor_host_adapter.gd',original],
 ['scripts/map_editor/map_document.gd',read(path.join(source,'scripts/map_editor/map_document.gd'))],
 ['host_adapter_v2.gd',read(path.join(own,'host_adapter_v2.gd'))],
 ['test_host_v2.gd',read(path.join(own,'test_host_v2.gd'))],
 ['project.godot',Buffer.from('config_version=5\n[application]\nconfig/name="Editor host V2 boundary fixtures"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')]
]);
const baseline=read(path.join(source,'tests/map_editor/test_editor_host_adapter.gd')).toString();
const needle='const Host = preload("res://scripts/map_editor/editor_host_adapter.gd")';
if(!baseline.includes(needle))throw Error('Baseline test changed');
files.set('test_original_contract_v2.gd',Buffer.from(baseline.replace(needle,'const Host = preload("res://host_adapter_v2.gd")')));
// Retain the independent counterexample logic, change only its terminal
// expectation from "hole reproduced" to exact "hole absent" after repair.
const independent=read(path.join(root,'tools/godot/map_editor_host_adapter_v2_review2/test_negative.gd'));
if(hash(independent)!=='a6330557cf6c59771edb825d952f64be4360d358a0f06772aa368773ec825259')throw Error('Independent counterexample source changed');
const oldExit='quit(0 if not old_reproduced and new_hole_reproduced else 1)';
if(!independent.toString().includes(oldExit))throw Error('Independent negative expectation changed');
files.set('test_independent_fixed_v2.gd',Buffer.from(independent.toString().replace(oldExit,'quit(0 if not old_reproduced and not new_hole_reproduced and input_case.queued and input_case.forwarded == 1 and input_case.consumed and input_case.leased and input_case.blocked else 1)')));
const outputRoot=path.join(root,'outputs');
if(fs.lstatSync(outputRoot).isSymbolicLink()||fs.realpathSync(outputRoot)!==outputRoot)throw Error('Linked output root');
const output=fs.mkdtempSync(path.join(outputRoot,'editor-host-v2-'));
const receipts=[];
for(const[name,bytes]of files){const p=path.join(output,...name.split('/'));fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,bytes,{flag:'wx'});if(hash(fs.readFileSync(p))!==hash(bytes))throw Error('Copy mismatch');receipts.push({path:name,bytes:bytes.length,sha256:hash(bytes)});}
fs.writeFileSync(path.join(output,'source_receipt.json'),JSON.stringify({schema:1,files:receipts,fixtureOnly:true,actualMainAdmission:false,productionInstalled:false,gpu:false},null,2),{flag:'wx'});
console.log(JSON.stringify({output,files:files.size,fixtureOnly:true,productionInstalled:false}));
