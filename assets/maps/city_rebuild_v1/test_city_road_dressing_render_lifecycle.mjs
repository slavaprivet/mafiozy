import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createCityRoadDressing} from './city_road_dressing.mjs';
import {roadSignalPhase} from './city_road_dressing_plan.mjs';

const THREE=await import(pathToFileURL((process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const plan=()=>({markings:[],signs:['yield','priority','speed','crosswalk','rail'].map((kind,i)=>({id:'sign-'+i,kind,x:i*4,y:0,z:0,yaw:0,direction:1})),signals:[0,512,1024].map((x,i)=>({id:'signal-'+i,kind:'traffic_signal',x,y:0,z:0,yaw:i*Math.PI/2,axis:i%2,offset:i*7})),stats:{}});
function bulbState(road,index){const result={};for(const name of ['red','amber','green']){const mesh=road.object.getObjectByName('TrafficBulbs:'+name),matrix=new THREE.Matrix4();mesh.getMatrixAt(index,matrix);result[name]={mesh,scale:new THREE.Vector3().setFromMatrixScale(matrix).length(),position:new THREE.Vector3().setFromMatrixPosition(matrix)};}return result;}

test('road-layer teardown releases every BatchedMesh allocation exactly once and detaches its group',()=>{
 const scene=new THREE.Scene(),road=createCityRoadDressing({THREE,plan:plan()});scene.add(road.object);const tracked=[],resources=new Set();
 road.object.traverse(mesh=>{if(!mesh.isMesh)return;for(const resource of [mesh,mesh.geometry,...Object.values(mesh).filter(v=>v?.isTexture),...(Array.isArray(mesh.material)?mesh.material:[mesh.material])]){if(!resource?.addEventListener||resources.has(resource))continue;resources.add(resource);const row={resource,calls:0};resource.addEventListener('dispose',()=>row.calls++);tracked.push(row);}});
 const batches=road.object.children.filter(n=>n.isBatchedMesh);assert.equal(batches.length,5);const batchGeometries=batches.map(m=>m.geometry),textures=batches.flatMap(m=>Object.values(m).filter(v=>v?.isTexture));assert.equal(textures.length,15);
 const previous=road.update(0,{time:20}).phases.slice();road.dispose();road.dispose();assert.equal(road.object.parent,null);assert.equal(road.object.children.length,0);assert.deepEqual(road.update(0,{time:32}).phases,previous);
 for(const resource of [...batchGeometries,...textures])assert.equal(tracked.find(row=>row.resource===resource).calls,1,'batched buffer/texture is released exactly once');
 for(const row of tracked.filter(r=>r.resource.isInstancedMesh||r.resource.isMaterial))assert.equal(row.calls,1);
});

for(const batched of [true,false])test('traffic lenses share equipment range culling and retain world-time phases ('+(batched?'BatchedMesh':'fallback')+')',()=>{
 const T=batched?THREE:{...THREE,BatchedMesh:undefined},data=plan(),road=createCityRoadDressing({THREE:T,plan:data});
 road.update(0,{time:0,focus:{x:0,z:0}});
 for(let i=0;i<3;i++){const state=bulbState(road,i);for(const [name,s]of Object.entries(state)){assert.equal(s.scale>0,i===0&&name===roadSignalPhase(0,data.signals[i].axis,data.signals[i].offset));assert.ok(Math.abs(s.position.x-data.signals[i].x-Math.sin(data.signals[i].yaw)*.285)<1e-3);}}
 const versions=['red','amber','green'].map(name=>road.object.getObjectByName('TrafficBulbs:'+name).instanceMatrix.version);road.update(0,{time:0,focus:{x:0,z:0}});assert.deepEqual(['red','amber','green'].map(name=>road.object.getObjectByName('TrafficBulbs:'+name).instanceMatrix.version),versions,'unchanged phase and focus do not upload lens matrices');
 const far=road.update(0,{time:22,focus:{x:10000,z:10000}});assert.deepEqual(far.phases,data.signals.map(s=>roadSignalPhase(22,s.axis,s.offset)),'hidden controllers keep advancing');assert.equal(road.stats.visibleDraws,0);
 for(let i=0;i<3;i++)for(const s of Object.values(bulbState(road,i))){assert.equal(s.scale,0);assert.equal(s.mesh.visible,false);}
 road.update(0,{time:22,focus:{x:512,z:0}});for(let i=0;i<3;i++)for(const[name,s]of Object.entries(bulbState(road,i)))assert.equal(s.scale>0,i===1&&name===roadSignalPhase(22,data.signals[i].axis,data.signals[i].offset));
 road.update(0,{time:22,focus:null});for(let i=0;i<3;i++)for(const[name,s]of Object.entries(bulbState(road,i)))assert.equal(s.scale>0,name===roadSignalPhase(22,data.signals[i].axis,data.signals[i].offset),'disabling range cull restores every current lens');road.dispose();
});
