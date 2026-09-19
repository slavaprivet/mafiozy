import {decorateCityTaxi} from './vehicle_taxi.mjs';
// Authored vehicle adapter for the shared game runtime (native metres).
// The source pack is immutable. Every vehicle owns its editable geometry and materials.
import {assembleArtistBody} from './vehicle_fleet_body.mjs';
import {createDetailedVehicleWheel,createWheelArch,wheelArchEnvelope,updateVehicleWheelVisuals,createVehicleWheelMaterialPalette} from './vehicle_wheels.mjs';
import {applyVehicleInteriorColors} from './vehicle_interior_colors.mjs';

// The player's fleet and source-world traffic use the same GLBs.  Keeping the
// parsed *source* scene next to its GLTFLoader avoids parsing/download work a
// second time during startup.  createArtistVehicle below still clones every
// editable geometry and material, so neither consumer can mutate this source.
// The cache belongs to the loader, rather than to an individual presentation:
// it is explicitly released when the world presentation is disposed and is
// otherwise collectable with the page's loader.
const artistVehicleSourceCaches=new WeakMap();

function sourceUrlKey(url){
 try{return new URL(String(url),import.meta.url).href}catch{return String(url)}
}

function disposeArtistVehicleSource(root){
 const resources=new Set();
 root?.traverse?.(node=>{
  if(node.geometry)resources.add(node.geometry);
  for(const material of Array.isArray(node.material)?node.material:node.material?[node.material]:[])resources.add(material);
 });
 for(const resource of resources)resource.dispose?.();
 root?.removeFromParent?.();
}

/**
 * Return an immutable parsed GLB scene shared by fleet and source traffic.
 * It deliberately has no per-actor release: actors receive private cloned
 * geometries/materials, while the loader-owned source remains reusable until
 * releaseArtistVehicleSourceCache(loader) is called.
 */
export function loadArtistVehicleSource({loader,url}={}){
 if(!loader?.loadAsync)throw Error('Vehicle GLTF loader required');
 const key=sourceUrlKey(url);let cache=artistVehicleSourceCaches.get(loader);
 if(!cache){cache=new Map();artistVehicleSourceCaches.set(loader,cache);}
 let entry=cache.get(key);
 if(!entry){
  entry={root:null,released:false,disposed:false};cache.set(key,entry);
  entry.promise=Promise.resolve().then(()=>loader.loadAsync(key)).then(gltf=>{
   const root=gltf?.scene||gltf;if(!root)throw Error('Vehicle GLTF has no scene');
   entry.root=root;
   if(entry.released&&!entry.disposed){entry.disposed=true;disposeArtistVehicleSource(root);}
   return root;
  },error=>{if(cache.get(key)===entry)cache.delete(key);throw error;});
 }
 return entry.promise;
}

// Do not dispose textures here. Artist vehicle materials are cloned per car
// but retain the same immutable texture maps; a live fleet can outlast a
// source-world traffic presentation. The renderer/browser owns those maps at
// page teardown, while geometry and source materials are released exactly once.
export function releaseArtistVehicleSourceCache(loader){
 const cache=artistVehicleSourceCaches.get(loader);if(!cache)return;
 artistVehicleSourceCaches.delete(loader);
 for(const entry of cache.values()){
  if(entry.released)continue;entry.released=true;
  if(entry.root&&!entry.disposed){entry.disposed=true;disposeArtistVehicleSource(entry.root);}
 }
 cache.clear();
}
const specs=[
 ['city_hatchback','Brooklyn SX','hatch',1.74,3.82,1.52,.32,1.48,1.86,.73,1150,28,7.2,4,'2b8f1e5a319556b67b1322f3bab55de521f3855e8894e82e1166c8ef5870772e'],
 ['compact_sedan','Easton S','sedan',1.80,4.42,1.47,.33,1.52,1.86,.68,1320,31,7,4,'08cf5677dec9ebdbbca329610be9e210e91185f976d3cdc307f87ff7345233f5'],
 ['family_wagon','Brooklyn LX','wagon',1.86,4.70,1.58,.34,1.58,2.55,.78,1540,30,6.2,4,'8357e3cba37673c565b3d289f8437afc4b140eeb963841c2aed6915a056761ce'],
 ['executive_sedan','Bellhaven V8','executive',1.95,5.05,1.49,.36,1.62,2.05,.66,1810,36,7.8,4,'08f8c863152eda4edfdd2262d93857a6f0e3476d7046fb4d105f2f7ead42b3d7'],
 ['sport_coupe','Ravelli GT','coupe',1.91,4.55,1.23,.36,1.48,1.68,.51,1380,43,10,2,'764576c6919bdd03f79e6b2f9738e9c9862b59b03f23d88893d8f35b0dbff158'],
 ['city_suv','Blackridge','suv',1.98,4.68,1.83,.40,1.68,2.42,.88,2020,31,6.3,4,'9e194b2b0fae7b1443743a47dbf97389e151f8c2d5e96c42e796a64640b42cb3'],
 ['delivery_van','Union Van','van',2.05,5.05,2.42,.38,1.72,1.18,.90,2390,26,4.8,2,'42abb4ee66d11850e7d2dfe13f449cb68f9b67e770c50a6e9ad0505a96ebe438'],
 ['utility_pickup','Ironvale','pickup',2.02,5.20,1.78,.40,1.70,1.62,.78,2160,29,5.8,2,'bad6a8f7d857f85edda09131ade16af1695e60fff5516d046f6e9f9ddb41f92e'],
 ['city_bus','Metroline 90','bus',2.55,10.8,3.18,.47,2.30,9.4,2.15,9800,23,2.7,2,'9735522832f8b314a93cbef116d51916eca633861178a5d6a5c1d94b2402a01f'],
 ['police_interceptor','Patrol LX','police',1.96,4.92,1.53,.36,1.62,2.04,.68,1830,39,8.9,4,'07374fcdaa792fb2b8933a420b71be9567c5df130f63bb353791a79edfca8c6e'],
 ['city_ambulance','Union Medic','ambulance',2.18,5.92,2.72,.42,1.82,1.45,.92,3500,29,4.9,2,'49306bfb80af503a36bf2c3f88ca7561d2433b587d638aa12136c05842a26933'],
 ['fire_engine','Ironvale F','fire',2.48,7.10,3.04,.48,2.10,1.80,1.22,10500,25,3,2,'967118f3763671e68c34b33fc0a7a8da2adf9f8eae564662af63f9a41f8ef55f'],
];
export const ARTIST_VEHICLE_PROFILES=Object.freeze(specs.map(([id,label,family,width,length,height,wheelRadius,cabinWidth,cabinLength,cabinHeight,massKg,maxSpeed,acceleration,seatCount,sha256])=>Object.freeze({id,label,family,width,length,height,wheelRadius,cabinWidth,cabinLength,cabinHeight,massKg,maxSpeed,reverseSpeed:family==='bus'?4:6,acceleration,seatCount,sha256,wheelBase:length*(['bus','fire'].includes(family)?.66:.62),halfWidth:width*.54+.18,halfLength:length*.51+.2,modelFile:id+'.glb',physicsTuning:'gameplay engineering estimates, not manufacturer specifications'})));
export const ARTIST_VEHICLE_PROFILE_BY_ID=Object.freeze(Object.fromEntries(ARTIST_VEHICLE_PROFILES.map(p=>[p.id,p])));

const clamp=(x,a=0,b=1)=>Math.max(a,Math.min(b,x));
const EPS=1e-7;
const occupantCaches=new WeakMap();
function vertexLerp(a,b,t){return {p:a.p.map((v,i)=>v+(b.p[i]-v)*t),n:a.n.map((v,i)=>v+(b.n[i]-v)*t)}}
function planeSplit(poly,axis,value,sign){
 const inside=[],outside=[];
 for(let i=0;i<poly.length;i++){
  const a=poly[i],b=poly[(i+1)%poly.length],dot=v=>Array.isArray(axis)?v.reduce((s,x,j)=>s+x*axis[j],0):v[axis],da=(dot(a.p)-value)*sign,db=(dot(b.p)-value)*sign,ai=da>=-EPS,bi=db>=-EPS;
  (ai?inside:outside).push(a);
  if(ai!==bi){const v=vertexLerp(a,b,da/(da-db));inside.push(v);outside.push(v)}
 }return {inside,outside};
}
function appendPolygon(poly,positions,normals){
 for(let i=1;i+1<poly.length;i++){
  const tri=[poly[0],poly[i],poly[i+1]],a=tri[0].p,b=tri[1].p,c=tri[2].p;
  const cross=[(b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1]),(b[2]-a[2])*(c[0]-a[0])-(b[0]-a[0])*(c[2]-a[2]),(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])];
  if(Math.hypot(...cross)<1e-10)continue;
  for(const v of tri){positions.push(...v.p);const d=Math.hypot(...v.n)||1;normals.push(...v.n.map(x=>x/d))}
 }
}
/** Actual triangle clipping, not AABB visibility: preserves the artist surface outside the aperture. */
export function splitVehicleGeometryBox(T,geometry,box){
 return splitGeometryPlanes(T,geometry,[[0,box.min[0],1],[0,box.max[0],-1],[1,box.min[1],1],[1,box.max[1],-1],[2,box.min[2],1],[2,box.max[2],-1]]);
}
function splitGeometryPlanes(T,geometry,planes){
 const p=geometry.attributes.position,n=geometry.attributes.normal,index=geometry.index,remainP=[],remainN=[],cutP=[],cutN=[];
 for(let i=0;i<(index?index.count:p.count);i+=3){
  let polygon=Array.from({length:3},(_,j)=>{const k=index?index.getX(i+j):i+j;return {p:[p.getX(k),p.getY(k),p.getZ(k)],n:n?[n.getX(k),n.getY(k),n.getZ(k)]:[0,1,0]}});
  for(const [axis,value,sign]of planes){if(!polygon.length)break;const result=planeSplit(polygon,axis,value,sign);appendPolygon(result.outside,remainP,remainN);polygon=result.inside}
  appendPolygon(polygon,cutP,cutN);
 }
 const build=(positions,normals)=>{const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(positions,3));g.setAttribute('normal',new T.Float32BufferAttribute(normals,3));g.computeBoundingBox();g.computeBoundingSphere();return g};
 return {outside:build(remainP,remainN),inside:build(cutP,cutN)};
}

export function createArtistVehicle(T,RoundedBox,source,profileOrId,{wheelRenderOptimization=false}={}){
 const definition=typeof profileOrId==='string'?ARTIST_VEHICLE_PROFILE_BY_ID[profileOrId]:profileOrId;
 if(!definition)throw Error('Unknown authored vehicle '+profileOrId);
 const profile={...definition},p=profile,id=p.id;
 const sourceCabin={width:p.cabinWidth,length:p.cabinLength,height:p.cabinHeight};
 const cabOverAxle=['van','ambulance','fire','bus'].includes(p.family);
 const floorTop=cabOverAxle?p.wheelRadius*2+.075:Math.max(.19,p.wheelRadius*.72);
 const bodyH=Math.max(.48,p.height*(['van','bus','ambulance','fire'].includes(p.family)?.28:.37));
 const bodyY=p.wheelRadius+bodyH*.52,cabinBase=bodyY+bodyH*.5-.03;
 profile.seatRecline=p.family==='coupe'?1.0:p.family==='bus'?.30:p.family==='fire'||p.family==='suv'?.55:p.family==='van'||p.family==='ambulance'||p.family==='pickup'?.70:.80;
 // Match the existing stylised humanoid without scaling, stretching or burying it.
 // These constants were measured on the actual 1.9m rig, with skull orientation kept level.
 const seatedHeadY=floorTop+.817829+.786602*Math.cos(profile.seatRecline)+.201946*Math.sin(profile.seatRecline);
 const cabinRaise=p.family==='bus'?0:Math.max(0,seatedHeadY+.060-(cabinBase+p.cabinHeight-.065));
 if(p.family!=='bus'){p.cabinWidth=Math.max(p.cabinWidth,p.width*1.02);p.cabinLength=Math.max(p.cabinLength,p.seatCount===4?2.72:1.65);p.cabinHeight+=cabinRaise}
 const input=source.scene||source,lod0=input.getObjectByName('LOD0_'+id);
 if(!lod0)throw Error('Missing authored LOD0_'+id);
 input.updateMatrixWorld(true);
 const object=new T.Group();object.name='Vehicle_'+id;object.userData.vehicleModelId=id;object.userData.massKg=p.massKg;object.userData.vehicleProfile=profile;
 // Opt-in only, before damage adapters capture canonical material ownership.
 const wheelMaterialPalette=wheelRenderOptimization?createVehicleWheelMaterialPalette(T,{owner:object,family:p.family,designId:p.wheelDesignId||p.family}):null;
 const materials=new Map(),sourceMeshes=[],shell=[],wheels=[],doors=new Map(),openings=[];
 const materialOwn=mat=>{if(!materials.has(mat)){const owned=mat.clone();owned.userData={...mat.userData};if(/SmokedGlass/i.test(mat.name)){owned.name='Automotive_Glass';owned.transparent=true;owned.opacity=.26;owned.depthWrite=false;owned.roughness=.22;owned.userData.breakableGlass=true}materials.set(mat,owned)}return materials.get(mat)};
 const rotation=new T.Matrix4().makeRotationY(Math.PI),inverseInput=input.matrixWorld.clone().invert();
 // Every authored mesh shares this source-to-game basis.  Reusing the working
 // matrix avoids allocating one Matrix4 per mesh during initial vehicle build;
 // applyMatrix4 consumes it immediately, before the next mesh overwrites it.
 const sourceToGame=rotation.clone().multiply(inverseInput),sourceToGameWork=new T.Matrix4();
 // Leave a real service nose in front of the cab, with no seat or pedal overlap.
 const movedCab=['van','ambulance','fire'].includes(p.family)?p.length*(p.family==='fire'?.31:.28)-.30:0;
 lod0.traverse(node=>{
  if(!node.isMesh)return;
  const geometry=node.geometry.clone();geometry.applyMatrix4(sourceToGameWork.copy(sourceToGame).multiply(node.matrixWorld));
  if(p.family!=='bus'&&/_(Cab|Cabin|Windshield|RearGlass|SideGlass_[LR]|DoorHandle_[LR]_\d|RoofExtension|RoofRail_[LR]|RoofSpoiler)$/.test(node.name)){
   const a=geometry.attributes.position;for(let i=0;i<a.count;i++){
    const sourceY=a.getY(i),z=a.getZ(i)*p.cabinLength/sourceCabin.length;
    a.setX(i,a.getX(i)*p.cabinWidth/sourceCabin.width);a.setZ(i,z);
    // A gentler rear roof slope leaves headroom over the genuine rear row.
    if((p.seatCount===4||p.family==='coupe')&&/_Cabin$/.test(node.name)&&z<0)a.setZ(i,z-.17*p.cabinLength*clamp((sourceY-cabinBase)/sourceCabin.height)*clamp(-z/(p.cabinLength*.20)));
    a.setY(i,cabinBase+(sourceY-cabinBase)*p.cabinHeight/sourceCabin.height);
   }a.needsUpdate=true;geometry.computeVertexNormals();
  }
  if(p.family==='police'&&/_Lightbar/.test(node.name))geometry.translate(0,cabinRaise,0);
  if(movedCab&&/_(Cab|Cabin|Windshield|RearGlass|SideGlass_[LR]|DoorHandle_[LR]_\d|Mirror_[LR])$/.test(node.name))geometry.translate(0,0,movedCab);
  geometry.computeBoundingBox();geometry.computeBoundingSphere();
  const mesh=new T.Mesh(geometry,Array.isArray(node.material)?node.material.map(materialOwn):materialOwn(node.material));mesh.name=node.name;mesh.userData={...node.userData,artistSourceNode:node.name};mesh.castShadow=mesh.receiveShadow=true;object.add(mesh);sourceMeshes.push(mesh);
 });
 const bySuffix=suffix=>sourceMeshes.find(m=>m.name.endsWith('_'+suffix));
 const bodyMaterial=sourceMeshes.find(m=>m.name.endsWith('_LowerBody')).material;
 object.userData.mapColor='#'+bodyMaterial.color.getHexString();
 const trim=new T.MeshStandardMaterial({color:'#5e655f',metalness:.25,roughness:.65});
 const dark=new T.MeshStandardMaterial({color:'#252e2b',roughness:.92});
 const leather=new T.MeshStandardMaterial({color:'#765440',roughness:.86});
 const insert=new T.MeshStandardMaterial({color:'#997452',roughness:.9});
 const metal=new T.MeshStandardMaterial({color:'#b6ad8c',metalness:.4,roughness:.47});
 const cabinTop=bodyY+bodyH*.5-.03+p.cabinHeight;
 let front=p.cabinLength*.5-.06+movedCab,rear=-p.cabinLength*.5+.06+movedCab,roofBottom=cabinTop-.065;
 if(p.family==='bus'){front=p.length*.433;rear=p.length*.16;roofBottom=p.height-.12}
 const interiorHalfWidth=Math.min(p.cabinWidth*.5-.065,p.width*.49);
 const interiorVoid={min:[-interiorHalfWidth,floorTop,rear],max:[interiorHalfWidth,roofBottom,front]};
 function addBox(name,w,h,d,x,y,z,material=bodyMaterial,parent=object,round=.02){const mesh=new T.Mesh(new RoundedBox(w,h,d,2,Math.min(round,w/4,h/4,d/4)),material);mesh.name=name;mesh.position.set(x,y,z);mesh.castShadow=mesh.receiveShadow=true;parent.add(mesh);return mesh}
 function cut(mesh,box,destination=null,name=null){
  if(!mesh.geometry?.attributes.position.count)return null;
  const split=splitVehicleGeometryBox(T,mesh.geometry,box);mesh.geometry.dispose();mesh.geometry=split.outside;
  if(!split.inside.attributes.position.count){split.inside.dispose();return null}
  if(!destination){split.inside.dispose();return null}
  const part=new T.Mesh(split.inside,mesh.material);part.name=name||mesh.name+'_panel';part.castShadow=part.receiveShadow=true;part.userData={...mesh.userData};destination.add(part);return part;
 }
 const structural=sourceMeshes.filter(m=>/_(LowerBody|Cabin|Cab|CargoVolume|PassengerBody|EquipmentBody|Trunk)$/.test(m.name));
 // Rounded wheel arches use the actual authored axles, leaving rolling contact unobstructed.
 for(const wheelMesh of sourceMeshes.filter(m=>/_Wheel_/.test(m.name))){
  wheelMesh.geometry.computeBoundingBox();const bounds=wheelMesh.geometry.boundingBox,center=bounds.getCenter(new T.Vector3()),side=Math.sign(center.x),envelope=wheelArchEnvelope(p.wheelRadius,bounds.max.x-bounds.min.x,/_Wheel_F/.test(wheelMesh.name)),radius=envelope.radius;
  const planes=[[0,side>0?center.x-envelope.halfDepth:-p.width*.8,1],[0,side>0?p.width*.8:center.x+envelope.halfDepth,-1]];
  for(let i=0;i<20;i++){const a=i*Math.PI/10,cy=Math.cos(a),cz=Math.sin(a);planes.push([[0,-cy,-cz],-radius-center.y*cy-center.z*cz,1])}
  for(const mesh of structural){const split=splitGeometryPlanes(T,mesh.geometry,planes);mesh.geometry.dispose();split.inside.dispose();mesh.geometry=split.outside}
 }
 for(const mesh of structural)cut(mesh,interiorVoid);
 // Transparent glass must look into an actual opening rather than an opaque cabin hull.
 for(const window of sourceMeshes.filter(m=>/_(Windshield|RearGlass|SideGlass_[LR]|FrontGlass|Window_[LR]_\d+)$/.test(m.name))){
  window.geometry.computeBoundingBox();const b=window.geometry.boundingBox,min=b.min.toArray(),max=b.max.toArray();
  if(/SideGlass|Window_[LR]_/.test(window.name)){if((min[0]+max[0])>0){min[0]=0;max[0]=p.width*.7}else{min[0]=-p.width*.7;max[0]=0}}
  else if((min[2]+max[2])>2*movedCab){min[2]=movedCab;max[2]=p.length*.6}else{min[2]=-p.length*.6;max[2]=movedCab}
  min[1]+=.009;max[1]-=.009;
  for(const mesh of structural)cut(mesh,{min,max});
 }
 const rowLength=(front-rear)/(p.seatCount===4?2:1),gap=.035;
 const doorSpecs=[];
 for(const side of [1,-1])for(let row=0;row<(p.seatCount===4?2:1);row++){
  const doorId=(row?'rear_':'front_')+(side>0?'left':'right');
  const doorFront=front-row*rowLength-gap,doorRear=p.family==='bus'?doorFront-1.30:front-(row+1)*rowLength+gap;
  const opening={min:[side>0?interiorHalfWidth-.008:-p.width*.7,floorTop+.025,doorRear],max:[side>0?p.width*.7:-interiorHalfWidth+.008,roofBottom-.035,doorFront]};
  const group=new T.Group();group.name='Door_'+doorId;group.userData.vehicleDoorId=doorId;object.add(group);
  for(const mesh of [...structural,...sourceMeshes.filter(m=>/SideGlass_[LR]|DoorHandle_[LR]|PassengerDoor/.test(m.name))])cut(mesh,opening,group);
  const doorX=side*(p.cabinWidth*.5-.035),panelTop=bodyY+bodyH*.45;
  // Inner trim gives thin clipped panels an interior face and leaves the aperture empty when open.
  addBox('Door_inner_'+doorId,.035,Math.max(.16,panelTop-floorTop-.08),doorFront-doorRear-.04,doorX-side*.06,(panelTop+floorTop+.08)/2,(doorFront+doorRear)/2,dark,group,.015);
  addBox('Door_armrest_'+doorId,.10,.055,Math.min(.32,(doorFront-doorRear)*.5),doorX-side*.115,panelTop-.06,(doorFront+doorRear)/2,trim,group,.018);
  if(!group.children.some(m=>m.material?.transparent)){
   const glass=sourceMeshes.find(m=>m.material?.transparent)?.material;
   if(glass)addBox('Door_window_'+doorId,.024,Math.max(.16,roofBottom-panelTop-.10),doorFront-doorRear-.09,doorX,(roofBottom+panelTop)/2-.035,(doorFront+doorRear)/2,glass,group,.009);
  }
  const hinge=new T.Vector3(doorX,Math.max(floorTop+.4,panelTop),doorFront);
  group.position.copy(hinge);
  for(const child of group.children){if(child.userData.artistSourceNode){child.geometry.translate(-hinge.x,-hinge.y,-hinge.z)}else child.position.sub(hinge)}
  doors.set(doorId,group);openings.push({...opening,id:doorId,side});doorSpecs.push({id:doorId,side,front:doorFront,rear:!!row,handle:{side:doorX+side*.05,front:doorRear+.15,y:panelTop},opening});
 }
 // Remove empty clipped source objects; retain every untouched artist detail.
 for(const mesh of sourceMeshes){if(!mesh.geometry.attributes.position.count){mesh.removeFromParent();mesh.geometry.dispose()}else if(!mesh.material?.transparent&&!/_Wheel_/.test(mesh.name))shell.push(mesh)}
 // Preserve authored centres, tyre radii, widths and IDs; replace the solid
 // rubber source plugs with separately modelled tyres and recessed metal rims.
 for(const axle of ['F','R'])for(const side of ['L','R']){
  const mesh=bySuffix('Wheel_'+axle+side);if(!mesh)throw Error('Missing wheel '+id+' '+axle+side);
  const gameId=(axle==='F'?'front_':'rear_')+(side==='L'?'left':'right');
  mesh.geometry.computeBoundingBox();const bounds=mesh.geometry.boundingBox,center=bounds.getCenter(new T.Vector3()),width=bounds.max.x-bounds.min.x;
  mesh.removeFromParent();mesh.geometry.dispose();
  const detail=createDetailedVehicleWheel(T,{id:gameId,radius:p.wheelRadius,width,side:Math.sign(center.x),family:p.family,designId:p.wheelDesignId||p.family,materialPalette:wheelMaterialPalette});
  const pivot=new T.Group();pivot.name='Wheel_attachment_'+gameId;pivot.userData.vehicleWheelId=gameId;pivot.position.copy(center);pivot.add(detail.wheel);object.add(pivot);
  wheels.push({id:gameId,pivot,...detail,front:axle==='F',rollingRadius:p.wheelRadius,restPosition:center.clone()});
 }
 const interior=new T.Group();interior.name='Interior_'+id;object.add(interior);
 addBox('Cabin_floor',interiorHalfWidth*2,.06,front-rear,0,floorTop-.03,(front+rear)/2,dark,interior);
 if(cabOverAxle)for(const side of [-1,1])for(const level of [1,2])addBox('Cab_step_'+side+'_'+level,.20,.055,Math.min(.54,(front-rear)*.55),side*(p.width*.49+.08*(3-level)),floorTop*level/3,(front+rear)/2,trim);
 const cushionTop=floorTop+.18,seatWidth=Math.min(.61,interiorHalfWidth-.12),seatDepth=Math.min(.54,rowLength*.62);
 const seatSide=Math.min(interiorHalfWidth*.50,.52),parts={seats:[],gauges:[]},seats=[];
 const driverRootY=floorTop-.25; // Actual rig seated sole is 0.276m above root; feet stay above the floor.
 for(const door of doorSpecs){
  const row=door.rear?1:0,z=front-row*rowLength-Math.min(rowLength*.62,.62),x=door.side*seatSide;
  const cushion=addBox(door.id+'_cushion',seatWidth,.14,seatDepth,x,cushionTop-.07,z,leather,interior,.055);parts.seats.push(cushion);
  addBox(door.id+'_seat_insert',seatWidth*.76,.012,seatDepth*.82,x,cushionTop+.006,z,insert,interior,.006);
  const backHeight=Math.min(.49,roofBottom-cushionTop-.21);
  const seatBackAngle=profile.seatRecline*.75,back=addBox(door.id+'_back',seatWidth,backHeight,.12,x,cushionTop+Math.cos(seatBackAngle)*backHeight*.5,z-seatDepth*.5+.025-Math.sin(seatBackAngle)*backHeight*.5,leather,interior,.05);back.rotation.x=-seatBackAngle;
  const headrest=addBox(door.id+'_headrest',seatWidth*.54,.17,.12,x,cushionTop+Math.cos(seatBackAngle)*(backHeight+.10),z-seatDepth*.5+.025-Math.sin(seatBackAngle)*(backHeight+.10),leather,interior,.045);headrest.rotation.x=-seatBackAngle;
  for(const sx of [-1,1])addBox(door.id+'_seat_rail',.035,.045,seatDepth*.80,x+sx*seatWidth*.3,floorTop+.025,z,metal,interior,.006);
  for(let seam=-2;seam<=2;seam++)addBox(door.id+'_seat_seam',.008,.009,seatDepth*.74,x+seam*seatWidth*.13,cushionTop+.014,z,metal,interior,.002);
  seats.push({id:door.id,doorId:door.id,label:door.id==='front_left'?'Водитель':door.rear?(door.side>0?'Задний левый пассажир':'Задний правый пассажир'):'Передний пассажир',side:door.side,canDrive:door.id==='front_left',anchor:{side:x,front:z,y:driverRootY},doorDistance:p.halfWidth+.62,doorFront:(door.opening.min[2]+door.opening.max[2])/2,pose:{cushionTop,roofBottom,seatBackZ:z-seatDepth*.5}});
 }
 const dashboardY=Math.min(roofBottom-.31,cushionTop+.52),dashboardZ=front-.08;
 addBox('Dashboard_shell',interiorHalfWidth*2-.04,.17,.21,0,dashboardY,dashboardZ,dark,interior,.05);
 addBox('Dashboard_fascia',interiorHalfWidth*2-.13,.11,.012,0,dashboardY,dashboardZ-.114,insert,interior,.006);
 for(const x of [-seatSide,0,seatSide])addBox('Dashboard_vent',.16,.044,.017,x,dashboardY+.035,dashboardZ-.125,trim,interior,.008);
 const steering=new T.Group();steering.name='Steering_column';steering.position.set(seatSide,dashboardY-.02,dashboardZ-.25);steering.rotation.x=-.25;interior.add(steering);
 steering.position.z-=p.family==='coupe'?.26:.12;
 const wheel=new T.Group();wheel.name='Steering_wheel';steering.add(wheel);
 const rim=new T.Mesh(new T.TorusGeometry(.16,.021,8,24),metal);rim.name='Steering_rim';wheel.add(rim);
 for(const angle of [0,Math.PI*2/3,Math.PI*4/3]){const spoke=addBox('Steering_spoke',.021,.145,.02,Math.sin(angle)*.065,Math.cos(angle)*.065,0,dark,wheel,.006);spoke.rotation.z=-angle}
 addBox('Steering_hub',.075,.075,.034,0,0,0,dark,wheel,.025);
 for(const x of [seatSide-.085,seatSide+.085]){const dial=new T.Mesh(new T.CircleGeometry(.055,16),metal);dial.name='Instrument_dial';dial.position.set(x,dashboardY+.014,dashboardZ-.124);dial.rotation.y=Math.PI;interior.add(dial);parts.gauges.push(dial)}
 addBox('Gear_console',.11,.13,.24,0,floorTop+.065,seats[0].anchor.front+.24,dark,interior,.03);
 addBox('Gear_lever',.025,.16,.025,0,floorTop+.21,seats[0].anchor.front+.24,metal,interior,.007);
 for(const x of [seatSide-.085,seatSide+.085])addBox('Driver_pedal',.08,.035,.12,x,floorTop+.06,front-.25,dark,interior,.008);

 // A real cavity and an authored removable lid; the separate trunk controller owns hinges/motion.
 const lid=new T.Group();lid.name='Trunk_lid';object.add(lid);
 let trunkSpec;
 const trunkMaterial=dark;
 if(p.family==='pickup'){
  const tail=bySuffix('TailGate');if(tail?.parent){object.updateMatrixWorld(true);lid.attach(tail)}
  const tailBounds=new T.Box3().setFromObject(lid),hingePoint=[0,tailBounds.min.y,tailBounds.max.z];
  trunkSpec={lid,mode:'tailgate',hingePoint,openAngle:-1.45,createCavity:false};
 }else if(['sedan','executive','police','coupe'].includes(p.family)){
  const original=bySuffix('Trunk'),cargoRear=-p.length*.465,cargoFront=Math.min(rear-.12,-p.length*.22),cargoTop=bodyY+bodyH*.55,cargoFloor=Math.max(.28,bodyY-bodyH*.30);
  const cavity={min:[-p.width*.36,cargoFloor,cargoRear],max:[p.width*.36,cargoTop+.13,cargoFront]};
  const lidSlice={min:[-p.width*.48,cargoTop-.10,cargoRear-.07],max:[p.width*.48,cargoTop+.35,cargoFront+.035]};
  for(const mesh of structural.filter(m=>m.parent)){cut(mesh,lidSlice,lid);cut(mesh,cavity)}
  // Source trunks can sit lower than the body crown: use their original full mesh if not captured above.
  if(!lid.children.length&&original?.parent){object.updateMatrixWorld(true);lid.attach(original)}
  if(!lid.children.length)addBox('Trunk_lid_surface',p.width*.76,.075,cargoFront-cargoRear,0,cargoTop,(cargoFront+cargoRear)/2,bodyMaterial,lid,.025);
  addBox('Trunk_floor',p.width*.70,.055,cargoFront-cargoRear,0,cargoFloor-.02,(cargoRear+cargoFront)/2,trunkMaterial);
  for(const x of [-p.width*.35,p.width*.35])addBox('Trunk_liner_side',.035,cargoTop-cargoFloor,cargoFront-cargoRear,x,(cargoFloor+cargoTop)/2,(cargoRear+cargoFront)/2,trunkMaterial);
  addBox('Trunk_liner_front',p.width*.70,cargoTop-cargoFloor,.035,0,(cargoFloor+cargoTop)/2,cargoFront,trunkMaterial);
  trunkSpec={lid,mode:'trunk',hingePoint:[0,cargoTop,cargoFront],openAngle:1.18,createCavity:false,cavityBounds:cavity};
 }else{
  const utility=['van','ambulance','fire','bus'].includes(p.family),cargoRear=-p.length*(utility?.433:.40),cargoFront=utility?Math.min(rear-.12,-p.length*.06):rear-.06;
  const cargoFloor=p.family==='bus'?1.38:utility?Math.max(.45,p.wheelRadius+.16):floorTop+.08;
  const cargoTop=p.family==='fire'?p.height*.77-.065:utility?p.height-.22:cabinTop-.08;
  const openingRear=utility?-p.length*.435:-p.cabinLength*.48;
  const aperture={min:[-p.width*(utility?.35:.41),cargoFloor,-p.length*.54],max:[p.width*(utility?.35:.41),cargoTop,utility?-p.length*.35:openingRear+.10]};
  for(const mesh of sourceMeshes.filter(m=>m.parent&&!/_Wheel_|DoorHandle|Mirror|Lightbar|Ladder|Roof/.test(m.name)))cut(mesh,aperture,lid);
  const cavity={min:[-p.width*.35,cargoFloor,cargoRear],max:[p.width*.35,cargoTop,cargoFront]};
  for(const mesh of structural.filter(m=>m.parent))cut(mesh,cavity);
  if(!lid.children.length)addBox('Cargo_hatch_panel',p.width*.69,cargoTop-cargoFloor,.045,0,(cargoFloor+cargoTop)/2,openingRear,bodyMaterial,lid,.035);
  const depth=Math.max(.3,cargoFront-cargoRear);
  addBox('Cargo_floor',p.width*.70,.06,depth,0,cargoFloor-.03,(cargoRear+cargoFront)/2,trunkMaterial);
  for(const x of [-p.width*.35,p.width*.35])addBox('Cargo_liner_side',.04,cargoTop-cargoFloor,depth,x,(cargoTop+cargoFloor)/2,(cargoRear+cargoFront)/2,trunkMaterial);
  addBox('Cargo_bulkhead',p.width*.70,cargoTop-cargoFloor,.05,0,(cargoTop+cargoFloor)/2,cargoFront,trunkMaterial);
  trunkSpec={lid,mode:'hatch',hingePoint:[0,cargoTop,openingRear],openAngle:1.5,createCavity:false,cavityBounds:cavity};
 }
 const forwardCabService=['van','ambulance','fire'].includes(p.family);
 const hoodSource=bySuffix('LowerBody'),hoodSlice=forwardCabService?{min:[-p.width*.42,bodyY-bodyH*.46,p.length*.34],max:[p.width*.42,bodyY+bodyH*.60,p.length*.54]}:{min:[-p.width*.44,bodyY+bodyH*.29,front+.035],max:[p.width*.44,bodyY+bodyH,p.length*.475]};
 let hood=null;if(p.family!=='bus'&&hoodSlice.max[2]>hoodSlice.min[2])hood=cut(hoodSource,hoodSlice,object,'Hood_lid');
 if(p.family==='bus'){
  hood=new T.Group();hood.name='Hood_lid';object.add(hood);
  const serviceAperture={min:[-p.width*.34,.49,-p.length*.52],max:[p.width*.34,1.26,-p.length*.42]};
  for(const mesh of structural.filter(m=>m.parent))cut(mesh,serviceAperture,hood);
  if(!hood.children.length)addBox('Rear_engine_service_hatch',p.width*.65,.72,.05,0,.87,-p.length*.457,bodyMaterial,hood,.025);
 }
 if(hood)shell.push(hood);
 const engineZ=p.family==='bus'?-p.length*.415:forwardCabService?p.length*.38:Math.min(p.length*.39,front+.25),engineY=p.family==='bus'?.82:forwardCabService?bodyY:Math.max(floorTop+.16,bodyY-.10);
 const engineCore=addBox('Engine_core',p.width*.46,.28,Math.min(.62,p.length*.12),0,engineY,engineZ,dark);
 const engineBounds=p.family==='bus'?{min:[-p.width*.30,.51,-p.length*.465],max:[p.width*.30,1.22,-p.length*.355]}:forwardCabService?{min:[-p.width*.31,Math.max(.28,bodyY-bodyH*.40),p.length*.29],max:[p.width*.31,bodyY+bodyH*.46,p.length*.475]}:{min:[-p.width*.31,Math.max(.25,engineY-.22),front+.05],max:[p.width*.31,bodyY+bodyH*.46,p.length*.465]};
 // The service cavity is cut in the owned hull; hiding Engine_core alone would leave a sealed solid body.
 for(const mesh of structural.filter(m=>m.parent))cut(mesh,{min:engineBounds.min,max:[engineBounds.max[0],Math.max(engineBounds.max[1],bodyY+bodyH*.60),engineBounds.max[2]]});
 const hoodSpec={lid:hood,core:engineCore,hingePoint:p.family==='bus'?[0,1.26,-p.length*.457]:forwardCabService?[0,bodyY+bodyH*.46,p.length*.34]:[0,bodyY+bodyH*.46,front+.035],openAngle:p.family==='bus'?1.40:-1.18,engineBounds,front:p.family!=='bus',mode:p.family==='bus'?'hatch':'hood'};
 const bodyAssembly=assembleArtistBody(T,RoundedBox,{object,p,sourceMeshes,shell,doors,doorSpecs,bodyMaterial,dark,trim,metal,floorTop,bodyY,bodyH,cabinTop,roofBottom,front,rear,movedCab,interiorHalfWidth,trunkSpec,hoodSpec,wheels,cut});
 // Newly constructed door skins / shoulders obey the same wheel clearance as
 // the original hull. Bake only for clipping, then restore each hinge's frame.
 object.updateMatrixWorld(true);
 const archPanels=[];object.traverse(n=>{if(n.isMesh&&!n.material?.transparent&&(n.userData.wheelArchCandidate||/^(Cabin_floor|Door_inner_|Body_sill_|Body_[AC]_pillar_lower_|Cab_step_|Engine_bay_sidewall_)|_cushion$|_PassengerDoor_/.test(n.name)))archPanels.push(n)});
 for(const panel of archPanels){
  const world=panel.matrixWorld.clone(),inverse=world.clone().invert();panel.geometry.applyMatrix4(world);
  for(const wheel of wheels){const center=wheel.restPosition,side=Math.sign(center.x),envelope=wheelArchEnvelope(p.wheelRadius,wheel.nominalWidth,wheel.front),radius=envelope.radius,planes=[[0,side>0?center.x-envelope.halfDepth:-p.width*.8,1],[0,side>0?p.width*.8:center.x+envelope.halfDepth,-1]];
   for(let i=0;i<20;i++){const a=i*Math.PI/10,cy=Math.cos(a),cz=Math.sin(a);planes.push([[0,-cy,-cz],-radius-center.y*cy-center.z*cz,1])}
   const split=splitGeometryPlanes(T,panel.geometry,planes);panel.geometry.dispose();split.inside.dispose();panel.geometry=split.outside;
  }panel.geometry.applyMatrix4(inverse);
 }
 for(const wheel of wheels){const arch=createWheelArch(T,{id:wheel.id,center:wheel.restPosition,radius:p.wheelRadius,width:wheel.nominalWidth,front:wheel.front,side:Math.sign(wheel.restPosition.x),outerX:p.width*.505,paint:bodyMaterial});object.add(arch);arch.traverse(n=>{if(n.isMesh)shell.push(n)})}
 // Door leaves and lid children are part of the deformable body, unlike glass and interior furniture.
 for(const door of doors.values())door.traverse(n=>{if(n.isMesh&&!n.material?.transparent)shell.push(n)});
 lid.traverse(n=>{if(n.isMesh&&!n.material?.transparent&&!shell.includes(n))shell.push(n)});
 shell.push(lid);
 // Damage snapshots must contain only current body objects, once each. Assembly
 // replaces authored panels and can add a door skin before the final door pass.
 const liveBody=new Set();object.traverseVisible(n=>liveBody.add(n));
 const currentShell=[...new Set(shell)].filter(n=>liveBody.has(n));shell.splice(0,shell.length,...currentShell);
 const getSteeringGrips=()=>{wheel.updateWorldMatrix(true,false);return {left:wheel.localToWorld(new T.Vector3(.16*Math.cos(Math.PI/6),.08,-.023)),right:wheel.localToWorld(new T.Vector3(-.16*Math.cos(Math.PI/6),.08,-.023))}};
 function poseOccupant(hero,seatId='front_left',options={}){
  const seat=seats.find(s=>s.id===seatId);if(!seat)throw Error('Unknown occupant seat '+seatId);
  const fold=clamp(options.fold??1),reach=clamp(options.reach??0),recline=(options.recline??profile.seatRecline??.55)*clamp(options.reclineBlend??fold);
  let cache=occupantCaches.get(hero);
  if(!cache){
   const bones={};hero.object.traverse(n=>{if(n.isBone&&['thigh_l','thigh_r','head','upperarm_l','upperarm_r'].includes(n.name))bones[n.name]=n});
   hero.vehiclePose(1,0,{driver:seat.canDrive});hero.object.updateMatrixWorld(true);
   if(!bones.thigh_l||!bones.thigh_r){hero.vehiclePose(fold,reach,{...options.pose,...options,driver:seat.canDrive});return}
   const hip=hero.object.worldToLocal(bones.thigh_l.getWorldPosition(new T.Vector3()).add(bones.thigh_r.getWorldPosition(new T.Vector3())).multiplyScalar(.5));
   cache={bones,hip,pivot:hero.object.children[0],inverseTilt:new T.Quaternion(),tilt:new T.Quaternion(),axis:new T.Vector3(1,0,0),point:new T.Vector3(),pos:new T.Vector3(),scale:new T.Vector3(),q:new T.Quaternion(),left:new T.Quaternion(),right:new T.Quaternion(),head:new T.Quaternion(),grips:{left:new T.Vector3(),right:new T.Vector3()}};occupantCaches.set(hero,cache);
  }
  const {bones,hip,pivot,inverseTilt,tilt}=cache;
  inverseTilt.setFromAxisAngle(cache.axis,recline);tilt.copy(inverseTilt).invert();hero.object.updateWorldMatrix(true,false);
  const actualGrips=seat.canDrive&&fold>.88?getSteeringGrips():null;
  if(actualGrips)for(const side of ['left','right'])hero.object.localToWorld(hero.object.worldToLocal(cache.grips[side].copy(actualGrips[side])).sub(hip).applyQuaternion(inverseTilt).add(hip));
  hero.vehiclePose(fold,reach,{...options.pose,...options,driver:seat.canDrive,steeringGrips:actualGrips?cache.grips:undefined});hero.object.updateMatrixWorld(true);
  if(!seat.canDrive&&fold>.7){
   const rootQ=hero.object.getWorldQuaternion(cache.head),axis=cache.point.set(0,0,1).applyQuaternion(rootQ);
   for(const [name,sign]of [['upperarm_l',1],['upperarm_r',-1]]){
    const arm=bones[name];if(!arm)continue;
    arm.getWorldQuaternion(cache.left);cache.right.setFromAxisAngle(axis,sign*.34*fold).multiply(cache.left);
    arm.matrix.decompose(cache.pos,cache.q,cache.scale);arm.parent.getWorldQuaternion(cache.q).invert().multiply(cache.right);arm.matrix.compose(cache.pos,cache.q,cache.scale);arm.matrixWorldNeedsUpdate=true;
   }hero.object.updateMatrixWorld(true);
  }
  bones.thigh_l.getWorldQuaternion(cache.left);bones.thigh_r.getWorldQuaternion(cache.right);bones.head?.getWorldQuaternion(cache.head);
  pivot.quaternion.copy(tilt);pivot.position.copy(hip).sub(cache.point.copy(hip).applyQuaternion(tilt));hero.object.updateMatrixWorld(true);
  function preserveWorldRotation(bone,target){bone.matrix.decompose(cache.pos,cache.q,cache.scale);bone.parent.getWorldQuaternion(cache.q).invert().multiply(target);bone.matrix.compose(cache.pos,cache.q,cache.scale);bone.matrixWorldNeedsUpdate=true}
  preserveWorldRotation(bones.thigh_l,cache.left);preserveWorldRotation(bones.thigh_r,cache.right);
  if(bones.head)preserveWorldRotation(bones.head,cache.head);
  hero.object.updateMatrixWorld(true);
 }
 const setDoorById=(amount,doorId)=>{const key=typeof doorId==='number'?(doorId>0?'front_left':'front_right'):doorId,door=doors.get(key);if(!door)throw Error('Unknown door '+key+' on '+id);if(!door.userData.detached)door.rotation.y=-(key.endsWith('left')?1:-1)*clamp(amount)*1.18};
 const brakeLights=sourceMeshes.filter(m=>/Taillamp/.test(m.name)).map(m=>m.material);
 function update(state,braking=false){
  updateVehicleWheelVisuals(wheels,state,p.wheelRadius);
  wheel.rotation.z=-(state.steer||0)*2.1;for(const mat of brakeLights)mat.emissiveIntensity=braking||state.handbrake?2.7:.5;
 }
 object.updateMatrixWorld(true);
 const visualBounds=new T.Box3().setFromObject(object),size=visualBounds.getSize(new T.Vector3());
 profile.halfWidth=Math.max(profile.halfWidth,size.x/2+.10);profile.halfLength=Math.max(profile.halfLength,Math.abs(visualBounds.min.z),Math.abs(visualBounds.max.z));profile.height=size.y;profile.bounds={min:visualBounds.min.toArray(),max:visualBounds.max.toArray()};
 profile.wheelPositions=Object.fromEntries(wheels.map(w=>[w.id,{x:w.restPosition.x,y:w.restPosition.y,z:w.restPosition.z}]));
 const engineLo=hoodSpec.engineBounds.min,engineHi=hoodSpec.engineBounds.max,engineDepth=engineHi[2]-engineLo[2],engineHeight=engineHi[1]-engineLo[1],serviceSign=hoodSpec.front?1:-1;
 const enginePoint={x:(engineLo[0]+engineHi[0])/2,y:engineLo[1]+engineHeight*(hoodSpec.front?.42:.32),z:(engineLo[2]+engineHi[2])/2-serviceSign*engineDepth*.13};
 engineCore.position.set(enginePoint.x,enginePoint.y,enginePoint.z);
 const panelPoint=n=>{const point=new T.Box3().setFromObject(n).getCenter(new T.Vector3());return{x:point.x,y:point.y,z:point.z}};
 profile.componentPoints={engine:enginePoint,radiator:{x:enginePoint.x,y:engineLo[1]+engineHeight*.46,z:hoodSpec.front?engineHi[2]-engineDepth*.065:engineLo[2]+engineDepth*.065}};
 profile.partPoints={hood:panelPoint(hoodSpec.lid),trunk:panelPoint(trunkSpec.lid),...Object.fromEntries(wheels.map(w=>['wheel_'+w.id,profile.wheelPositions[w.id]])),...Object.fromEntries(doorSpecs.map(d=>['door_'+d.id,{x:d.side*p.width*.48,y:bodyY,z:(d.opening.min[2]+d.opening.max[2])/2}]))};
 for(const seat of seats)seat.doorDistance=profile.halfWidth+.57;
 const anchors={driver:seats[0].anchor,passenger:seats.find(s=>s.id==='front_right').anchor,rear:seats.filter(s=>s.id.startsWith('rear_')).map(s=>s.anchor),floorTop,cushionTop,roofBottom,doors:doorSpecs};
 const diagnostics={sourceId:id,sourceSha256:p.sha256,sourceMeshCount:sourceMeshes.length,seatCount:seats.length,openings,interiorVoid,sourceCabForwardCorrection:movedCab,cabinRaise,cabinSource:sourceCabin,cabinAdapted:{width:p.cabinWidth,length:p.cabinLength,height:p.cabinHeight},bodyAssembly:{version:2,roof:bodyAssembly.roof,belt:bodyAssembly.belt,created:bodyAssembly.created.length,retired:bodyAssembly.retired.length},geometryOwnership:'per-vehicle clones',sourceUnits:'meters',sourceFront:'-Z',gameFront:'+Z'};
 object.userData.vehicleProfile=profile;
 applyVehicleInteriorColors(object,p.interiorPaletteId||(p.wheelDesignId==='city_taxi'?'city_taxi':p.id));
 return {object,profile,seats,wheels,doors,shell,anchors,trunkSpec,hoodSpec,getSteeringGrips,poseOccupant,update,interior:{object:interior,profile:{family:p.family,floorTop,cushionTop,roofBottom},anchors,parts,wheel,steeringWheel:wheel,getSteeringGrips,update:state=>{wheel.rotation.z=-(state.steer||0)*2.1}},setDoorById,setDoor:(amount,side=1)=>setDoorById(amount,typeof side==='string'?side:side>0?'front_left':'front_right'),setRearDoor:(amount,side=1)=>{const key='rear_'+(side>0?'left':'right');if(doors.has(key))setDoorById(amount,key)},setHighlightedDoor(){},diagnostics:()=>diagnostics};
}
export async function loadArtistFleetModels({THREE,loader,RoundedBox,baseUrl='./models/artist_vehicle_pack/',onProgress,includeTaxi=false,vehicleFactory=createArtistVehicle}={}){
 if(!THREE||!loader||!RoundedBox)throw Error('THREE, loader and RoundedBox are required');
 const vehicles=[],errors=[];
 // Pipeline a small fixed window of transfers/parses while assembling the
 // previous vehicle.  A full Promise.all would retain twelve parsed GLBs at
 // once; three keeps the established bounded-memory property while avoiding
 // network idle gaps between the 12 independent source files.
 const requests=new Map(),maxInFlight=3,base=baseUrl.replace(/\/?$/,'/');let next=0;
 const start=index=>{const profile=ARTIST_VEHICLE_PROFILES[index],url=base+profile.modelFile;requests.set(index,Promise.resolve().then(()=>loadArtistVehicleSource({loader,url})).then(source=>({profile,source}),error=>({profile,error})));};
 while(next<Math.min(maxInFlight,ARTIST_VEHICLE_PROFILES.length))start(next++);
 for(let index=0;index<ARTIST_VEHICLE_PROFILES.length;index++){
  const result=await requests.get(index);requests.delete(index);if(next<ARTIST_VEHICLE_PROFILES.length)start(next++);
  const {profile,source,error}=result;
  if(error){errors.push({id:profile.id,message:String(error?.message||error)});continue}
  try{vehicles.push(vehicleFactory(THREE,RoundedBox,source,profile));if(includeTaxi&&profile.id==='compact_sedan')vehicles.push(decorateCityTaxi(THREE,RoundedBox,vehicleFactory(THREE,RoundedBox,source,{...profile,wheelDesignId:'city_taxi'})));onProgress?.({id:profile.id,loaded:vehicles.length,total:ARTIST_VEHICLE_PROFILES.length+(includeTaxi?1:0)})}
  catch(error){errors.push({id:profile.id,message:String(error?.message||error)})}
 }
 if(errors.length){const error=new Error('Authored fleet failed to load: '+errors.map(e=>e.id+': '+e.message).join('; '));error.failures=errors;error.vehicles=vehicles;throw error}
 return vehicles;
}
