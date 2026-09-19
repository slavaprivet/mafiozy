import {worldTrafficProfile,trafficActorBlocks} from './world_traffic_presentation.mjs';
import {createNpcVehicleAccessResolver} from './npc_vehicle_access.mjs';
// Geometry-only source proxies. They are never added to a scene or rendered.
// Queries expose geometry; transition and driving permissions require source proof.
export function createNpcLogicalVehicleBinding({bridge,getTemplate,getVisibleVehicle,getVisibleNpc,groundHeight=()=>0,worldScale=4.1,streamRadius=95/worldScale}={}){
 const actors=new Map(),sourceRows=new Map(),grid=new Map();let records=null;
 const cellSize=24;
 function update(row){
  if(!row?.id||row.helicopter||/heli|aircraft|plane/i.test(row.model||'')||![row.r,row.c,row.ang].every(Number.isFinite))return null;
  const profileId=worldTrafficProfile(row),template=profileId&&getTemplate(profileId),profile=template?.profile;
  let actor=actors.get(row.id);if(!actor){actor={object:{scale:{x:1,y:1,z:1},visible:true,userData:{}},seats:[],logicalSource:true,sourceBinding:null};
   actor.object.position={get x(){return actor.sourceRow.c*worldScale},get z(){return actor.sourceRow.r*worldScale},get y(){const r=actor.sourceRow.r,c=actor.sourceRow.c;if(r!==actor.floorR||c!==actor.floorC){actor.floorR=r;actor.floorC=c;actor.floorY=groundHeight(c*worldScale,r*worldScale);}return actor.floorY}};
   actor.object.rotation={get y(){return Math.PI/2-actor.sourceRow.ang}};actors.set(row.id,actor);}
  actor.sourceRow=row;
  actor.profileKnown=!!profile;actor.profile=profile||{halfLength:(row.halfLength||1.4)*worldScale,halfWidth:(row.halfWidth||.6)*worldScale,height:3};actor.seats=template?.seats||[];
  actor.object.scale={x:Math.abs(template?.object?.scale?.x??1),y:Math.abs(template?.object?.scale?.y??1),z:Math.abs(template?.object?.scale?.z??1)};
  actor.object.userData.sourceVehicleId=row.id;actor.object.userData.vehicleProfile=actor.profile;return actor;
 }
 function ensure(){
  if(records)return;records=[];grid.clear();sourceRows.clear();const snapshot=bridge?.getWalkNpcVehicleTraffic?.();
  for(const row of snapshot?.rows||[]){sourceRows.set(row.id,row);const actor=update(row);if(!actor)continue;records.push({id:row.id,actor});
   const object=actor.object,reach=Math.hypot(actor.profile.halfLength*Math.abs(object.scale?.z??1),actor.profile.halfWidth*Math.abs(object.scale?.x??1))+6;
   for(let x=Math.floor((object.position.x-reach)/cellSize);x<=Math.floor((object.position.x+reach)/cellSize);x++)for(let z=Math.floor((object.position.z-reach)/cellSize);z<=Math.floor((object.position.z+reach)/cellSize);z++){const key=x+','+z,bucket=grid.get(key)||[];bucket.push({id:row.id,actor});grid.set(key,bucket);}
  }
  for(const id of actors.keys())if(!sourceRows.has(id))actors.delete(id);
 }
 function getActor(id){const visible=getVisibleVehicle(id);if(visible)return visible;ensure();const row=sourceRows.get(id);return row?update(row):null;}
 const resolver=createNpcVehicleAccessResolver({worldScale,allowLogicalActor:actor=>actor.profileKnown===true,traffic:{getActor:(id,request)=>{
  const visible=getVisibleVehicle(id);if(visible)return visible;
  if(request.phase==='query'){
   ensure();const row=sourceRows.get(id);if(!row||!Number.isFinite(row.viewerDistance)||row.viewerDistance<=streamRadius)return null;
   const actor=update(row);return actor?.profileKnown?actor:null;
  }
  const proof=bridge?.getWalkNpcVehicleBinding?.(request);if(!proof?.access||!proof.bound||!proof.alive||proof.viewerDistance<=streamRadius)return null;
  if(request.phase==='board'&&proof.phase!=='board'||request.phase==='drive'&&!proof.ready||request.phase==='exit'&&proof.phase!=='exit')return null;
  const actor=update(proof.vehicle);if(!actor?.profileKnown)return null;actor.sourceBinding=proof;return actor;
 }}});
 return {
  beginFrame(){records=null;},getActor,access:resolver,
  driver(request){const proof=bridge?.getWalkNpcVehicleBinding?.(request);if(!proof?.ready||!proof.bound||!proof.alive||!proof.riding||proof.carId!==request.carId||proof.npcId!==String(request.npcId))return {ready:false,reason:'source-driver-unbound'};
   const vehicle=getVisibleVehicle(request.carId),npc=getVisibleNpc(request.npcId);if(proof.viewerDistance<=streamRadius)return {ready:!!vehicle?.object?.parent&&!!npc?.object?.parent&&npc.object.visible!==false,mode:'visible'};
   const actor=update(proof.vehicle);return {ready:!!actor?.profileKnown&&actor.seats.some(s=>s.id==='front_left'),mode:'logical',sourceFrame:proof.sourceFrame};
  },
  getVehicles(){ensure();return records;},
  blocks(x,z,body={}){ensure();const bucket=grid.get(Math.floor(x/cellSize)+','+Math.floor(z/cellSize))||[];return bucket.some(record=>record.id!==body.ignoreId&&trafficActorBlocks(record.actor,x,z,0,body));},
  diagnostics(){return {logicalActors:actors.size,sourceVehicles:sourceRows.size,renderedObjects:0};}
 };
}
