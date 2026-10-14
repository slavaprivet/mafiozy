import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
const dir=path.dirname(fileURLToPath(import.meta.url));
const repo=path.resolve(dir,'../../..');
const fixturePath=path.join(repo,'godot/mafiozi_walk/data/transport/vehicle_deformation_oracle.json');
const bytes=fs.readFileSync(fixturePath);
const sha=b=>createHash('sha256').update(b).digest('hex');
assert.equal(sha(bytes),'ccd5b46084439ca3aaa12c7d23b94cfdc9b979bd81eed0edd80ac7a9fc7f69e7');
const f=JSON.parse(bytes);
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
const T=await import('three');
assert.equal(T.REVISION,'180');
const crashPath=path.join(repo,f.source.vehicle_crash.path);
assert.equal(sha(fs.readFileSync(crashPath)),f.source.vehicle_crash.sha256);
assert.equal(sha(fs.readFileSync(path.join(repo,f.source.vehicle_crash_mechanics.path))),f.source.vehicle_crash_mechanics.sha256);
const {subdivideVehicleGeometry}=await import(pathToFileURL(crashPath));
const original=new T.BufferGeometry();
for(const [name,a] of Object.entries(f.input.attributes)) original.setAttribute(name,new T.Float32BufferAttribute(a.values,a.item_size));
original.setIndex(f.input.indices);
for(const g of f.input.groups)original.addGroup(g.start,g.count,g.material_index);
const rest=subdivideVehicleGeometry(T,original,.15,9000);
const base=Array.from(rest.attributes.position.array);
assert.equal(base.length,f.expected.attributes.position.values.length);
const m=f.input.mesh_transform;
const sourceFrame=new T.Matrix4().compose(new T.Vector3(...m.position),new T.Quaternion(...m.quaternion),new T.Vector3(...m.scale));
const nativeFrame=new T.Matrix4().makeRotationY(Math.PI).multiply(sourceFrame);
const inverse=new T.Matrix3().setFromMatrix4(nativeFrame).invert().elements;
const grid=[[-f.profile.halfWidth,0,f.profile.halfWidth],[.28,f.profile.height*.46,f.profile.height*.91],[-f.profile.halfLength,-f.profile.halfLength*.5,0,f.profile.halfLength*.5,f.profile.halfLength]];
function interval(g,v){if(v<=g[0])return 0;if(v>=g.at(-1))return g.length-2;for(let i=0;i<g.length-1;i++)if(v<=g[i+1])return i;throw Error('grid');}
const vertexBinding=[],indices=[],weights=[],unique=new Map();
for(let j=0;j<base.length;j+=3){
  const key=base.slice(j,j+3).join(',');
  if(!unique.has(key)){
    unique.set(key,unique.size);
    // Source bind stores car-local coordinates into Float32 before fractions.
    const p=new T.Vector3(...base.slice(j,j+3)).applyMatrix4(sourceFrame);
    const values=[p.x,p.y,p.z].map(Math.fround);
    const cells=values.map((v,i)=>interval(grid[i],v));
    const blends=values.map((v,i)=>{const g=grid[i],k=cells[i];return (Math.max(g[0],Math.min(g.at(-1),v))-g[k])/(g[k+1]-g[k]);});
    for(let z=0;z<2;z++)for(let y=0;y<2;y++)for(let x=0;x<2;x++){
      indices.push(((cells[2]+z)*3+cells[1]+y)*3+cells[0]+x);
      weights.push((x?blends[0]:1-blends[0])*(y?blends[1]:1-blends[1])*(z?blends[2]:1-blends[2]));
    }
  }
  vertexBinding.push(unique.get(key));
}
const offsets=f.snapshot.positions_native.flatMap((v,i)=>v.map((n,k)=>Math.fround(Math.fround(n)-Math.fround(f.snapshot.rest_native[i][k]))));
// Executable JS reference for the proposed Float32 buffer contract, NOT C++ proof.
const local=[];
for(let b=0;b<unique.size;b++){
  const d=[0,0,0];for(let c=0;c<8;c++)for(let k=0;k<3;k++)d[k]+=offsets[indices[b*8+c]*3+k]*weights[b*8+c];
  local.push(...[0,1,2].map(k=>Math.fround(inverse[k]*d[0]+inverse[k+3]*d[1]+inverse[k+6]*d[2])));
}
const predicted=base.map((v,i)=>Math.fround(v+local[vertexBinding[Math.floor(i/3)]*3+i%3]));
let maxPositionError=0;
for(let i=0;i<predicted.length;i++)maxPositionError=Math.max(maxPositionError,Math.abs(predicted[i]-f.expected.attributes.position.values[i]));
assert.ok(maxPositionError<=3e-6,`position error ${maxPositionError}`);
const predictedMesh=new T.BufferGeometry();predictedMesh.setAttribute('position',new T.Float32BufferAttribute(predicted,3));predictedMesh.computeVertexNormals();
let maxNormalError=0;
for(let i=0;i<predictedMesh.attributes.normal.array.length;i++)maxNormalError=Math.max(maxNormalError,Math.abs(predictedMesh.attributes.normal.array[i]-f.expected.attributes.normal.values[i]));
assert.ok(maxNormalError<=5e-5,`normal error ${maxNormalError}`);
const numeric=(v,type)=>{assert.ok(Number.isFinite(v));let s=String(v);if(type==='float'&&!/[.eE]/.test(s))s+='.0';return s+(type==='float'?'f':'');};
const array=(name,type,values)=>`inline constexpr std::array<${type}, ${values.length}> ${name} = {\n${values.map(v=>numeric(v,type)).join(',')}\n};\n`;
let header='#pragma once\n#include <array>\n#include <cstdint>\nnamespace mafiozi::transport::fixture {\n';
header+=`inline constexpr const char* source_sha = "${f.source.vehicle_crash.sha256}";\n`;
for(const [name,type,values] of [['base','float',base],['bindings','std::uint32_t',vertexBinding],['nodes','std::uint8_t',indices],['weights','double',weights],['offsets','float',offsets],['inverse','double',inverse],['expected_positions','float',f.expected.attributes.position.values],['expected_normals','float',f.expected.attributes.normal.values]])header+=array(name,type,values);
header+='}\n';
fs.writeFileSync(path.join(dir,'kernel_fixture_data.h'),header);
console.log(JSON.stringify({status:'JS_FIXTURE_PASS_CPP_NOT_COMPILED',vertices:base.length/3,bindings:unique.size,maxPositionError,maxNormalError,header_sha256:sha(Buffer.from(header))}));
rest.dispose();original.dispose();predictedMesh.dispose();
