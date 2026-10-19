#!/usr/bin/env node
// Offline capture of the original factory. No weapon gameplay or model redesign.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath, pathToFileURL} from 'node:url';
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
let output = path.join(repo, 'outputs/coordinator22_weapon_visual/source');
for (let i=2; i<process.argv.length; i++) {
  if (process.argv[i]==='--output' && process.argv[i+1]) output=path.resolve(process.argv[++i]);
  else throw Error('Unknown/incomplete argument: '+process.argv[i]);
}
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const THREE=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
assert.equal(THREE.REVISION,'180');
const sourcePath='assets/maps/city_rebuild_v1/hero_arsenal.mjs';
const {ARSENAL,createWeaponModel}=await import(pathToFileURL(path.join(repo,sourcePath)));
const {sampleReloadPresentation}=await import(pathToFileURL(path.join(repo,'assets/maps/city_rebuild_v1/hero_motion_presentation.mjs')));
const hash=data=>createHash('sha256').update(data).digest('hex');
const normalizedHash=file=>hash(fs.readFileSync(file,'utf8').replaceAll('\r\n','\n'));
const ids=['none','nagan','tt_pistol','revolver','deagle','golden_colt','sawn_off','shotgun','uzi','golden_uzi','ak74','m16','tommy_gun','sniper','rpg'];
assert.deepEqual(ARSENAL.map(row=>row.id),ids);
fs.mkdirSync(output,{recursive:true});
const dependencies=[sourcePath,'assets/maps/city_rebuild_v1/hero_walk.mjs','assets/maps/city_rebuild_v1/hero_motion_presentation.mjs','assets/maps/city_rebuild_v1/weapon_effects.mjs'];
const sourceHashes=dependencies.map(file=>({path:file,sha256:normalizedHash(path.join(repo,file))}));
function capture(spec) {
  const root=createWeaponModel({THREE,id:spec.id}); root.updateMatrixWorld(true);
  const materials=[],materialKeys=new Map(),batches=[],staticByMaterial=new Map(),parts=[],oracleParts=[];
  const materialKey=m=>{
    assert(m.isMeshStandardMaterial && !Array.isArray(m));
    assert.equal(m.onBeforeCompile,THREE.Material.prototype.onBeforeCompile);
    for(const value of Object.values(m)) assert(!value?.isTexture,'Texture needs explicit transfer');
    assert.equal(m.side,THREE.FrontSide);assert(m.depthWrite && m.depthTest);
    assert(!m.vertexColors && !m.flatShading);assert.deepEqual(m.emissive.toArray(),[0,0,0]);
    const state={color_linear:m.color.toArray(),metallic:m.metalness,roughness:m.roughness,
      opacity:m.opacity,transparent:m.transparent,depth_write:m.depthWrite,depth_test:m.depthTest,
      side:m.side,flat_shading:m.flatShading,vertex_colors:m.vertexColors,
      emissive_linear:m.emissive.toArray(),emissive_intensity:m.emissiveIntensity};
    const signature=JSON.stringify(state);
    if(!materialKeys.has(signature)){materialKeys.set(signature,materials.length);materials.push(state);}
    return materialKeys.get(signature);
  };
  root.traverse(node=>{
    if(!node.isMesh)return;
    assert.equal(node.parent,root,'Factory hierarchy changed: review transform capture');
    assert(node.visible && node.castShadow && node.receiveShadow);
    assert(!node.isSkinnedMesh && !node.isInstancedMesh);
    const geometry=node.geometry, mat=materialKey(node.material);
    assert.equal(geometry.drawRange.start,0); assert.equal(geometry.drawRange.count,Infinity);
    assert.deepEqual(Object.keys(geometry.attributes).sort(),['normal','position','uv']);
    const slot=/^(magazine|drum_magazine)$/.test(node.name)?'magazine':node.name==='slide'?'slide':null;
    let batch=slot?null:staticByMaterial.get(mat);
    if(!batch){batch={key:'b'+String(batches.length).padStart(3,'0'),slot,material:mat,
      local_matrix:slot?node.matrix.toArray():new THREE.Matrix4().toArray(),positions:[],normals:[],uvs:[],indices:[]};
      batches.push(batch); if(!slot)staticByMaterial.set(mat,batch);}
    const position=geometry.attributes.position, normal=geometry.attributes.normal, uv=geometry.attributes.uv;
    const offset=batch.positions.length/3,indexStart=batch.indices.length;
    const p=new THREE.Vector3(), n=new THREE.Vector3(), normalMatrix=new THREE.Matrix3().getNormalMatrix(node.matrix);
    for(let i=0;i<position.count;i++){
      p.fromBufferAttribute(position,i);n.fromBufferAttribute(normal,i);
      if(!slot){p.applyMatrix4(node.matrix);n.applyNormalMatrix(normalMatrix);}
      batch.positions.push(...p.toArray().map(Math.fround));batch.normals.push(...n.toArray().map(Math.fround));
      batch.uvs.push(uv.getX(i),uv.getY(i));
    }
    const indices=geometry.index?Array.from(geometry.index.array):Array.from({length:position.count},(_,i)=>i);
    assert.equal(indices.length%3,0);
    // Godot front faces are clockwise. Preserve every source triangle, reverse corners only.
    for(let i=0;i<indices.length;i+=3)batch.indices.push(offset+indices[i],offset+indices[i+2],offset+indices[i+1]);
    const part={key:'p'+String(parts.length).padStart(3,'0'),name:node.name,local_matrix:node.matrix.toArray(),
      batch:batch.key,material:mat,slot,vertex_start:offset,vertex_count:position.count,index_start:indexStart,index_count:indices.length};
    parts.push(part);
    oracleParts.push({...part,positions:Array.from(position.array),normals:Array.from(normal.array),uvs:Array.from(uv.array),indices});
  });
  // Merging separately sorted transparent parts would change blending order.
  for(const batch of batches)if(materials[batch.material].transparent)
    assert.equal(parts.filter(part=>part.batch===batch.key).length,1,'Transparent batching needs explicit sorting review');
  const chunks=[];let byteOffset=0;
  const append=(values,type)=>{const array=type==='int32'?new Int32Array(values):new Float32Array(values);const bytes=Buffer.from(array.buffer);
    const record={offset:byteOffset,count:values.length,bytes:bytes.length,type};chunks.push(bytes);byteOffset+=bytes.length;return record;};
  const batchRows=batches.map(batch=>({key:batch.key,slot:batch.slot,material:batch.material,local_matrix:batch.local_matrix,
    positions:append(batch.positions,'float32'),normals:append(batch.normals,'float32'),uvs:append(batch.uvs,'float32'),indices:append(batch.indices,'int32')}));
  const bytes=Buffer.concat(chunks),metadata=structuredClone(root.userData);
  const sourceBounds=new THREE.Box3().setFromObject(root);
  const entry={id:spec.id,label:spec.label,family:spec.family,two_handed:spec.twoHanded,source_metadata:metadata,
    primary_hand_grip:[0,-.13,-.02],reload_hand_target:[-.08,-.34,.12],
    source_forward:'+Z',units:'unscaled_original_hero_rig',source_meshes:parts.length,
    triangles:parts.reduce((n,p)=>n+p.index_count/3,0),native_draw_surfaces:batches.length,
    materials,batches:batchRows,parts,
    bounds:parts.length?{min:sourceBounds.min.toArray(),max:sourceBounds.max.toArray()}:null,
    buffer_file:spec.id+'.bytes',buffer_sha256:hash(bytes),buffer_bytes:bytes.length};
  for(const child of root.children){child.geometry?.dispose();}
  const oracle={id:spec.id,parts:oracleParts,materials,metadata};
  return {entry,bytes,oracle};
}
const entries=[];
for(const spec of ARSENAL){
  const a=capture(spec), b=capture(spec);
  assert.deepEqual(a.entry,b.entry);assert(a.bytes.equals(b.bytes));assert.deepEqual(a.oracle,b.oracle);
  fs.writeFileSync(path.join(output,a.entry.buffer_file),a.bytes);
  fs.writeFileSync(path.join(output,spec.id+'.oracle.json'),JSON.stringify(a.oracle));
  entries.push(a.entry);
  console.log(JSON.stringify({id:spec.id,source_meshes:a.entry.source_meshes,native_surfaces:a.entry.native_draw_surfaces,triangles:a.entry.triangles,bytes:a.bytes.length}));
}
for(const row of sourceHashes)assert.equal(normalizedHash(path.join(repo,row.path)),row.sha256,'Source changed during export');
const reloadSamples=[-1,0,.1,.2,.3,.4,.5,.6,.7,.78,.79,.81,.83,.85,.87,.89,.96,1,2].map(progress=>({input:progress,...sampleReloadPresentation(progress)}));
const manifest={schema:'mafiozi.weapon-source/v1',three_revision:THREE.REVISION,source_hash_normalization:'crlf_to_lf',source_inputs:sourceHashes,
  basis:'identity: preserve source +Z under existing hero basis/scale',entries,reload_samples:reloadSamples,
  limits:['Visual asset package only; owner/admission/ammo/HP unchanged','Shader values preserved; final GPU lighting/tone-mapping requires root render review','Host owns body/hand IK and weapon world pose; no automatic hand pose']};
fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({status:'PASS_TWO_INDEPENDENT_CAPTURES',weapons:entries.length-1,source_meshes:entries.reduce((n,e)=>n+e.source_meshes,0),native_surfaces:entries.reduce((n,e)=>n+e.native_draw_surfaces,0),manifest_sha256:hash(fs.readFileSync(path.join(output,'manifest.json')))}));
