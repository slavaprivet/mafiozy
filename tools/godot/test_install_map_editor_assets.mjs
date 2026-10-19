import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,readFile,access,rm} from 'node:fs/promises';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {inspectGlb,installAssets} from './install_map_editor_assets.mjs';
const digest=raw=>createHash('sha256').update(raw).digest('hex');
function glb(json={asset:{version:'2.0'},materials:[{}],meshes:[]}){
 let text=JSON.stringify(json);text+=' '.repeat((4-text.length%4)%4);const raw=Buffer.alloc(20+Buffer.byteLength(text));raw.write('glTF');raw.writeUInt32LE(2,4);raw.writeUInt32LE(raw.length,8);raw.writeUInt32LE(raw.length-20,12);raw.writeUInt32LE(0x4e4f534a,16);raw.write(text,20);return raw;
}
async function fixture(t,values=[glb()]){
 const root=await mkdtemp(join(tmpdir(),'mafiozi-editor-assets-'));
 t.after(async()=>{if(!root.startsWith(join(tmpdir(),'mafiozi-editor-assets-')))throw new Error('Unsafe fixture cleanup');await rm(root,{recursive:true,force:true});});
 await mkdir(join(root,'assets/models'),{recursive:true});const resources=[];
 for(let i=0;i<values.length;i++){await writeFile(join(root,`assets/models/${i}.glb`),values[i]);resources.push({id:digest(values[i]),sha256:digest(values[i]),bytes:values[i].length,sourcePaths:[`assets/models/${i}.glb`]});}
 return {root,catalog:{schema:'mafiozi.godot.map-editor-catalog/v1',resources}};
}
test('dry run is read-only; explicit installation copies byte-identical shared resource',async t=>{
 const options=await fixture(t),receipt=await installAssets(options);assert.equal(receipt.installed,0);assert.equal(receipt.pendingBefore,1);
 await assert.rejects(access(receipt.items[0].target));
 const copied=await installAssets({...options,install:true});assert.equal(copied.installed,1);assert.equal(digest(await readFile(copied.items[0].target)),options.catalog.resources[0].id);
 const repeat=await installAssets({...options,install:true});assert.equal(repeat.installed,0);assert.equal(repeat.presentBefore,1);
});
test('bounded admission creates only requested count without touching unselected assets',async t=>{
 const options=await fixture(t,[glb(),glb({asset:{version:'2.0'},nodes:[{name:'unchanged'}]})]);
 const result=await installAssets({...options,install:true,limit:1});assert.equal(result.installed,1);assert.equal(result.remaining,1);
 await assert.rejects(access(result.items.find(v=>v.status==='pending-stage').target));
});
test('mismatched preexisting target is never overwritten',async t=>{
 const options=await fixture(t),check=await installAssets(options),target=check.items[0].target;
 await mkdir(join(options.root,'outputs/map_editor_asset_stage'),{recursive:true});await writeFile(target,'user-content');
 await assert.rejects(installAssets({...options,install:true}),/Refusing to overwrite/);
 assert.equal(await readFile(target,'utf8'),'user-content');
});
test('all sources are verified before any copy; missing/tampered paths abort',async t=>{
 const options=await fixture(t,[glb(),glb({asset:{version:'2.0'},nodes:[{}]})]);await writeFile(join(options.root,'assets/models/1.glb'),'tampered');
 await assert.rejects(installAssets({...options,install:true}),/SHA\/size changed/);
 await assert.rejects(access(join(options.root,'outputs/map_editor_asset_stage')));
 await writeFile(join(options.root,'assets/models/1.glb'),glb({asset:{version:'2.0'},nodes:[{}]}));
 options.catalog.resources[0].sourcePaths=['assets/../../private.glb'];
 await assert.rejects(installAssets(options),/outside assets/);
});
test('external texture or buffer is rejected rather than silently stripped',async t=>{
 const options=await fixture(t,[glb({asset:{version:'2.0'},images:[{uri:'missing.png'}]})]);
 await assert.rejects(installAssets({...options,install:true}),/External GLB dependencies/);
 assert.throws(()=>inspectGlb(Buffer.alloc(24)),/Invalid/);
 assert.throws(()=>inspectGlb(glb({asset:{version:'2.0'},buffers:[{uri:'mesh.bin'}]})),/External/);
});
