import {CAR} from './car_drive.mjs';
import {cityParkingCarFits} from './city_parking_plan.mjs';
import {createLaneConnector} from './city_lane_connector.mjs';
import {collisionPolygon} from './vehicle_collision_shape.mjs';
import {polygonVehicleContact} from './vehicle_contact.mjs';

const RADIUS=4.3,STEP=.065,MAX_CACHE=128;
const angle=n=>Math.atan2(Math.sin(n),Math.cos(n));
const finite=p=>p&&[p.x,p.z,p.yaw].every(Number.isFinite);
const inside=(p,r)=>r&&p.x>=r.minX&&p.x<=r.maxX&&p.z>=r.minZ&&p.z<=r.maxZ;
const gap=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
const poseKey=p=>[p.x,p.z,p.yaw].join(',');

// Standard 2/4-bay yards need a reverse-out manoeuvre before their outward-
// facing driveway. Each tuple is [gear, steering sign, metres]. These bounded
// templates were solved once, not searched in an actor update. Every arc has
// radius 4.3m; the last C1 segment joins the actual driveway pose. The templates
// are merely candidates: every returned pose is checked against the current
// full vehicle hull and solids. Occupied neighbouring bays may block them.
const MANOEUVRES={
 '4:0':[[[-1,1,6],[-1,0,1],[-1,1,3],[1,-1,2],[-1,1,1],[-1,0,1]]],
 '4:1':[[[-1,-1,5],[1,0,1],[1,1,3],[1,0,1],[1,1,2],[-1,-1,2]]],
 '4:2':[
  [[-1,-1,1],[-1,1,1],[-1,-1,5],[1,1,5],[-1,-1,1],[-1,0,1],[-1,-1,2]],
  [[-1,-1,6],[1,1,5],[-1,-1,2],[-1,0,1]]
 ],
 '4:3':[[[-1,-1,6],[1,1,2],[-1,-1,3]]],
 '2:0':[[[-1,-1,1],[-1,1,1],[-1,-1,1],[1,1,4],[-1,-1,2],[1,1,2],[-1,-1,1]]],
 '2:1':[
  [[-1,1,1],[-1,-1,6],[1,1,2],[-1,-1,2],[1,1,3],[-1,-1,3],[-1,1,1],[-1,0,1],[1,-1,1]],
  [[-1,-1,5],[1,1,2],[-1,-1,2],[1,1,3],[-1,-1,3],[-1,1,1]]
 ]
};

// The outer hospital bays cannot reach the nine-metre driveway with one arc
// while the three neighbouring bays are occupied. These deterministic,
// orientation-independent low-speed manoeuvres use the same 4.3m turning
// radius as the lane connector and finish beside an inbound driveway curve.
const OCCUPIED_BAY_MANOEUVRES={
 '4:0':[
  [-1,1,.3],[-1,0,2.4],[-1,1,.6],[1,-1,.9],[-1,1,.3],[-1,0,.3],[-1,1,.6],[-1,0,1.5],[-1,-1,.6],[-1,0,.6],[-1,-1,.3],[-1,0,.6],[-1,-1,.3],[-1,0,.3],[-1,-1,.6],[1,1,1.2],[1,0,.9],
  [1,-1,.6],[-1,1,.9],[-1,-1,.9],[1,1,.55],[1,0,.65],[1,-1,.25]
 ],
 '4:3':[
  [-1,0,.6],[-1,-1,.9],[-1,0,.3],[-1,-1,1.5],[1,1,.3],[-1,-1,1.5],[-1,0,.3],[-1,-1,.3],[-1,0,.3],[-1,-1,.6],[-1,0,3],[-1,1,.9],[-1,0,.6],[-1,1,.3],[1,-1,1.8],[-1,1,.9],[1,-1,.6],
  [-1,0,.3],[-1,1,.45],[1,-1,.55],[1,0,.3],[1,1,.15],[1,0,.05],[1,1,.15],[-1,-1,.1]
 ]
};

export function validateParkingVehicleProfile(profile){
 if(profile===undefined||profile===null)return CAR;
 if(!Number.isFinite(profile.halfLength)||!Number.isFinite(profile.halfWidth)||profile.halfLength<=0||profile.halfWidth<=0||profile.halfLength>20||profile.halfWidth>10)return null;
 if(profile.collisionHull!==undefined&&(!Array.isArray(profile.collisionHull)||profile.collisionHull.length<3||profile.collisionHull.length>64||!profile.collisionHull.every(p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite))))return null;
 return {...CAR,...profile};
}

function advance(p,metres,curvature){
 const yaw=p.yaw+metres*curvature;
 return Math.abs(curvature)<1e-10?{x:p.x+Math.sin(yaw)*metres,z:p.z+Math.cos(yaw)*metres,yaw}:{x:p.x+(Math.cos(p.yaw)-Math.cos(yaw))/curvature,z:p.z+(Math.sin(yaw)-Math.sin(p.yaw))/curvature,yaw};
}
function actionPath(from,actions){
 const points=[{x:from.x,z:from.z,yaw:from.yaw,gear:actions[0][0]<0?'reverse':'forward'}];
 for(const [direction,steer,metres] of actions){
  const start=points.at(-1),count=Math.ceil(metres/STEP),gear=direction<0?'reverse':'forward';
  for(let i=1;i<=count;i++)points.push({...advance(start,direction*metres*i/count,steer/RADIUS),gear});
 }
 return points;
}
function templatePath(from,to,actions){
 const points=actionPath(from,actions);
 const join=createLaneConnector({from:points.at(-1),to,isRoad:()=>true,poseAllowed:()=>true,minRadius:RADIUS,sampleStep:STEP});
 if(!join)return null;
 return points.concat(join.points.slice(1).map(p=>({...p,gear:'forward'})));
}
function gearChanges(points){
 const out=[];for(let i=1;i<points.length;i++)if(points[i].gear!==points[i-1].gear)out.push({pointIndex:i-1,from:points[i-1].gear,to:points[i].gear,requiresStop:true});return out;
}
function clearPath(points,fits){
 for(let i=0;i<points.length;i++){
  const p=points[i];if(!finite(p)||!fits(p.x,p.z,p.yaw))return false;
  if(!i)continue;
  const a=points[i-1],distance=gap(a,p),dyaw=angle(p.yaw-a.yaw),n=Math.max(1,Math.ceil(distance/STEP),Math.ceil(Math.abs(dyaw)/(.9*Math.PI/180)));
  if(distance<1e-9){if(Math.abs(dyaw)>1e-8)return false;continue;}
  const movement=(p.x-a.x)*Math.sin(a.yaw+dyaw/2)+(p.z-a.z)*Math.cos(a.yaw+dyaw/2);
  if(movement/distance*(p.gear==='reverse'?-1:1)<.998)return false;
  for(let j=1;j<n;j++){const t=j/n;if(!fits(a.x+(p.x-a.x)*t,a.z+(p.z-a.z)*t,a.yaw+dyaw*t))return false;}
 }
 return true;
}
// A stopped reverse departure already on an authored exit resumes that path.
// Match position AND interpolated body yaw; never snap an arbitrary pose onto it.
function remainingExit(from,exit){
 for(let i=1;i<exit.points.length;i++){
  const a=exit.points[i-1],b=exit.points[i],dx=b.x-a.x,dz=b.z-a.z,lengthSq=dx*dx+dz*dz;
  if(!lengthSq)continue;
  const t=Math.max(0,Math.min(1,((from.x-a.x)*dx+(from.z-a.z)*dz)/lengthSq));
  if(Math.hypot(from.x-a.x-dx*t,from.z-a.z-dz*t)>1e-7||Math.abs(angle(from.yaw-a.yaw-angle(b.yaw-a.yaw)*t))>1e-7)continue;
  return [{...from,gear:exit.gear},...exit.points.slice(t>=1-1e-10?i+1:i).map(p=>({...p,gear:exit.gear}))];
 }
 return null;
}
function neighbouringBayPolygons(parking,lot,bay,shape){
 if(!bay)return [];
 return (parking.bays||[]).filter(other=>other.lotId===lot.id&&other.id!==bay.id).map(other=>({x:other.x,z:other.z,polygon:collisionPolygon(other.x,other.z,other.yaw,shape)}));
}
function neighbouringBayClear(neighbours,shape,x,z,yaw){
 if(!neighbours.length)return true;
 let moving=null;const reach=2*Math.hypot(shape.halfLength,shape.halfWidth);
 for(const other of neighbours){
  if(Math.hypot(x-other.x,z-other.z)>reach)continue;
  moving||=collisionPolygon(x,z,yaw,shape);
  if(polygonVehicleContact(moving,other.polygon))return false;
 }
 return true;
}
function reverseEntryOptions({parking,lot,bay,origin,safeFits,index,firstOnly=false}){
 if(!bay||lot.layout!=='perpendicular')return [];
 const options=[],entries=(parking.access?.routes||[]).filter(r=>r.lotId===lot.id&&r.kind==='entry'&&r.points?.length>1);
 for(const entry of entries){
  const target=entry.points.at(-1),shift=Math.PI;
  const connector=createLaneConnector({from:{...origin,yaw:origin.yaw+shift},to:{...target,yaw:target.yaw+shift},isRoad:()=>true,poseAllowed:(x,z,yaw)=>safeFits(x,z,yaw-shift),minRadius:RADIUS,sampleStep:STEP});
  if(connector){
   const approach=connector.points.map(p=>({...p,yaw:p.yaw-shift,gear:'reverse'})),tail=entry.points.slice().reverse().slice(1).map(p=>({...p,gear:'reverse'}));
   options.push({path:approach.concat(tail),point:{...entry.points[0]},complete:true});
   if(firstOnly)return options;
  }
  const actions=OCCUPIED_BAY_MANOEUVRES[lot.bayCount+':'+index];
  if(!actions)continue;
  const manoeuvre=actionPath(origin,actions);if(!clearPath(manoeuvre,safeFits))continue;
  const reverse=entry.points.slice().reverse().map(p=>({...p,gear:'reverse'}));
  for(let join=0;join<Math.min(16,reverse.length);join++){
   if(!clearPath([manoeuvre.at(-1),reverse[join]],safeFits))continue;
   options.unshift({path:manoeuvre.concat(reverse.slice(join)),point:{...entry.points[0]},complete:true});if(firstOnly)return options;break;
  }
 }
 return options;
}

/** Reusable geometry cache. x/z and profile sizes are metres, yaw faces +Z.
 * poseAllowed receives (x,z,yaw,profile) and must check that complete profile.
 * No lane search, actor movement, allocation of game IDs, or clearance cache.
 */
export function createParkingOriginResolver({parking,isRoad,poseAllowed}={}){
 const geometry=new Map(),supportByLot=new Map();let geometryBuilds=0,cacheHits=0,checkedPaths=0;
 const remember=(key,value)=>{geometry.set(key,value);if(geometry.size>MAX_CACHE)geometry.delete(geometry.keys().next().value);return value;};
 function support(lot){
  let result=supportByLot.get(lot);
  if(!result){
   const relevant=(r)=>r.minX<lot.rect.maxX+40&&r.maxX>lot.rect.minX-40&&r.minZ<lot.rect.maxZ+40&&r.maxZ>lot.rect.minZ-40;
   result={surfaceRects:(parking.surfaceRects||[lot.rect,lot.driveway]).filter(Boolean).filter(relevant),roadSupportRects:(parking.roadSupportRects||[]).filter(Boolean).filter(relevant)};supportByLot.set(lot,result);
  }
  return result;
 }
 function candidates(from,lot,exit){
  const key=lot.id+'|'+poseKey(from)+'|'+poseKey(exit.points[0]);
  if(geometry.has(key)){cacheHits++;return geometry.get(key);}
  geometryBuilds++;
  const target=exit.points[0],paths=[],bay=(parking.bays||[]).find(b=>b.lotId===lot.id&&gap(b,from)<1e-6&&Math.abs(angle(b.yaw-from.yaw))<1e-6);
  if(lot.layout==='perpendicular'&&bay){
   const index=lot.bayIds?.indexOf(bay.id)??(parking.bays||[]).filter(b=>b.lotId===lot.id).indexOf(bay);
   for(const actions of MANOEUVRES[lot.bayCount+':'+index]||[]){const p=templatePath(from,target,actions);if(p)paths.push(p);}
  }
  return remember(key,paths);
 }
 function resolve({from,profile,firstOnly=false}={}){
  const shape=validateParkingVehicleProfile(profile);
  if(!shape||!from||!Number.isFinite(from.x)||!Number.isFinite(from.z)||typeof poseAllowed!=='function'||typeof isRoad!=='function')return [];
  const lot=parking?.lots?.find(l=>inside(from,l.rect)||inside(from,l.driveway));
  if(!lot)return [{point:from,prefix:[]}];
  const starts=[],paved=support(lot),checkedJoins=new Map(),fits=(x,z,yaw)=>poseAllowed(x,z,yaw,shape)&&(!parking.surfaceRects||cityParkingCarFits(paved,x,z,yaw,shape));
  for(const exit of parking.access?.routes||[]){
   if(exit.lotId!==lot.id||exit.kind!=='exit'||!exit.points?.length)continue;
   const target=exit.points[0],bodyYaw=Number.isFinite(from.yaw)?from.yaw:target.yaw,origin={x:from.x,z:from.z,yaw:bodyYaw},shift=exit.gear==='reverse'?Math.PI:0;
   if(!fits(origin.x,origin.z,origin.yaw))continue;
   const remaining=lot.layout==='parallel'&&exit.gear==='reverse'?remainingExit(origin,exit):null;
   if(remaining?.length>1&&clearPath(remaining,fits)){
    checkedPaths++;starts.push({point:{...exit.points.at(-1)},prefix:remaining,accessRouteId:exit.id,lotId:lot.id,gearChanges:gearChanges(remaining),requiresLiveClearance:true,minRadiusM:RADIUS,speedLimitKmh:5});if(firstOnly)return starts;continue;
   }
   const bay=(parking.bays||[]).find(b=>b.lotId===lot.id&&gap(b,origin)<1e-6&&Math.abs(angle(b.yaw-origin.yaw))<1e-6),index=bay?(lot.bayIds?.indexOf(bay.id)??(parking.bays||[]).filter(b=>b.lotId===lot.id).indexOf(bay)):-1,hasEntry=(parking.access?.routes||[]).some(r=>r.lotId===lot.id&&r.kind==='entry'&&r.points?.length>1),guardNeeded=hasEntry&&bay&&(lot.bayCount===2&&index===0||lot.bayCount===4&&[0,1,3].includes(index));
   const neighbours=guardNeeded?neighbouringBayPolygons(parking,lot,bay,shape):[];
   const safeFits=(x,z,yaw)=>fits(x,z,yaw)&&(!guardNeeded||neighbouringBayClear(neighbours,shape,x,z,yaw));
   const options=guardNeeded?reverseEntryOptions({parking,lot,bay,origin,safeFits,index,firstOnly}):[];
   const direct=createLaneConnector({from:{...origin,yaw:bodyYaw+shift},to:{...target,yaw:target.yaw+shift},isRoad:(x,z)=>isRoad(x,z)||inside({x,z},lot.rect)||inside({x,z},lot.driveway),poseAllowed:(x,z,yaw)=>safeFits(x,z,yaw-shift)});
   if(direct)options.push({path:direct.points.map(p=>({...p,yaw:p.yaw-shift,gear:exit.gear||'forward'})),point:{...exit.points.at(-1)}});
   options.push(...candidates(origin,lot,exit).map(path=>({path,point:{...exit.points.at(-1)}})));
   for(const option of options){const path=option.path;
    if(!checkedJoins.has(path))checkedJoins.set(path,clearPath(path,safeFits));
    if(!checkedJoins.get(path))continue;
    if(option.complete){
     checkedPaths++;const prefix=path;
     starts.push({point:{...option.point},prefix:prefix.map(p=>({...p})),accessRouteId:exit.id,lotId:lot.id,gearChanges:gearChanges(prefix),requiresLiveClearance:true,minRadiusM:RADIUS,speedLimitKmh:5});if(firstOnly)return starts;break;
    }
    const tail=exit.points.map(p=>({...p,gear:exit.gear||'forward'}));checkedPaths++;
    if(!clearPath(tail,safeFits))continue;
    const prefix=path.concat(tail.slice(1));
    starts.push({point:{...exit.points.at(-1)},prefix:prefix.map(p=>({...p})),accessRouteId:exit.id,lotId:lot.id,gearChanges:gearChanges(prefix),requiresLiveClearance:true,minRadiusM:RADIUS,speedLimitKmh:5});if(firstOnly)return starts;break;
   }
  }
  return starts;
 }
 return {resolve,diagnostics:()=>({geometryBuilds,cacheHits,checkedPaths,cachedGeometries:geometry.size}),clear(){geometry.clear();supportByLot.clear();}};
}

const resolvers=new WeakMap();
/** Convenience wrapper; reuse is keyed by immutable parking plan and predicates. */
export function getParkingOrigins({from,parking,isRoad,poseAllowed,profile,firstOnly=false}={}){
 if(!parking)return [];
 let cached=resolvers.get(parking);
 if(!cached||cached.isRoad!==isRoad||cached.poseAllowed!==poseAllowed){cached={isRoad,poseAllowed,resolver:createParkingOriginResolver({parking,isRoad,poseAllowed})};resolvers.set(parking,cached);}
 return cached.resolver.resolve({from,profile,firstOnly});
}
