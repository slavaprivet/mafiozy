// Parking is an additive, native-4.1m layer. The serialized plan is worker-safe.
import {CAR,carCorners,createCarWorld,carFits} from './car_drive.mjs';
import {explorationKeepouts} from './exploration_scene_support.mjs';
const M=4.1,EPS=1e-7;
const overlap=(a,b,p=0)=>a.minX<b.maxX+p-EPS&&a.maxX>b.minX-p+EPS&&a.minZ<b.maxZ+p-EPS&&a.maxZ>b.minZ-p+EPS;
const inside=(r,x,z)=>x>=r.minX-EPS&&x<=r.maxX+EPS&&z>=r.minZ-EPS&&z<=r.maxZ+EPS;
function rectangleIndex(rects,size=16){const buckets=new Map();for(const rect of rects)for(let x=Math.floor(rect.minX/size);x<=Math.floor(rect.maxX/size);x++)for(let z=Math.floor(rect.minZ/size);z<=Math.floor(rect.maxZ/size);z++){const key=x+','+z;if(!buckets.has(key))buckets.set(key,[]);buckets.get(key).push(rect)}return {at:(x,z)=>buckets.get(Math.floor(x/size)+','+Math.floor(z/size))||[],near(rect,pad=0){const out=new Set();for(let x=Math.floor((rect.minX-pad)/size);x<=Math.floor((rect.maxX+pad)/size);x++)for(let z=Math.floor((rect.minZ-pad)/size);z<=Math.floor((rect.maxZ+pad)/size);z++)for(const r of buckets.get(x+','+z)||[])out.add(r);return [...out]}}}
function rectAt(origin,dx,dz,u0,u1,v0,v1){const points=[[u0,v0],[u1,v0],[u1,v1],[u0,v1]].map(([u,v])=>({x:origin.x+dz*u+dx*v,z:origin.z-dx*u+dz*v}));return {minX:Math.min(...points.map(p=>p.x)),maxX:Math.max(...points.map(p=>p.x)),minZ:Math.min(...points.map(p=>p.z)),maxZ:Math.max(...points.map(p=>p.z))}}
const point=(o,dx,dz,u,v)=>({x:o.x+dz*u+dx*v,z:o.z-dx*u+dz*v});
function cells(rect,m,visit){for(let r=Math.floor((rect.minZ+EPS)/m);r<Math.ceil((rect.maxZ-EPS)/m);r++)for(let c=Math.floor((rect.minX+EPS)/m);c<Math.ceil((rect.maxX-EPS)/m);c++)if(!visit(r,c))return false;return true}
export function isCityParkingSurface(plan,x,z){return Number.isFinite(x+z)&&plan.surfaceRects.some(r=>inside(r,x,z))}
export function cityParkingGroundHeight(plan,x,z){return isCityParkingSurface(plan,x,z)?0:null}
// Convex polygon subtraction provides exact support coverage, including the
// small holes between a rectangular driveway and a grid-aligned road edge.
function clip(poly,axis,value,greater){const out=[];for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length],aa=greater?a[axis]>=value-EPS:a[axis]<=value+EPS,bb=greater?b[axis]>=value-EPS:b[axis]<=value+EPS;if(aa)out.push(a);if(aa!==bb){const t=(value-a[axis])/(b[axis]-a[axis]);out.push([a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t])}}return out}
function area(p){let sum=0;for(let i=0;i<p.length;i++){const a=p[i],b=p[(i+1)%p.length];sum+=a[0]*b[1]-a[1]*b[0]}return Math.abs(sum)/2}
function subtract(poly,rect){let rest=poly;const out=[];for(const [axis,value,greater] of [[0,rect.minX,true],[0,rect.maxX,false],[1,rect.minZ,true],[1,rect.maxZ,false]]){const outside=clip(rest,axis,value,!greater);if(area(outside)>EPS)out.push(outside);rest=clip(rest,axis,value,greater);if(!rest.length)break}return out}
export function cityParkingCarFits(plan,x,z,yaw,shape=CAR){
 if(![x,z,yaw].every(Number.isFinite))return false;
 const polygon=carCorners(x,z,yaw,shape),bounds={minX:Math.min(...polygon.map(p=>p[0])),maxX:Math.max(...polygon.map(p=>p[0])),minZ:Math.min(...polygon.map(p=>p[1])),maxZ:Math.max(...polygon.map(p=>p[1]))};
 // This support contract complements runtime solid-body collision, never bypasses it.
 let uncovered=[polygon];for(const rect of [...plan.surfaceRects,...plan.roadSupportRects]){if(!overlap(bounds,rect))continue;uncovered=uncovered.flatMap(p=>subtract(p,rect));if(!uncovered.length)return true}return false;
}
export function createCityParkingPlan({topology,instances=[],keepouts=[],railPlan=null,metresPerCell=M,maxLots=60}={}){
 if(metresPerCell!==M||!topology?.roadMask||!topology?.grid)throw Error('Parking requires unchanged native4.1 topology');
 const m=M,raw=instances.map(i=>i.userData?.instance||i),reserved=[...explorationKeepouts(raw,m),...keepouts],reservedIndex=rectangleIndex(reserved),lots=[],bays=[],signs=[],colliders=[],surfaceRects=[],accessKeepouts=[],skipped=[];
 const safeCell=(r,c,road=false)=>!(topology.protectedMask?.[r]?.[c]||topology.policeMask?.[r]?.[c])&&(road?topology.grid[r]?.[c]===0&&!!topology.roadMask[r]?.[c]:[8,9].includes(topology.grid[r]?.[c])&&!topology.roadMask[r]?.[c]);
 const clear=(rect,{road=false,pad=.35}={})=>cells(rect,m,(r,c)=>safeCell(r,c,road))&&!reservedIndex.near(rect,pad).some(b=>overlap(rect,b,pad))&&!surfaceRects.some(b=>overlap(rect,b,2))&&(!railPlan||(()=>{for(let x=rect.minX;x<=rect.maxX;x+=1.5)for(let z=rect.minZ;z<=rect.maxZ;z+=1.5)if(railPlan.blocksPlacement(x,z,2))return false;return !railPlan.blocksPlacement(rect.maxX,rect.maxZ,2)})());
 const roadSupportRects=[];for(let r=0;r<topology.grid.length;r++){let start=-1;for(let c=0;c<=topology.grid[r].length;c++){if(c<topology.grid[r].length&&safeCell(r,c,true)){if(start<0)start=c}else if(start>=0){roadSupportRects.push({minX:start*m,maxX:c*m,minZ:r*m,maxZ:(r+1)*m});start=-1}}}
 const world=createCarWorld(topology,raw.flatMap(i=>i.collision?.worldBodies||[]),m),candidates=[];
 // Each candidate is a verified straight frontage with a six-metre carriageway
 // behind it; a driveway cannot emerge at a dead corner or cross an intersection.
 for(let r=1;r<topology.grid.length-1;r++)for(let c=1;c<topology.grid[r].length-1;c++)if(safeCell(r,c,true))for(const [dx,dz]of[[1,0],[-1,0],[0,1],[0,-1]]){
  if(!safeCell(r+dz,c+dx))continue;const origin={x:(c+.5+dx*.5)*m,z:(r+.5+dz*.5)*m};
  if(!cells(rectAt(origin,dx,dz,-9,9,-6,-.02),m,(r,c)=>safeCell(r,c,true)))continue;
  for(const bayCount of [4,2]){const width=bayCount*3.2+1.6,yard=rectAt(origin,dx,dz,-width/2,width/2,2,14),driveway=rectAt(origin,dx,dz,-4.5,4.5,0,2.1);
  if(clear(yard)&&clear(driveway))candidates.push({origin,dx,dz,yard,driveway,bayCount,width,layout:'perpendicular'})}
  const width=14.4,yard=rectAt(origin,dx,dz,-7.2,7.2,0,4.4),driveway=rectAt(origin,dx,dz,-7.2,7.2,0,.1);
  if(clear(yard))candidates.push({origin,dx,dz,yard,driveway,bayCount:1,width,layout:'parallel'});
 }
 const targets=raw.filter(i=>i.footprint&&(/hospital/i.test(i.assetId)||i.role==='residence'||i.role==='glass_tower')).sort((a,b)=>Number(/hospital/i.test(b.assetId))-Number(/hospital/i.test(a.assetId))||a.id.localeCompare(b.id));
 for(const building of targets){if(lots.length>=maxLots)break;const door=building.entry?.anchorRC,anchor=door?{x:door.c*m,z:door.r*m}:{x:(building.footprint.minC+building.footprint.maxC)*m/2,z:(building.footprint.minR+building.footprint.maxR)*m/2};
  const available=candidates.map(candidate=>({...candidate,distance:Math.hypot(candidate.origin.x-anchor.x,candidate.origin.z-anchor.z)})).filter(c=>c.distance<95).sort((a,b)=>a.distance-b.distance);let accepted=null;
  for(const candidate of available){const {origin,dx,dz,yard,driveway}=candidate;if(!clear(yard)||!clear(driveway))continue;
   const yaw=Math.atan2(dx,dz),entryPaths=candidate.layout==='parallel'?[Array.from({length:65},(_,i)=>{const t=i/64,u=-9+12.6*t,v=-2.5+4.7*t*t*(3-2*t),du=12.6,dv=28.2*t*(1-t);return {...point(origin,dx,dz,u,v),yaw:Math.atan2(dz*du+dx*dv,-dx*du+dz*dv)}})]:[-1,1].map(side=>Array.from({length:49},(_,i)=>{const angle=i/48*Math.PI/2,u=side*4.8*(1-Math.sin(angle)),v=2.3-4.8*Math.cos(angle),du=-side*Math.cos(angle),dv=Math.sin(angle);return {...point(origin,dx,dz,u,v),yaw:Math.atan2(dz*du+dx*dv,-dx*du+dz*dv)}}));
   const support={surfaceRects:[yard,driveway],roadSupportRects};
   if(entryPaths.flat().some(p=>!carFits(p.x,p.z,p.yaw,world)||!cityParkingCarFits(support,p.x,p.z,p.yaw)))continue;
   accepted={...candidate,yaw,entryPath:entryPaths[0],entryPaths};break;
  }
  if(!accepted){skipped.push({buildingId:building.id,reason:'no_clear_frontage_with_native_road_access_within_95m'});continue}
  const {origin,dx,dz,yard,driveway,yaw,entryPath,entryPaths,distance,bayCount,width,layout}=accepted,id='parking:'+building.id,hospital=/hospital/i.test(building.assetId),name=hospital?'Парковка больницы':'Парковка у дома',parallel=layout==='parallel';
  const lot={id,buildingId:building.id,kind:hospital?'hospital':'residential',name,origin,dx,dz,yaw,layout,groundY:0,width,depth:parallel?4.4:12,aisleWidth:parallel?0:6.2,bayWidth:3.2,bayLength:parallel?6.4:5.4,bayCount,distanceToDoor:distance,rect:yard,driveway,entryPath,entryPaths,exitRule:'yield_to_road_and_pedestrians',mouth:point(origin,dx,dz,0,-2),tour:{...point(origin,dx,dz,-width/2+2.2,3),yaw},bayIds:[]};
  lots.push(lot);surfaceRects.push({id:id+':lot',...yard},{id:id+':driveway',...driveway});accessKeepouts.push({id:id+':access',...rectAt(origin,dx,dz,parallel?-11.7:-7.4,7.4,-6,parallel?4.4:2.2)});
  for(let index=0;index<bayCount;index++){const bay={id:id+':bay:'+index,lotId:id,...point(origin,dx,dz,parallel?3.6:(index-(bayCount-1)/2)*3.2,parallel?2.2:10.9),yaw:parallel?yaw+Math.PI/2:yaw,width:3.2,length:parallel?6.4:5.4};bays.push(bay);lot.bayIds.push(bay.id)}
  for(const [kind,u,v,signYaw]of (parallel?[['parking',-6.6,3.7,yaw-Math.PI/2]]:[['parking',-width/2+.6,2.65,yaw+Math.PI],['yield',width/2-.6,2.65,yaw]])){const sign={id:id+':'+kind,lotId:id,kind,...point(origin,dx,dz,u,v),y:0,yaw:signYaw};signs.push(sign);colliders.push({id:sign.id,source:'city_parking',minYM:0,maxYM:2.9,groundRadius:.15,polygonCR:Array.from({length:8},(_,i)=>[(sign.x+Math.cos(i*Math.PI/4)*.15)/m,(sign.z+Math.sin(i*Math.PI/4)*.15)/m])})}
 }
 // A shared lot serves a building only when a dry collision-free walking route
 // to its real public entrance exists. This is access evidence, not a new sidewalk.
 const {coverage,walkingRoutes:chosenRoutes}=computeCityParkingWalks({lots,raw,targets,topology,keepouts,railPlan,colliders,m});
 const plan={version:1,metresPerCell:m,lots,bays,signs,colliders,surfaceRects,accessKeepouts,keepouts:surfaceRects.map(r=>({...r})),roadSupportRects,skipped,coverage,walkingRoutes:chosenRoutes,mapFeatures:lots.map(l=>({id:l.id,kind:'parking',type:'parking',name:l.name,x:(l.rect.minX+l.rect.maxX)/2,z:(l.rect.minZ+l.rect.maxZ)/2,radius:5})),stats:{lots:lots.length,bays:bays.length,hospitalLots:lots.filter(l=>l.kind==='hospital').length,residentialLots:lots.filter(l=>l.kind==='residential').length,skipped:skipped.length,servedBuildings:coverage.filter(c=>c.status==='served').length,uncoveredBuildings:coverage.filter(c=>c.status==='uncovered').length,pointLights:0},limitations:['Supports validated sedan-sized access; player/runtime collisions still apply.','No parking AI, ownership or gameplay identifiers are created.','Unfit buildings are explicitly skipped instead of paving occupied land.','Walking coverage proves dry physical access; road crossings retain actual traffic priority.']};
 for(const lot of lots)for(const p of lot.entryPath)if(!cityParkingCarFits(plan,p.x,p.z,p.yaw))throw Error('Parking entry support gap: '+lot.id);
 return plan;
}




function computeCityParkingWalks({lots,raw,targets,topology,keepouts,railPlan,colliders,m,extraBodies=[]}){
 const rectKey=r=>['minX','maxX','minZ','maxZ'].map(k=>r[k].toFixed(6)).join(','),baseKeepouts=new Set(explorationKeepouts(raw,m).map(rectKey)),extraWalkKeepouts=rectangleIndex(keepouts.filter(r=>!baseKeepouts.has(rectKey(r))));
 const walker=createCarWorld(topology,[...raw.flatMap(i=>i.collision?.worldBodies||[]),...colliders,...extraBodies],m),step=m/2,walkingRoutes=[],coverage=[],walkCache=new Map();
 function walkable(x,z){for(const [dx,dz]of[[0,0],[.38,0],[-.38,0],[0,.38],[0,-.38]]){const xx=x+dx,zz=z+dz,r=Math.floor(zz/m),c=Math.floor(xx/m);if(!walker(xx,zz)||topology.protectedMask?.[r]?.[c]||railPlan?.blocksPlacement?.(xx,zz,.4)||extraWalkKeepouts.at(xx,zz).some(b=>inside(b,xx,zz)))return false}return true}
 const edgeClear=(a,b)=>{const n=Math.max(1,Math.ceil(Math.hypot(a.x-b.x,a.z-b.z)/.4));for(let i=0;i<=n;i++)if(!walkable(a.x+(b.x-a.x)*i/n,a.z+(b.z-a.z)*i/n))return false;return true};
 for(const lot of lots){lot.servedBuildingIds=[];const start=point(lot.origin,lot.dx,lot.dz,0,lot.layout==='parallel'?2.2:5),goals=targets.map(b=>({building:b,anchor:(()=>{const a=b.entry?.anchorRC,p=b.entry?.roadProbeRC;if(!a||!p)return null;const x=(p.c-a.c)*m,z=(p.r-a.r)*m,d=Math.hypot(x,z);return {x:a.c*m+x/d*.7,z:a.r*m+z/d*.7}})()})).filter(g=>g.anchor&&Math.hypot(start.x-g.anchor.x,start.z-g.anchor.z)<=100);if(!goals.length)continue;
  const sr=Math.round(start.z/step),sc=Math.round(start.x/step),key=(r,c)=>r+','+c,startKey=key(sr,sc),startNode={r:sr,c:sc,key:startKey,parent:null,distance:0},queue=[startNode],visited=new Set([startKey]),endpoints=new Set();
  for(let qi=0;qi<queue.length&&endpoints.size<goals.length;qi++){const node=queue[qi],p={x:node.c*step,z:node.r*step};if(node.distance>125)continue;
   for(const goal of goals){if(endpoints.has(goal.building.id)||Math.hypot(p.x-goal.anchor.x,p.z-goal.anchor.z)>2.4||!edgeClear(p,goal.anchor))continue;const route=[goal.anchor,p];let prev=node.parent;while(prev){route.push({x:prev.c*step,z:prev.r*step});prev=prev.parent}route.push(start);route.reverse();if(!edgeClear(start,route[1]))continue;const distance=route.slice(1).reduce((sum,p,i)=>sum+Math.hypot(p.x-route[i].x,p.z-route[i].z),0);if(distance>125)continue;endpoints.add(goal.building.id);walkingRoutes.push({lotId:lot.id,buildingId:goal.building.id,distance,points:route})}
   for(const [dr,dc]of[[1,0],[-1,0],[0,1],[0,-1]]){const r=node.r+dr,c=node.c+dc,k=key(r,c);if(visited.has(k))continue;const q={x:c*step,z:r*step};if(Math.hypot(q.x-start.x,q.z-start.z)>101)continue;const ek=node.key<k?node.key+'|'+k:k+'|'+node.key;let safe=walkCache.get(ek);if(safe===undefined){safe=edgeClear(p,q);walkCache.set(ek,safe)}if(safe){visited.add(k);queue.push({r,c,key:k,parent:node,distance:node.distance+step})}}
  }
 }
 for(const b of targets){const best=walkingRoutes.filter(r=>r.buildingId===b.id).sort((a,b)=>a.distance-b.distance)[0];coverage.push(best?{buildingId:b.id,lotId:best.lotId,walkingDistance:best.distance,status:'served'}:{buildingId:b.id,status:'uncovered',reason:'no_verified_dry_public_entrance_walk_within_125m'});if(best)lots.find(l=>l.id===best.lotId).servedBuildingIds.push(b.id)}
 const chosenRoutes=walkingRoutes.filter(r=>coverage.some(c=>c.buildingId===r.buildingId&&c.lotId===r.lotId));
 return {coverage,walkingRoutes:chosenRoutes};
}
/** Re-route walking links after road equipment exists, without moving parking. */
export function replanCityParkingWalks(plan,{topology,instances=[],keepouts=[],railPlan=null,extraBodies=[]}={}){
 const lots=plan.lots.map(l=>({...l,servedBuildingIds:[]})),raw=instances.map(i=>i.userData?.instance||i),targets=raw.filter(i=>i.footprint&&(/hospital/i.test(i.assetId)||i.role==='residence'||i.role==='glass_tower')).sort((a,b)=>Number(/hospital/i.test(b.assetId))-Number(/hospital/i.test(a.assetId))||a.id.localeCompare(b.id));
 const {coverage,walkingRoutes}=computeCityParkingWalks({lots,raw,targets,topology,keepouts,railPlan,colliders:plan.colliders,m:plan.metresPerCell,extraBodies});
 return {...plan,lots,coverage,walkingRoutes,stats:{...plan.stats,servedBuildings:coverage.filter(c=>c.status==='served').length,uncoveredBuildings:coverage.filter(c=>c.status==='uncovered').length}};
}
