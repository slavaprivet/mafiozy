// Run with Node; this offline audit does not import into or mutate the game UI.
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const factory=process.argv.find(a=>a.startsWith('--factory='))?.slice(10)||process.env.MAFIOZY_FLEET_FACTORY;
const {ARTIST_VEHICLE_PROFILES,createArtistVehicle}=await import(factory?pathToFileURL(factory):new URL('./vehicle_fleet_models.mjs',import.meta.url));
const {createVehicleTrunk}=await import(new URL('./vehicle_trunk.mjs',import.meta.url));
const {createVehicleHood}=await import(new URL('./vehicle_hood.mjs',import.meta.url));
const {createDemoCar}=await import(new URL('./car_drive.mjs',import.meta.url));
class RoundedBox extends T.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const r=v=>Number.isFinite(v)?Number(v.toFixed(4)):999,boxData=b=>({min:b.min.toArray().map(r),max:b.max.toArray().map(r)});
const accessoryPattern=/_(Headlamp|Taillamp|(?:Front|Rear)?Bumper|Lightbar|Ladder|RoofLadderRail|RoofRail|RoofSpoiler|Mirror)/;
const supportPattern=/LowerBody|Cabin|(?:_|^)Cab(?:_|$)|CargoVolume|PassengerBody|EquipmentBody|Trunk|Hood_lid|Door_inner|Pillar|pillar|Frame|frame|Fender|fender|Mount|mount|Bracket|bracket|Support|support/;
const anchoredBodyPattern=/LowerBody|Cabin|(?:_|^)Cab(?:_|$)|CargoVolume|PassengerBody|EquipmentBody|Trunk|Hood_lid|Door_inner|Fender|fender/;
function meshes(root){const result=[];root.traverse(n=>{if(n.isMesh&&n.geometry?.attributes?.position?.count&&n.visible){let visible=true;for(let p=n.parent;p;p=p.parent)if(!p.visible)visible=false;if(visible)result.push(n)}});return result;}
const opaque=m=>!(Array.isArray(m.material)?m.material.every(x=>x.transparent):m.material?.transparent);
const gap=(a,b)=>Math.hypot(Math.max(a.min.x-b.max.x,b.min.x-a.max.x,0),Math.max(a.min.y-b.max.y,b.min.y-a.max.y,0),Math.max(a.min.z-b.max.z,b.min.z-a.max.z,0));
function attachmentReport(all){
 const supports=all.filter(m=>opaque(m)&&supportPattern.test(m.name)),bounds=new Map(all.map(m=>[m,new T.Box3().setFromObject(m)]));
 return all.filter(m=>accessoryPattern.test(m.name)).map(m=>{
  const b=bounds.get(m),nearest=supports.filter(s=>s!==m).map(s=>({name:s.name,gap:gap(b,bounds.get(s))})).sort((a,b)=>a.gap-b.gap)[0];
  return{name:m.name,bounds:boxData(b),nearestSupport:nearest?.name,gapM:r(nearest?.gap??999)};
 });
}
// A lens may touch its base and a ladder rung may touch its rail: neither must
// touch the body directly. Find the weakest join along the best mounting path.
// AABB separation is a conservative *lower bound*, never a watertight claim.
function attachmentPaths(all){
 const parts=all.filter(m=>opaque(m)&&(m.userData.assembledBody||accessoryPattern.test(m.name)||supportPattern.test(m.name))),bounds=parts.map(m=>new T.Box3().setFromObject(m));
 const fixed=parts.map(m=>anchoredBodyPattern.test(m.name)&&!m.userData.assembledBody&&!accessoryPattern.test(m.name)),cost=parts.map((_,i)=>fixed[i]?0:Infinity),via=parts.map(()=>null),used=new Set();
 for(let step=0;step<parts.length;step++){
  let index=-1;for(let i=0;i<parts.length;i++)if(!used.has(i)&&(index<0||cost[i]<cost[index]))index=i;
  if(index<0||!Number.isFinite(cost[index]))break;used.add(index);
  for(let i=0;i<parts.length;i++)if(!used.has(i)){const d=Math.max(cost[index],gap(bounds[index],bounds[i]));if(d<cost[i]){cost[i]=d;via[i]=index}}
 }
 return parts.flatMap((m,i)=>accessoryPattern.test(m.name)?[{name:m.name,mountGapM:r(cost[i]),via:via[i]===null?null:parts[via[i]].name}]:[]);
}
const point=new T.Vector3(),a=new T.Vector3(),b=new T.Vector3(),c=new T.Vector3(),closest=new T.Vector3(),triangle=new T.Triangle();
function cacheTriangles(all){return all.map(mesh=>{
 const p=mesh.geometry.attributes.position,index=mesh.geometry.index,positions=[];
 for(let i=0;i<(index?.count??p.count);i++){point.fromBufferAttribute(p,index?index.getX(i):i).applyMatrix4(mesh.matrixWorld);positions.push(point.x,point.y,point.z);}
 return{mesh,positions,bounds:new T.Box3().setFromObject(mesh)};
});}
function nearestSurface(p,supports){let best=Infinity,name=null;
 for(const item of supports){if(item.bounds.distanceToPoint(p)>best)continue;
  for(let i=0;i<item.positions.length;i+=9){a.fromArray(item.positions,i);b.fromArray(item.positions,i+3);c.fromArray(item.positions,i+6);triangle.set(a,b,c);triangle.closestPointToPoint(p,closest);const d=p.distanceTo(closest);if(d<best){best=d;name=item.mesh.name}}
 }return{distanceM:r(best),support:name};
}
function windowReport(all,supports){
 const reports=[];
 for(const mesh of all.filter(m=>/_(Windshield|FrontGlass|RearGlass)$/.test(m.name)||/^Fitted_(windscreen|rear_glass|door_glass_)/.test(m.name))){
  const p=mesh.geometry.attributes.position,vertices=[];
  for(let i=0;i<p.count;i++)vertices.push(new T.Vector3().fromBufferAttribute(p,i).applyMatrix4(mesh.matrixWorld));
  const maxY=Math.max(...vertices.map(v=>v.y)),minY=Math.min(...vertices.map(v=>v.y));
  const axis=/door_glass/.test(mesh.name)?'z':'x';
  const points=[];for(const [label,y] of [['upper',maxY],['lower',minY]]){const edge=vertices.filter(v=>Math.abs(v.y-y)<.018);edge.sort((a,b)=>a[axis]-b[axis]);for(const [side,p]of [['right',edge[0]],['left',edge.at(-1)]])if(p)points.push({label:label+'_'+side,point:p.toArray().map(r),...nearestSurface(p,supports)})}
  reports.push({name:mesh.name,points});
 }return reports;
}
function cargoReport(car,all,supports){
 const spec=car.object.getObjectByName('Trunk_cavity')?.userData.cargoBounds||car.trunkSpec?.cavityBounds;if(!spec)return{specified:false};
 const min=new T.Vector3(...spec.min),max=new T.Vector3(...spec.max),center=min.clone().add(max).multiplyScalar(.5),half=new T.Vector3(.15,.15,.15),cube=new T.Box3(center.clone().sub(half),center.clone().add(half));
 const blockers=[];for(const item of supports){if(!cube.intersectsBox(item.bounds))continue;let intersects=false;
  for(let i=0;i<item.positions.length;i+=9){triangle.set(a.fromArray(item.positions,i),b.fromArray(item.positions,i+3),c.fromArray(item.positions,i+6));if(cube.intersectsTriangle(triangle)){intersects=true;break}}
  if(intersects){const parents=[];for(let p=item.mesh.parent;p&&p!==car.object;p=p.parent)parents.push(p.name);blockers.push({name:item.mesh.name,parents});}
 }
 const ray=new T.Raycaster(new T.Vector3(center.x,cube.min.y+.005,center.z),new T.Vector3(0,-1,0),0,3),floor=ray.intersectObjects(all.filter(opaque),false)[0];
 // A clear cargo box alone cannot detect a missing external rear fascia.
 // Nine two-sided rays from the declared interior must meet a CLOSED rear skin.
 // Restrict samples below the cavity ceiling, so intentional glazing is not
 // mistaken for an unsealed opaque body. The pickup's open top is irrelevant.
 const rearClosure=[];
 for(const x of [min.x+.08,center.x,max.x-.08])for(const y of [min.y+.08,center.y,max.y-.08]){
  const ray=new T.Ray(new T.Vector3(x,y,center.z),new T.Vector3(0,0,-1));let nearest=Infinity,name=null;
  for(const item of supports)for(let i=0;i<item.positions.length;i+=9){a.fromArray(item.positions,i);b.fromArray(item.positions,i+3);c.fromArray(item.positions,i+6);const hit=ray.intersectTriangle(a,b,c,false,closest);if(hit){const d=ray.origin.distanceTo(hit);if(d<nearest){nearest=d;name=item.mesh.name}}}
  rearClosure.push({x:r(x),y:r(y),hit:name,distanceM:r(nearest),sealed:nearest<=center.z-min.z+.65});
 }
 const roofClosure=[];
 if(car.trunkSpec?.mode!=='tailgate'){
  // Glass is a legitimate closed roof/window seal, unlike an empty hole. A
  // pickup has an intentionally open bed and is excluded only from this test.
  const panels=cacheTriangles(all);
  for(const x of [min.x+.08,center.x,max.x-.08])for(const z of [min.z+.08,center.z,max.z-.08]){
   const ray=new T.Ray(new T.Vector3(x,center.y,z),new T.Vector3(0,1,0));let nearest=Infinity,name=null;
   for(const item of panels)for(let i=0;i<item.positions.length;i+=9){a.fromArray(item.positions,i);b.fromArray(item.positions,i+3);c.fromArray(item.positions,i+6);const hit=ray.intersectTriangle(a,b,c,false,closest);if(hit){const d=ray.origin.distanceTo(hit);if(d<nearest){nearest=d;name=item.mesh.name}}}
   roofClosure.push({x:r(x),z:r(z),hit:name,distanceM:r(nearest),sealed:nearest<4});
  }
 }
 return{specified:true,bounds:spec,cubeCenter:center.toArray().map(r),cubeFitsBounds:cube.min.x>=min.x&&cube.min.y>=min.y&&cube.min.z>=min.z&&cube.max.x<=max.x&&cube.max.y<=max.y&&cube.max.z<=max.z,blockers,rearClosure,roofClosure,floor:floor?{name:floor.object.name,y:r(floor.point.y),dropM:r(floor.distance)}:null};
}
function engineReport(car,hood){
 if(!hood.enabled)return{enabled:false};
 const vehicleState={x:0,y:0,z:0,yaw:0,speed:0},hero={x:hood.profile.accessSide||0,y:0,z:hood.profile.accessZ+(hood.profile.front?.65:-.65)};
 const toggle=hood.toggle({hero,vehicleState});for(let i=0;i<90;i++)hood.update(1/60,{vehicleState,crashState:{engine:1,radiator:1,temperature:0}});
 car.object.updateMatrixWorld(true);
 const spec=hood.bay.userData.engineBounds,interior=new T.Box3(new T.Vector3(...spec.min).addScalar(.025),new T.Vector3(...spec.max).subScalar(.025)),foreign=meshes(car.object).filter(m=>{if(!opaque(m))return false;for(let p=m;p;p=p.parent)if(p===hood.bay||p===hood.lid)return false;return true});
 const blockers=[];
 for(const item of cacheTriangles(foreign)){
  if(!interior.intersectsBox(item.bounds))continue;
  for(let i=0;i<item.positions.length;i+=9){triangle.set(a.fromArray(item.positions,i),b.fromArray(item.positions,i+3),c.fromArray(item.positions,i+6));if(interior.intersectsTriangle(triangle)){const parents=[];for(let p=item.mesh.parent;p&&p!==car.object;p=p.parent)parents.push(p.name);blockers.push({name:item.mesh.name,parents});break}}
 }
 return{enabled:true,openAccepted:toggle.accepted,amount:hood.state.amount,angleDegrees:r(Math.abs(hood.hinge.rotation.x)*180/Math.PI),bounds:spec,foreignBlockers:blockers,smokeParticles:hood.stats().smokeParticles,visibleEngineParts:hood.stats().visibleEngineParts};
}
const report=[];
for(const profile of [...ARTIST_VEHICLE_PROFILES,{id:'red_demo'}]){
 let source,car;
 if(profile.id==='red_demo')car=createDemoCar(T,RoundedBox);
 else{const bytes=fs.readFileSync(new URL('./models/artist_vehicle_pack/'+profile.modelFile,import.meta.url));source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;car=createArtistVehicle(T,RoundedBox,source,profile);}
 const scene=new T.Scene();scene.add(car.object);
 const trunk=createVehicleTrunk(T,RoundedBox,car,{scene}),hood=createVehicleHood(T,RoundedBox,car,{scene});car.object.updateMatrixWorld(true);
 let original=[];if(source){source.rotation.y=Math.PI;source.updateMatrixWorld(true);const lod0=source.getObjectByName('LOD0_'+profile.id);original=attachmentReport(meshes(lod0));}
 const all=meshes(car.object),supports=cacheTriangles(all.filter(m=>opaque(m)&&(m.userData.assembledBody||supportPattern.test(m.name)))),attachments=attachmentReport(all);
 const windows=windowReport(all,supports),cargo=cargoReport(car,all,cacheTriangles(all.filter(opaque)));
 report.push({id:profile.id,bounds:boxData(all.reduce((box,m)=>box.union(new T.Box3().setFromObject(m)),new T.Box3())),cabin:car.diagnostics?.().cabinAdapted,attachments:attachments.map(item=>({...item,sourceGapM:original.find(x=>x.name===item.name)?.gapM})),mounts:attachmentPaths(all),windows,cargo,engine:engineReport(car,hood)});
 trunk.dispose();hood.dispose();const gs=new Set(),ms=new Set();car.object.traverse(n=>{if(n.geometry)gs.add(n.geometry);for(const m of Array.isArray(n.material)?n.material:n.material?[n.material]:[])ms.add(m)});for(const g of gs)g.dispose();for(const m of ms)m.dispose();
}
console.log(JSON.stringify({schema:'vehicle-closed-continuity-audit/v1',units:'metres',method:'Guaranteed AABB separation for exterior attachments; exact triangle distance from authored glass edge vertices to opaque frame/body; actual triangle/AABB cargo cube intersection. Pristine factory+closed controllers, then open healthy engine bay foreign-triangle check.',vehicles:process.argv.includes('--full')?report:report.map(v=>({id:v.id,windowMaxGapM:Math.max(0,...v.windows.flatMap(w=>w.points.map(p=>p.distanceM))),mounts:v.mounts.filter(m=>m.mountGapM>.04),cargo:v.cargo,engine:v.engine}))},null,2));
