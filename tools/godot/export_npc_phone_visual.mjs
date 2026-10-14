#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'),out=path.join(repo,'outputs/astra21_npc_phone_mesh'),file=path.join(repo,'godot/mafiozi_walk/data/npc_phone_geometry.json');
const hash=b=>createHash('sha256').update(b).digest('hex');
const sourcePath='assets/maps/city_rebuild_v1/npc_phone_visual.mjs',sourceBytes=fs.readFileSync(path.join(repo,sourcePath));
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',threePath=path.join(vendor,'build/three.module.js'),corePath=path.join(vendor,'build/three.core.js');
const THREE=await import(pathToFileURL(threePath));assert.equal(THREE.REVISION,'180');
const {createNpcPhoneVisualPool}=await import(pathToFileURL(path.join(repo,sourcePath)));
function capture(){
 const pool=createNpcPhoneVisualPool({THREE}),a=pool.acquire(),b=pool.acquire();
 assert.notEqual(a,b);assert.equal(a.geometry,b.geometry);assert.equal(a.material,b.material);
 assert.equal(a.geometry.index,null);assert.equal(a.geometry.attributes.position.itemSize,3);assert.equal(a.geometry.attributes.color.itemSize,3);
 const positions=a.geometry.attributes.position.array,colors=a.geometry.attributes.color.array;assert(positions instanceof Float32Array&&colors instanceof Float32Array);assert.equal(positions.length,990);assert.equal(colors.length,990);
 const copy=p=>Buffer.from(new Uint8Array(p.buffer,p.byteOffset,p.byteLength));
 const p=copy(positions),c=copy(colors),result={schema:'mafiozi.npc-phone-geometry/v1',source:{path:sourcePath,sha256:hash(sourceBytes),three_revision:'180',default_color_hex:'171a1e',entrypoint:'createNpcPhoneVisualPool({THREE}).acquire()',geometry_indexed:false},geometry:{primitive:'TRIANGLES',vertex_count:330,triangle_count:110,source_winding:'CCW',native_corner_order:[0,2,1],component_type:'FLOAT32_LE',positions_base64:p.toString('base64'),positions_sha256:hash(p),linear_rgb_base64:c.toString('base64'),linear_rgb_sha256:hash(c),bounds:{min:a.geometry.boundingBox.min.toArray(),max:a.geometry.boundingBox.max.toArray()}},source_material:{type:a.material.type,color_linear:a.material.color.toArray(),vertex_colors:a.material.vertexColors,tone_mapped:a.material.toneMapped,transparent:a.material.transparent,opacity:a.material.opacity,side:a.material.side},native_contract:{visual_only:true,opaque:true,unshaded:true,vertex_color_is_srgb:false,cast_shadow:false,collision:false,light:false,shared_resources:true,private_nodes:true,material_fidelity:'HOLD_RGBA8_AND_TONEMAPPER',pose_applied:false,call_authority:false},limits:['Exact original source Float32 geometry/linear RGB; native triangle winding reorder only','Native ARRAY_COLOR storage RGBA8/toneMapper output fidelity HOLD','No behavior/HP/police authority, automatic pose or GPU/fullscene claims']};
 assert(pool.release(a));assert(!pool.release(a));pool.dispose();return result;
}
const data=capture();assert.deepEqual(capture(),data);assert.equal(hash(fs.readFileSync(path.join(repo,sourcePath))),hash(sourceBytes),'Source changed during capture');
const bytes=Buffer.from(JSON.stringify(data,null,2)+'\n'),check=process.argv.includes('--check');
if(check)assert(fs.readFileSync(file).equals(bytes),'Exact phone package bytes differ');else{fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);}
const receipt={schema:'mafiozi.npc-phone-export-receipt/v1',status:'PASS_SOURCE_GEOMETRY_ONLY',check,package_path:'godot/mafiozi_walk/data/npc_phone_geometry.json',package_sha256:hash(bytes),package_bytes:bytes.length,source_sha256:hash(sourceBytes),exporter_sha256:hash(fs.readFileSync(fileURLToPath(import.meta.url))),three:[threePath,corePath].map(p=>({path:p,sha256:hash(fs.readFileSync(p))})),source_vertices:330,source_triangles:110,source_attribute_bytes:7920,independent_captures:2,limits:data.limits};
fs.mkdirSync(out,{recursive:true});if(!check)fs.writeFileSync(path.join(out,'EXPORT_RECEIPT.json'),JSON.stringify(receipt,null,2)+'\n');console.log(JSON.stringify(receipt));
