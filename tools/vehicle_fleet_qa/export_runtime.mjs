// Offline geometry evidence. No browser access, game mutation, or source GLB edit.
import fs from 'node:fs';
import crypto from 'node:crypto';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {registerHooks} from 'node:module';
const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import('three');
const {RoundedBoxGeometry}=await import('./RoundedBoxGeometry.mjs');
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const assets=new URL('../../assets/maps/city_rebuild_v1/',import.meta.url);
const out=new URL('../../outputs/vehicle_fleet_continuation/',import.meta.url);fs.mkdirSync(out,{recursive:true});
const {ARTIST_VEHICLE_PROFILES,createArtistVehicle}=await import(new URL('vehicle_fleet_models.mjs',assets));
const {createDemoCar}=await import(new URL('car_drive.mjs',assets));
const {createVehicleHood}=await import(new URL('vehicle_hood.mjs',assets));
const {createVehicleTrunk}=await import(new URL('vehicle_trunk.mjs',assets));
const sha=url=>crypto.createHash('sha256').update(fs.readFileSync(url)).digest('hex');
const round=x=>Number(x.toFixed(7));
const sampleBox=new RoundedBoxGeometry(1,1,1,2,.1);
if(sampleBox.attributes.position.count<=36)throw Error('Real RoundedBoxGeometry required');
sampleBox.dispose();
const states={closed:[],open:[]};
const metadata={schema:'runtime-vehicle-offline-render/v1',createdAt:new Date().toISOString(),threeRevision:T.REVISION,units:'native metres',axisMapping:'Three x,y,z -> Blender x,z,y; triangle winding reversed',geometry:'Actual runtime factories + real Three 0.180 RoundedBoxGeometry + attached hood/trunk controllers',limitations:'Offline Blender presentation of runtime geometry, not a browser/live gameplay test. Mesh positions/normals/material colors exported; Three shader, lighting and transparency are approximated by Blender. Display normalization exists only in Blender.',roundedBoxSource:'https://cdn.jsdelivr.net/npm/three@0.180.0/examples/jsm/geometries/RoundedBoxGeometry.js',roundedBoxSha256:sha(new URL('./RoundedBoxGeometry.mjs',import.meta.url)),modules:{},vehicles:[]};
for(const name of ['vehicle_fleet_models.mjs','vehicle_fleet_body.mjs','car_drive.mjs','vehicle_hood.mjs','vehicle_trunk.mjs'])metadata.modules[name]=sha(new URL(name,assets));
function snapshot(car){
 car.object.updateWorldMatrix(true,true);const pieces=[];
 car.object.traverse(m=>{
  if(!m.isMesh||!m.geometry?.attributes.position)return;for(let n=m;n;n=n.parent)if(!n.visible)return;
  if(m.isSkinnedMesh||m.isInstancedMesh)throw Error('Unsupported geometry '+m.name);
  const g=m.geometry,p=g.attributes.position,normal=g.attributes.normal,index=g.index,v=new T.Vector3(),normalMatrix=new T.Matrix3().getNormalMatrix(m.matrixWorld),vertices=[],normals=[],faces=[],materialIndices=[];
  for(let i=0;i<p.count;i++){v.fromBufferAttribute(p,i).applyMatrix4(m.matrixWorld);vertices.push([v.x,v.z,v.y].map(round));if(normal){v.fromBufferAttribute(normal,i).applyNormalMatrix(normalMatrix);normals.push([v.x,v.z,v.y].map(round))}}
  const end=Math.min(index?.count??p.count,g.drawRange.start+g.drawRange.count);
  for(let i=g.drawRange.start;i<end;i+=3){const f=index?[index.getX(i+2),index.getX(i+1),index.getX(i)]:[i+2,i+1,i];if(m.matrixWorld.determinant()<0)f.reverse();faces.push(f);materialIndices.push(g.groups.find(group=>i>=group.start&&i<group.start+group.count)?.materialIndex??0)}
  const mats=(Array.isArray(m.material)?m.material:[m.material]).map(mat=>({color:mat.color?.toArray()??[.5,.5,.5],alpha:mat.transparent?mat.opacity:1,emissive:mat.emissive?.toArray()??[0,0,0],emissiveIntensity:mat.emissiveIntensity??1,roughness:mat.roughness??.8,metalness:mat.metalness??0,doubleSide:mat.side===T.DoubleSide,flatShading:!!mat.flatShading,textureMaps:['map','normalMap','roughnessMap','metalnessMap'].filter(k=>mat[k])}));
  pieces.push({name:m.name,geometryType:g.type,vertices,normals,faces,materialIndices,materials:mats});
 });return pieces;
}
for(const profile of [...ARTIST_VEHICLE_PROFILES,{id:'red_demo',label:'Kingswell'}]){
 let car,sourceHash=null;
 if(profile.id==='red_demo')car=createDemoCar(T,RoundedBoxGeometry);
 else{const file=new URL('models/artist_vehicle_pack/'+profile.modelFile,assets),b=fs.readFileSync(file);sourceHash=sha(file);if(sourceHash!==profile.sha256)throw Error('Source hash mismatch '+profile.id);const source=(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene;car=createArtistVehicle(T,RoundedBoxGeometry,source,profile)}
 const scene=new T.Scene();scene.add(car.object);const trunk=createVehicleTrunk(T,RoundedBoxGeometry,car,{scene}),hood=createVehicleHood(T,RoundedBoxGeometry,car,{scene});
 const vehicleState={x:0,y:0,z:0,yaw:0,speed:0};
 trunk.update(0,{vehicleState});hood.update(0,{vehicleState});
 const closed=snapshot(car);states.closed.push({id:profile.id,label:profile.label,pieces:closed});
 const trunkResult=trunk.toggle({hero:{x:0,y:0,z:trunk.profile.rearZ-.65},vehicleState}),hoodResult=hood.toggle({hero:{x:hood.profile.accessSide||0,y:0,z:hood.profile.accessZ+(hood.profile.front?1:-1)*.65},vehicleState});
 if(!trunkResult.accepted||!hoodResult.accepted)throw Error('Panel toggle rejected '+profile.id+JSON.stringify({trunkResult,hoodResult}));
 for(const id of ['front_left','front_right','rear_left','rear_right'])if(car.doors?.has(id))car.setDoorById?.(1,id);
 for(let i=0;i<90;i++){trunk.update(1/60,{vehicleState});hood.update(1/60,{vehicleState})}
 const opened=snapshot(car);states.open.push({id:profile.id,label:profile.label,pieces:opened});
 metadata.vehicles.push({id:profile.id,label:profile.label,sourceGlbSha256:sourceHash,closedMeshCount:closed.length,openMeshCount:opened.length,trunk:trunk.stats(),hood:hood.stats(),closedTriangleCount:closed.reduce((n,p)=>n+p.faces.length,0),openTriangleCount:opened.reduce((n,p)=>n+p.faces.length,0),textureMaps:closed.flatMap(p=>p.materials.flatMap(m=>m.textureMaps))});
 console.log(profile.id,closed.length,opened.length);
}
for(const [state,records]of Object.entries(states))fs.writeFileSync(new URL('runtime_'+state+'.json',out),JSON.stringify(records));
fs.writeFileSync(new URL('runtime_metadata.json',out),JSON.stringify(metadata,null,2));
console.log(fileURLToPath(out));
