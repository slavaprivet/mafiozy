// Isolated real-host composition for the one approved print-shop pilot.
import {createPrintShopServiceStation,PRINT_SHOP_SERVICE_PILOT} from '../native_print_shop_service_station.mjs';
import {createStationaryServiceAdapter} from '../npc_stationary_service_adapter.mjs';
import {createStationaryServiceSource23} from './source.mjs';
import {createServiceEmployeeReturn23} from './return.mjs';
import {createServiceVisitLease23,createServiceExitMovement23} from './visits.mjs';
import {createServiceSpawnVisibility23} from './visibility.mjs';
import {createNpcSweptFootprint} from '../npc_swept_footprint.mjs';
const finite=p=>p&&['x','y','z'].every(k=>Number.isFinite(p[k]));
const distanceSegment=(p,a,b)=>{const dx=b.x-a.x,dz=b.z-a.z,l=dx*dx+dz*dz,t=l?Math.max(0,Math.min(1,((p.x-a.x)*dx+(p.z-a.z)*dz)/l)):0;return Math.hypot(p.x-a.x-dx*t,p.z-a.z-dz*t);};
export function createStationaryServiceWalk23({THREE:T,bridge,host,siteRevision,sourceFactory=createStationaryServiceSource23}={}){
 const M=4.1,R=.18*M,entry=host.getEntries().find(e=>e.instance?.id===PRINT_SHOP_SERVICE_PILOT);
 if(!entry||typeof bridge?.installStationaryServiceMerchant23!=='function'||typeof bridge.getWalkServicePhysicalBodies23!=='function'||typeof bridge.getWalkNpcVehicleTraffic!=='function')return null;
 let disposed=false,station=null,registration=null,lease=null,index=null,bodies=null,source=null;
 const dynamicFootprint=createNpcSweptFootprint(),diagnostics={bodyReads:0,lastBodyCount:0,lastHold:null};
 const bodyHold=reason=>{diagnostics.lastHold=reason;return null;};
 const ready=()=>!disposed&&host.ready()===true&&host.getEntries().includes(entry)&&!!entry.storeys?.root?.parent;
 const current=l=>ready()&&l?.revision===siteRevision&&l.buildingId===PRINT_SHOP_SERVICE_PILOT;
 const floor=p=>host.groundHeight(p.c*M,p.r*M),point=n=>({x:n.c*M,y:host.groundHeight(n.c*M,n.r*M),z:n.r*M});
 function syncCollision(){
  if(!station||!ready())return false;
  const next=host.getCollisionIndex(),nextBodies=station.getCollisionBodies();if(!next)return false;
  if(index!==next){index?.removeGroup(station);index=next;bodies=null;}
  if(bodies!==nextBodies){index.replaceGroup(station,nextBodies,{order:100000});bodies=nextBodies;host.invalidateNavigation();}
  return true;
 }
 function physicalBodies(from,to,ignoreActor=null){
  if(!ready()||!finite(from)||!finite(to))return bodyHold('physical-host-not-ready');
  diagnostics.bodyReads++;
  const centre={r:(from.z+to.z)/(2*M),c:(from.x+to.x)/(2*M)},radius=(Math.hypot(to.x-from.x,to.z-from.z)/2+16)/M;
  if(radius>16)return bodyHold('physical-query-too-long');
  let people,traffic;try{people=bridge.getWalkServicePhysicalBodies23({...centre,radius});traffic=bridge.getWalkNpcVehicleTraffic();}catch{return bodyHold('source-roster-threw');}
  if(people?.complete!==true||!Array.isArray(people.rows)||!Array.isArray(traffic?.rows))return bodyHold('source-roster:'+String(people?.reason||'missing-traffic'));
  const out=[],ignoredIds=new Set(),near=(p,r)=>Math.hypot(p.x-centre.c*M,p.z-centre.r*M)<=radius*M+r;
  const push=(id,position,radius,height,ref=null,polygonCR=null)=>{if(!finite(position)||!Number.isFinite(radius)||radius<=0||!Number.isFinite(height)||height<=0)return false;if(near(position,radius))out.push({id,position,radius,height,ref,polygonCR});return true;};
  for(const row of people.rows){
   if(row.ref===ignoreActor&&ignoreActor){for(const id of row.aliasIds||[row.id])ignoredIds.add(id);continue;}
   if(!Number.isFinite(row.r)||!Number.isFinite(row.c))return null;
   const x=row.c*M,z=row.r*M,low=host.groundHeight(x,z);
   // Unknown source storey/seat/airborne pose is a conservative vertical column.
   // A rendered pose supplements it; it never erases an uncapped source body.
   const known=Number.isFinite(row.footY),lying=row.dead||row.downed||row.prone;
   if(!push(row.id,{x,y:known?row.footY:low-4,z},lying?2.5:R,known?(lying?1.0:2.3):40,row.ref))return null;
  }
  for(const row of host.getNpcActors()){
   if(ignoredIds.has(row.id)||!row.object?.parent)continue;
   const p=row.object.getWorldPosition(new T.Vector3()),s=row.source||{};
   if(!push(row.id+':view',p,s.dead||s.downed||s.forcedCrawl?2.5:R,2.3))return null;
  }
  const hero=host.getHero();if(!hero?.object?.parent)return null;
  const heroPosition=hero.object.getWorldPosition(new T.Vector3()),heroShape=host.heroBody();
  if(!push('player',heroPosition,heroShape.radius,heroShape.height))return null;
  for(const row of traffic.rows){
   const x=row.c*M,z=row.r*M;if(!Number.isFinite(x+z))return null;
   const length=Number(row.halfLength)*M,width=Number(row.halfWidth)*M;
   if(!Number.isFinite(length+width)||length<=0||width<=0)return null;
   if((row.helicopter||/heli|aircraft|plane|tow/i.test(String(row.model)))&&near({x,z},24))return bodyHold('unsupported-nearby-vehicle:'+String(row.id));
   if(!Number.isFinite(row.ang))return null;
   const cos=Math.cos(row.ang),sin=Math.sin(row.ang),polygon=[[-1,-1],[1,-1],[1,1],[-1,1]].map(([a,b])=>[(x+a*(length+.5)*cos-b*(width+.25)*sin)/M,(z+a*(length+.5)*sin+b*(width+.25)*cos)/M]);
   if(!push(row.id+':source-car',{x,y:host.groundHeight(x,z)-2,z},Math.hypot(length,width)+.6,12,null,polygon))return null;
  }
  for(const row of [...host.getFleet(),...host.getTrafficActors()]){
   const actor=row.car||row.actor||row,object=actor.object,profile=actor.profile||object?.userData?.vehicleProfile;
   if(!object?.parent)continue;const p=object.getWorldPosition(new T.Vector3()),scale=object.getWorldScale(new T.Vector3());
   if(!profile||![profile.halfLength,profile.halfWidth,profile.height,scale.x,scale.y,scale.z].every(Number.isFinite))return null;
   // Transform all eight profile corners: rolled/tilted cars remain occupied.
   object.updateWorldMatrix(true,false);const bounds=new T.Box3();
   for(const x of [-profile.halfWidth,profile.halfWidth])for(const z of [-profile.halfLength,profile.halfLength])for(const y of [profile.bounds?.min?.[1]??-.5,profile.bounds?.max?.[1]??profile.height])bounds.expandByPoint(new T.Vector3(x,y,z).applyMatrix4(object.matrixWorld));
   const polygon=[[bounds.min.x,bounds.min.z],[bounds.max.x,bounds.min.z],[bounds.max.x,bounds.max.z],[bounds.min.x,bounds.max.z]].map(([x,z])=>[x/M,z/M]);
   const centre=bounds.getCenter(new T.Vector3());
   if(!push(String(row.id)+':view-car',{x:centre.x,y:bounds.min.y,z:centre.z},Math.hypot(bounds.max.x-bounds.min.x,bounds.max.z-bounds.min.z)/2,bounds.max.y-bounds.min.y,null,polygon))return null;
  }
  diagnostics.lastBodyCount=out.length;return out;
 }
 function clearDynamic(from,to,ignoreActor){
  const obstacles=physicalBodies(from,to,ignoreActor);if(!obstacles)return false;
  const minY=Math.min(from.y,to.y),maxY=Math.max(from.y,to.y)+1.9;
  dynamicFootprint.set({r:from.z/M,c:from.x/M},{r:to.z/M,c:to.x/M},.18+.02/M);
  return obstacles.every(b=>b.position.y+b.height<=minY+.03||b.position.y>=maxY||(b.polygonCR?!dynamicFootprint.overlaps(b.polygonCR,()=>true):distanceSegment(b.position,from,to)>=b.radius+R+.02));
 }
 function supported(p){const y=floor(p);return Number.isFinite(y)&&host.ceilingHeight(p.c*M,p.r*M,y)>=y+1.85&&!(host.waterAt(p.c*M,p.r*M)?.depth>.05);}
 function sweep(from,to,actor){
  if(!syncCollision()||![from?.r,from?.c,to?.r,to?.c].every(Number.isFinite))return false;
  const result=host.nativeQuery({mode:'sweep',from,to,radius:.18});if(result?.swept!==true||result.blocked!==false)return false;
  const steps=Math.max(1,Math.ceil(Math.hypot(to.r-from.r,to.c-from.c)*M/.25));if(steps>400)return false;
  for(let i=0;i<=steps;i++){
   const p={r:from.r+(to.r-from.r)*i/steps,c:from.c+(to.c-from.c)*i/steps};if(!supported(p))return false;
   for(const [dr,dc]of [[0,0],[.18,0],[-.18,0],[0,.18],[0,-.18]]){const q=host.nativeQuery({r:p.r+dr,c:p.c+dc});if(!q||q.blocked!==false||q.depth>.05)return false;}
  }
  return clearDynamic({x:from.c*M,y:floor(from),z:from.r*M},{x:to.c*M,y:floor(to),z:to.r*M},actor);
 }
 const visibility=createServiceSpawnVisibility23({THREE:T,getCamera:host.getCamera,getOccluders:()=>[entry.visual],isCurrentSite:current,ready});
 function presentationReady(n){
  const h=host.getHero()?.object?.position;if(!h)return false;
  if(Math.hypot(n.c*M-h.x,n.r*M-h.z)>105)return true;
  const id=source?.entityId(n),actor=id&&host.getNpcActor(id),row=id&&host.getNpcActors().find(row=>row.id===id);
  // getActor also returns retained, streamed-out cached actors. Readiness must
  // refer to the current selected snapshot and the same attached visible skin.
  if(!actor?.object?.parent||row?.object!==actor.object||row.source?.id!==id||row.source.dead||row.source.carried||row.source.evacuated){diagnostics.lastHold='source-model-pending';return false;}
  for(let object=actor.object;object;object=object.parent)if(object.visible===false){diagnostics.lastHold='source-model-hidden';return false;}
  return true;
 }
 try{
  station=createPrintShopServiceStation({THREE:T,entry,siteRevision,validateLayout:({layout})=>['spawn','doorInside','doorOutside','work','customer','customerVia'].every(k=>{const p=layout[k],r=p.z/M,c=p.x/M,q=host.nativeQuery({mode:'sweep',from:{r,c},to:{r,c},radius:.18}),ground=host.groundHeight(p.x,p.z),ok=Math.abs(ground-p.y)<.05&&q?.swept===true&&q.blocked===false;if(!ok)throw Error('Service anchor '+JSON.stringify({k,p:[p.x,p.y,p.z].map(v=>+v.toFixed(3)),g:Number.isFinite(ground)?+ground.toFixed(3):String(ground),s:q?.swept,b:q?.blocked,why:q?.reason||q?.surface||'none'}));return ok;})});
  if(!syncCollision())throw Error('Service collision index unavailable');
  const layout=station.layout,isFloor=(p,y)=>Math.abs(floor(p)-y)<.05&&supported(p);
  const geometry={validateLayout:l=>l===layout,isCurrentSite:current,groundHeight:n=>point(n).y,canSweep:sweep,isStationFloor:isFloor,
   onServiceDoorChanged:syncCollision,
   canSpawnHidden:(l,now)=>{const hidden=visibility(l,now);if(!hidden)diagnostics.lastHold='camera-visible-or-uncertified';return hidden;},canOccupySpawn:p=>{const at={r:p.z/M,c:p.x/M};return isFloor(at,p.y)&&sweep(at,at,null);},
   occupants:()=>{const p=layout.doorOutside,q=layout.doorInside,all=physicalBodies(p,q);if(!all)return null;return all.filter(b=>distanceSegment(b.position,p,q)<=b.radius+4);},
   canPresentServiceActor:presentationReady,
   createEmployeeReturn:createServiceEmployeeReturn23,
   employeeReturnGeometry:{validateLayout:l=>l===layout,isCurrentSite:current,canSweep:sweep,isWorkFloor:isFloor,groundHeight:floor,hasGround:supported}};
  registration=bridge.installStationaryServiceMerchant23(sourceFactory,station,geometry,({controller,source:access})=>{
   source=access;
   const customerHost={...access,validateLayout:l=>l===layout,isCurrentSite:current,employeeReady:now=>controller.lifecycle.available&&controller.lifecycle.lastNow===now,
    validateRoute:(points,n)=>points.slice(1).every((p,i)=>sweep(points[i],p,n)&&sweep(p,points[i],n)),canSweep:sweep,isStationFloor:isFloor};
   lease=createServiceVisitLease23({layout,host:customerHost});
   const provider=createStationaryServiceAdapter({buildingId:layout.buildingId,getServiceAccess:({npc,visit,now})=>controller.serviceAccess({customer:{id:String(npc.id),generation:1,position:point(npc),hp:npc.hp,dead:npc.dead},visitId:visit.id,now})});
   Object.assign(provider,lease);return{provider,exitMovement:createServiceExitMovement23({layout,host:customerHost})};
  });
  if(!registration)throw Error('Service source registration unavailable');
 }catch(error){registration?.unregister();lease?.disposeServiceVisits();index?.removeGroup(station);station?.dispose();host.invalidateNavigation();throw error;}
 return{station,controller:registration.controller,diagnostics:()=>({...diagnostics,...registration.controller.stats,available:registration.controller.lifecycle.available,door:station.doorState,geometry:station.stats()}),syncCollision,physicalBodies,canSweep:sweep,canSpawnHidden:visibility,
  dispose(){if(disposed)return;registration.unregister();lease?.disposeServiceVisits();disposed=true;index?.removeGroup(station);station.dispose();host.invalidateNavigation();}};
}
