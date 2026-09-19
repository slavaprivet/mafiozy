// Read the same authored world solids and water support used by /walk. This
// query is independent of the player's posture, position and camera.
import {createNpcSweptFootprint} from './npc_swept_footprint.mjs';
export function createNpcNativeNavigation({worldScale=4.1,waterAt=()=>null,groundHeight=()=>0,bodiesAt=()=>[],bodiesInBounds=null,containsBody,terrainAllows=()=>true,surfaceAt=null,blocksDynamic=()=>false,height=1.9}={}){
 if(typeof containsBody!=='function')throw new TypeError('NPC navigation requires a polygon containment query');
 const counts={queries:0,solid:0,water:0,cacheHits:0,sweepQueries:0,sweepCandidates:0,sweepBlocked:0},cache=new Map(),dynamicBody={y:0,height},sweepCache=new Map(),footprint=createNpcSweptFootprint(),seenBodies=new Set();
 let activeBody=null,cacheSize=0;
 const ignoredVehicleCaches=new Map();
 function solidAtContact(c,r){
  // A footprint corner on a ramp uses its own support height, just like the
  // existing source corner probes. The centre's lower floor is not a wall.
  const floor=groundHeight(c*worldScale,r*worldScale);
  return !Number.isFinite(floor)||!(Number.isFinite(activeBody.maxYM)&&activeBody.maxYM<=floor+.05||Number.isFinite(activeBody.minYM)&&activeBody.minYM>=floor+height);
 }
 function sweep(from,to,radius=.18){
  // This supplements source terrain, water, vehicle and custom passage gates.
  if(typeof bodiesInBounds!=='function')return {swept:false};
  if(!from||!to||![from.r,from.c,to.r,to.c,radius].every(Number.isFinite)||radius<=0)return {swept:true,blocked:true};
  const key=from.r+'|'+from.c+'|'+to.r+'|'+to.c+'|'+radius,cached=sweepCache.get(key);if(cached){counts.cacheHits++;return cached;}
  counts.sweepQueries++;footprint.set(from,to,radius);seenBodies.clear();let blocked=false;
  for(const body of bodiesInBounds(footprint.minC,footprint.minR,footprint.maxC,footprint.maxR)||[]){
   if(seenBodies.has(body))continue;seenBodies.add(body);counts.sweepCandidates++;
   activeBody=body;
   if(footprint.overlaps(body.polygonCR,solidAtContact)){blocked=true;break;}
  }
  activeBody=null;
  if(blocked)counts.sweepBlocked++;const result={swept:true,blocked};if(sweepCache.size<4000)sweepCache.set(key,result);return result;
 }
 function query({r,c,ignoreVehicleId,mode,from,to,radius}={}){
  if(mode==='sweep')return sweep(from,to,radius);
  if(!Number.isFinite(r)||!Number.isFinite(c))return {blocked:true,depth:0};
  // Exact numeric coordinates avoid formatting every repeated footprint probe.
  // Keep vehicle access identities separate, with the same string coercion as
  // the previous composite key. All results still expire at the next frame.
  const ignoredId=ignoreVehicleId?String(ignoreVehicleId):null;
  let points=ignoredId===null?cache:ignoredVehicleCaches.get(ignoredId),row=points?.get(r);
  const cached=row?.get(c);if(cached){counts.cacheHits++;return cached;}
  const x=c*worldScale,z=r*worldScale,floor=groundHeight(x,z),water=waterAt(x,z);
  const depth=water&&Number.isFinite(water.level)?Math.max(0,water.level-floor):Math.max(0,Number(water?.depth)||0);
  let blocked=!Number.isFinite(floor)||!terrainAllows(x,z);
  if(!blocked)for(const body of bodiesAt(c,r)||[]){
   if(Number.isFinite(body.maxYM)&&body.maxYM<=floor+.05)continue;
   if(Number.isFinite(body.minYM)&&body.minYM>=floor+height)continue;
   if(containsBody(body,r,c)){blocked=true;break;}
  }
  // The callback only samples the current query synchronously.  Reusing this
  // small context avoids one short-lived object for every uncached route cell.
  if(!blocked){dynamicBody.y=floor;dynamicBody.ignoreId=ignoreVehicleId;blocked=!!blocksDynamic(x,z,dynamicBody);}
  counts.queries++;if(blocked)counts.solid++;if(depth>.025)counts.water++;
  const result={blocked,depth};if(surfaceAt){const surface=surfaceAt(x,z,r,c);if(surface==='land'||surface==='road')result.surface=surface;}
  if(cacheSize<30000){
   if(!points)ignoredVehicleCaches.set(ignoredId,points=new Map());
   if(!row)points.set(r,row=new Map());
   row.set(c,result);cacheSize++;
  }
  return result;
 }
 return {query,beginFrame:()=>{cache.clear();ignoredVehicleCaches.clear();cacheSize=0;sweepCache.clear();},diagnostics:()=>({...counts})};
}
