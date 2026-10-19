// Actual GLB cut-cap geometry only. No prototype/runtime edit or GPU.
import fs from 'node:fs';import assert from 'node:assert/strict';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';
import {clone} from './test_npc_death_offline_setup.mjs';import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {prepareNpcGarmentCutCaps20,createNpcGarmentCapGeometry20} from './npc_garment_cut_cap20.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const regionOf=name=>/head|neck/.test(name)?1:/upperarm_l|forearm_l|hand_l|clavicle_l/.test(name)?2:/upperarm_r|forearm_r|hand_r|clavicle_r/.test(name)?3:/thigh_l|shin_l|foot_l/.test(name)?4:/thigh_r|shin_r|foot_r/.test(name)?5:0;
const reports=[];
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,scene=new THREE.Scene(),actor=createNpcActor({THREE,scene,source,cloneSkeleton:clone,id:sex,sex,height:1.9});actor.update(0,{time:10,position:{x:3,y:0,z:-2},yaw:.7});
 let mesh;actor.walker.artistContext().scene.traverse(m=>{if(m.isSkinnedMesh&&/core_FABRIC/i.test(m.name))mesh=m;});assert(mesh);mesh.updateWorldMatrix(true,false);mesh.skeleton.update();
 const g=mesh.geometry,oldMaterial=mesh.material,before={index:g.index.array.slice(),attributes:Object.fromEntries(Object.entries(g.attributes).map(([key,attr])=>[key,attr.array.slice()]))},positions=new Float32Array(g.attributes.position.count*3),indices=g.index.array.slice(),triangleRegions=new Uint8Array(indices.length/3),p=new THREE.Vector3(),labels=mesh.skeleton.bones.map(b=>regionOf(b.name)),scores=new Float64Array(6);
 for(let i=0;i<g.attributes.position.count;i++){mesh.getVertexPosition(i,p).applyMatrix4(mesh.matrixWorld);p.toArray(positions,i*3);}for(let i=0;i<indices.length;i+=3){scores.fill(0);for(let j=0;j<3;j++)for(let k=0;k<4;k++)scores[labels[g.attributes.skinIndex.getComponent(indices[i+j],k)]??0]+=g.attributes.skinWeight.getComponent(indices[i+j],k);let best=0;for(let r=1;r<6;r++)if(scores[r]>scores[best])best=r;triangleRegions[i/3]=best;}
 const input={positions,indices,triangleRegions};
 for(const targetRegion of [2,3,0]){
  const at=performance.now(),result=prepareNpcGarmentCutCaps20({...input,targetRegion}),ms=performance.now()-at;
  for(const cap of result.caps){assert.equal(cap.indices.length/3,cap.sourceVertexIds.length-2);assert([...cap.positions,...cap.uv].every(Number.isFinite));for(let i=0;i<cap.sourceVertexIds.length;i++)assert.deepEqual(cap.positions.slice(i*3,i*3+3),positions.slice(cap.sourceVertexIds[i]*3,cap.sourceVertexIds[i]*3+3),'cap retains exact nonplanar boundary positions');const geometry=createNpcGarmentCapGeometry20(THREE,cap);assert([...geometry.attributes.normal.array].every(Number.isFinite));geometry.dispose();}
  reports.push({sex,targetRegion,status:result.status,prepareMs:ms,naturalBoundaryEdges:result.naturalBoundaryEdges,introducedBoundaryEdges:result.introducedBoundaryEdges,maxWeldResidual:result.maxWeldResidual,caps:result.caps.map(c=>({vertices:c.sourceVertexIds.length,triangles:c.triangles,maxPlaneDeviation:c.maxPlaneDeviation,projectedArea:c.projectedArea})),unknown:result.unknown});
 }
 assert.equal(mesh.material,oldMaterial);assert.deepEqual(g.index.array,before.index);for(const [key,attr]of Object.entries(g.attributes))assert.deepEqual(attr.array,before.attributes[key],`existing ${sex} ${key} unchanged`);actor.dispose();
}
console.log(JSON.stringify({status:'PASS',reports,limits:'Isolated cap geometry only; no actor/prototype/runtime edits, material palette, GPU or art acceptance.'},null,2));
